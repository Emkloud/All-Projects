variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
  default     = "barista-cafe"
}

variable "region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "default"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Two public subnet CIDRs"
  type        = list(string)
  default     = ["10.10.1.0/24", "10.10.2.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for web server"
  type        = string
  default     = "t3.micro"
}
