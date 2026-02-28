# -------------------------
# Terraform & Provider Setup
# -------------------------
terraform {
  backend "s3" {
    bucket  = "techbleat-cicd-state-bucket-s3"
    key     = "envs/dev/terraform.tfstate"
    region  = "eu-north-1"
    encrypt = true
  }
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.26" # Modern version to prevent serialization errors
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

# -------------------------
# 1. Let's Encrypt SSL (ACME) via DuckDNS
# -------------------------
resource "tls_private_key" "reg_key" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.reg_key.private_key_pem
  email_address   = var.admin_email
}

resource "acme_certificate" "certificate" {
  account_key_pem = acme_registration.reg.account_key_pem
  common_name     = var.domain_name # e.g., "my-app.duckdns.org"
  
  dns_challenge {
    provider = "duckdns"
    config = {
      DUCKDNS_TOKEN = var.duckdns_token # Ensure this is in your variables.tf
    }
  }
}

resource "aws_acm_certificate" "le_cert" {
  private_key       = acme_certificate.certificate.private_key_pem
  certificate_body  = acme_certificate.certificate.certificate_pem
  certificate_chain = acme_certificate.certificate.issuer_pem

  lifecycle {
    create_before_destroy = true
  }
}

# -------------------------
# 2. Security Groups (Diagram-Aligned)
# -------------------------

# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  vpc_id      = var.project_vpc
  description = "Allow HTTPS from Internet"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Bastion Security Group (For Ansible Jump Host)
resource "aws_security_group" "bastion_sg" {
  name        = "ansible-sg"
  description = "Allow SSH inbound"
  vpc_id      = var.project_vpc 

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# App Security Group (Private)
resource "aws_security_group" "app_sg" {
  name        = "app-sg"
  vpc_id      = var.project_vpc 
  description = "Allow traffic from ALB and Bastion"

  ingress {
    description     = "Traffic from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS Security Group (Private)
resource "aws_security_group" "rds_sg" {
  name   = var.rds_name
  vpc_id = var.project_vpc
  
  ingress {
    description     = "Postgres from App SG"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------------
# 3. Load Balancer (ELB/ALB)
# -------------------------
resource "aws_lb" "main_alb" {
  name               = "main-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [var.project_subnet, var.project_aurora_subnet] 
}

resource "aws_lb_target_group" "app_tg" {
  name     = "app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.project_vpc
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.le_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# -------------------------
# 4. Instances
# -------------------------

# Bastion (Public)
resource "aws_instance" "bastion-node" {
  ami                    = var.project_ami
  instance_type          = var.project_instance_type
  subnet_id              = var.project_subnet
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = var.project_keyname
  tags                   = { Name = "bastion-node" }
}

# App Node (Private)
resource "aws_instance" "app-node" {
  ami                    = var.project_ami
  instance_type          = var.project_instance_type
  subnet_id              = var.project_aurora_subnet
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name               = var.project_keyname
  tags                   = { Name = "app-node" }
}

resource "aws_lb_target_group_attachment" "app_attachment" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.app-node.id
  port             = 80
}

# -------------------------
# 5. RDS Database (Private)
# -------------------------
resource "aws_db_subnet_group" "rds_subnet" {
  name       = var.rds_subnet_name
  subnet_ids = [var.project_subnet, var.project_aurora_subnet]
}

resource "aws_db_instance" "postgres" {
  identifier             = var.db_identifier
  engine                 = var.db_engine
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  storage_type           = var.db_storage_type
  db_name                = var.db_username
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false 
  skip_final_snapshot    = true
  tags                   = { Name = "free-tier-postgres" }
}

# -------------------------
# 6. Outputs
# -------------------------
output "alb_dns" {
  value = aws_lb.main_alb.dns_name
}

output "ansible_node_ip" {
  value = aws_instance.bastion-node.public_ip
}

output "app_private_ip" {
  value = aws_instance.app-node.private_ip
}