# ---------------------------------------------------------------------------
# AMI Ubuntu 22.04 (Jammy) mới nhất của Canonical
# ---------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Dùng VPC mặc định cho đơn giản (tài khoản AWS nào cũng có sẵn)
data "aws_vpc" "default" {
  default = true
}

# ---------------------------------------------------------------------------
# Key pair: dùng public key có sẵn, hoặc tự sinh nếu public_key_path rỗng
# ---------------------------------------------------------------------------
locals {
  generate_key = var.public_key_path == ""
}

resource "tls_private_key" "ssh" {
  count     = local.generate_key ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "private_key" {
  count           = local.generate_key ? 1 : 0
  content         = tls_private_key.ssh[0].private_key_pem
  filename        = "${path.module}/${var.project_name}-key.pem"
  file_permission = "0400"
}

resource "aws_key_pair" "this" {
  key_name   = "${var.project_name}-key"
  public_key = local.generate_key ? tls_private_key.ssh[0].public_key_openssh : file(pathexpand(var.public_key_path))
}

# ---------------------------------------------------------------------------
# Security Group
# ---------------------------------------------------------------------------
resource "aws_security_group" "this" {
  name        = "${var.project_name}-sg"
  description = "Jenkins, SonarQube, App, Prometheus, Grafana, Node Exporter"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  dynamic "ingress" {
    for_each = var.app_ports
    content {
      description = ingress.key
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = [var.allowed_cidr]
    }
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# ---------------------------------------------------------------------------
# EC2
# ---------------------------------------------------------------------------
resource "aws_instance" "this" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.this.id]

  # replace() bỏ CRLF phòng khi file bị checkout trên Windows
  user_data = var.install_tools ? replace(templatefile("${path.module}/user_data.sh.tftpl", {
    repo_url    = var.repo_url
    repo_branch = var.repo_branch
  }), "\r\n", "\n") : null
  user_data_replace_on_change = true

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_tokens = "required" # IMDSv2
  }

  tags = {
    Name = "${var.project_name}-server"
  }
}

# ---------------------------------------------------------------------------
# Quản lý chi phí: cảnh báo qua email khi chi phí vượt 80% / 100% ngưỡng
# ---------------------------------------------------------------------------
resource "aws_budgets_budget" "monthly" {
  count        = var.budget_email == "" ? 0 : 1
  name         = "${var.project_name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }
}
