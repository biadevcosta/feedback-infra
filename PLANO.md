# Plano - feedback-infra

Tarefas extraídas da planilha de planejamento. Siga a ordem e respeite "Depende de".
Ao validar uma tarefa, troque `[ ]` por `[x]`.

Como pedir ao Claude: `Execute a tarefa X.Y do PLANO.md` (uma por sessão; use /clear entre tarefas).

## Tarefas deste repositório

### Fase 0 - Preparação

- [x] **0.2** Ativar MFA no usuário raiz da AWS e criar um usuário administrador (ou IAM Identity Center) para o dia a dia
  - Validar: Login com o administrador funciona e o usuário raiz fica sem uso
  - Obs: Nunca usar o usuário raiz no dia a dia

- [ ] **0.3** Criar alerta de orçamento (AWS Budgets) com aviso por e-mail
  - Validar: Alerta aparece em Budgets e o e-mail de teste chega
  - Depende de: 0.2
  - Obs: Importante: os créditos são limitados

### Fase 1 - Base Terraform

- [x] **1.1** HCP Terraform (plano gratuito) para guardar o state: criar conta e organização em app.terraform.io, workspace `feedback-infra` do tipo CLI-driven com Execution Mode **Local**, e rodar `terraform login`
  - Validar: Workspace aparece no HCP Terraform e `terraform login` conclui
  - Depende de: 0.4, 0.5
  - Obs: Feito manualmente por você (conta pessoal). Execution Mode Local = o HCP só guarda o state; plan/apply rodam na sua máquina e no GitHub Actions, que acessa a AWS via OIDC

- [x] **1.2** Criar providers.tf (com bloco `cloud` apontando para a organização e o workspace `feedback-infra`) e variables.tf
  - Validar: terraform init conclui sem erro
  - Depende de: 1.1

- [x] **1.3** Rodar terraform plan e apply com o ambiente vazio
  - Validar: State aparece na aba States do workspace no HCP Terraform
  - Depende de: 1.2
  - Obs: Validado pelo init e plan ("No changes"); o primeiro state é gravado no apply da 1.4

- [x] **1.4** Criar o provedor OIDC do GitHub na AWS (aws_iam_openid_connect_provider)
  - Validar: Provedor aparece em IAM > Identity providers
  - Depende de: 1.3
  - Obs: Permite o GitHub Actions acessar a AWS sem chave fixa

- [x] **1.5** Criar a role OIDC da esteira da infra, restrita ao repositório feedback-infra
  - Validar: Política de confiança cita só este repositório
  - Depende de: 1.4

- [x] **1.6** Workflow ci.yml (Pull Request): terraform fmt, validate e plan
  - Validar: Pull Request de teste mostra o plan
  - Depende de: 1.5

- [x] **1.7** Workflow deploy.yml (merge na main): terraform apply
  - Validar: Merge de teste roda o apply e fica verde
  - Depende de: 1.6
  - Obs: Marco: esteira da infra funcionando

### Fase 2 - Dados e identidade

- [x] **2.1** dynamodb.tf: tabela Evaluations (on-demand, KMS com a chave aws/dynamodb, recuperação PITR), índice by-day e Streams ligado
  - Validar: Tabela visível no console com Streams e índice
  - Depende de: 1.7

- [ ] **2.2** cognito.tf: User Pool (login por e-mail), app client sem secret (SRP), sem auto cadastro (só admin cria usuário) e grupos students e admins
  - Validar: User Pool criado com os 2 grupos
  - Depende de: 1.7

- [ ] **2.3** Criar usuários de teste (1 aluno e 1 admin) e colocá-los nos grupos
  - Validar: Usuários aparecem nos grupos certos
  - Depende de: 2.2

- [x] **2.4** Validar o login pela CLI (aws cognito-idp initiate-auth)
  - Validar: Comando devolve o ID token
  - Depende de: 2.3

### Fase 3 - Ingestão

- [x] **3.1** Criar o módulo lambda-function (role, log group com retenção de 14 dias, código de exemplo e lifecycle ignore_changes no código)
  - Validar: Módulo passa no terraform validate
  - Depende de: 1.7
  - Obs: O código real vem do repositório de cada função; o Terraform só cria a função

- [ ] **3.2** lambdas.tf: função de ingestão com permissão só de PutItem na tabela
  - Validar: Função aparece no console
  - Depende de: 2.1, 3.1

- [ ] **3.3** api.tf: HTTP API, JWT authorizer (Cognito), rota POST /evaluations e throttling (1 req/s, rajada de 1, no stage $default)
  - Validar: Chamada sem token retorna 401; várias chamadas seguidas retornam 429
  - Depende de: 2.2, 3.2

- [ ] **3.4** Role OIDC do repositório feedback-lambda-ingestion, só com lambda:UpdateFunctionCode nesta função
  - Validar: Política limitada ao ARN da função
  - Depende de: 1.4, 3.2

### Fase 4 - Notificação

- [ ] **4.1** ses.tf: identidade do remetente e dos e-mails dos admins
  - Validar: Todos os e-mails aparecem como Verified no SES
  - Depende de: 1.7
  - Obs: Cada pessoa precisa clicar no link de confirmação (conta em sandbox)

- [ ] **4.2** Fila SQS (DLQ) para falhas da notificação
  - Validar: Fila criada
  - Depende de: 1.7

- [ ] **4.3** Função de notificação com gatilho do Streams (só INSERT com urgência alta), DLQ e permissões ListUsersInGroup e ses:SendEmail
  - Validar: Gatilho ativo no console
  - Depende de: 2.1, 3.1, 4.1, 4.2

- [ ] **4.4** Role OIDC do repositório feedback-lambda-notification, só com lambda:UpdateFunctionCode nesta função
  - Validar: Política limitada ao ARN da função
  - Depende de: 1.4, 4.3

### Fase 5 - Relatório

- [ ] **5.1** scheduler.tf: regra do EventBridge para segunda 8h de Brasília (cron(0 11 ? * MON *), em UTC) e permissão de invocação
  - Validar: Regra ativa no console
  - Depende de: 1.7
  - Obs: O cron do EventBridge é sempre em UTC

- [ ] **5.2** Função de relatório com permissões Query no índice by-day e ses:SendEmail
  - Validar: Função criada só com as permissões necessárias
  - Depende de: 2.1, 3.1, 4.1, 5.1

- [ ] **5.3** Role OIDC do repositório feedback-lambda-report, só com lambda:UpdateFunctionCode nesta função
  - Validar: Política limitada ao ARN da função
  - Depende de: 1.4, 5.2

### Fase 6 - Monitoramento e segurança

- [ ] **6.1** monitoring.tf: tópico SNS de alertas e inscrição dos e-mails dos admins
  - Validar: Inscrição confirmada
  - Depende de: 1.7

- [ ] **6.2** Alarmes do CloudWatch: erros e throttles das 3 Lambdas, 5xx da API e mensagens na DLQ
  - Validar: Alarmes criados e ligados ao SNS
  - Depende de: 6.1, 5.2, 4.3, 3.3

- [ ] **6.3** Dashboard simples do CloudWatch (invocações e erros)
  - Validar: Dashboard mostra os dados das funções
  - Depende de: 6.2

- [ ] **6.4** Revisar o IAM (sem permissões com curinga além do necessário) e conferir a criptografia com KMS (chave aws/dynamodb)
  - Validar: Checklist de segurança sem pendências
  - Depende de: 5.8

- [ ] **6.5** Teste: forçar um erro numa Lambda e receber o alerta por e-mail
  - Validar: E-mail de alarme chega
  - Depende de: 6.2

### Fase 7 - Documentação e entrega

- [ ] **7.1** Atualizar o diagrama (Terraform no lugar de CloudFormation) e exportar em PNG
  - Validar: PNG aparece no README
  - Depende de: 6.5

- [ ] **7.2** README: arquitetura, modelo de cloud, instruções de deploy, monitoramento e segurança, com índice dos 4 repositórios
  - Validar: Alguém de fora consegue seguir e reproduzir o deploy
  - Depende de: 7.1

- [ ] **7.9** Depois da gravação e da entrega: rodar terraform destroy para parar de gastar crédito
  - Validar: Recursos removidos
  - Depende de: 7.8
  - Obs: Só depois de gravar o vídeo e de a entrega ser aceita

## Tarefas do grupo (não são de código)

Concluir junto com o time; marque aqui quando feitas.

- [ ] **0.1** Criar a organização/conta no GitHub e os 4 repositórios públicos, cada um com README inicial e .gitignore
  - Validar: Os 4 repositórios aparecem abertos no GitHub

- [ ] **0.4** Instalar Git, AWS CLI, Terraform, Java 21 (JDK) e Maven e configurar as credenciais
  - Validar: aws sts get-caller-identity retorna a conta; terraform -version responde
  - Depende de: 0.2

- [x] **0.5** Definir convenções: região, prefixo de nomes (feedback-), tags e nomes das 3 funções
  - Validar: Convenções registradas no README do feedback-infra
  - Obs: Os repositórios das funções dependem destes nomes

- [ ] **0.6** Proteger a branch main dos 4 repositórios (Pull Request obrigatório)
  - Validar: Push direto na main é bloqueado
  - Depende de: 0.1

- [ ] **3.8** Teste ponta a ponta: sem token (401), com token (grava) e score fora do intervalo (400)
  - Validar: Item aparece no DynamoDB
  - Depende de: 3.3, 3.7

- [ ] **4.8** Teste ponta a ponta: enviar um score baixo e receber o e-mail de urgência
  - Validar: E-mail chega aos admins
  - Depende de: 3.8, 4.7

- [ ] **5.8** Disparar o relatório manualmente e conferir o e-mail
  - Validar: Relatório chega com média e contagens corretas
  - Depende de: 5.7

- [ ] **7.6** Escrever o roteiro do vídeo seguindo os fluxos F1 a F4 do diagrama
  - Validar: Roteiro aprovado pelo grupo
  - Depende de: 6.5

- [ ] **7.7** Gravar o vídeo: arquitetura, repositórios, esteiras, funções ativas, configurações e os fluxos funcionando
  - Validar: Vídeo cobre todos os itens da aba Entrega
  - Depende de: 7.2, 7.6

- [ ] **7.8** Revisão final com o checklist da aba Entrega
  - Validar: Todos os itens em Concluído
  - Depende de: 7.7

