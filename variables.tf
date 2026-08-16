variable "region" {
  type        = string
  description = "Default AWS region"
}

variable "any_ip" {
  type        = string
  description = "All possible IP addresses"
}

variable "local_ip" {
  type        = string
  description = "Local IP address"
}

variable "ec2_instance_type" {
  type = string
  description = "EC2 Instance type"
}

variable "secret_value" {
  type        = string
  description = "Value to store in the Secrets Manager secret"
  sensitive   = true
}