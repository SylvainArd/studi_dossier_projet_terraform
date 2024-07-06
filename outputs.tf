output "frontend_instance_ips" {
  description = "The public IPs of the frontend instances"
  value       = aws_instance.frontend_instance[*].public_ip
}

output "backend_instance_ips" {
  description = "The public IPs of the backend instances"
  value       = aws_instance.backend[*].public_ip
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.hello_world.repository_url
}
