terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    archive = {
      source = "hashicorp/archive"
    }
  }
}

# Placeholder code so the function exists before its own repository publishes
# real code. lambda:UpdateFunctionCode (from the function's own pipeline)
# replaces this, and the lifecycle block below keeps Terraform from reverting it.
data "archive_file" "placeholder" {
  type        = "zip"
  output_path = "${path.module}/placeholder-${var.function_name}.zip"

  source {
    content  = "Placeholder deployed by Terraform. Real code comes from this function's own repository."
    filename = "README.txt"
  }
}

resource "aws_iam_role" "this" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14 # short retention, kept low for cost
}

# Minimal permission: only this function's own log group, no wildcard resource
data "aws_iam_policy_document" "logs" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }
}

resource "aws_iam_role_policy" "logs" {
  name   = "logs"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.logs.json
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  description   = var.description
  role          = aws_iam_role.this.arn

  runtime = var.runtime
  handler = var.handler

  memory_size = var.memory_size
  timeout     = var.timeout

  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  depends_on = [aws_cloudwatch_log_group.this, aws_iam_role_policy.logs]

  lifecycle {
    # Real code is deployed by the function's own repository (update-function-code)
    ignore_changes = [filename, source_code_hash]
  }
}
