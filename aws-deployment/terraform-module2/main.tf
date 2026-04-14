# Module 2 Terraform Configuration — .NET 10 on Amazon Linux 2023
# This is a SEPARATE root module with its own state. It provisions Linux compute
# resources alongside the existing Module 1 Windows deployment.
#
# IMPORTANT: The existing Module 1 listener default action (forward to Windows TG)
# remains as the fallback. The new weighted listener rule (priority 100) takes
# priority when linux_traffic_weight > 0. When linux_traffic_weight is 0, all
# traffic continues to flow through the Module 1 default action to the Windows TG.
#
# No existing Module 1 Terraform files are modified by this module.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Project     = var.project_name
        Environment = var.environment
        ManagedBy   = "Terraform"
        Purpose     = "ModernizationWorkshop-Module2"
      },
      var.tags
    )
  }
}

# ---------------------------------------------------------------------------
# Data Sources
# ---------------------------------------------------------------------------

# Amazon Linux 2023 AMI (x86_64)
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# Local Variables
# ---------------------------------------------------------------------------

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ---------------------------------------------------------------------------
# Security Group Rule — Allow ALB to reach Kestrel on port 5000
# ---------------------------------------------------------------------------

resource "aws_security_group_rule" "alb_to_kestrel" {
  type                     = "ingress"
  from_port                = 5000
  to_port                  = 5000
  protocol                 = "tcp"
  description              = "Kestrel from ALB"
  security_group_id        = var.app_security_group_id
  source_security_group_id = var.alb_security_group_id
}

# ---------------------------------------------------------------------------
# Linux Launch Template
# ---------------------------------------------------------------------------

resource "aws_launch_template" "linux" {
  name_prefix   = "${local.name_prefix}-linux-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  key_name      = var.key_name != "" ? var.key_name : null

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  vpc_security_group_ids = [var.app_security_group_id]

  user_data = base64encode(templatefile("${path.module}/user-data-linux.sh", {
    db_endpoint      = var.db_endpoint
    db_name          = var.db_name
    db_secret_arn    = var.db_secret_arn
    project_name     = var.project_name
    environment      = var.environment
    aws_region       = var.aws_region
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.tags,
      {
        Name     = "${local.name_prefix}-linux-app"
        Platform = "AmazonLinux2023"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      var.tags,
      {
        Name = "${local.name_prefix}-linux-app-volume"
      }
    )
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Linux Target Group (port 5000 — Kestrel)
# ---------------------------------------------------------------------------

resource "aws_lb_target_group" "linux" {
  name_prefix = "linux-"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    port                = "5000"
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = false
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-tg-linux-5000"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Linux Auto Scaling Group
# ---------------------------------------------------------------------------

resource "aws_autoscaling_group" "linux" {
  name_prefix               = "${local.name_prefix}-linux-"
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [aws_lb_target_group.linux.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 1800
  min_size                  = 1
  max_size                  = 2
  desired_capacity          = 1

  launch_template {
    id      = aws_launch_template.linux.id
    version = "$Latest"
  }

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances"
  ]

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-linux-app"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

# ---------------------------------------------------------------------------
# Weighted ALB Listener Rule
# ---------------------------------------------------------------------------
# This rule uses weighted forward actions to distribute traffic between the
# existing Windows target group (Module 1, port 80) and the new Linux target
# group (Module 2, port 5000).
#
# The Module 1 listener default action (forward to Windows TG) remains as the
# fallback. This weighted rule takes priority (priority 100) when
# linux_traffic_weight > 0. To switch all traffic to Linux:
#   terraform apply -var="windows_traffic_weight=0" -var="linux_traffic_weight=100"

resource "aws_lb_listener_rule" "weighted" {
  listener_arn = var.alb_listener_arn
  priority     = 100

  action {
    type = "forward"

    forward {
      target_group {
        arn    = var.windows_target_group_arn
        weight = var.windows_traffic_weight
      }

      target_group {
        arn    = aws_lb_target_group.linux.arn
        weight = var.linux_traffic_weight
      }

      stickiness {
        enabled  = false
        duration = 1
      }
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}


