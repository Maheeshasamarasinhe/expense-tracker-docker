# Input Variables for Terraform Configuration

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "AMI ID for EC2 instance (Ubuntu 22.04 LTS recommended)"
  type        = string
  default     = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS in us-east-1
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.medium" # 2 vCPU, 4 GB RAM - suitable for Docker containers
}

variable "key_pair_name" {
  description = "Name of the SSH key pair for EC2 access"
  type        = string
  default     = "task-tracker-key"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "task-tracker"
}
