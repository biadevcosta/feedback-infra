variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "sa-east-1"
}

variable "project" {
  description = "Project name, used as resource name prefix and Project tag"
  type        = string
  default     = "feedback"
}

variable "environment" {
  description = "Environment name, used in the Environment tag"
  type        = string
  default     = "dev"
}

variable "github_owner" {
  description = "GitHub user or organization that owns the repositories"
  type        = string
  default     = "biadevcosta"
}

variable "github_owner_id" {
  description = "Numeric ID of the GitHub owner, used in the immutable OIDC subject claim"
  type        = number
  default     = 97992738
}

variable "github_repo_ids" {
  description = "Numeric IDs of the GitHub repositories, used in the immutable OIDC subject claim"
  type        = map(number)
  default = {
    feedback-infra = 1427783940
  }
}

variable "ses_sender_email" {
  description = "Verified SES sender address used as From for urgency alerts and the weekly report. No default on purpose: set it in a local terraform.tfvars (gitignored) or a GitHub Actions variable, never commit a real address."
  type        = string
}

variable "admin_emails" {
  description = "Admin email addresses that receive urgency alerts and the weekly report; each must be verified in SES while the account is in sandbox. No default on purpose, same reason as ses_sender_email."
  type        = list(string)
}
