output "infra_plan_role_arn" {
  description = "Role assumed by the infra pull request pipeline (ci.yml)"
  value       = aws_iam_role.infra_plan.arn
}

output "infra_apply_role_arn" {
  description = "Role assumed by the infra main branch pipeline (deploy.yml)"
  value       = aws_iam_role.infra_apply.arn
}
