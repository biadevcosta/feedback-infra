# Receives POST /evaluations and writes the evaluation to DynamoDB.
# Real code is published by the feedback-lambda-ingestion repository
# (lambda:UpdateFunctionCode); this module only provisions the function.
module "ingestion" {
  source = "./modules/lambda-function"

  function_name = "${var.project}-ingestion"
  description   = "Receives POST /evaluations and writes the evaluation to DynamoDB"

  # TODO: update to match the real class once feedback-lambda-ingestion defines it
  handler = "com.feedback.ingestion.CreateEvaluationHandler::handleRequest"

  # Simple PutItem call: low memory and timeout are enough
  memory_size = 256
  timeout     = 5
}

# Only permission this function needs: write new evaluations to the table
data "aws_iam_policy_document" "ingestion_dynamodb" {
  statement {
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.evaluations.arn]
  }
}

resource "aws_iam_role_policy" "ingestion_dynamodb" {
  name   = "dynamodb-put-item"
  role   = module.ingestion.role_name
  policy = data.aws_iam_policy_document.ingestion_dynamodb.json
}
