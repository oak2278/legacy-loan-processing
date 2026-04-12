# Variables for CI/CD Module

variable "environment" {
  description = "Environment name (dev, staging, production, workshop)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production", "workshop"], var.environment)
    error_message = "Environment must be dev, staging, production, or workshop."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-west-2"
}

variable "github_connection_arn" {
  description = "ARN of the CodeStar Connection for GitHub integration"
  type        = string
}

variable "ec2_instance_role_arn" {
  description = "ARN of the IAM role for EC2 instances (from security module)"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "asg_name" {
  description = "Name of the Auto Scaling Group for deployment targets"
  type        = string
}

variable "target_group_name" {
  description = "Name of the ALB target group for load balancer integration"
  type        = string
}

variable "github_repository_id" {
  description = "Full GitHub repository ID in format 'owner/repo' (e.g., 'aws-shawn/legacy-loan-processing')"
  type        = string
  default     = "aws-shawn/legacy-loan-processing"
}

variable "github_branch_name" {
  description = "GitHub branch name to monitor for changes"
  type        = string
  default     = "main"
}

variable "notification_email" {
  description = "Email address for pipeline notifications (operations team)"
  type        = string
}

variable "require_manual_approval" {
  description = "Whether to require manual approval before deployment (typically true for production)"
  type        = bool
  default     = false
}

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials (from database module)"
  type        = string
}

variable "resource_suffix" {
  description = "Random suffix for unique resource naming"
  type        = string
  default     = ""
}

# Linux deployment variables (Module 2)

variable "linux_asg_name" {
  description = "Name of the Linux Auto Scaling Group for deployment targets"
  type        = string
  default     = ""
}

variable "linux_target_group_name" {
  description = "Name of the Linux ALB target group for load balancer integration"
  type        = string
  default     = ""
}
