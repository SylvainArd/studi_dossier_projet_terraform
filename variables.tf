variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "ami_id" {
  description = "The ID of the AMI"
  type        = string
}

variable "db_username" {
  description = "The username for the RDS instance"
  type        = string
}

variable "db_password" {
  description = "The password for the RDS instance"
  type        = string
  sensitive   = true
}

variable "key_name" {
  description = "The name of the SSH key pair"
  type        = string
}

variable "public_key" {
  description = "The public key content"
  type        = string
}