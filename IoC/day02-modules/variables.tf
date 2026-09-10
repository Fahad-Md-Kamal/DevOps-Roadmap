variable "region" {
  type        = string
  default     = "ap-south-1"
  description = "AWS region everything is deployed into."
}

variable "profile" {
  type        = string
  default     = "fahad"
  description = "AWS CLI profile to authenticate with."
}

variable "vpc_cidr" {
  type        = string
  default     = "11.0.0.0/16"
  description = "CIDR block for the VPC."
}

variable "name_prefix" {
  type        = string
  default     = "fmk"
  description = "Prefix applied to every resource name and tag across all modules."
}
