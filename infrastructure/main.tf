provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "expense-tracker-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "expense-tracker-igw"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "expense-tracker-public-subnet"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "expense-tracker-public-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group for EC2
resource "aws_security_group" "ec2" {
  name        = "expense-tracker-ec2-sg"
  description = "Security group for Expense Tracker EC2"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # Frontend (React)
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "React Frontend"
  }

  # Backend (Node.js)
  ingress {
    from_port   = 4000
    to_port     = 4000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Node.js Backend"
  }

  # MongoDB
  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "MongoDB"
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "expense-tracker-ec2-sg"
  }
}

# Key Pair for SSH
resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = file(var.public_key_path) # Simplified

  tags = {
    Name = "expense-tracker-key"
  }
}

# Check for existing EC2 instance
data "aws_instances" "existing" {
  filter {
    name   = "tag:Name"
    values = ["expense-tracker-server"]
  }

  filter {
    name   = "instance-state-name"
    values = ["running", "pending", "stopping", "stopped"]
  }
}

# Locals to determine if we should create new instance
locals {
  instance_exists = length(data.aws_instances.existing.ids) > 0
  existing_instance_id = local.instance_exists ? data.aws_instances.existing.ids[0] : null
}

# EC2 Instance (only create if doesn't exist)
resource "aws_instance" "app_server" {
  count                  = local.instance_exists ? 0 : 1
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.ec2.id]
  subnet_id              = aws_subnet.public.id

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y python3 python3-pip
              EOF

  tags = {
    Name        = "expense-tracker-server"
    Environment = var.environment
    Project     = var.project_name
  }

  lifecycle {
    ignore_changes = [user_data]
  }
}

# Get existing or newly created instance
data "aws_instance" "current" {
  depends_on = [aws_instance.app_server]
  
  instance_id = local.instance_exists ? local.existing_instance_id : aws_instance.app_server[0].id
}

# Elastic IP
resource "aws_eip" "app_server" {
  instance = data.aws_instance.current.id
  domain   = "vpc"

  tags = {
    Name = "expense-tracker-eip"
  }
}

# Auto-generate Ansible Inventory File
resource "null_resource" "generate_inventory" {
  depends_on = [aws_eip.app_server]

  provisioner "local-exec" {
    command = <<-EOT
      echo "[ec2_instances]" > ../ansible/inventory
      echo "${aws_eip.app_server.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/expense-tracker-key ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> ../ansible/inventory
    EOT
  }

  triggers = {
    instance_id = data.aws_instance.current.id
    public_ip   = aws_eip.app_server.public_ip
  }
}