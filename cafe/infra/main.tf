# Networking
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.tags, { Name = "${local.name}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${local.name}-igw" })
}

resource "aws_subnet" "public" {
  for_each = {
    a = { cidr = var.public_subnet_cidrs[0], az = data.aws_availability_zones.available.names[0] }
    b = { cidr = var.public_subnet_cidrs[1], az = data.aws_availability_zones.available.names[1] }
  }
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true
  tags = merge(local.tags, { Name = "${local.name}-public-${each.key}" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${local.name}-public-rt" })
}

resource "aws_route" "public_inet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Security Groups
resource "aws_security_group" "alb_sg" {
  name        = "${local.name}-alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.this.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.tags, { Name = "${local.name}-alb-sg" })
}

resource "aws_security_group" "ec2_sg" {
  name        = "${local.name}-ec2-sg"
  description = "EC2 security group: only from ALB on 80"
  vpc_id      = aws_vpc.this.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.tags, { Name = "${local.name}-ec2-sg" })
}

# IAM for SSM (no SSH)
resource "aws_iam_role" "ssm_role" {
  name               = "${local.name}-ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = "${local.name}-ec2-instance-profile"
  role = aws_iam_role.ssm_role.name
}

###############################################
# Launch Template for web tier (used by ASG)  #
###############################################
resource "aws_launch_template" "web_lt" {
  name_prefix   = "${local.name}-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.this.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = filebase64("${path.module}/user_data.sh")

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.tags, { Name = "${local.name}-web" })
  }
}

###############################################
# Auto Scaling Group (zero-downtime rollouts) #
###############################################
resource "aws_autoscaling_group" "web_asg" {
  name                      = "${local.name}-asg"
  min_size                  = 1
  desired_capacity          = 2
  max_size                  = 3
  vpc_zone_identifier       = [for s in aws_subnet.public : s.id]
  health_check_type         = "ELB"
  health_check_grace_period = 90
  target_group_arns         = [aws_lb_target_group.this.arn]
  force_delete              = true

  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
      instance_warmup        = 60
    }
  }
}

# ALB
resource "aws_lb" "this" {
  name               = "${local.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [for s in aws_subnet.public : s.id]
  tags               = merge(local.tags, { Name = "${local.name}-alb" })
}

resource "aws_lb_target_group" "this" {
  name     = "${local.name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id
  health_check {
    enabled  = true
    protocol = "HTTP"
    path     = "/"
    matcher  = "200"
  }
  tags = merge(local.tags, { Name = "${local.name}-tg" })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# Target attachment is handled by ASG via target_group_arns
