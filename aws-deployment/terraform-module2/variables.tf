# Module 2 Variables — .NET 10 on Amazon Linux 2023
# These variables reference outputs from the Module 1 Terraform deployment.
# See terraform.tfvars.example for how to populate them from Module 1 outputs.

# ---------------------------------------------------------------------------
# General Configuration
# ---------------------------------------------------------------------------

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "loanprocessing"
}

variable "environment" {
  description = "Environment name (workshop, dev, prod)"
  type        = string
  default     = "workshop"
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

# ---------------------------------------------------------------------------
# Networking (from Module 1 outputs)
# ---------------------------------------------------------------------------

variable "vpc_id" {
  description = "VPC ID from Module 1"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs from Module 1 for Linux EC2 instances"
  type        = list(string)
}

# ---------------------------------------------------------------------------
# Security (from Module 1 outputs)
# ---------------------------------------------------------------------------

variable "app_security_group_id" {
  description = "Application security group ID from Module 1"
  type        = string
}

# ---------------------------------------------------------------------------
# ALB (from Module 1 outputs)
# ---------------------------------------------------------------------------

variable "alb_listener_arn" {
  description = "ARN of the Module 1 ALB HTTP listener to attach the weighted rule to"
  type        = string
}

variable "windows_target_group_arn" {
  description = "ARN of the Module 1 Windows target group (port 80)"
  type        = string
}

# ---------------------------------------------------------------------------
# Compute Configuration
# ---------------------------------------------------------------------------

variable "instance_type" {
  description = "EC2 instance type for Linux application servers"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "EC2 key pair name (optional, use Systems Manager Session Manager instead)"
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Database (from Module 1 outputs)
# ---------------------------------------------------------------------------

variable "db_endpoint" {
  description = "RDS SQL Server endpoint from Module 1"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "LoanProcessing"
}

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials (from Module 1)"
  type        = string
}

# ---------------------------------------------------------------------------
# IAM (from Module 1 outputs)
# ---------------------------------------------------------------------------

variable "iam_instance_profile_name" {
  description = "Name of the IAM instance profile from Module 1"
  type        = string
}

# ---------------------------------------------------------------------------
# CI/CD Configuration
# ---------------------------------------------------------------------------

variable "github_connection_arn" {
  description = "ARN of the CodeStar Connection to GitHub (from Module 1)"
  type        = string
  default     = ""
}

variable "github_repository_id" {
  description = "Full GitHub repository ID in format 'owner/repo'"
  type        = string
  default     = "aws-shawn/legacy-loan-processing"
}

variable "github_branch_name" {
  description = "GitHub branch name to monitor for changes"
  type        = string
  default     = "main"
}

variable "notification_email" {
  description = "Email address for pipeline notifications"
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Traffic Weights — ALB Weighted Routing
# ---------------------------------------------------------------------------

variable "windows_traffic_weight" {
  description = "ALB traffic weight for Windows target group (port 80). Set to 0 to route all traffic to Linux."
  type        = number
  default     = 100
}

variable "linux_traffic_weight" {
  description = "ALB traffic weight for Linux target group (port 5000). Set to 100 to route all traffic to Linux."
  type        = number
  default     = 0
}

# ---------------------------------------------------------------------------
# Tags
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
