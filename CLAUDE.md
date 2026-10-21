# feedback-infra

## Projeto
Plataforma de feedback de aulas (Tech Challenge, fase 4), serverless na AWS. O aluno envia `POST /avaliacao` com `{"descricao": string, "nota": int 0 a 10}`. Os administradores recebem e-mail de urgência e um relatório semanal.

## Os 4 repositórios
- feedback-infra: Terraform de toda a infraestrutura e a documentação geral
- feedback-lambda-ingestao: recebe a avaliação e grava no DynamoDB
- feedback-lambda-notificacao: avisa os admins por e-mail quando a urgência é alta
- feedback-lambda-relatorio: gera e envia o relatório semanal

## Convenções (definidas na tarefa 0.5; ajuste aqui se o grupo mudar)
- Região AWS: sa-east-1 (sugestão; confirmar). Prefixo de nomes: `feedback-`
- Funções: `feedback-ingestao`, `feedback-notificacao`, `feedback-relatorio`. Python 3.12
- Grupos do Cognito: `alunos` e `admins`

## Contrato de dados (igual nos 4 repositórios)
Tabela `Avaliacoes`, chave `avaliacaoId` (string, UUID). Atributos: `usuarioId` (sub do Cognito), `descricao`, `nota` (número), `urgencia` (`alta`, `media` ou `baixa`), `dataEnvio` (ISO 8601 em UTC) e `dia` (AAAA-MM-DD no horário de Brasília, UTC-3 fixo).
Índice `por-dia`: chave `dia`, ordenação `dataEnvio`. Urgência (sugestão, editável): nota 0 a 3 alta, 4 a 6 media, 7 a 10 baixa.

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
- State remoto no bucket S3 criado em `bootstrap/` (versionamento e criptografia ligados).
- As 3 Lambdas são criadas aqui com código de exemplo e `lifecycle { ignore_changes }` no código. O código real vem dos repositórios das funções (update-function-code).
- Cada Lambda tem role própria e mínima, sem `*`. Log group com retenção de 14 dias. Tags padrão em tudo.
- OIDC: uma role para a esteira desta infra e uma role por repositório de função. A confiança fica restrita a `repo:ORG/REPO:ref:refs/heads/main` e a permissão é só `lambda:UpdateFunctionCode` na função daquele repositório.
- API: HTTP API com JWT authorizer do Cognito (rota `POST /avaliacao`) e throttling ligado.
- DynamoDB: on-demand, KMS, PITR e Streams NEW_IMAGE. Notificação: filtro do event source mapping (INSERT e urgencia alta) e fila SQS como destino de falha.
- SES: cada e-mail precisa ser confirmado pelo link recebido (conta em sandbox).
- EventBridge usa UTC: segunda 8h em Brasília é `cron(0 11 ? * MON *)`.
- Ao rodar `plan`, resuma só o que será criado, alterado ou destruído.
- Expor em `outputs.tf`: nomes e ARNs das funções, URL da API e IDs do Cognito.
- Não ler `.terraform/` nem arquivos de state.
