# feedback-infra

## Projeto
Plataforma de feedback de aulas (Tech Challenge, fase 4), serverless na AWS. O aluno envia `POST /evaluations` com `{"description": string, "score": int 0 a 10}`. Os administradores recebem e-mail de urgência e um relatório semanal.

## Os 4 repositórios
- feedback-infra: Terraform de toda a infraestrutura e a documentação geral
- feedback-lambda-ingestion: recebe a avaliação e grava no DynamoDB
- feedback-lambda-notification: avisa os admins por e-mail quando a urgência é alta
- feedback-lambda-report: gera e envia o relatório semanal

## Convenções (definidas na tarefa 0.5; ajuste aqui se o grupo mudar)
- Região AWS: sa-east-1 (São Paulo) - CONFIRMADA. Prefixo de nomes: `feedback-`
- Funções: `feedback-ingestion`, `feedback-notification`, `feedback-report`. Java 21 (Maven), AWS SDK v2
- Grupos do Cognito: `students` e `admins`
- Idioma: código Java, comentários, nomes de variáveis/recursos de código e README em inglês. CLAUDE.md e PLANO.md continuam em português (são instruções de processo, não código).
- Custos: esta conta AWS **não tem free tier**. Antes de qualquer `apply` ou criação manual de recurso, informe o custo estimado (ou "sem custo fixo, cobrança por uso") e peça confirmação. Prefira sempre a opção mais barata: on-demand em vez de provisionado, menor memória/timeout que atenda, retenção de log curta, sem recursos redundantes "por segurança". Nunca crie recurso ocioso só para teste sem avisar.
- Economia de requisições (orçamento de US$ 4/mês, sem dinheiro para excedente): o projeto é para entregar e rodar poucas vezes. Testes contra a AWS real só com o mínimo de chamadas, uma por vez e de forma manual. Proibido teste de carga, loops, scripts repetitivos ou agendamentos extras de teste. Testes automatizados (`mvn test`) usam mocks e nunca chamam a AWS. Antes de qualquer chamada real à API ou à AWS, diga quantas chamadas serão feitas.

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
`modules/lambda-function/`, `dynamodb.tf`, `cognito.tf`, `api.tf`, `lambdas.tf`, `ses.tf`, `scheduler.tf`, `monitoring.tf`, `iam.tf`, `providers.tf`, `variables.tf`, `outputs.tf`, `.github/workflows/` (ci.yml e deploy.yml), `docs/` (diagramas) e `README.md`.
Commitar o `.terraform.lock.hcl`.

## Regras de infra
- Antes de propor apply: `terraform fmt -check`, `terraform validate` e `terraform plan`. Nunca `apply` nem `destroy` sem a minha aprovação.
- Sem free tier: ao resumir o `plan`, liste também o custo estimado de cada recurso novo (ou "sem custo fixo"). Se algo tiver custo por hora (ex.: NAT Gateway, instância, ElastiCache), avise antes mesmo de escrever o `.tf` e confirme se é realmente necessário.
- State remoto no HCP Terraform (plano gratuito, sem custo na AWS): bloco `cloud { organization = ...; workspaces { name = "feedback-infra" } }` no `providers.tf`. Workspace com Execution Mode **Local** (o HCP só guarda o state; o Terraform roda localmente e no GitHub Actions). Na esteira, o token do HCP fica no secret `TF_API_TOKEN` do repositório (é o único secret; a AWS continua via OIDC). Não existe pasta `bootstrap/` nem bucket S3 de state.
- As 3 Lambdas são criadas aqui com código de exemplo e `lifecycle { ignore_changes }` no código. O código real vem dos repositórios das funções (update-function-code).
- Cada Lambda tem role própria e mínima, sem `*`. Log group com retenção de 14 dias (curta, por custo). Tags padrão em tudo.
- OIDC: duas roles para a esteira desta infra (`feedback-github-infra-plan`, só leitura, para Pull Request; `feedback-github-infra-apply`, para a main, limitada aos serviços do projeto e ao IAM `feedback-*`) e uma role por repositório de função. A confiança fica restrita ao `sub` no formato imutável do GitHub, `repo:DONO@ID_DONO/REPO@ID_REPO:ref:refs/heads/main` (IDs nas variáveis `github_owner_id` e `github_repo_ids`; pegar o ID com `gh api repos/DONO/REPO --jq .id`) e a permissão é só `lambda:UpdateFunctionCode` na função daquele repositório.
- API: HTTP API com JWT authorizer do Cognito (rota `POST /evaluations`).
- Limite de tráfego (proteção de custo, orçamento de US$ 4/mês): throttling no stage `$default` da HTTP API com `throttling_rate_limit = 1` e `throttling_burst_limit = 1` (`default_route_settings`), valendo para todas as rotas. Não subir sem aprovação. A infra só existe durante testes e apresentação: após a entrega, `terraform destroy` (tarefa 7.9).
- Cognito sem auto cadastro (`allow_admin_create_user_only = true`): só quem o admin cria recebe token, então ninguém de fora consegue chamar a API autenticado.
- Concorrência das Lambdas: a conta tem limite de 10 execuções simultâneas, então não usar `reserved_concurrent_executions` (a AWS exige 10 livres). O teto de tráfego fica no throttling da API.
- DynamoDB: on-demand (sem custo fixo ocioso), KMS com a chave gerenciada pela AWS `aws/dynamodb` (`server_side_encryption { enabled = true }` sem `kms_key_arn`; sem mensalidade, ao contrário de uma chave própria de ~US$ 1/mês), PITR e Streams NEW_IMAGE. Notificação: filtro do event source mapping (INSERT e urgency high) e fila SQS como destino de falha.
- SES: cada e-mail precisa ser confirmado pelo link recebido (conta em sandbox).
- EventBridge usa UTC: segunda 8h em Brasília é `cron(0 11 ? * MON *)`.
- Ao rodar `plan`, resuma o que será criado, alterado ou destruído e o custo estimado de cada item novo.
- Expor em `outputs.tf`: nomes e ARNs das funções, URL da API e IDs do Cognito.
- Não ler `.terraform/` nem arquivos de state.
