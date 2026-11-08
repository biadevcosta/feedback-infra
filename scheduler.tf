# EventBridge cron is always UTC: Monday 8am in Brasília (UTC-3) is 11:00 UTC
resource "aws_cloudwatch_event_rule" "weekly_report" {
  name                = "${var.project}-weekly-report"
  description         = "Triggers the weekly report every Monday at 8am Brasília time"
  schedule_expression = "cron(0 11 ? * MON *)"
}

resource "aws_cloudwatch_event_target" "weekly_report" {
  rule = aws_cloudwatch_event_rule.weekly_report.name
  arn  = module.report.function_arn
}

resource "aws_lambda_permission" "events_invoke_report" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.report.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.weekly_report.arn
}
