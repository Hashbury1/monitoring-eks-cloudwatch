# Amazon Managed Prometheus workspace
resource "aws_prometheus_workspace" "main" {
  alias = "${var.app_name}-workspace"
}

# Example alarm on Prometheus metric via CW (simplified using AMP CW integration)
resource "aws_cloudwatch_metric_alarm" "http_latency_p95" {
  alarm_name          = "${var.app_name}-http-latency-p95"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 500
  treat_missing_data  = "notBreaching"

  metric_query {
    id         = "q1"
    expression = "SEARCH('{Namespace=\"AWS/Prometheus\", Service=\"APS\"]} MetricName=\"http_request_duration_ms_p95\"', 'Average', 60)"
    label      = "http_p95"
    return_data = true
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}
