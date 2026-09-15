provider "aws" {
  region  = "ap-south-1"
  profile = "fahad"
}

# 1. IAM ROLE
# 2. IAM POLICY
# 3. IAM ROLE POLICY ATTACHMENT
# 4. DATA ARCHIVE FILE
# 5. LAMBDA FUNCTION

resource "aws_iam_role" "lambda_role" {
  name               = "tf-aws-lambda-role"
  assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
            "Service": "lambda.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
        ]
    }
  EOF
}

resource "aws_iam_policy" "iam_policy_for_lambda" {
  name        = "aws_iam_policy_for_tf_aws_lambda_role"
  path        = "/"
  description = "AWS IAM Policy for managing aws lambda role"
  policy      = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents"
                ],
                "Resource": "arn:aws:logs:*:*:*",
                "Effect" : "Allow"
            }
        ]
    }
  EOF
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.iam_policy_for_lambda.arn
}

data "archive_file" "zip_the_lambda_code" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda/lambda-func.zip"
}


resource "aws_lambda_function" "tf_lambda_func" {
  filename = "${path.module}/lambda/lambda-func.zip"
  function_name = "fmk-tf-lambda-function"
  role = aws_iam_role.lambda_role.arn
  handler = "main.lambda_handler"
  runtime = "python3.10"
  depends_on = [ aws_iam_role_policy_attachment.attach_iam_policy_to_role ]
}

