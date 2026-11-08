# Receives POST /evaluations and writes the evaluation to DynamoDB.
# Real code is published by the feedback-lambda-ingestion repository
# (lambda:UpdateFunctionCode); this module only provisions the function.
module "ingestion" {
  source = "./modules/lambda-function"

  function_name = "${var.project}-ingestion"
  description   = "Receives POST /evaluations and writes the evaluation to DynamoDB"

  # Must match the class in feedback-lambda-ingestion
  handler = "com.feedback.ingestion.IngestionHandler::handleRequest"

  # Java cold start: CPU scales with memory, and the first SDK call (class loading,
  # TLS) timed out at 256 MB / 5 s. Warm calls take milliseconds; the timeout only
  # matters on cold start and stays below the 30 s API Gateway limit
  memory_size = 512
  timeout     = 20

  environment_variables = {
    TABLE_NAME = aws_dynamodb_table.evaluations.name
  }
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

  # Must match the class in feedback-lambda-notification
  handler = "com.feedback.notification.NotificationHandler::handleRequest"

  # Two SDK clients (Cognito and SES) on a Java cold start: same reasoning as ingestion
  memory_size = 512
  timeout     = 30

  environment_variables = {
    USER_POOL_ID = aws_cognito_user_pool.main.id
    ADMIN_GROUP  = aws_cognito_user_group.admins.name
    SES_SENDER   = var.ses_sender_email
  }
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

  # Send the urgency email from the verified sender identity. In the SES sandbox
  # the recipient identities are authorized too, so the admins are listed as well
  statement {
    actions = ["ses:SendEmail"]
    resources = concat(
      [aws_ses_email_identity.sender.arn],
      [for identity in aws_ses_email_identity.admins : identity.arn],
    )
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

# Weekly report: queries the last 7 days on the by-day index and emails the admins.
# Invoked by the EventBridge rule in scheduler.tf
module "report" {
  source = "./modules/lambda-function"

  function_name = "${var.project}-report"
  description   = "Builds the weekly evaluation report and emails it to admins"

  # Must match the class in feedback-lambda-report
  handler = "com.feedback.report.ReportHandler::handleRequest"

  # Runs once a week, always a cold start with three SDK clients; more memory = more CPU
  memory_size = 512
  timeout     = 30

  environment_variables = {
    TABLE_NAME   = aws_dynamodb_table.evaluations.name
    INDEX_NAME   = "by-day"
    USER_POOL_ID = aws_cognito_user_pool.main.id
    ADMIN_GROUP  = aws_cognito_user_group.admins.name
    SES_SENDER   = var.ses_sender_email
    DAYS         = "7"
  }
}

data "aws_iam_policy_document" "report" {
  # Query only on the by-day index; no Scan and no access to the base table
  statement {
    actions   = ["dynamodb:Query"]
    resources = ["${aws_dynamodb_table.evaluations.arn}/index/by-day"]
  }

  # Find the admins group members to email
  statement {
    actions   = ["cognito-idp:ListUsersInGroup"]
    resources = [aws_cognito_user_pool.main.arn]
  }

  # Same SES sandbox rule as the notification function: sender and recipients
  statement {
    actions = ["ses:SendEmail"]
    resources = concat(
      [aws_ses_email_identity.sender.arn],
      [for identity in aws_ses_email_identity.admins : identity.arn],
    )
  }
}

resource "aws_iam_role_policy" "report" {
  name   = "report-permissions"
  role   = module.report.role_name
  policy = data.aws_iam_policy_document.report.json
}
