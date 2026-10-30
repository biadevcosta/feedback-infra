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

# Failure destination for the notification function's Streams trigger (task 4.3):
# an event the function can't process after retrying lands here instead of being lost
resource "aws_sqs_queue" "notification_dlq" {
  name = "${var.project}-notification-dlq"
}

# Sends an urgency email to admins when a high-urgency evaluation is inserted
module "notification" {
  source = "./modules/lambda-function"

  function_name = "${var.project}-notification"
  description   = "Sends an urgency email to admins when a high-urgency evaluation is inserted"

  # TODO: update to match the real class once feedback-lambda-notification defines it
  handler = "com.feedback.notification.UrgencyAlertHandler::handleRequest"

  memory_size = 256
  timeout     = 10
}

# Only INSERT events, and only when the new item's urgency is "high"
resource "aws_lambda_event_source_mapping" "notification_stream" {
  event_source_arn  = aws_dynamodb_table.evaluations.stream_arn
  function_name     = module.notification.function_name
  starting_position = "LATEST"
  batch_size        = 1

  # Cost guard: a few retries, then straight to the DLQ instead of retrying forever
  maximum_retry_attempts = 2

  filter_criteria {
    filter {
      pattern = jsonencode({
        eventName = ["INSERT"]
        dynamodb = {
          NewImage = {
            urgency = { S = ["high"] }
          }
        }
      })
    }
  }

  destination_config {
    on_failure {
      destination_arn = aws_sqs_queue.notification_dlq.arn
    }
  }
}

data "aws_iam_policy_document" "notification" {
  # Required by the event source mapping above to read the DynamoDB Streams records
  statement {
    actions   = ["dynamodb:DescribeStream", "dynamodb:GetRecords", "dynamodb:GetShardIterator"]
    resources = [aws_dynamodb_table.evaluations.stream_arn]
  }

  # ListStreams has no resource-level permissions in DynamoDB; same as the AWS managed
  # AWSLambdaDynamoDBExecutionRole policy
  statement {
    actions   = ["dynamodb:ListStreams"]
    resources = ["*"]
  }

  # Find the admins group members to notify
  statement {
    actions   = ["cognito-idp:ListUsersInGroup"]
    resources = [aws_cognito_user_pool.main.arn]
  }

  # Send the urgency email from the verified sender identity
  statement {
    actions   = ["ses:SendEmail"]
    resources = [aws_ses_email_identity.sender.arn]
  }

  # Lets the event source mapping deliver failed events to the DLQ
  statement {
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.notification_dlq.arn]
  }
}

resource "aws_iam_role_policy" "notification" {
  name   = "notification-permissions"
  role   = module.notification.role_name
  policy = data.aws_iam_policy_document.notification.json
}
