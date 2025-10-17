variable "project_name" {
  description = "Project name"
  type        = string
  default     = "seniorcare"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "profile" {
  description = "AWS profile (optional)"
  type        = string
  default     = "default"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.30.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Two public subnets"
  type        = list(string)
  default     = ["10.30.1.0/24", "10.30.2.0/24"]
}

variable "instance_type" {
  description = "EC2 type"
  type        = string
  default     = "t3.micro"
}

variable "site_bucket" {
  description = "S3 bucket name that holds the SeniorCare site"
  type        = string
}
