# CloudWatch Log Groups for CI/CD Pipeline
# This configuration creates log groups for CodeDeploy and CodePipeline
# Note: CodeBuild log group is defined in codebuild.tf
# Requirements: 10.4, 13.4

# CloudWatch Log Group for CodeDeploy
resource "aws_cloudwatch_log_group" "codedeploy" {
  name              = "/aws/codedeploy/loan-processing-${var.environment}"
  retention_in_days = 30

  tags = merge(
    var.common_tags,
    {
      Name        = "codedeploy-logs-${var.environment}"
      Environment = var.environment
      Project     = "loan-processing"
      ManagedBy   = "terraform"
    }
  )
}

# CloudWatch Log Group for CodePipeline
resource "aws_cloudwatch_log_group" "codepipeline" {
  name              = "/aws/codepipeline/loan-processing-${var.environment}"
  retention_in_days = 30

  tags = merge(
    var.common_tags,
    {
      Name        = "codepipeline-logs-${var.environment}"
      Environment = var.environment
      Project     = "loan-processing"
      ManagedBy   = "terraform"
    }
  )
}

# CloudWatch Metric Filters for CI/CD Pipeline Monitoring
# These filters extract metrics from log events for alerting and monitoring
# Requirements: 10.5, 13.6

# Metric Filter for Build Failures in CodeBuild Logs
# Detects build failures by matching error patterns in CodeBuild logs
resource "aws_cloudwatch_log_metric_filter" "build_failures" {
  name           = "BuildFailures-${var.environment}"
  log_group_name = aws_cloudwatch_log_group.codebuild.name
  pattern        = "\"[ERROR] Build failed\""

  metric_transformation {
    name          = "BuildFailureCount"
    namespace     = "LoanProcessing/CICD"
    value         = "1"
    default_value = 0
    unit          = "Count"
  }
}

# Metric Filter for Deployment Failures in CodeDeploy Logs
# Detects deployment failures by matching error patterns in CodeDeploy logs
resource "aws_cloudwatch_log_metric_filter" "deployment_failures" {
  name           = "DeploymentFailures-${var.environment}"
  log_group_name = aws_cloudwatch_log_group.codedeploy.name
  pattern        = "?ERROR ?FAILED ?\"deployment failed\""

  metric_transformation {
    name          = "DeploymentFailureCount"
    namespace     = "LoanProcessing/CICD"
    value         = "1"
    default_value = 0
    unit          = "Count"
  }
}

# Metric Filter for Credential Exposure Detection
# Monitors all CI/CD logs for potential credential leaks
# This filter should NEVER match if security practices are followed
# Pattern matches common credential patterns: passwords, connection strings, API keys
resource "aws_cloudwatch_log_metric_filter" "credential_exposure_codebuild" {
  name           = "CredentialExposure-CodeBuild-${var.environment}"
  log_group_name = aws_cloudwatch_log_group.codebuild.name
  # Pattern matches: password=, Password=, pwd=, connectionString=, secret=, apikey=, token=
  pattern = "?password= ?Password= ?pwd= ?connectionString= ?secret= ?apikey= ?token= ?SECRET ?PASSWORD"

  metric_transformation {
    name          = "CredentialExposureCount"
    namespace     = "LoanProcessing/Security"
    value         = "1"
    default_value = 0
    unit          = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "credential_exposure_codedeploy" {
  name           = "CredentialExposure-CodeDeploy-${var.environment}"
  log_group_name = aws_cloudwatch_log_group.codedeploy.name
  # Pattern matches: password=, Password=, pwd=, connectionString=, secret=, apikey=, token=
  pattern = "?password= ?Password= ?pwd= ?connectionString= ?secret= ?apikey= ?token= ?SECRET ?PASSWORD"

  metric_transformation {
    name          = "CredentialExposureCount"
    namespace     = "LoanProcessing/Security"
    value         = "1"
    default_value = 0
    unit          = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "credential_exposure_codepipeline" {
  name           = "CredentialExposure-CodePipeline-${var.environment}"
  log_group_name = aws_cloudwatch_log_group.codepipeline.name
  # Pattern matches: password=, Password=, pwd=, connectionString=, secret=, apikey=, token=
  pattern = "?password= ?Password= ?pwd= ?connectionString= ?secret= ?apikey= ?token= ?SECRET ?PASSWORD"

  metric_transformation {
    name          = "CredentialExposureCount"
    namespace     = "LoanProcessing/Security"
    value         = "1"
    default_value = 0
    unit          = "Count"
  }
}

# CloudWatch Alarms for CI/CD Pipeline Monitoring
# These alarms monitor pipeline health and trigger auto-rollback when issues are detected
# Requirements: 10.6

# Alarm for Repeated Build Failures
# Triggers when 3 or more builds fail within 1 hour
# This indicates a systemic issue with the build process (e.g., broken dependencies, code issues)
resource "aws_cloudwatch_metric_alarm" "repeated_build_failures" {
  alarm_name          = "loan-processing-repeated-build-failures-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "BuildFailureCount"
  namespace           = "LoanProcessing/CICD"
  period              = 3600 # 1 hour in seconds
  statistic           = "Sum"
  threshold           = 3
  alarm_description   = "Triggers when 3 or more builds fail within 1 hour, indicating systemic build issues"
  treat_missing_data  = "notBreaching"

  tags = merge(
    var.common_tags,
    {
      Name        = "repeated-build-failures-${var.environment}"
      Environment = var.environment
      Project     = "loan-processing"
      ManagedBy   = "terraform"
      Severity    = "High"
      AlarmType   = "BuildHealth"
    }
  )
}

# Alarm for Repeated Deployment Failures
# Triggers when 2 or more deployments fail within 1 hour
# This indicates issues with deployment scripts, infrastructure, or application configuration
resource "aws_cloudwatch_metric_alarm" "repeated_deployment_failures" {
  alarm_name          = "loan-processing-repeated-deployment-failures-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "DeploymentFailureCount"
  namespace           = "LoanProcessing/CICD"
  period              = 3600 # 1 hour in seconds
  statistic           = "Sum"
  threshold           = 2
  alarm_description   = "Triggers when 2 or more deployments fail within 1 hour, indicating deployment issues"
  treat_missing_data  = "notBreaching"

  tags = merge(
    var.common_tags,
    {
      Name        = "repeated-deployment-failures-${var.environment}"
      Environment = var.environment
      Project     = "loan-processing"
      ManagedBy   = "terraform"
      Severity    = "Critical"
      AlarmType   = "DeploymentHealth"
    }
  )
}

# Alarm for Deployment Duration Exceeding 15 Minutes
# Triggers when a deployment takes longer than 15 minutes (900 seconds)
# Long deployments may indicate performance issues, network problems, or stuck processes
resource "aws_cloudwatch_metric_alarm" "deployment_duration_exceeded" {
  alarm_name          = "loan-processing-deployment-duration-exceeded-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/CodeDeploy"
  period              = 300 # 5 minutes evaluation period
  statistic           = "Maximum"
  threshold           = 900 # 15 minutes in seconds
  alarm_description   = "Triggers when a deployment takes longer than 15 minutes, indicating performance issues"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApplicationName = aws_codedeploy_app.loan_processing.name
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "deployment-duration-exceeded-${var.environment}"
      Environment = var.environment
      Project     = "loan-processing"
      ManagedBy   = "terraform"
      Severity    = "Medium"
      AlarmType   = "DeploymentPerformance"
    }
  )
}
