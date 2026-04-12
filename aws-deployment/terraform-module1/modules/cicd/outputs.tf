# Outputs for CI/CD Module

output "artifact_bucket_id" {
  description = "ID of the S3 bucket for pipeline artifacts"
  value       = aws_s3_bucket.pipeline_artifacts.id
}

output "artifact_bucket_arn" {
  description = "ARN of the S3 bucket for pipeline artifacts"
  value       = aws_s3_bucket.pipeline_artifacts.arn
}

output "artifact_bucket_name" {
  description = "Name of the S3 bucket for pipeline artifacts"
  value       = aws_s3_bucket.pipeline_artifacts.bucket
}

output "artifact_bucket_domain_name" {
  description = "Domain name of the S3 bucket for pipeline artifacts"
  value       = aws_s3_bucket.pipeline_artifacts.bucket_domain_name
}

output "kms_key_id" {
  description = "ID of the KMS key for pipeline artifact encryption"
  value       = aws_kms_key.pipeline_artifacts.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key for pipeline artifact encryption"
  value       = aws_kms_key.pipeline_artifacts.arn
}

output "kms_key_alias" {
  description = "Alias of the KMS key for pipeline artifact encryption"
  value       = aws_kms_alias.pipeline_artifacts.name
}

output "codepipeline_role_arn" {
  description = "ARN of the IAM role for CodePipeline"
  value       = aws_iam_role.codepipeline.arn
}

output "codepipeline_role_name" {
  description = "Name of the IAM role for CodePipeline"
  value       = aws_iam_role.codepipeline.name
}

output "codedeploy_app_name" {
  description = "Name of the CodeDeploy application"
  value       = aws_codedeploy_app.loan_processing.name
}

output "codedeploy_app_id" {
  description = "ID of the CodeDeploy application"
  value       = aws_codedeploy_app.loan_processing.id
}

output "codedeploy_deployment_group_name" {
  description = "Name of the CodeDeploy deployment group"
  value       = aws_codedeploy_deployment_group.loan_processing.deployment_group_name
}

output "codedeploy_deployment_group_id" {
  description = "ID of the CodeDeploy deployment group"
  value       = aws_codedeploy_deployment_group.loan_processing.id
}

output "deployment_failure_alarm_arn" {
  description = "ARN of the CloudWatch alarm for deployment failures"
  value       = aws_cloudwatch_metric_alarm.deployment_failure.arn
}

output "codepipeline_id" {
  description = "ID of the CodePipeline"
  value       = aws_codepipeline.loan_processing.id
}

output "codepipeline_arn" {
  description = "ARN of the CodePipeline"
  value       = aws_codepipeline.loan_processing.arn
}

output "codepipeline_name" {
  description = "Name of the CodePipeline"
  value       = aws_codepipeline.loan_processing.name
}

output "codepipeline_url" {
  description = "URL to access the CodePipeline in AWS Console"
  value       = "https://console.aws.amazon.com/codesuite/codepipeline/pipelines/${aws_codepipeline.loan_processing.name}/view?region=${var.aws_region}"
}

output "codebuild_project_name" {
  description = "Name of the CodeBuild project"
  value       = aws_codebuild_project.loan_processing.name
}

output "codebuild_project_arn" {
  description = "ARN of the CodeBuild project"
  value       = aws_codebuild_project.loan_processing.arn
}

# CloudWatch Alarm Outputs
output "repeated_build_failures_alarm_arn" {
  description = "ARN of the CloudWatch alarm for repeated build failures"
  value       = aws_cloudwatch_metric_alarm.repeated_build_failures.arn
}

output "repeated_deployment_failures_alarm_arn" {
  description = "ARN of the CloudWatch alarm for repeated deployment failures"
  value       = aws_cloudwatch_metric_alarm.repeated_deployment_failures.arn
}

output "deployment_duration_exceeded_alarm_arn" {
  description = "ARN of the CloudWatch alarm for deployment duration exceeding threshold"
  value       = aws_cloudwatch_metric_alarm.deployment_duration_exceeded.arn
}

# SNS Topic Outputs
output "sns_topic_arn" {
  description = "ARN of the SNS topic for pipeline notifications"
  value       = aws_sns_topic.pipeline_notifications.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic for pipeline notifications"
  value       = aws_sns_topic.pipeline_notifications.name
}

# Parameter Store Outputs
output "ssm_parameter_app_pool_name" {
  description = "Name of the SSM parameter for IIS application pool name"
  value       = aws_ssm_parameter.app_pool_name.name
}

output "ssm_parameter_site_name" {
  description = "Name of the SSM parameter for IIS website name"
  value       = aws_ssm_parameter.site_name.name
}

output "ssm_parameter_deployment_path" {
  description = "Name of the SSM parameter for deployment path"
  value       = aws_ssm_parameter.deployment_path.name
}

output "ssm_parameter_notification_email" {
  description = "Name of the SSM parameter for notification email"
  value       = var.notification_email != "" ? aws_ssm_parameter.notification_email[0].name : ""
}

output "ssm_parameter_db_secret_arn" {
  description = "Name of the SSM parameter for database secret ARN"
  value       = aws_ssm_parameter.db_secret_arn.name
}

output "db_secret_arn" {
  description = "ARN of the database credentials secret (passed through from database module)"
  value       = var.db_secret_arn
}

# Linux CI/CD Outputs (Module 2)

output "linux_codebuild_project_name" {
  description = "Name of the Linux CodeBuild project"
  value       = aws_codebuild_project.linux.name
}

output "linux_codebuild_project_arn" {
  description = "ARN of the Linux CodeBuild project"
  value       = aws_codebuild_project.linux.arn
}

output "linux_codepipeline_name" {
  description = "Name of the Linux CodePipeline"
  value       = aws_codepipeline.linux.name
}

output "linux_codepipeline_arn" {
  description = "ARN of the Linux CodePipeline"
  value       = aws_codepipeline.linux.arn
}

output "linux_codedeploy_deployment_group_name" {
  description = "Name of the Linux CodeDeploy deployment group"
  value       = aws_codedeploy_deployment_group.linux.deployment_group_name
}
