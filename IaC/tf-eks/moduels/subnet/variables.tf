variable "vpc_id" {
  type        = string
  description = "VPC-ID"
}

variable "env" {
  type        = string
  description = "Environment variable"
}

variable "az" {
  type        = string
  description = "Availability Zone"
}

variable "cidr_block" {
  type        = string
  description = "CIDR block"
}

variable "type" {
  type        = string
  description = "Public/Private type subnet"
}

variable "eks_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "map_public_ip_on_launch" {
  type        = bool
  default     = false
  description = "Whether instances launched into this subnet get a public IP automatically. Left false (the private-subnet default) unless a caller explicitly opts in for a public subnet."
}