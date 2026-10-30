# HTTP API: cheaper than REST API, enough for a single route
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project}-api"
  protocol_type = "HTTP"
}

# Validates the Cognito JWT sent by students/admins; rejects missing or invalid tokens
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.main.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${var.project}-cognito-jwt"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.app.id]
    issuer   = "https://${aws_cognito_user_pool.main.endpoint}"
  }
}

resource "aws_apigatewayv2_integration" "ingestion" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = module.ingestion.function_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_evaluations" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /evaluations"
  target    = "integrations/${aws_apigatewayv2_integration.ingestion.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# Cost guard: default budget is $4/month, so cap traffic at 1 req/s, burst 1,
# for every route on this stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = 1
    throttling_burst_limit = 1
  }
}

resource "aws_lambda_permission" "api_invoke_ingestion" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.ingestion.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
