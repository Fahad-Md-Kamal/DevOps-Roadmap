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

variable "env" {
  type        = string
  default     = "staging"
  description = "Environment that will be handling it."
}