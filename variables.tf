variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "monitoring-app"
}

variable "alert_email" {
  description = "Email for alerts"
  type        = string
}
