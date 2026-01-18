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
