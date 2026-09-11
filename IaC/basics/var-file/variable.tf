variable "instance_type" {
  description = "Instace type is t3.micro free tier"
  type        = string
  default     = "t3.micro"
}

variable "instance_count" {
  description = "EC2 instance count"
  type        = number
  default     = 2
}

variable "enable_public_ip" {
  description = "Enable public IP Address"
  type        = bool
  default     = false
}

variable "username_prefix" {
  description = "username's general prefix"
  type        = string
  default     = "fmk-tf"
}

variable "project_environment" {
  description = "Project name and envrionment"
  type        = map(string)
  default = {
    Name  = "TF Instance"
    Owner = "fahad"
    Event = "learning-devops-tf"
  }
}
