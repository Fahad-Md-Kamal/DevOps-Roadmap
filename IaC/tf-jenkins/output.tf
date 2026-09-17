output "ec2_public_dns" {
  value = aws_instance.ec2_example.public_dns
}

output "ec2_public_ip" {
  value = aws_instance.ec2_example.public_ip
}