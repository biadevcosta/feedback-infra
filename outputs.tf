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
