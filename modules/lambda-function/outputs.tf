output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "Invoke ARN, used by API Gateway and event source permissions"
  value       = aws_lambda_function.this.invoke_arn
}

output "role_name" {
  description = "Name of the function's own IAM role, for callers to attach extra inline policies"
  value       = aws_iam_role.this.name
}

output "role_arn" {
  description = "ARN of the function's own IAM role"
  value       = aws_iam_role.this.arn
}

output "log_group_name" {
  description = "CloudWatch log group name (14-day retention)"
  value       = aws_cloudwatch_log_group.this.name
}
