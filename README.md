# Portfolio API Infrastructure

## Deployed Resources
- ECS Cluster: portfolio-cluster
- ECS Service: portfolio-service
- ECR Repository: portfolio-api
- CloudWatch Dashboard: monitoring-app-dashboard

## Deployment
```bash
# Deploy changes
terraform plan
terraform apply

# View logs
aws logs tail /aws/ecs/portfolio-api --follow
```

## Monitoring
- Dashboard: https://console.aws.amazon.com/cloudwatch/dashboards
- Logs: https://console.aws.amazon.com/cloudwatch/logs

## Troubleshooting
- Check service status: `terraform output`
- View task logs: `aws logs tail /aws/ecs/portfolio-api`





┌─────────────────┐    ┌──────────────────┐
│   GitHub        │───▶│   AWS IAM Role   │
│   Actions       │    │   (OIDC)         │
│   (terraform    │    └──────────────────┘
│   apply)        │           │
└─────────────────┘           ▼
                             ┌──────────────────┐
                    ┌────────│     VPC + NAT    │────────┐
                    │        │  Public/Private  │        │
                    │        │    Subnets       │        │
                    │        └──────────────────┘        │
                    │                  │                │
                    ▼                  ▼                ▼
            ┌──────────────┐ ┌──────────────────┐ ┌──────────────┐
            │   EKS        │ │ CloudWatch       │ │ Prometheus   │
            │ Control Plane│ │ Alarms + SNS     │ │ + Grafana    │
            │ Worker Nodes │ │ Dashboard        │ │ (monitoring) │
            └──────────────┘ └──────────────────┘ └──────────────┘
                       │
                       ▼
                ┌──────────────┐
                │   Sample     │
                │   App        │───▶ /health, /heavy, /error
                │ (/metrics)   │     (Triggers alarms)
                └──────────────┘



