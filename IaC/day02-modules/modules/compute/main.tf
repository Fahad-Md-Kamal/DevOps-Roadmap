# Looked up live instead of hardcoded, so it never goes stale
# (week4.html 18.8, section 8).
data "aws_ami" "amzn_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "this" {
  for_each               = var.subnet_ids
  ami                    = data.aws_ami.amzn_linux.id
  instance_type          = var.instance_type
  subnet_id              = each.value
  user_data              = file("${path.module}/userdata.sh")
  vpc_security_group_ids = [var.security_group_id]

  tags = {
    Name  = "${var.name_prefix}-ec2-${each.key}"
    Owner = "fahad"
    Event = "IaC-learning"
  }
}
