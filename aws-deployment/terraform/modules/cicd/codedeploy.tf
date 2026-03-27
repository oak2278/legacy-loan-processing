# CodeDeploy Application and Deployment Group
# This configuration manages deployments to EC2 instances with rolling updates and automatic rollback
# Requirements: 4.6, 4.7, 8.6, 9.1, 15.1, 15.2, 15.3, 15.4, 15.5

# CodeDeploy Application
resource "aws_codedeploy_app" "loan_processing" {
  name             = "loan-processing-${var.environment}"
  compute_platform = "Server"

  tags = merge(
    var.common_tags,
    {
      Name        = "loan-processing-${var.environment}"
      Environment = var.environment
      Project     = "loan-processing"
      ManagedBy   = "terraform"
    }
  )
}

# CloudWatch Alarm for deployment failures (used for auto-rollback)
resource "aws_cloudwatch_metric_alarm" "deployment_failure" {
  alarm_name          = "loan-processing-deployment-failure-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FailedDeployments"
  namespace           = "AWS/CodeDeploy"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Triggers when a CodeDeploy deployment fails"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApplicationName = aws_codedeploy_app.loan_processing.name
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "loan-processing-deployment-failure-${var.environment}"
      Environment = var.environment
      Project     = "loan-processing"
      ManagedBy   = "terraform"
    }
  )
}

# CodeDeploy Deployment Group
resource "aws_codedeploy_deployment_group" "loan_processing" {
  app_name              = aws_codedeploy_app.loan_processing.name
  deployment_group_name = "loan-processing-${var.environment}"
  service_role_arn      = aws_iam_role.codedeploy.arn

  # Rolling deployment: one instance at a time
  deployment_config_name = "CodeDeployDefault.OneAtATime"

  # Link to Auto Scaling Group from existing infrastructure
  autoscaling_groups = [var.asg_name]

  # IN_PLACE deployment with traffic control
  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  # Configure load balancer integration with ALB target group
  load_balancer_info {
    target_group_info {
      name = var.target_group_name
    }
  }

  # Enable automatic rollback on deployment failures and alarm triggers
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  # Link CloudWatch alarms for auto-rollback
  # These alarms trigger automatic rollback when deployment issues are detected
  alarm_configuration {
    enabled = true
    alarms = [
      aws_cloudwatch_metric_alarm.deployment_failure.alarm_name,
      aws_cloudwatch_metric_alarm.repeated_deployment_failures.alarm_name,
      aws_cloudwatch_metric_alarm.deployment_duration_exceeded.alarm_name
    ]
  }

  # SNS notification triggers for deployment events
  # Requirements: 9.6, 10.1, 10.2, 10.3
  trigger_configuration {
    trigger_events = [
      "DeploymentStart",
      "DeploymentSuccess",
      "DeploymentFailure",
      "DeploymentRollback"
    ]
    trigger_name       = "deployment-notifications-${var.environment}"
    trigger_target_arn = aws_sns_topic.pipeline_notifications.arn
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "loan-processing-${var.environment}"
      Environment = var.environment
      Project     = "loan-processing"
      ManagedBy   = "terraform"
    }
  )
}
