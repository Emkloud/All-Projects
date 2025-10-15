# -----------------
# Networking (simple, cost-aware)
# - Public subnets for ALB and EC2
# - No SSH; only ALB -> EC2 on 80
# -----------------
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

# Public subnets in two AZs
resource "aws_subnet" "public" {
  for_each = {
    a = {
      cidr = var.public_subnet_cidrs[0]
      az   = data.aws_availability_zones.available.names[0]
    }
    b = {
      cidr = var.public_subnet_cidrs[1]
      az   = data.aws_availability_zones.available.names[1]
    }
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

# -----------------
# Security Groups
# -----------------
resource "aws_security_group" "alb_sg" {
  name        = "${local.name}-alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP from anywhere"
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
    description     = "HTTP from ALB"
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

# -----------------
# IAM Role for SSM (no SSH needed)
# -----------------
resource "aws_iam_role" "ssm_role" {
  name               = "${local.name}-ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = local.tags
}
## IAM assume role policy document moved to data.tf

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = "${local.name}-ec2-instance-profile"
  role = aws_iam_role.ssm_role.name
}

# -----------------
# EC2 Instance with user_data to install nginx and tic-tac-toe
# -----------------
resource "aws_instance" "web" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = values(aws_subnet.public)[0].id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.this.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "required"
  }

  user_data = <<-EOF
              #!/bin/bash
              set -eux
              dnf install -y nginx || yum install -y nginx
              # Ensure SSM agent is running (generally preinstalled on AL2023)
              (dnf install -y amazon-ssm-agent || true) || (yum install -y amazon-ssm-agent || true)
              systemctl enable amazon-ssm-agent || true
              systemctl restart amazon-ssm-agent || true
              systemctl enable nginx
              cat > /usr/share/nginx/html/index.html <<'HTML'
              <!DOCTYPE html>
              <html lang="en">
              <head>
                <meta charset="UTF-8" />
                <meta name="viewport" content="width=device-width, initial-scale=1.0" />
                <title>Tic-Tac-Toe</title>
                <style>
                  body { font-family: Arial, sans-serif; background: #0f172a; color: #e2e8f0; display:flex; align-items:center; justify-content:center; height:100vh; margin:0; }
                  .board { display:grid; grid-template-columns: repeat(3, 100px); gap:10px; }
                  .cell { width:100px; height:100px; background:#1f2937; display:flex; align-items:center; justify-content:center; font-size:48px; cursor:pointer; border-radius:12px; box-shadow:0 4px 10px rgba(0,0,0,0.4);} 
                  .cell:hover { background:#374151; }
                  .panel { position:absolute; top:24px; text-align:center; }
                  button { margin-left:8px; padding:6px 10px; border-radius:8px; border:1px solid #64748b; background:#111827; color:#e5e7eb; cursor:pointer; }
                </style>
              </head>
              <body>
                <div class="panel">
                  <span id="status">Player X's turn</span>
                  <button onclick="resetGame()">Reset</button>
                </div>
                <div class="board" id="board"></div>
                <script>
                  const board = Array(9).fill(null);
                  const boardEl = document.getElementById('board');
                  const statusEl = document.getElementById('status');
                  let player = 'X';
                  function lines() { return [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]]; }
                  function winner(b){ for (const [a,c,d] of lines()) if (b[a] && b[a]===b[c] && b[a]===b[d]) return b[a]; return null; }
                  function isFull(b){ return b.every(Boolean); }
                  function render(){ boardEl.innerHTML=''; board.forEach((v,i)=>{ const d=document.createElement('div'); d.className='cell'; d.textContent=v||''; d.onclick=()=>move(i); boardEl.appendChild(d);}); }
                  function move(i){ if(board[i]||winner(board)) return; board[i]=player; const w=winner(board); if(w){ statusEl.textContent = `Player $${w} wins!`; render(); return;} if(isFull(board)){ statusEl.textContent='Draw'; render(); return;} player = (player==='X')?'O':'X'; statusEl.textContent = `Player $${player}'s turn`; render(); }
                  function resetGame(){ for(let i=0;i<9;i++) board[i]=null; player='X'; statusEl.textContent='Player X\'s turn'; render(); }
                  resetGame();
                </script>
              </body>
              </html>
              HTML
              systemctl restart nginx
              EOF

  tags = merge(local.tags, { Name = "${local.name}-web" })
}

# -----------------
# Load Balancer
# -----------------
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

resource "aws_lb_target_group_attachment" "web" {
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = aws_instance.web.id
  port             = 80
}
