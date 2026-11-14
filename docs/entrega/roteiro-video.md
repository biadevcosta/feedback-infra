# Roteiro do vídeo — Plataforma de Feedback de Aulas

Duração alvo: **12 a 15 minutos**. O enunciado pede que o vídeo mostre a aplicação funcionando, as funções serverless ativas e as configurações do projeto. Cada cena traz o que aparece na **tela**, o que **fazer** e uma sugestão de **fala**.

---

## Antes de gravar (checklist)

- [ ] Console da AWS aberto na região **São Paulo (sa-east-1)**.
- [ ] Pelo menos **1 aluno** (grupo `students`) e **1 admin** (grupo `admins`) criados no Cognito, com senha definitiva.
- [ ] O e-mail do admin **verificado no SES** (conta em sandbox) e a caixa de entrada aberta numa aba.
- [ ] A última execução de cada pipeline está **verde** no GitHub.
- [ ] A fila `feedback-notification-dlq` está vazia (para não confundir no vídeo).
- [ ] Abas abertas, na ordem das cenas:
  1. PDF da entrega (página da arquitetura)
  2. GitHub (os 4 repositórios)
  3. Lambda → Functions
  4. API Gateway → `feedback-api`
  5. Cognito → `feedback-users`
  6. DynamoDB → `Evaluations`
  7. EventBridge → Rules → `feedback-weekly-report`
  8. SES → Identities
  9. CloudShell
  10. CloudWatch → Log groups
  11. Caixa de e-mail do admin
- [ ] Teste o CloudShell antes (cena 4): rode os comandos uma vez para conferir que funcionam.
- [ ] Aumente o zoom do navegador (125%) e a fonte do CloudShell para ficar legível no vídeo.

> **Dados pessoais:** os e-mails do aluno e do admin aparecem na tela. Use endereços de teste ou desfoque depois.

---

## Cena 1 — Apresentação e arquitetura (1 min 30)

**Tela:** PDF, página da arquitetura (Figura 1).

**Fazer:** passe o mouse pelos fluxos F1, F2 e F3 enquanto fala.

**Fala:**
> "Esta é a Plataforma de Feedback de Aulas. O aluno avalia uma aula, os administradores recebem um aviso na hora quando a avaliação é crítica e, toda segunda, recebem um relatório semanal.
> A solução é 100% serverless na AWS, na região de São Paulo. São três funções Lambda, cada uma com uma responsabilidade:
> a **ingestão** recebe a avaliação pela API; a **notificação** manda o e-mail de urgência; e o **relatório** manda o resumo da semana.
> Em volta delas: Cognito para login, API Gateway como entrada, DynamoDB como banco, SES para e-mail, EventBridge para o agendamento e CloudWatch para monitoramento. Tudo foi criado com Terraform e o deploy é automático pelo GitHub Actions."

---

## Cena 2 — Repositórios e deploy automatizado (2 min)

**Tela:** GitHub.

**Fazer:**
1. Mostre os **4 repositórios públicos**: `feedback-infra` e os 3 `feedback-lambda-*`.
2. Entre em `feedback-lambda-ingestion` → aba **Actions** → abra a última execução verde. Mostre os jobs **build** e **deploy**, e o passo `aws lambda update-function-code`.
3. Entre em `feedback-infra` → **Actions** → mostre um `plan` (de um pull request) e um `apply` (na main).
4. Abra **Settings → Secrets and variables → Actions** do `feedback-infra`. Mostre só os **nomes**: não existe nenhuma chave da AWS ali.

**Fala:**
> "Cada função tem o seu próprio repositório e a sua própria pipeline. No pull request rodam os testes, com cobertura mínima de 80%. No merge para a main, a pipeline publica o código direto na Lambda.
> A infraestrutura fica no `feedback-infra`: no pull request roda o `terraform plan`, e no merge roda o `apply`.
> Não existe chave de acesso da AWS guardada no GitHub. As pipelines entram na AWS por OIDC, e cada uma só pode fazer o que precisa: a pipeline da ingestão, por exemplo, só consegue atualizar o código da ingestão."

---

## Cena 3 — Configuração na AWS (3 min)

Passe rápido por cada serviço e mostre **só o essencial**.

| Tela | O que mostrar | Fala curta |
|---|---|---|
| **Lambda → Functions** | As 3 funções `feedback-ingestion`, `feedback-notification`, `feedback-report` (Java 21) | "As três funções serverless, ativas." |
| `feedback-notification` → **Configuration → Triggers** | O gatilho do DynamoDB com o **filtro** (`INSERT` + `urgency = high`) e o destino de falha na **SQS** | "A notificação só roda para avaliação crítica; se falhar, o evento vai para uma fila e não se perde." |
| `feedback-ingestion` → **Configuration → Permissions** → clique na role | A política com **só `dynamodb:PutItem`** | "Cada função tem permissão mínima: a ingestão só consegue gravar." |
| **API Gateway → feedback-api** | Rota `POST /evaluations`, **Authorization** com o autorizador JWT do Cognito, **Throttling** de 1 req/s | "A API só aceita quem tem token do Cognito, e tem um limite de requisições para proteger os créditos." |
| **Cognito → feedback-users** | Aba **Users** e aba **Groups** (`students`, `admins`) | "Login por e-mail, sem cadastro aberto. Os grupos separam alunos e administradores." |
| **DynamoDB → Evaluations** | Aba **Indexes** (`by-day`), **Exports and streams** (Streams ligado), **Backups** (PITR) e criptografia em **Additional settings** | "A tabela guarda as avaliações. O índice by-day serve ao relatório, o Streams dispara a notificação, e tem backup contínuo e criptografia." |
| **EventBridge → Rules → feedback-weekly-report** | `cron(0 11 ? * MON *)` e o alvo `feedback-report` | "Toda segunda às 8h de Brasília, que são 11h em UTC." |
| **SES → Identities** | Remetente e admin **Verified** | "O SES envia os e-mails; na conta de teste, os endereços precisam ser verificados." |

---

## Cena 4 — Demonstração: aluno envia avaliação pela API (F1) (3 min 30)

O teste é feito no **CloudShell**, o terminal que abre **dentro do console da AWS** (ícone `>_` no topo da tela). Ele já entra com as suas credenciais, então não precisa instalar nada.

São três passos, nesta ordem:
1. **Cognito:** o aluno faz login e recebe o token.
2. **API Gateway:** o POST `/evaluations` leva o token e a avaliação.
3. **DynamoDB:** a avaliação aparece gravada na tabela.

**Preparar antes de gravar:**
- Abra o CloudShell, confira que a região no topo é **São Paulo** e aumente a fonte (engrenagem → *Font size: Large*).
- Rode os comandos uma vez para testar. Antes de gravar, limpe a tela com `clear`.
- Deixe os blocos abaixo num bloco de notas, prontos para colar um por vez.

**4.0 Mostrar a rota no console (antes do terminal).** Abra **API Gateway → feedback-api → Routes → POST /evaluations** e mostre o autorizador **JWT** ligado ao Cognito.

> **Fala:** "Esta é a rota que o aluno chama. Ela tem um autorizador: só passa quem mandar um token válido do Cognito. Vou fazer a chamada de verdade, pelo terminal do próprio console da AWS."

**4.1 Descobrir os endereços** (pool do Cognito, app client e URL da API):

```bash
export AWS_REGION=sa-east-1
POOL=$(aws cognito-idp list-user-pools --max-results 20 --query "UserPools[?Name=='feedback-users'].Id" --output text)
CLIENT=$(aws cognito-idp list-user-pool-clients --user-pool-id "$POOL" --query "UserPoolClients[?ClientName=='feedback-app'].ClientId" --output text)
API=$(aws apigatewayv2 get-apis --query "Items[?Name=='feedback-api'].ApiEndpoint" --output text)
echo "User pool: $POOL" ; echo "App client: $CLIENT" ; echo "API: $API"
```

> **Fala:** "Primeiro pego os identificadores do Cognito e o endereço da API."

**4.2 Pegar o token no Cognito.** Troque o e-mail e a senha pelos do aluno de teste:

```bash
TOKEN=$(aws cognito-idp admin-initiate-auth --user-pool-id "$POOL" --client-id "$CLIENT" \
  --auth-flow ADMIN_USER_PASSWORD_AUTH \
  --auth-parameters USERNAME=aluno@exemplo.com,PASSWORD='SuaSenha123' \
  --query AuthenticationResult.IdToken --output text)

echo "Token: ${TOKEN:0:60}..."
echo "$TOKEN" | cut -d. -f2 | python3 -c "import sys,base64,json; p=sys.stdin.read().strip(); p+='='*(-len(p)%4); d=json.loads(base64.urlsafe_b64decode(p)); print(json.dumps({k:d.get(k) for k in ['sub','email','cognito:groups','exp']}, indent=2))"
```

> Na tela aparece o começo do token e, logo abaixo, o que tem dentro dele: o `sub` (id do aluno), o e-mail, o grupo `students` e a validade.
> **Fala:** "O aluno fez login no Cognito e recebeu este token. Dentro dele está a identidade do aluno e o grupo dele. O token vale uma hora."

**4.3 POST sem token → 401** (o API Gateway barra):

```bash
curl -s -X POST "$API/evaluations" -H "Content-Type: application/json" -d '{"description": "Tentando sem login", "score": 8}' -w '\nHTTP %{http_code}\n'
```

> **Fala:** "Sem token, o API Gateway recusa com 401. A função nem chega a ser executada."

**4.4 POST com token, mas nota inválida → 400** (a função valida):

```bash
curl -s -X POST "$API/evaluations" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"description": "Nota fora da escala", "score": 11}' -w '\nHTTP %{http_code}\n'
```

> **Fala:** "Com token passa pelo API Gateway, mas a nota tem que ser de 0 a 10. A função de ingestão devolve 400."

**4.5 POST com token e avaliação válida → 201:**

```bash
curl -s -X POST "$API/evaluations" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"description": "Aula muito clara, exemplos ótimos", "score": 9}' -w '\nHTTP %{http_code}\n'
```

> A resposta mostra `{"evaluationId": "..."}` e `HTTP 201`. Deixe o id visível.
> **Fala:** "Agora sim: token válido e avaliação válida. A API devolve 201 e o id da avaliação."

**4.6 Mostrar no DynamoDB.** Vá em **DynamoDB → Tables → Evaluations → Explore table items**. Mostre o item com o **mesmo `evaluationId`** da resposta, e os campos:
- `score = 9` e `urgency = low`: a urgência foi calculada pela função;
- `userId`: é o `sub` que apareceu no token (o id do aluno vem do token, não do corpo);
- `submittedAt` e `day`: data e hora de envio.

> **Fala:** "E aqui está a avaliação gravada no DynamoDB, com o mesmo id. A função calculou a urgência como baixa, e o userId é o mesmo id que estava no token do aluno."

---

## Cena 5 — Demonstração: feedback crítico gera e-mail (F2) (2 min)

**Tela:** CloudShell → caixa de e-mail → CloudWatch.

**5.1 POST com nota 2** (urgência alta):

```bash
curl -s -X POST "$API/evaluations" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"description": "O áudio cortou a aula inteira, não deu para acompanhar", "score": 2}' -w '\nHTTP %{http_code}\n'
```

**Fazer:**
1. Mostre a resposta **201**.
2. Abra a **caixa de e-mail do admin**. O e-mail "**[Critical feedback] New evaluation with high urgency**" chega em segundos. Mostre a **descrição, a urgência e a data de envio**.
3. Vá em **Lambda → feedback-notification → aba Monitor → View CloudWatch logs**. Abra o último log stream e mostre a linha `Evaluation <id>: notified 1 admins`.
4. (Opcional) No **DynamoDB → Explore table items**, mostre o novo item com `urgency = high`.

**Fala:**
> "Nota 2 é urgência alta. Eu só mandei a avaliação para a API, ninguém chamou a notificação. A gravação no DynamoDB gerou um evento no Streams, o filtro deixou passar porque é crítica, e a função de notificação disparou sozinha, buscou os admins no Cognito e mandou o e-mail pelo SES. O e-mail tem o que o enunciado pede: descrição, urgência e data de envio.
> No log aparecem só ids e quantidades, nenhum dado pessoal, por causa da LGPD."

---

## Cena 6 — Relatório semanal (F3) (1 min 30)

O relatório roda sozinho toda segunda. Para não esperar, rode na hora pelo console (fica bem visual):

**Fazer:**
1. **Lambda → feedback-report → aba Test**. Crie o evento `semanal` com o corpo `{}` e clique em **Test**. Mostre o resultado verde.
2. Abra a **caixa de e-mail**. O e-mail "**[Weekly report] Evaluations from … to …**" mostra a **média**, a **quantidade por dia**, a **quantidade por urgência** e a lista com **descrição, urgência e data**.

> **Atenção:** o relatório cobre os **7 dias anteriores a hoje** (até ontem). As avaliações enviadas hoje na gravação **não aparecem**. Se quiser ver dados no relatório, envie algumas avaliações **no dia anterior à gravação**. Se não, o e-mail diz "No evaluations were submitted in this period", e isso também mostra que ele rodou.

**Fala:**
> "No dia a dia, quem dispara essa função é o EventBridge, toda segunda às 8h. Aqui eu disparei na mão para mostrar. Ela lê os sete dias anteriores pelo índice by-day, sem varrer a tabela inteira, calcula a média e as contagens e manda para os administradores."

---

## Cena 7 — Monitoramento (1 min 30)

**Tela:** CloudWatch e Lambda.

**Fazer:**
1. **Lambda → feedback-ingestion → aba Monitor**: gráficos de **Invocations**, **Duration** e **Error count**, com os testes que você acabou de fazer.
2. **CloudWatch → Log groups**: os 3 grupos `/aws/lambda/feedback-*` com **retenção de 14 dias**. Abra o da ingestão e mostre `Saved evaluation <id>`.
3. **CloudWatch → Metrics → ApiGateway**: `Count` e `4xx` (os testes de 401 e 400 aparecem aqui).
4. **SQS → feedback-notification-dlq**: **0 mensagens** quer dizer que nenhum aviso se perdeu.

**Fala:**
> "A aplicação é monitorada pelo CloudWatch: logs de cada função e métricas de execução, erro e duração. Na API dá para ver as requisições e os erros 4xx que eu provoquei. E a fila de falhas vazia mostra que nenhum aviso crítico deixou de ser enviado."

---

## Cena 8 — Fechamento (30 s)

**Tela:** PDF, página "Atendimento aos requisitos".

**Fala:**
> "Recapitulando: a solução é serverless na AWS, com três funções de responsabilidade única. Tem segurança com Cognito, permissões mínimas e deploy sem chaves fixas. A infraestrutura é toda em Terraform, com deploy automático pelo GitHub Actions. O aluno avalia pela API, os admins são avisados na hora quando a avaliação é crítica e recebem o relatório semanal com a média. Tudo monitorado pelo CloudWatch. O código está nos quatro repositórios públicos e a documentação completa está no PDF. Obrigado!"

---
