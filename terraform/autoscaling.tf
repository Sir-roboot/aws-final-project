# =============================================================================
# Data Source: Amazon Linux 2023 AMI
# =============================================================================

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

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# =============================================================================
# Launch Template
# =============================================================================

resource "aws_launch_template" "app" {
  name          = "${var.project_prefix}-launch-template"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = data.aws_iam_instance_profile.lab.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2.id]
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh.tpl", {}))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_prefix}-app-instance"
    }
  }

  tags = {
    Name = "${var.project_prefix}-launch-template"
  }
}

# =============================================================================
# Auto Scaling Group
# =============================================================================

resource "aws_autoscaling_group" "app" {
  name                = "${var.project_prefix}-asg"
  min_size            = var.asg_min
  max_size            = var.asg_max
  desired_capacity    = var.asg_desired
  vpc_zone_identifier = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  target_group_arns   = [aws_lb_target_group.main.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_prefix}-app-instance"
    propagate_at_launch = true
  }
}

# =============================================================================
# Target Tracking Scaling Policy
# =============================================================================

resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${var.project_prefix}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target
  }
}
