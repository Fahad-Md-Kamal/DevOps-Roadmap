variable "subnet_az_id" {
  type        = string
  description = "subnet availability zone id"
}

variable "env" {
  type        = string
  description = "Environment variable"
}

variable "depends_on_igw_ids" {
  type        = list(string)
  description = "Internet Gateway IDS"
}