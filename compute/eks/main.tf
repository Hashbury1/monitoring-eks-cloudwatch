# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
  
  cluster_name    = "${var.app_name}-eks"
  cluster_version = "1.30"
  
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids
  
  eks_managed_node_groups = {
    workers = {
      min_size     = 2
      max_size     = 4
      desired_size = 2
      instance_types = ["t3.medium"]

      cluster_addons = {
        coredns           = {}
        kube-proxy        = {}
        vpc-cni           = {}
        aws-ebs-csi-driver = {}
        container-insights = {}  # ← ENABLES pod_cpu_utilization metrics
      }
    }
  }
  
  # Enable CloudWatch Container Insights
  cluster_enabled_log_types = ["api", "audit", "authenticator"]
  cluster_addons = {
    coredns = {}
    kube-proxy = {}
    vpc-cni = {}
    aws-ebs-csi-driver = {}
  }
}

# CloudWatch Observability Operator (for Prometheus federation)
resource "helm_release" "cloudwatch_observability" {
  name       = "amazon-cloudwatch"
  repository = "https://aws.github.io/observability"
  chart      = "amazon-cloudwatch-observability"
  namespace  = "amazon-cloudwatch"
  
  create_namespace = true
  
  set {
    name  = "image.repository"
    value = "public.ecr.aws/aws-observability/aws-otel-collector"
  }
  
  depends_on = [module.eks]
}

# Prometheus + Grafana (kube-prom-stack)
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  create_namespace = true
  
  values = [
    file("${path.module}/prometheus-values.yaml")
  ]
  
  depends_on = [module.eks, helm_release.cloudwatch_observability]
}

# Sample App Deployment
resource "kubectl_manifest" "app_deployment" {
  yaml_body = file("${path.module}/app-deployment.yaml")
  
  depends_on = [helm_release.prometheus]
}
