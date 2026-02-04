
```markdown
# Monitoring EKS with CloudWatch, Prometheus, and Grafana

This repository provisions an Amazon EKS cluster with end‑to‑end monitoring using Amazon CloudWatch, Prometheus, and Grafana, including a sample application that exposes health and metrics endpoints to trigger alarms.

## Architecture

The high‑level architecture:

- GitHub Actions uses OIDC to assume an AWS IAM role and run `terraform apply` in your AWS account.
- Terraform creates:
  - VPC with public and private subnets, NAT gateway, and required networking.
  - EKS control plane and worker nodes.
  - CloudWatch log groups, metrics, alarms, and SNS topics for notifications.
  - Prometheus and Grafana stack for Kubernetes metrics and dashboards.
- A sample application is deployed on EKS that exposes:
  - `/health` – normal health check.
  - `/heavy` – simulates heavy load.
  - `/error` – simulates errors.
  - `/metrics` – Prometheus metrics endpoint.
- CloudWatch alarms fire on abnormal metrics or errors and send notifications via SNS.

You can replace this section with your own diagram (the one in the repo that shows GitHub Actions, IAM role, VPC, EKS, CloudWatch, Prometheus, Grafana, and the sample app).

## Features

- Automated provisioning via GitHub Actions and Terraform (IaC pipeline).
- EKS cluster with worker nodes in private subnets behind NAT.
- CloudWatch Container Insights for cluster, node, pod, and service metrics.
- Control plane logging and application logs to CloudWatch Logs.
- Prometheus and Grafana installed for Kubernetes‑native metrics and dashboards.
- Sample application with `/health`, `/heavy`, `/error`, and `/metrics` endpoints to exercise monitoring and alarms.
- CloudWatch alarms and SNS notifications for key cluster and app signals.


## Prerequisites

- AWS account with permissions to create:
  - IAM roles and OIDC provider for GitHub Actions.
  - VPC, subnets, EKS, CloudWatch, and SNS.
- Terraform installed (version as required by this repo).
- kubectl installed and configured.
- aws CLI configured with an IAM user/role that can bootstrap the IAM role used by GitHub Actions.
- GitHub repository with:
  - OIDC trust configured for AWS IAM role.
  - GitHub Actions workflow file.

## Repository Structure

Adjust this section to match your actual layout, for example:

```text
.
├── .github/
│   └── workflows/
│       └── deploy.yaml        # GitHub Actions pipeline (OIDC + terraform apply)
├── modules/
│   ├── network/               # VPC, subnets, NAT, gateways
│   ├── eks/                   # EKS cluster and node groups
│   ├── monitoring/            # CloudWatch, Prometheus, Grafana, alarms, SNS
│   └── sample-app/            # Kubernetes manifests for the demo app
├── envs/
│   └── dev/                   # Environment-specific Terraform configs
├── main.tf
├── variables.tf
├── outputs.tf
└── README.md
```


## Getting Started

### 1. Configure GitHub OIDC and IAM

1. Create an IAM role in AWS that trusts your GitHub repo’s OIDC provider.
2. Attach IAM policies to allow Terraform to manage VPC, EKS, CloudWatch, and SNS.
3. Configure the GitHub Actions workflow in `.github/workflows/*.yaml` to assume this role.

Document the exact trust policy and role ARN here if you want copy‑paste snippets.

### 2. Configure Terraform variables

Copy and edit the example vars file if present:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Key variables (update to match `variables.tf`):

- `aws_region` – AWS region to deploy to.
- `project_name` – Prefix for resource names.
- `cluster_name` – EKS cluster name.
- `grafana_admin_password` – Initial Grafana admin password.
- `alarm_email` – Email subscribed to SNS topic for alerts.

### 3. Deploy via GitHub Actions (recommended)

Push changes to the main branch (or the branch your workflow targets):

- GitHub Actions will:
  - Assume the AWS IAM role via OIDC.
  - Run `terraform init`, `terraform plan`, and `terraform apply`.
- Monitor the Actions tab for run status and Terraform output.

### 4. Deploy locally (optional)

You can also run Terraform locally:

```bash
terraform init
terraform plan
terraform apply
```

This will create the VPC, EKS cluster, monitoring stack, and sample application.

## Sample Application

The sample app is designed to exercise monitoring and alerts:

- `/health` – Healthy response for readiness and liveness.
- `/heavy` – Simulates high CPU or latency to test performance alerts.
- `/error` – Returns errors to test error‑rate alarms.
- `/metrics` – Prometheus metrics endpoint scraped by Prometheus and surfaced in Grafana.

Example:

```bash
kubectl port-forward deploy/sample-app 8080:8080
curl localhost:8080/health
curl localhost:8080/heavy
curl localhost:8080/error
curl localhost:8080/metrics
```

Triggering `/heavy` and `/error` should change metrics and logs visible in CloudWatch, Prometheus, and Grafana dashboards.

## Observability and Dashboards

After deployment, you should see:

- **CloudWatch Logs**:
  - EKS control plane logs and application logs in dedicated log groups.
- **CloudWatch Metrics / Container Insights**:
  - Cluster, node, pod, and service metrics under Container Insights namespaces.
- **CloudWatch Alarms & SNS**:
  - Alarms for high CPU, errors, or health issues, sending notifications to the configured SNS topic.
- **Grafana**:
  - Dashboards for:
    - Cluster and node metrics.
    - Workload metrics from Prometheus.
  - Login with the configured admin credentials and update or import additional dashboards as needed.

### Key Variables Table

Update this table to match your actual `variables.tf`:

| Variable          | Description                                      | Required | Default        |
|-------------------|--------------------------------------------------|----------|----------------|
| `aws_region`      | AWS region for all resources                     | Yes      | `us-east-1`    |
| `project_name`    | Prefix for naming resources                      | Yes      | `monitoring`   |
| `cluster_name`    | EKS cluster name                                 | Yes      | n/a            |
| `grafana_admin_password` | Initial Grafana admin password            | Yes      | n/a            |
| `alarm_email`     | Email address subscribed to SNS alerts.          | No       | n/a            |

## Cleanup

To avoid ongoing costs, destroy the environment when you’re done:

```bash
terraform destroy
```

Also remove any SNS subscriptions or manual resources created outside Terraform if applicable.

## References

- Monitor EKS cluster data with Amazon CloudWatch.
- Proactive Amazon EKS monitoring with CloudWatch Observability Operator.
- Enhanced observability for EKS with CloudWatch Container Insights.
- EKS monitoring notes and Prometheus/Grafana examples.
- Example of using CloudWatch alarms and SNS for notifications.
```
