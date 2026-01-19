terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    helm = { source = "hashicorp/helm", version = "~> 2.12" }
  }
}

provider "aws" {
  region = var.aws_region
}

# Working Modules
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.app_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # PITFALL FIXES:
  enable_nat_gateway     = true
  one_nat_gateway_per_az = true
  enable_dns_hostnames   = true
  enable_dns_support     = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# EKS Cluster (uses VPC module outputs - NO MANUAL IDs)
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.app_name}-eks"
  cluster_version = "1.29"  # Stable version

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets  # PRIVATE subnets only
  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 3
      desired_size = 2
      instance_types = ["t3.medium"]
    }
  }

  # Stable addons only
  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }
}

# CloudWatch Monitoring 
resource "aws_sns_topic" "alerts" {
  name = "${var.app_name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "node_cpu" {
  alarm_name          = "${var.app_name}-node-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 80
  alarm_actions       = [aws_sns_topic.alerts.arn]

  metric_name = "CPUUtilization"
  namespace   = "AWS/EKS"
  period      = 60
  statistic   = "Average"

  dimensions = {
    ClusterName = module.eks.cluster_id
    NodegroupName = "default"
  }
}


# CloudWatch config

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "monitoring-app-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        x = 0
        y = 0
        width = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization"]
          ]
          period = 300
          stat = "Average"
          region = "us-east-1"  # Required!
          title = "CPU Usage"
        }
      }
    ]
  })
}