# Student and admin login; the API JWT authorizer validates the tokens issued here
resource "aws_cognito_user_pool" "main" {
  name = "${var.project}-users"

  # Lite tier: cheapest per MAU, covers email login, groups and JWT
  user_pool_tier = "LITE"

  # Email is the login name
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  username_configuration {
    case_sensitive = false
  }

  # No self sign-up: only users created by an admin get a token
  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = false
    temporary_password_validity_days = 7
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Cognito default sender (no SES needed, low daily limit is enough here)
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Kept off so terraform destroy works after delivery (task 7.9)
  deletion_protection = "INACTIVE"
}

# Public client (no secret): SRP for apps, admin password auth only for CLI tests with IAM credentials
resource "aws_cognito_user_pool_client" "app" {
  name         = "${var.project}-app"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true

  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 1

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}

resource "aws_cognito_user_group" "students" {
  name         = "students"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Students who submit class evaluations"
}

resource "aws_cognito_user_group" "admins" {
  name         = "admins"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Administrators who receive urgency emails and the weekly report"
}
