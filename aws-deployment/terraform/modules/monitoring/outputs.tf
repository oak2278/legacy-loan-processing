# Monitoring Module Outputs

output "log_group_name" {
  description = "Name of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.app.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.app.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarms"
  value       = aws_sns_topic.alarms.arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch Dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}
