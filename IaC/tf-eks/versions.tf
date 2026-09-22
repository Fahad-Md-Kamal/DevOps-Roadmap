terraform {
  required_version = ">= 1.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
    backend "s3" {
    bucket = "fmk-terraform-backup"
    use_lockfile = true
    key    = "states/tf-eks-state.tfstate"
    region = "ap-south-1"
    profile = "fahad"
  }
}
