# feedback-infra

Infraestrutura (Terraform) da **Plataforma de Feedback de Aulas** — Tech Challenge fase 4, arquitetura serverless na AWS.

O aluno envia `POST /avaliacao` com `{"descricao": string, "nota": int 0..10}`.
Os administradores recebem e-mail de urgência (notas baixas) e um relatório semanal.

## Os 4 repositórios

| Repositório | Responsabilidade |
|---|---|
| **feedback-infra** (este) | Terraform de toda a infraestrutura e documentação geral |
| [feedback-lambda-ingestao](../feedback-lambda-ingestao) | Recebe a avaliação e grava no DynamoDB |
| [feedback-lambda-notificacao](../feedback-lambda-notificacao) | Avisa os admins por e-mail quando a urgência é alta |
| [feedback-lambda-relatorio](../feedback-lambda-relatorio) | Gera e envia o relatório semanal |

## Convenções (tarefa 0.5)

- **Região AWS:** `sa-east-1` (São Paulo)
- **Prefixo de nomes:** `feedback-`
- **Funções Lambda:** `feedback-ingestao`, `feedback-notificacao`, `feedback-relatorio` — runtime **Python 3.12**
- **Grupos do Cognito:** `alunos` e `admins`
- **Tags padrão:** `Projeto=feedback`, `Ambiente=dev`, `ManagedBy=terraform`
- **Autenticação da esteira:** OIDC do GitHub (sem chaves fixas da AWS)

## Contrato de dados

Tabela **`Avaliacoes`** — chave `avaliacaoId` (string, UUID).

| Atributo | Tipo | Descrição |
|---|---|---|
| `avaliacaoId` | string | UUID v4 |
| `usuarioId` | string | `sub` do Cognito |
| `descricao` | string | Texto da avaliação (máx. 1000 caracteres) |
| `nota` | número | Inteiro de 0 a 10 |
| `urgencia` | string | `alta` (0-3), `media` (4-6), `baixa` (7-10) |
| `dataEnvio` | string | ISO 8601 em UTC |
| `dia` | string | AAAA-MM-DD no horário de Brasília (UTC-3 fixo) |

Índice **`por-dia`**: chave de partição `dia`, chave de ordenação `dataEnvio`.

## Estrutura (em construção)

```
bootstrap/              # bucket do state e OIDC — roda 1 vez, localmente
modules/lambda-function/
dynamodb.tf  cognito.tf  api.tf  lambdas.tf
ses.tf  scheduler.tf  monitoring.tf  iam.tf
providers.tf  variables.tf  outputs.tf
.github/workflows/      # ci.yml e deploy.yml
docs/                   # diagramas
```

## Status

Acompanhe o andamento em [PLANO.md](PLANO.md).
