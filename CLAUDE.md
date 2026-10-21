# feedback-infra

## Projeto
Plataforma de feedback de aulas (Tech Challenge, fase 4), serverless na AWS. O aluno envia `POST /evaluations` com `{"description": string, "score": int 0 a 10}`. Os administradores recebem e-mail de urgência e um relatório semanal.

## Os 4 repositórios
- feedback-infra: Terraform de toda a infraestrutura e a documentação geral
- feedback-lambda-ingestao: recebe a avaliação e grava no DynamoDB
- feedback-lambda-notificacao: avisa os admins por e-mail quando a urgência é alta
- feedback-lambda-relatorio: gera e envia o relatório semanal

## Convenções (definidas na tarefa 0.5; ajuste aqui se o grupo mudar)
- Região AWS: sa-east-1 (São Paulo) - CONFIRMADA. Prefixo de nomes: `feedback-`
- Funções: `feedback-ingestao`, `feedback-notificacao`, `feedback-relatorio`. Java 21 (Maven), AWS SDK v2
- Grupos do Cognito: `students` e `admins`
- Idioma: código Java, comentários, nomes de variáveis/recursos de código e README em inglês. CLAUDE.md e PLANO.md continuam em português (são instruções de processo, não código).
- Custos: esta conta AWS **não tem free tier**. Antes de qualquer `apply` ou criação manual de recurso, informe o custo estimado (ou "sem custo fixo, cobrança por uso") e peça confirmação. Prefira sempre a opção mais barata: on-demand em vez de provisionado, menor memória/timeout que atenda, retenção de log curta, sem recursos redundantes "por segurança". Nunca crie recurso ocioso só para teste sem avisar.

## Contrato de dados (igual nos 4 repositórios)
Tabela `Evaluations`, chave `evaluationId` (string, UUID). Atributos: `userId` (sub do Cognito), `description`, `score` (número), `urgency` (`high`, `medium` ou `low`), `submittedAt` (ISO 8601 em UTC) e `day` (AAAA-MM-DD no horário de Brasília, UTC-3 fixo).
Índice `by-day`: chave `day`, ordenação `submittedAt`. Urgência (sugestão, editável): score 0 a 3 high, 4 a 6 medium, 7 a 10 low.
Nomes em inglês porque são campos literais no JSON da API e no código Java dos 3 repositórios de função.

## Regras de trabalho
- Uma tarefa por vez do PLANO.md, só deste repositório. Confira "Depende de" antes de começar.
- Ao terminar e validar, marque `[x]` no PLANO.md e resuma em 1 ou 2 frases.
- Nunca commitar segredos, `.env`, `*.tfstate` nem `*.tfvars`. Sem chaves fixas da AWS: a esteira usa OIDC.
- Mudanças por branch e Pull Request (a main é protegida). Commits pequenos, mensagens curtas em português.
- Respostas curtas. Não cole saídas longas (resuma plan, logs e testes).
- Em dúvida entre opções, pergunte antes de decidir.
- LGPD: não registrar e-mails nem o texto das avaliações nos logs.

## Estrutura
`bootstrap/` (bucket do state e acesso do GitHub à AWS; roda 1 vez, localmente), `modules/lambda-function/`, `dynamodb.tf`, `cognito.tf`, `api.tf`, `lambdas.tf`, `ses.tf`, `scheduler.tf`, `monitoring.tf`, `iam.tf`, `providers.tf`, `variables.tf`, `outputs.tf`, `.github/workflows/` (ci.yml e deploy.yml), `docs/` (diagramas) e `README.md`.
Commitar o `.terraform.lock.hcl`.

## Regras de infra
- Antes de propor apply: `terraform fmt -check`, `terraform validate` e `terraform plan`. Nunca `apply` nem `destroy` sem a minha aprovação.
- Sem free tier: ao resumir o `plan`, liste também o custo estimado de cada recurso novo (ou "sem custo fixo"). Se algo tiver custo por hora (ex.: NAT Gateway, instância, ElastiCache), avise antes mesmo de escrever o `.tf` e confirme se é realmente necessário.
- State remoto no bucket S3 criado em `bootstrap/` (versionamento e criptografia ligados).
- As 3 Lambdas são criadas aqui com código de exemplo e `lifecycle { ignore_changes }` no código. O código real vem dos repositórios das funções (update-function-code).
- Cada Lambda tem role própria e mínima, sem `*`. Log group com retenção de 14 dias (curta, por custo). Tags padrão em tudo.
- OIDC: uma role para a esteira desta infra e uma role por repositório de função. A confiança fica restrita a `repo:ORG/REPO:ref:refs/heads/main` e a permissão é só `lambda:UpdateFunctionCode` na função daquele repositório.
- API: HTTP API com JWT authorizer do Cognito (rota `POST /evaluations`) e throttling ligado.
- DynamoDB: on-demand (sem custo fixo ocioso), KMS, PITR e Streams NEW_IMAGE. Notificação: filtro do event source mapping (INSERT e urgency high) e fila SQS como destino de falha.
- SES: cada e-mail precisa ser confirmado pelo link recebido (conta em sandbox).
- EventBridge usa UTC: segunda 8h em Brasília é `cron(0 11 ? * MON *)`.
- Ao rodar `plan`, resuma o que será criado, alterado ou destruído e o custo estimado de cada item novo.
- Expor em `outputs.tf`: nomes e ARNs das funções, URL da API e IDs do Cognito.
- Não ler `.terraform/` nem arquivos de state.
