# Terraform Variables Configuration File
# Copy this file to terraform.tfvars and customize for your deployment

# AWS Configuration
aws_region = "us-east-1"

# EC2 Instance Configuration
# AMI IDs for Ubuntu 22.04 LTS by region:
# us-east-1: ami-0c7217cdde317cfec
# us-west-2: ami-03f65b8614a860c29
# eu-west-1: ami-0905a3c97561e0b69
ami_id = "ami-0c7217cdde317cfec"

# Instance type (t2.medium recommended for running Docker containers)
# t2.micro (1 vCPU, 1 GB RAM) - Free tier, may be too small
# t2.small (1 vCPU, 2 GB RAM) - Minimum for testing
# t2.medium (2 vCPU, 4 GB RAM) - Recommended for production
# t2.large (2 vCPU, 8 GB RAM) - For heavier workloads
instance_type = "t3.micro"

# SSH Key Pair
# Create a key pair in AWS EC2 console first, then put the name here
key_name = "expense-tracker-key"
public_key_path = "~/.ssh/id_rsa.pub"

# Environment
environment = "production"

# Project Name
project_name = "expense-tracker"
