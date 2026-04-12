# Module 2 Outputs — .NET 10 on Amazon Linux 2023

# ---------------------------------------------------------------------------
# Linux Target Group
# ---------------------------------------------------------------------------

output "linux_target_group_arn" {
  description = "ARN of the Linux target group (port 5000)"
  value       = aws_lb_target_group.linux.arn
}

output "linux_target_group_name" {
  description = "Name of the Linux target group"
  value       = aws_lb_target_group.linux.name
}

# ---------------------------------------------------------------------------
# Linux Auto Scaling Group
# ---------------------------------------------------------------------------

output "linux_asg_name" {
  description = "Name of the Linux Auto Scaling Group"
  value       = aws_autoscaling_group.linux.name
}

# ---------------------------------------------------------------------------
# Linux CI/CD (populated by cicd.tf in Task 1.4)
# ---------------------------------------------------------------------------

output "linux_codebuild_project_name" {
  description = "Name of the Linux CodeBuild project"
  value       = aws_codebuild_project.linux.name
}

output "linux_codepipeline_name" {
  description = "Name of the Linux CodePipeline"
  value       = aws_codepipeline.linux.name
}

# ---------------------------------------------------------------------------
# Traffic Weights
# ---------------------------------------------------------------------------

output "windows_traffic_weight" {
  description = "Current ALB traffic weight for Windows target group"
  value       = var.windows_traffic_weight
}

output "linux_traffic_weight" {
  description = "Current ALB traffic weight for Linux target group"
  value       = var.linux_traffic_weight
}
