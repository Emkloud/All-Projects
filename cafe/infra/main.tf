terraform {
  required_version = ">= 1.1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.67"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

locals {
  name = var.project_name
  tags = {
    Project = var.project_name
    Managed = "terraform"
  }
}

# AMI: Amazon Linux 2023 x86_64
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"]
  filter { name = "name"         values = ["al2023-ami-*-x86_64"] }
  filter { name = "architecture" values = ["x86_64"] }
}

data "aws_availability_zones" "available" { state = "available" }

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
  ingress { from_port = 80 to_port = 80 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0  to_port = 0  protocol = "-1"  cidr_blocks = ["0.0.0.0/0"] }
  tags = merge(local.tags, { Name = "${local.name}-alb-sg" })
}

resource "aws_security_group" "ec2_sg" {
  name        = "${local.name}-ec2-sg"
  description = "EC2 security group: only from ALB on 80"
  vpc_id      = aws_vpc.this.id
  ingress { from_port = 80 to_port = 80 protocol = "tcp" security_groups = [aws_security_group.alb_sg.id] }
  egress  { from_port = 0  to_port = 0  protocol = "-1"  cidr_blocks = ["0.0.0.0/0"] }
  tags = merge(local.tags, { Name = "${local.name}-ec2-sg" })
}

# IAM for SSM (no SSH)
resource "aws_iam_role" "ssm_role" {
  name               = "${local.name}-ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["ec2.amazonaws.com"] }
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = "${local.name}-ec2-instance-profile"
  role = aws_iam_role.ssm_role.name
}

# EC2 instance with Cafe site
resource "aws_instance" "web" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = values(aws_subnet.public)[0].id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.this.name

  metadata_options { http_endpoint = "enabled" http_tokens = "required" }

  user_data = <<-EOF
              #!/bin/bash
              set -eux
              dnf install -y nginx || yum install -y nginx
              systemctl enable nginx
              cat > /usr/share/nginx/html/index.html <<'HTML'
              <!DOCTYPE html>
              <html lang="en">
              <head>
                <meta charset="utf-8"/>
                <meta name="viewport" content="width=device-width, initial-scale=1"/>
                <title>Barista Cafe</title>
                <style>
                  :root{--bg:#0b0f19;--card:#111827;--text:#e5e7eb;--muted:#94a3b8;--accent:#d97706;}
                  *{box-sizing:border-box} body{margin:0;background:var(--bg);color:var(--text);font-family:Inter,system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif}
                  .hero{min-height:70vh;display:grid;place-items:center;background:linear-gradient(120deg,#1f2937, #0b0f19);position:relative;overflow:hidden}
                  .hero:before{content:"";position:absolute;inset:-20%;background:radial-gradient(600px 300px at 20% 20%,rgba(217,119,6,.15),transparent),radial-gradient(500px 260px at 80% 30%,rgba(59,130,246,.18),transparent)}
                  .wrap{width:min(1100px,92%);margin-inline:auto}
                  .nav{display:flex;justify-content:space-between;align-items:center;padding:18px 0}
                  .brand{font-weight:800;letter-spacing:.8px}
                  .pill{background:#0b1220;border:1px solid #223; padding:10px 14px;border-radius:999px;color:var(--muted)}
                  .hgrid{display:grid;grid-template-columns:1.1fr .9fr;gap:40px;align-items:center}
                  h1{font-size:48px;line-height:1.1;margin:0 0 10px}
                  .lead{color:var(--muted);font-size:18px;margin:0 0 20px}
                  .cta{display:flex;gap:12px}
                  .btn{padding:12px 16px;border-radius:10px;border:1px solid #334155;background:#0b1220;color:#e2e8f0;cursor:pointer}
                  .btn.accent{background:var(--accent);border-color:#b45309;color:#0b0f19;font-weight:700}
                  .cardgrid{display:grid;grid-template-columns:repeat(3,1fr);gap:18px;margin:40px 0}
                  .card{background:var(--card);padding:18px;border-radius:14px;border:1px solid #1f2937}
                  .card h3{margin:0 0 6px}
                  .menu{background:#0a0f1a;padding:60px 0;border-top:1px solid #1e293b;border-bottom:1px solid #1e293b}
                  .menu h2{margin:0 0 18px}
                  .list{display:grid;grid-template-columns:repeat(2,1fr);gap:14px}
                  .item{display:flex;justify-content:space-between;background:#0c1424;border:1px solid #1e293b;padding:14px;border-radius:12px}
                  footer{padding:30px 0;color:var(--muted)}
                  @media(max-width:900px){.hgrid{grid-template-columns:1fr}.cardgrid{grid-template-columns:1fr}.list{grid-template-columns:1fr}}
                </style>
              </head>
              <body>
                <div class="wrap">
                  <div class="nav">
                    <div class="brand">BARISTA CAFE</div>
                    <div class="pill">Open daily • 7:00–19:00 • Downtown</div>
                  </div>
                </div>

                <section class="hero">
                  <div class="wrap hgrid">
                    <div>
                      <h1>Craft Coffee & Fresh Bakery</h1>
                      <p class="lead">Inspired by the Barista Cafe template. Small-batch roasts, artisan pastries, and a cozy space to meet or work.</p>
                      <div class="cta">
                        <a class="btn accent" href="#menu">View Menu</a>
                        <a class="btn" href="#about">About Us</a>
                      </div>
                    </div>
                    <div>
                      <div class="cardgrid">
                        <div class="card"><h3>Single Origin</h3><p class="lead">Seasonal beans with bright notes.</p></div>
                        <div class="card"><h3>Oat Latte</h3><p class="lead">Smooth, velvety, balanced.
                        </p></div>
                        <div class="card"><h3>Croissants</h3><p class="lead">Butter-forward, flaky layers.</p></div>
                      </div>
                    </div>
                  </div>
                </section>

                <section id="menu" class="menu">
                  <div class="wrap">
                    <h2>Menu Highlights</h2>
                    <div class="list">
                      <div class="item"><span>Espresso</span><span>$3.00</span></div>
                      <div class="item"><span>Cappuccino</span><span>$4.50</span></div>
                      <div class="item"><span>Oat Latte</span><span>$5.00</span></div>
                      <div class="item"><span>Cold Brew</span><span>$4.00</span></div>
                      <div class="item"><span>Butter Croissant</span><span>$3.25</span></div>
                      <div class="item"><span>Chocolate Muffin</span><span>$3.75</span></div>
                    </div>
                  </div>
                </section>

                <div id="about" class="wrap" style="padding:40px 0">
                  <h2>About</h2>
                  <p class="lead">We source ethically, rotate single-origin roasts, and bake in-house daily. Visit us for cuppings, latte art classes, and seasonal specials.</p>
                </div>

                <footer>
                  <div class="wrap">© <span id="y"></span> Barista Cafe • Follow @barista.cafe</div>
                  <script>document.getElementById('y').textContent=new Date().getFullYear()</script>
                </footer>
              </body>
              </html>
              HTML
              systemctl restart nginx
              EOF

  tags = merge(local.tags, { Name = "${local.name}-web" })
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
  health_check { enabled = true protocol = "HTTP" path = "/" matcher = "200" }
  tags = merge(local.tags, { Name = "${local.name}-tg" })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action { type = "forward" target_group_arn = aws_lb_target_group.this.arn }
}

resource "aws_lb_target_group_attachment" "web" {
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = aws_instance.web.id
  port             = 80
}
