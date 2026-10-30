output "infra_plan_role_arn" {
  description = "Role assumed by the infra pull request pipeline (ci.yml)"
  value       = aws_iam_role.infra_plan.arn
}

output "infra_apply_role_arn" {
  description = "Role assumed by the infra main branch pipeline (deploy.yml)"
  value       = aws_iam_role.infra_apply.arn
}

output "evaluations_table_name" {
  description = "DynamoDB table that stores the evaluations"
  value       = aws_dynamodb_table.evaluations.name
}

output "evaluations_table_arn" {
  description = "ARN of the evaluations table"
  value       = aws_dynamodb_table.evaluations.arn
}

output "evaluations_stream_arn" {
  description = "ARN of the evaluations table stream, consumed by the notification Lambda"
  value       = aws_dynamodb_table.evaluations.stream_arn
}

output "cognito_user_pool_id" {
  description = "Cognito user pool with the students and admins groups"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_arn" {
  description = "ARN of the Cognito user pool, used by the notification Lambda (ListUsersInGroup)"
  value       = aws_cognito_user_pool.main.arn
}

output "cognito_app_client_id" {
  description = "Public app client used to log in and get the JWT"
  value       = aws_cognito_user_pool_client.app.id
}

output "cognito_issuer_url" {
  description = "JWT issuer, used by the API authorizer"
  value       = "https://${aws_cognito_user_pool.main.endpoint}"
}

output "ingestion_function_name" {
  description = "Name of the ingestion Lambda function"
  value       = module.ingestion.function_name
}

output "ingestion_function_arn" {
  description = "ARN of the ingestion Lambda function"
  value       = module.ingestion.function_arn
}

output "api_url" {
  description = "Base URL of the HTTP API (append /evaluations for POST)"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "notification_dlq_arn" {
  description = "ARN of the DLQ for failed notification Lambda invocations"
  value       = aws_sqs_queue.notification_dlq.arn
}

output "notification_function_name" {
  description = "Name of the notification Lambda function"
  value       = module.notification.function_name
}

output "notification_function_arn" {
  description = "ARN of the notification Lambda function"
  value       = module.notification.function_arn
}
