variable "region" {
  description = "AWS Region"
  type        = string
  default     = "ap-south-1"
}

variable "key_name" {
  description = "AWS EC2 Key Pair Name"
  type        = string
  default     = "Redis-key"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  default = "10.0.2.0/24"
}