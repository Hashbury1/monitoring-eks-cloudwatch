
terraform {
  required_providers {
    aws         = { source = "hashicorp/aws" }
    helm        = { source = "hashicorp/helm" }
    kubernetes  = { source = "hashicorp/kubernetes" }
  }
}

# Providers configuration
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}



# AWS SNS configuration

resource "aws_sns_topic" "alerts" {
  name = "${var.app_name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Example CPU alarm on EKS worker nodes
resource "aws_cloudwatch_metric_alarm" "node_cpu_high" {
  alarm_name          = "${var.app_name}-node-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.app_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type       = "metric",
        x          = 0,
        y          = 0,
        width      = 12,
        height     = 6,
        properties = {
          title   = "EKS Node CPU"
          metrics = [
            [ "ContainerInsights", "node_cpu_utilization", { "stat": "Average" } ]
          ]
          period = 60
          view   = "timeSeries"
          region = var.aws_region
        }
      }
    ]
  })
}



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
