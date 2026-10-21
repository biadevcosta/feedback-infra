resource "aws_dynamodb_table" "evaluations" {
  name         = "Evaluations"
  billing_mode = "PAY_PER_REQUEST" # on-demand: no idle cost
  hash_key     = "evaluationId"

  attribute {
    name = "evaluationId"
    type = "S"
  }

  attribute {
    name = "day"
    type = "S"
  }

  attribute {
    name = "submittedAt"
    type = "S"
  }

  # Weekly report: one Query per day, ordered by submission time
  global_secondary_index {
    name               = "by-day"
    projection_type    = "INCLUDE"
    non_key_attributes = ["description", "score", "urgency"] # userId left out on purpose

    key_schema {
      attribute_name = "day"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "submittedAt"
      key_type       = "RANGE"
    }

    on_demand_throughput {
      max_read_request_units = 5
    }
  }

  # Cost guard: caps on-demand throughput (requests above it are throttled, not billed)
  on_demand_throughput {
    max_read_request_units  = 5
    max_write_request_units = 5
  }

  # Without kms_key_arn, DynamoDB uses the AWS managed key aws/dynamodb (no monthly fee)
  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  # Feeds the notification Lambda
  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
}
