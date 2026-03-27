# AWS Systems Manager Parameter Store entries for environment-specific configuration
# These parameters are used by deployment scripts to retrieve environment-specific settings

# Application Pool Name
resource "aws_ssm_parameter" "app_pool_name" {
  name        = "/loan-processing/${var.environment}/app-pool-name"
  description = "IIS Application Pool name for ${var.environment} environment"
  type        = "String"
  value       = "LoanProcessingAppPool"

  tags = merge(
    var.common_tags,
    {
      Name        = "loan-processing-app-pool-name-${var.environment}"
      Environment = var.environment
      Project     = "loan-processing"
      ManagedBy   = "terraform"
      Purpose     = "IIS Configuration"
    }
  )
}

# Website Name
resource "aws_ssm_parameter" "site_name" {
  name        = "/loan-processing/${var.environment}/site-name"
  description = "IIS Website name for ${var.environment} environment"
  type        = "String"
  value       = "LoanProcessing"

  tags = merge(
    var.common_tags,
    {
      Name        = "loan-processing-site-name-${var.environment}"
      Environment = var.environment
      Project     = "loan-processing"
      ManagedBy   = "terraform"
      Purpose     = "IIS Configuration"
    }
  )
}

# Deployment Path
resource "aws_ssm_parameter" "deployment_path" {
  name        = "/loan-processing/${var.environment}/deployment-path"
  description = "Application deployment path for ${var.environment} environment"
  type        = "String"
  value       = "C:\\inetpub\\wwwroot\\LoanProcessing"

  tags = merge(
    var.common_tags,
    {
      Name        = "loan-processing-deployment-path-${var.environment}"
      Environment = var.environment
      Project     = "loan-processing"
      ManagedBy   = "terraform"
      Purpose     = "Deployment Configuration"
    }
  )
}

# Notification Email
resource "aws_ssm_parameter" "notification_email" {
  count       = var.notification_email != "" ? 1 : 0
  name        = "/loan-processing/${var.environment}/notification-email"
  description = "Notification email address for ${var.environment} environment"
  type        = "String"
  value       = var.notification_email

  tags = merge(
    var.common_tags,
    {
      Name        = "loan-processing-notification-email-${var.environment}"
      Environment = var.environment
      Project     = "loan-processing"
      ManagedBy   = "terraform"
      Purpose     = "Notification Configuration"
    }
  )
}

# Database Secret ARN
resource "aws_ssm_parameter" "db_secret_arn" {
  name        = "/loan-processing/${var.environment}/db-secret-arn"
  description = "ARN of Secrets Manager secret containing database credentials for ${var.environment} environment"
  type        = "String"
  value       = var.db_secret_arn

  tags = merge(
    var.common_tags,
    {
      Name        = "loan-processing-db-secret-arn-${var.environment}"
      Environment = var.environment
      Project     = "loan-processing"
      ManagedBy   = "terraform"
      Purpose     = "Database Configuration"
    }
  )
}
