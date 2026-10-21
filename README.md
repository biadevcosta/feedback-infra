# feedback-infra

Infrastructure (Terraform) for the **Class Feedback Platform** — Tech Challenge phase 4, serverless architecture on AWS.

Students submit `POST /evaluations` with `{"description": string, "score": int 0..10}`.
Administrators receive an urgent-feedback email (low scores) and a weekly report.

## The 4 repositories

| Repository | Responsibility |
|---|---|
| **feedback-infra** (this one) | Terraform for all infrastructure and general documentation |
| [feedback-lambda-ingestion](../feedback-lambda-ingestion) | Receives the evaluation and writes it to DynamoDB |
| [feedback-lambda-notification](../feedback-lambda-notification) | Notifies admins by email when urgency is high |
| [feedback-lambda-report](../feedback-lambda-report) | Generates and sends the weekly report |

## Conventions (task 0.5)

- **AWS region:** `sa-east-1` (São Paulo)
- **Name prefix:** `feedback-`
- **Lambda functions:** `feedback-ingestion`, `feedback-notification`, `feedback-report` — runtime **Java 21** (built with **Maven**), **AWS SDK v2**
- **Cognito groups:** `students` and `admins`
- **Default tags:** `Project=feedback`, `Environment=dev`, `ManagedBy=terraform`
- **Pipeline authentication:** GitHub OIDC (no static AWS keys)
- **Billing:** this account has **no free tier**. Every `terraform plan` must call out the estimated cost of new resources; prefer on-demand/pay-per-use over anything with an idle hourly cost.

## Data contract

Table **`Evaluations`** — partition key `evaluationId` (string, UUID).

| Attribute | Type | Description |
|---|---|---|
| `evaluationId` | string | UUID v4 |
| `userId` | string | Cognito `sub` |
| `description` | string | Evaluation text (max 1000 characters) |
| `score` | number | Integer from 0 to 10 |
| `urgency` | string | `high` (0-3), `medium` (4-6), `low` (7-10) |
| `submittedAt` | string | ISO 8601, UTC |
| `day` | string | YYYY-MM-DD, America/Sao_Paulo (fixed UTC-3) |

Index **`by-day`**: partition key `day`, sort key `submittedAt`.

## Structure (in progress)

```
modules/lambda-function/
dynamodb.tf  cognito.tf  api.tf  lambdas.tf
ses.tf  scheduler.tf  monitoring.tf  iam.tf
providers.tf  variables.tf  outputs.tf
.github/workflows/      # ci.yml and deploy.yml
docs/                   # diagrams
```

## Status

Track progress in [PLANO.md](PLANO.md).
