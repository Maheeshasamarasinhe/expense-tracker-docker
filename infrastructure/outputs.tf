# Output Values from Terraform

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.task_tracker_server.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.task_tracker_eip.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.task_tracker_server.public_dns
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.task_tracker_sg.id
}

output "frontend_url" {
  description = "URL to access the frontend application"
  value       = "http://${aws_eip.task_tracker_eip.public_ip}:9000"
}

output "backend_url" {
  description = "URL to access the backend API"
  value       = "http://${aws_eip.task_tracker_eip.public_ip}:8000"
}

output "ssh_connection" {
  description = "SSH connection command"
  value       = "ssh -i ${var.key_pair_name}.pem ubuntu@${aws_eip.task_tracker_eip.public_ip}"
}
