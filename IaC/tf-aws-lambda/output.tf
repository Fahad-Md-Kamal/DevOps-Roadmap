output "tf_aws_role_output" {
  value = aws_iam_role.lambda_role.name
}

output "tf_aws_role_arn_output" {
  value = aws_iam_role.lambda_role.arn
}

output "tf_logging_arn_output" {
  value = aws_iam_policy.iam_policy_for_lambda.arn
}
