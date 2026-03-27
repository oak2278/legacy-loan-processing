# Terraform Outputs for Legacy .NET Loan Processing Application

# Networking Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.networking.private_subnet_ids
}

# Application Load Balancer Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.compute.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.compute.alb_zone_id
}

output "application_url" {
  description = "URL to access the application"
  value       = "http://${module.compute.alb_dns_name}"
}

# Auto Scaling Group Outputs
output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.compute.asg_name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = module.compute.asg_arn
}

# Database Outputs
output "db_endpoint" {
  description = "RDS instance endpoint"
  value       = module.database.db_endpoint
  sensitive   = true
}

output "db_instance_id" {
  description = "RDS instance identifier"
  value       = module.database.db_instance_id
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials"
  value       = module.database.db_secret_arn
  sensitive   = true
}

output "db_name" {
  description = "Database name"
  value       = var.db_name
}

# Security Outputs
output "app_security_group_id" {
  description = "ID of the application security group"
  value       = module.security.app_security_group_id
}

output "db_security_group_id" {
  description = "ID of the database security group"
  value       = module.security.db_security_group_id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.security.alb_security_group_id
}

output "instance_role_arn" {
  description = "ARN of the EC2 instance IAM role"
  value       = module.security.instance_role_arn
}

# Monitoring Outputs
output "cloudwatch_log_group" {
  description = "CloudWatch Log Group name for application logs"
  value       = module.monitoring.log_group_name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alarms"
  value       = module.monitoring.sns_topic_arn
}

# CI/CD Pipeline Outputs
output "codepipeline_url" {
  description = "URL to access the CodePipeline in AWS Console"
  value       = module.cicd.codepipeline_url
}

output "codepipeline_name" {
  description = "Name of the CodePipeline"
  value       = module.cicd.codepipeline_name
}

output "codebuild_project_name" {
  description = "Name of the CodeBuild project"
  value       = module.cicd.codebuild_project_name
}

output "codedeploy_application_name" {
  description = "Name of the CodeDeploy application"
  value       = module.cicd.codedeploy_app_name
}

output "codedeploy_deployment_group_name" {
  description = "Name of the CodeDeploy deployment group"
  value       = module.cicd.codedeploy_deployment_group_name
}

output "artifact_bucket_name" {
  description = "Name of the S3 bucket for pipeline artifacts"
  value       = module.cicd.artifact_bucket_name
}

output "pipeline_sns_topic_arn" {
  description = "ARN of the SNS topic for pipeline notifications"
  value       = module.cicd.sns_topic_arn
}

# Connection Information
output "connection_instructions" {
  description = "Instructions for connecting to resources"
  value       = <<-EOT
    
    ========================================
    Deployment Complete!
    ========================================
    
    Application URL:
      http://${module.compute.alb_dns_name}
    
    CI/CD Pipeline:
      Pipeline URL: ${module.cicd.codepipeline_url}
      CodeBuild Project: ${module.cicd.codebuild_project_name}
      CodeDeploy Application: ${module.cicd.codedeploy_app_name}
      Deployment Group: ${module.cicd.codedeploy_deployment_group_name}
      Artifact Bucket: ${module.cicd.artifact_bucket_name}
      Notifications Topic: ${module.cicd.sns_topic_arn}
    
    Database Connection:
      Endpoint: ${module.database.db_endpoint}
      Database: ${var.db_name}
      Username: ${var.db_username}
      Password: Stored in AWS Secrets Manager
    
    To retrieve database password:
      aws secretsmanager get-secret-value --secret-id ${module.database.db_secret_arn} --query SecretString --output text
    
    To connect to EC2 instance via Session Manager:
      aws ssm start-session --target <instance-id>
    
    To view application logs:
      aws logs tail ${module.monitoring.log_group_name} --follow
    
    CloudWatch Dashboard:
      https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${var.project_name}-${var.environment}
    
    ========================================
  EOT
}

# Workshop-specific outputs
output "workshop_info" {
  description = "Information for workshop participants"
  value = {
    application_url  = "http://${module.compute.alb_dns_name}"
    region           = var.aws_region
    environment      = var.environment
    database_engine  = "SQL Server ${var.db_engine_version}"
    instance_type    = var.instance_type
    multi_az_enabled = var.db_multi_az
  }
}
