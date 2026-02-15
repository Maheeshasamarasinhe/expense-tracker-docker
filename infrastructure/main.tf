terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Generate SSH Key Pair
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS Key Pair from generated key
resource "aws_key_pair" "generated" {
  key_name   = var.key_name
  public_key = tls_private_key.ssh_key.public_key_openssh

  tags = {
    Name = var.key_name
  }
}

# Save private key to local file for Ansible
resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/../ansible/ssh_key.pem"
  file_permission = "0600"
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

# EC2 Instance - Create with generated key pair
resource "aws_instance" "app_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.generated.key_name
  vpc_security_group_ids = [aws_security_group.ec2.id]
  subnet_id              = aws_subnet.public.id

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              
              # === PRIORITY 1: Ensure SSH is immediately available ===
              # Configure SSH daemon for reliability before anything else
              systemctl stop ssh 2>/dev/null || systemctl stop openssh-server 2>/dev/null || true
              
              # Configure SSH daemon settings for better stability
              cat > /etc/ssh/sshd_config.d/99-stable.conf << 'SSHCONF'
# Stability settings
MaxStartups 10:30:60
ClientAliveInterval 30
ClientAliveCountMax 10
LoginGraceTime 120
TCPKeepAlive yes
UseDNS no
SSHCONF
              
              # Start SSH with new configuration
              systemctl start ssh 2>/dev/null || systemctl start openssh-server 2>/dev/null || true
              systemctl enable ssh 2>/dev/null || systemctl enable openssh-server 2>/dev/null || true
              
              # Log remaining output
              exec > >(tee /var/log/user-data.log) 2>&1
              
              echo "=== Starting user-data script ==="
              echo "SSH daemon configured and started"
              
              # Wait for cloud-init to complete if running
              cloud-init status --wait || true
              
              # Update system (non-blocking for SSH)
              apt-get update -y
              apt-get install -y python3 python3-pip curl wget
              
              # Create completion marker
              echo "User data script completed successfully" > /var/lib/user-data-complete
              echo "=== user-data script completed ==="
              EOF
  )
  
  user_data_replace_on_change = true

  tags = {
    Name        = "expense-tracker-server"
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [
    aws_internet_gateway.main,
    aws_route_table_association.public,
    aws_key_pair.generated
  ]
  
  
  
}

# Elastic IP
resource "aws_eip" "app_server" {
  instance = aws_instance.app_server.id
  domain   = "vpc"

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "expense-tracker-eip"
  }
}


resource "null_resource" "generate_inventory" {
  depends_on = [aws_eip.app_server, local_file.private_key]

  provisioner "local-exec" {
    command = <<-EOT
      echo "[ec2_instances]" > ${path.module}/../ansible/inventory
      echo "${aws_eip.app_server.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=./ssh_key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> ${path.module}/../ansible/inventory
    EOT
  }

  triggers = {
    instance_id = aws_instance.app_server.id
    public_ip   = aws_eip.app_server.public_ip
  }
}