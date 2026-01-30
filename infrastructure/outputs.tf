# Output values to display after Terraform apply

output "instance_id" {
  description = "EC2 Instance ID"
  value       = data.aws_instance.current.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.app_server.public_ip
}
}

output "instance_public_dns" {
  description = "Public DNS of the EC2 instance"
  value       = data.aws_instance.current.public_dns
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/expense-tracker-key ubuntu@${aws_eip.app_server.public_ip}"
}

output "frontend_url" {
  description = "Frontend application URL"
  value       = "http://${aws_eip.app_server.public_ip}:3000"
}

output "backend_url" {
  description = "Backend API URL"
  value       = "http://${aws_eip.app_server.public_ip}:4000"
}

output "ansible_inventory" {
  description = "Ansible inventory file content"
  value       = "[ec2_instances]\n${aws_eip.app_server.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/expense-tracker-key"
}