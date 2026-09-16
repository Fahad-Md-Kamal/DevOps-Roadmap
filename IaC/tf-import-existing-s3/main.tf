provider "aws" {
  region  = "ap-south-1"
  profile = "fahad"
}


# tf import aws_s3_bucket.fmk-terraform-backup fmk-terraform-backup 

resource "aws_s3_bucket" "fmk-terraform-backup" {
    bucket = "fmk-terraform-backup"
    # tags = {
    #     Name = "fmk-tf-bucket"
    # }
  
}


# resource "aws_s3_bucket_acl" "fmk-terraform-backup-acl" {
#   bucket = aws_s3_bucket.fmk-terraform-backup.id
# }