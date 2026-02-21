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
  }
}

provider "aws" {
  region = "eu-north-1"
}

# -------------------------
# Web Node Security Group
# -------------------------

resource "aws_security_group" "ansible_sg" {

  name        = "ansible-sg"
  description = "Allow SSH and Port 80  inbound, all outbound"
  vpc_id      = var.project_vpc 


  # inbound SSH

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # inbound 80 (web)
  ingress {
    description = "Web port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # inbound 443 (web)
  ingress {
    description = "Web port 443"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-security_group"
  }

}

#-------------------------
# ANSIBLE EC2 Instance
# ------------------------


resource "aws_instance" "ansible-node" {
  ami                    = var.project_ami
  instance_type          = var.project_instance_type
  subnet_id              = var.project_subnet
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]
  key_name               =  var.project_keyname

  tags = {
    Name = "ansible-node"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = var.rds_name
  description = "RDS PostgreSQL access"
  vpc_id      = var.project_vpc
  
  ingress {
    description = "Postgres from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "Postgres from anywhere (DEV ONLY)"
    from_port   = 5432
    to_port     = 5432
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

resource "aws_db_subnet_group" "rds_subnet" {
  name       = var.rds_subnet_name
  subnet_ids = [var.project_subnet, var.project_aurora_subnet]
}

resource "aws_db_instance" "postgres" {
  identifier = var.db_identifier

  engine         =var.db_engine


  instance_class = var.db_instance_class

  allocated_storage = 20
  storage_type      = var.db_storage_type

  db_name  = var.db_username
  username = var.db_password
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  publicly_accessible = true
  multi_az            = false

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name        = "free-tier-postgres"
    Environment = var.environment
  }
}


# set up rds


#--------------------------------
# Outputs - Public (external) IPs
#--------------------------------


output "ansible_node_ip" {
  description = " Public IP"
  value  = aws_instance.ansible-node.public_ip
}
