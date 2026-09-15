provider "aws" {
  region = "ap-south-1"
  profile = "fahad"
}

resource "aws_iam_user" "created_user" {
  name = "fmk-tf-user"
}

resource "aws_iam_access_key" "access_key" {
    user = aws_iam_user.created_user.name
}

resource "aws_iam_user_policy" "instance_manager_user_assume_role" {
  name = "InstanceManagePolicy"
  user = "${aws_iam_user.created_user.name}"
  policy = jsonencode(
    {
        "Version": "2012-10-17"
        "Statement": [
            {
                "Effect":"Allow",
                "Action": [
                    "ec2:RunInstances",
                    "ec2:StopInstances",
                    "ec2:StartInstances",
                    "ec2:TerminateInstances",
                    "ec2:Describe*",
                    "ec2:CreateTags",
                    "ec2:RequestSpotInstance"
                ],
                "Resource": "*"
            }
        ]
    }
  )
}