output "ec2_public_dns" {
  value = aws_instance.ec2_example.public_dns
}

output "s3_bucket_arn" {
  value = aws_s3_bucket.s3_bucket_created.arn
}