output "instance_ips" {
  description = "The public IPs of the instances"
  value       = aws_instance.backend[*].public_ip
}