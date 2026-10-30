# Account is in SES sandbox: every address below must click the
# verification link SES sends before it can send or receive email here.

# Sender identity used as "From" by the notification and report Lambdas
resource "aws_ses_email_identity" "sender" {
  email = var.ses_sender_email
}

# Admin recipients; deduplicated in case one of them is also the sender
resource "aws_ses_email_identity" "admins" {
  for_each = toset([for e in var.admin_emails : e if e != var.ses_sender_email])
  email    = each.value
}
