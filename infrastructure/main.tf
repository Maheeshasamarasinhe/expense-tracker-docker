provider "aws" {
  region = "us-east-1"
}

resource "aws_ecr_repository" "backend" {
  name = "expense-backend"
}

resource "aws_ecr_repository" "frontend" {
  name = "expense-frontend"
}

resource "aws_documentdb_cluster" "mongodb" {
  cluster_identifier      = "expense-tracker-db"
  engine                  = "docdb"
  master_username         = "admin"
  master_password         = "password123"
  backup_retention_period = 1
  preferred_backup_window = "07:00-09:00"
  skip_final_snapshot     = true
}

resource "aws_ecs_cluster" "main" {
  name = "expense-tracker"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "expense-tracker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512

  container_definitions = jsonencode([
    {
      name  = "backend"
      image = "${aws_ecr_repository.backend.repository_url}:latest"
      portMappings = [
        {
          containerPort = 4000
        }
      ]
      environment = [
        {
          name  = "MONGODB_URI"
          value = "mongodb://${aws_documentdb_cluster.mongodb.endpoint}:27017/expense_tracker"
        }
      ]
    },
    {
      name  = "frontend"
      image = "${aws_ecr_repository.frontend.repository_url}:latest"
      portMappings = [
        {
          containerPort = 3000
        }
      ]
    }
  ])
}