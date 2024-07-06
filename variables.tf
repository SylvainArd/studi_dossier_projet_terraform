variable "vpc_id" {
  description = "The VPC ID where resources will be created"
  type        = string
}

variable "key_name" {
  description = "The name of the SSH key pair"
  type        = string
}

variable "ami_id" {
  description = "The AMI ID for the frontend instances"
  type        = string
}

variable "db_username" {
  description = "The username for the RDS instance"
  type        = string
}

variable "db_password" {
  description = "The password for the RDS instance"
  type        = string
}
