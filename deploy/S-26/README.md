# S-26 — Runbook de implantação e desmontagem

Execução `3bdd7f92-dda2-492e-a399-2e209a1e6238`, projeto `solar-ai-cloud`, região **southamerica-east1 (São Paulo)**. O líder é `Codex S-26`; o Maestro é `Claude Code`. Somente o líder executa nuvem, publica branches e abre PRs. O usuário digita os segredos no terminal do líder.

Este documento completa a preparação local do critério 8 e documenta as quatro configurações do critério 9. **Não comprova uma implantação.** Scripts aprovados localmente: `493daf3` e `a28ec647`; aceite registrado pelo líder em `14ea1f9`. Critério 10, bootstrap, permissões efetivas, URLs e custos correntes dependem de verificação na nuvem. O [briefing](../../execucoes/briefing-S-26-3bdd7f92-dda2-492e-a399-2e209a1e6238.md) e o [registro da execução](../../execucoes/S-26-3bdd7f92-dda2-492e-a399-2e209a1e6238.md) definem as responsabilidades.

## 1. Preparação e planos offline

Use PowerShell 7 ou Windows PowerShell 5.1. A raiz é a pasta que contém os quatro repositórios lado a lado. Os scripts a calculam a partir da própria localização (três níveis acima de `deploy/S-26`), então valem tanto no checkout principal quanto num worktree de card. As imagens são construídas a partir dos repositórios dessa raiz, que precisam estar limpos e no SHA que o plano pede.

```powershell
$raiz = 'C:/Users/felip/Documents/FIAP/Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS/solar'
$docs = Join-Path $raiz 'solar-ai-docs'
$scripts = Join-Path $docs 'deploy/S-26'
$execucao = '3bdd7f92-dda2-492e-a399-2e209a1e6238'
$gcloud = 'C:/Users/felip/AppData/Local/Google/Cloud SDK/google-cloud-sdk/bin/gcloud.cmd'
$projeto = 'solar-ai-cloud'
$regiao = 'southamerica-east1'

$planoApis = & (Join-Path $scripts 'Provisionar.ps1') -Etapa Apis
$planoRecursos = & (Join-Path $scripts 'Provisionar.ps1') -Etapa Recursos
$planoSegredos = & (Join-Path $scripts 'Segredos.ps1')
$planoApis | ConvertTo-Json -Depth 30
$planoRecursos | ConvertTo-Json -Depth 30
$planoSegredos | ConvertTo-Json -Depth 30
```

Sem `-Executar`, os scripts retornam planos sem chamar nuvem, pedir credenciais ou executar Docker. Os planos mostram comandos e corpos **não secretos**. Criar um plano não realiza as verificações remotas de conta, inventário ou IAM. `Deploy.ps1` também exige entradas válidas e declaração dos peers para gerar seu plano: não marque essa declaração antes das provas da seção 7.

## 2. Autorização e preflight do líder

Ao concluir os critérios locais 1 a 9, antes de tocar na nuvem, o líder envia ao Maestro o primeiro relatório: planos completos, SHAs, testes antes/depois, estimativa regional de custos, procedimento de bootstrap e limites. Aguarda autorização explícita para as operações propostas. `-Executar -PeloLider -AprovacaoMaestro $execucao` é uma trava operacional: **o UUID e os switches não são prova de autorização**, identidade ou observação dos peers.

Os comandos remotos das seções seguintes são para execução futura pelo líder, dentro da autorização recebida. Nenhum deve ser executado como parte da revisão local deste runbook. Login do SDK é interativo, do usuário. Reconferir a conta ativa em memória, sem imprimir seu identificador:

```powershell
$config = (& $gcloud config list --format=json) | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $config.core.project -cne $projeto -or
    [string]::IsNullOrWhiteSpace($config.core.account)) { throw 'Conta/projeto incorretos.' }
$config = $null
```

Não depender de `run.region`: passar região em todos os comandos regionais. Primeiro autorizar e executar a etapa de APIs, depois consultar inventários; APIs ausentes podem impedir as consultas.

```powershell
& (Join-Path $scripts 'Provisionar.ps1') -Etapa Apis -Executar -PeloLider -AprovacaoMaestro $execucao
& $gcloud services list --enabled --project=$projeto --format=json
& $gcloud artifacts repositories list --location=$regiao --project=$projeto --format=json
& $gcloud sql instances list --project=$projeto --format=json
& $gcloud iam service-accounts list --project=$projeto --format=json
& $gcloud secrets list --project=$projeto --format=json
& $gcloud run services list --region=$regiao --project=$projeto --format=json
```

Cada falha ou inventário indeterminado bloqueia o próximo passo. Conferir códigos de saída; não interpretar saída vazia de erro como ausência de recursos. Os scripts repetem seus próprios inventários e validações antes de mutar.

## 3. Recursos e operações que exigem autorização

Nomes reservados: Artifact Registry e instância SQL `solar-s26-3bdd7f92`, banco `solar`, usuário SQL `solar_app`; serviços `solar-front`, `solar-api`, `solar-agente`. Contas de runtime `s26-front-3bdd7f92`, `s26-api-3bdd7f92`, `s26-agente-3bdd7f92`, todas com sufixo `@solar-ai-cloud.iam.gserviceaccount.com`.

Ownership é a marca `s26-execucao=3bdd7f92-dda2-492e-a399-2e209a1e6238`: labels nos recursos compatíveis e descrição exata nas contas de serviço. Provisionamento exige nomes ausentes, inclusive os três serviços Cloud Run. Colisão, marca diferente ou inventário ambíguo bloqueiam; não adotar recursos. A marca ajuda a conferir a execução, mas não substitui autorização nem constitui controle de acesso.

Lista para revisão do Maestro; os arrays `Acoes` dos planos são a fonte dos argumentos completos. Comandos gcloud dos scripts incluem `--project=solar-ai-cloud --quiet --format=json`.

| Etapa | Comando/operação a autorizar |
|---|---|
| APIs | `gcloud services enable run.googleapis.com artifactregistry.googleapis.com sqladmin.googleapis.com secretmanager.googleapis.com iam.googleapis.com` |
| Registro | `gcloud artifacts repositories create solar-s26-3bdd7f92 --location=southamerica-east1 --repository-format=docker --immutable-tags --labels=s26-execucao=3bdd7f92-dda2-492e-a399-2e209a1e6238` |
| SQL | REST `POST https://sqladmin.googleapis.com/v1/projects/solar-ai-cloud/instances`, corpo abaixo; depois `gcloud sql operations wait <nome-retornado> --timeout=1800` |
| Banco | `gcloud sql databases create solar --instance=solar-s26-3bdd7f92` |
| Contas | `gcloud iam service-accounts create <cada-uma-das-tres-contas> --description=s26-execucao=3bdd7f92-dda2-492e-a399-2e209a1e6238` |
| Segredos vazios | Para cada nome da seção 4: `gcloud secrets create <nome> --replication-policy=user-managed --locations=southamerica-east1 --labels=s26-execucao=3bdd7f92-dda2-492e-a399-2e209a1e6238` |
| Acesso SQL | `gcloud projects add-iam-policy-binding solar-ai-cloud --member=serviceAccount:s26-api-3bdd7f92@solar-ai-cloud.iam.gserviceaccount.com --role=roles/cloudsql.client --condition=None` |
| Acesso segredos | `gcloud secrets add-iam-policy-binding <nome> --member=serviceAccount:<conta-destinataria> --role=roles/secretmanager.secretAccessor --condition=None`; seis segredos para API, apenas Gemini para agente, nenhum para front |
| Entrada protegida | REST de usuário SQL e sete versões, descritos na seção 4; corpos sensíveis nunca são anexados ao pedido de aprovação |
| Imagens | `gcloud auth configure-docker southamerica-east1-docker.pkg.dev`, `docker build --platform=linux/amd64 -t <imagem:SHA> <worktree-absoluto>` e `docker push <imagem:SHA>` para os três serviços |
| Deploy | Três `gcloud run deploy` com argumentos da seção 8, mais dois bindings de invoker entre serviços |
| Publicação | Binding `allUsers` exclusivamente no `solar-front`, depois das provas e autorização específicas |

Corpo REST **não secreto** da criação SQL, igual ao plano aprovado:

```json
{
  "name": "solar-s26-3bdd7f92",
  "region": "southamerica-east1",
  "databaseVersion": "POSTGRES_16",
  "settings": {
    "tier": "db-f1-micro",
    "edition": "ENTERPRISE",
    "availabilityType": "ZONAL",
    "dataDiskType": "PD_SSD",
    "dataDiskSizeGb": "10",
    "storageAutoResize": false,
    "userLabels": {"s26-execucao": "3bdd7f92-dda2-492e-a399-2e209a1e6238"},
    "ipConfiguration": {"ipv4Enabled": true, "authorizedNetworks": []},
    "connectorEnforcement": "REQUIRED",
    "backupConfiguration": {"enabled": true, "startTime": "03:00", "location": "southamerica-east1"},
    "deletionProtectionEnabled": true
  }
}
```

Sem rede autorizada ampla ou VPC adicional. O conector Cloud SQL é obrigatório; a API usa socket Unix via integração Cloud Run/SQL. Após aprovar o plano e confirmar ausência de conflitos:

```powershell
& (Join-Path $scripts 'Provisionar.ps1') -Etapa Recursos -Executar -PeloLider -AprovacaoMaestro $execucao
```

## 4. Segredos: operação do usuário

O usuário prepara a conta Gmail dedicada e senha de app. Ele próprio executa o comando abaixo no terminal do líder, com presença e aprovação reais. **`-AsSecureString` pertence aos sete `Read-Host` internos; não é parâmetro de `Segredos.ps1`.** Não colocar valores em argv, arquivo temporário, `.env`, log, transcript, chat ou captura de tela. O implementador não recebe nem observa esses valores.

```powershell
$versoes = & (Join-Path $scripts 'Segredos.ps1') -Executar -PeloLider -UsuarioPresente -AprovacaoMaestro $execucao
```

O script verifica ownership, projeto/APIs e inexistência de `solar_app`; recebe todos os valores antes da primeira escrita. Senha SQL gera a connection string com escaping, host `/cloudsql/solar-ai-cloud:southamerica-east1:solar-s26-3bdd7f92`, banco `solar`, usuário `solar_app`.

| Nome no Secret Manager | Destino |
|---|---|
| `solar-postgres-connection-string` | API: `ConnectionStrings__Postgres` |
| `solar-smtp-usuario` | API: `Email__Smtp__Usuario` |
| `solar-smtp-senha-app` | API: `Email__Smtp__SenhaApp` |
| `solar-smtp-remetente` | API: `Email__Smtp__Remetente` |
| `solar-semente-senha-supervisor` | API: `Semente__SenhaSupervisor` |
| `solar-chave-privacidade` | API: `Seguranca__ChavePrivacidade` |
| `solar-gemini-api-key` | Agente: `GEMINI_API_KEY` |

Operações sensíveis autorizadas, mas sem exemplos de valores: `POST https://sqladmin.googleapis.com/v1/projects/solar-ai-cloud/instances/solar-s26-3bdd7f92/users` com `name`, `type=BUILT_IN` e `password`; depois `POST https://secretmanager.googleapis.com/v1/projects/solar-ai-cloud/secrets/<nome>:addVersion` com `payload.data` em base64. Base64 não é criptografia. Tokens OAuth obtidos pelo transporte, senha, JSON e payload ficam somente em memória; não executar `gcloud sql users ... --password` ou `secrets versions access` manualmente.

A saída `$versoes` contém apenas os sete nomes e números explícitos; preservar essas referências não secretas para o deploy. Não usar `latest`. O script descarta SecureStrings e limpa referências/bytes controlados, mas não garante zeragem de todas as cópias de strings gerenciadas. Uma interrupção pode deixar usuário/versões criados; seguir seção 11.

## 5. SHAs reais, imagens e push

Obter os SHAs dos três repositórios **limpos** em `feature/S-26`, depois dos commits aceitos. Este bloco é local:

```powershell
$repos = @{Api='solar-ai-api'; Agente='solar-ai'; Front='solar-ai-front'}
$shas = @{}
foreach ($servico in @('Api','Agente','Front')) {
    $repo = Join-Path $raiz $repos[$servico]
    $branch = & git -C $repo branch --show-current
    if ($LASTEXITCODE -ne 0 -or $branch -cne 'feature/S-26') { throw 'Branch incorreta.' }
    $estado = & git -C $repo status --porcelain --untracked-files=all
    if ($LASTEXITCODE -ne 0 -or $estado) { throw 'Worktree indisponivel ou sujo.' }
    $sha = & git -C $repo rev-parse HEAD
    if ($LASTEXITCODE -ne 0 -or $sha -cnotmatch '\A[0-9a-f]{40}\z') { throw 'SHA invalido.' }
    $shas[$servico] = $sha
}
$planoImagens = & (Join-Path $scripts 'Imagens.ps1') -Shas $shas
$planoImagens | ConvertTo-Json -Depth 30
```

Após autorização, executar `Imagens.ps1` com os mesmos SHAs:

```powershell
& (Join-Path $scripts 'Imagens.ps1') -Shas $shas -Executar -PeloLider -AprovacaoMaestro $execucao
```

O script repete as verificações Git e ownership. Tags imutáveis: `southamerica-east1-docker.pkg.dev/solar-ai-cloud/solar-s26-3bdd7f92/solar-api:<SHA-api>`, `solar-agente:<SHA-agente>` e `solar-front:<SHA-front>` sob o mesmo prefixo. Build local, sem Cloud Build; push é escrita remota autorizada. Registrar também os digests resultantes. Segredos não entram em imagem ou argumentos de build.

## 6. Número do projeto e URLs

Leitura futura pelo líder, antes do deploy:

```powershell
$numeroProjeto = & $gcloud projects describe $projeto --project=$projeto --format='value(projectNumber)'
if ($LASTEXITCODE -ne 0 -or $numeroProjeto -cnotmatch '\A[1-9][0-9]{5,19}\z') { throw 'Numero de projeto invalido.' }
$urlFront = 'https://solar-front-' + $numeroProjeto + '.' + $regiao + '.run.app'
$urlApi = 'https://solar-api-' + $numeroProjeto + '.' + $regiao + '.run.app'
$urlAgente = 'https://solar-agente-' + $numeroProjeto + '.' + $regiao + '.run.app'
```

São URLs determinísticas derivadas do número **lido**, não URLs observadas nem confirmação de serviço existente. O segmento `<servico>-<numero>` deve ter até 63 caracteres. Ver [URLs determinísticas oficiais](https://docs.cloud.google.com/run/docs/triggering/https-request#deterministic_url). Depois do deploy, o guard UrlPublicada exige nome/marca exatos e a presenca exata da URL deterministica esperada e de status.url na lista canonica run.googleapis.com/urls anunciada pelo servico. status.url pode conter hash, como observado no passo C. Lista ausente/invalida ou origem faltante bloqueia publicacao; nao normalizar diferencas arbitrarias. Guard5017d9b aprovado pelo Maestro em PS7/5.1.

## 7. Bootstrap privado e confianca no IP — resolvida pelo desenho aprovado

O Maestro aceitou o [passo C](../../execucoes/S-26-diagnostico-passo-C-3bdd7f92-dda2-492e-a399-2e209a1e6238.md) e o usuario aprovou S-26-decisao-desenho-ip.md em 01/10. O diagnostico terminou e seus cinco recursos foram removidos; nao repetir nuvem diagnostica.

Nas nove amostras de tres revisoes gen2, o peer TCP do front e da API foi 169.254.169.126. O Cloud Run acrescentou uma entrada direita ao XFF do front, preservando prefixos enviados pelo cliente. O helper normaliza esse IP com FRONT_TRUSTED_PROXY_CIDRS=169.254.169.126/32 e FRONT_TRUSTED_HOPS=1. Sao constantes do plano apoiadas na evidencia aprovada, nao entradas livres.

A API usa ProxyTrust__ForwardedForHeaderName=X-Solar-Client-IP, ProxyTrust__KnownProxies__0=169.254.169.126 e ProxyTrust__ForwardLimit=1. O nginx sobrescreve X-Solar-Client-IP com $client_ip normalizado e conserva X-Forwarded-For normalizado para compatibilidade. Nesse modo, a API ignora XFF e remove header proprio invalido, com virgula ou repetido antes do middleware; conserva o IP do peer sem400 e sem logar o valor. O modo padrao X-Forwarded-For continua disponivel com comportamento anterior.

O peer link-local da API nao identifica o front, e o egress compartilhado nao vira allow-list. A confianca em X-Solar-Client-IP depende de IAM: somente a SA dedicada do front recebe run.invoker direto da API; somente a SA da API recebe run.invoker direto do agente. Nginx sobrescreve X-Serverless-Authorization com token da SA front e audiencia da API, sem devolver token ao navegador.

**Limite dos owners:** owners e outras identidades com permissao efetiva herdada podem invocar a API diretamente e forjar o header proprio; pertencem a fronteira administrativa confiavel. O HTTP200 do operador no diagnostico nao comprovou exclusividade de identidade. Verificar IAM direto e herdado, nao conceder run.invoker de projeto nem allUsers na API/agente, e registrar o limite sem remover permissoes alheias.

BootstrapPeersComprovado agora referencia o passo C e este desenho aceito; o switch e registro de autorizacao, nao prova automatica. As secoes9/10 precisam confirmar a cadeia real da aplicacao: peer da API169.254.169.126, header proprio chegando intacto pelo Cloud Run, headers XFF/X-Solar-Client-IP forjados sem efeito no IP efetivo e no rate limit. **Peer diferente no deploy real: parar e devolver ao Maestro; nunca ampliar lista ou usar /0.**

## 8. Configuração final e deploy privado

Depois da decisao da secao7, preparar apenas URLs e SHAs reais nas entradas nao secretas. O plano fixa peers, saltos e nome do header; nao fornecer cidrs/saltos livres:

```powershell
$entradas = @{
    UrlFront=$urlFront; UrlApi=$urlApi; UrlAgente=$urlAgente
    ShaFront=$shas.Front; ShaApi=$shas.Api; ShaAgente=$shas.Agente
    PeersObservadosConfirmados=$true
}
$planoDeploy = & (Join-Path $scripts 'Deploy.ps1') -Entradas $entradas -VersoesSegredos $versoes -NumeroProjeto $numeroProjeto -BootstrapPeersComprovado
$planoDeploy | ConvertTo-Json -Depth 30
```

Revisar `Acoes`, mapas de ambiente e referências de segredos antes de autorizar a execução:

```powershell
& (Join-Path $scripts 'Deploy.ps1') -Entradas $entradas -VersoesSegredos $versoes -NumeroProjeto $numeroProjeto -BootstrapPeersComprovado -Executar -PeloLider -AprovacaoMaestro $execucao
```

Ordem interna: agente → API → front; aplicar invoker no agente para a SA API ANTES do invoker da API para a SA front; espera IAM limitada; verificacao de URLs. Nenhuma sonda nova/health encadeado ou impersonacao. Todos usam `--region=southamerica-east1 --execution-environment=gen2 --cpu=1 --memory=512Mi --max-instances=1 --no-allow-unauthenticated --invoker-iam-check`, imagem SHA e SA dedicada. Portas: agente 8000, API/front 8080. API: `--no-cpu-throttling --min-instances=1 --set-cloudsql-instances=solar-ai-cloud:southamerica-east1:solar-s26-3bdd7f92`; front/agente: `--cpu-throttling --min-instances=0`. A API fica com CPU contínua para os workers S-24/S-39 executarem entre requisições; este card não altera esses workers.

O script aplica `--set-secrets=<variavel>=<nome>:<versao-numerica>` na API/agente e `--clear-secrets` no front. Os mapas não secretos são passados por arquivo JSON temporário de ambiente, removido em `finally`; isso preserva os mapas sem delimitadores no argv. Nenhum segredo vai para esse arquivo. API em `ASPNETCORE_ENVIRONMENT=Production`, agente em `SOLAR_ENV=production`; SMTP Gmail porta 587 com STARTTLS. Front usa `FRONT_AUTH_MODE=iam`; API ativa autenticação do agente. Audiences são as URLs HTTPS canônicas dos respectivos destinatários.

Bindings: `gcloud run services add-iam-policy-binding solar-api --region=southamerica-east1 --member=serviceAccount:s26-front-3bdd7f92@solar-ai-cloud.iam.gserviceaccount.com --role=roles/run.invoker --condition=None`; equivalente para `solar-agente`, membro SA API. Ambos com projeto explícito. Verificar políticas efetivas, inclusive permissões herdadas: o preflight cobre bindings de projeto/serviço, mas não constitui auditoria completa de herança da organização/pasta.

| Configuração obrigatória (critério 9) | Motivo e comprovação exigida |
|---|---|
| API `--max-instances=1` | `TravaDeConversas` usa `SemaphoreSlim` em memória, válido em um processo. Conferir configuração publicada; um máximo por serviço não transforma a trava em distribuída nem elimina possível sobreposição de revisões durante rollout. Não dividir tráfego entre revisões; planejar janela controlada quando necessário. |
| `Cors__Origens__0` = origem pública do front | Restringe origens autorizadas. Confirmar valor publicado e fluxo real. Front e API vistos pelo navegador no mesmo endereço via nginx preservam cookie `SameSite=Strict`. |
| `SOLAR_VERSION` = SHA completo de cada imagem | Identifica a combinação implantada; API, agente e front recebem seus próprios SHAs, correspondentes às tags construídas dos worktrees limpos. Conferir versões nos healths da API/agente e configuração/imagem do front. |
| Painel protegido | Sem cookie, a rota do painel de dados via front deve responder 401 sem dados; API privada por IAM recebe somente SA front, agente privado somente SA API. Cookies/sessão continuam exigidos na aplicação. OpenAPI/Swagger devem responder 404 em Production. IAM não substitui autenticação de usuário. |

### Espera IAM antes das verificacoes

O executor conserva o token do operador somente em memoria e sonda o front privado em GET /api/sessao, sem cookie. Sucesso e401 **da aplicacao**, com codigo sessao_invalida;403/502 ainda nao comprovam front→API. Fazer uma sonda cada60s, primeira depois da espera inicial, por no maximo10min/dez sondas. Nao aceitar apenas200 da SPA ou401 HTML do proxy. Redirecionamentos, erro de transporte ou resposta inesperada interrompem; sem registrar corpo/token.

Cada sonda tem no maximo20s para obter o token e completar HTTP, dentro do prazo total600s. A leitura do token usa helper exclusivo Windows: processo criado suspenso e associado a Job Object antes de executar, somente handles stdout/NUL herdados, stdout limitado32KiB somente em memoria e stderr descartado. Se o prazo esgotar, encerra e confere apenas a arvore criada, com reserva para limpeza, e bloqueia URL/publicacao com erro sanitizado. O transporte nativo geral nao muda; testes Python/.cmd locais provaram timeout e ausencia de filhos em PS7/5.1. Isso nao substitui a futura prova com Google Cloud SDK/IAM reais.

Depois do sucesso, esperar somente o tempo restante ate completar cinco minutos desde a conclusao do binding do agente. Nao sondar API→agente com owner/impersonacao nem adicionar endpoint. Esta espera nao prova propagacao: a prova e o primeiro turno real da secao10, sob aprovacao de cota. Se front→API nao passar no prazo, interromper antes das verificacoes/publicacao e devolver o bloqueio ao Maestro.

## 9. Provas antes de publicar e liberação do front

Com serviços privados, o líder verifica imagens/SHAs, regiões, CPU/instâncias, variáveis, versões de segredos, URLs, IAM, peers/XFF e endpoints por acesso autenticado controlado. Em especial, a API direta sem identidade será barrada pelo IAM; o **401 da aplicação** deve ser observado via front autenticado na camada Cloud Run, sem cookie de sessão da aplicação. Confirmar ausência de permissões diagnósticas excedentes.

Não passar `-LiberarFrontPublico` enquanto essas provas e a aprovação de publicação estiverem pendentes. Esse switch acrescenta ao plano `gcloud run services add-iam-policy-binding solar-front --region=southamerica-east1 --member=allUsers --role=roles/run.invoker --condition=None`, depois de verificar URLs.

**Limite do script:** executar novamente `Deploy.ps1 -LiberarFrontPublico` refaz os três deploys antes do binding. Para publicar exatamente as revisões já verificadas, o líder deve submeter e executar apenas o binding público acima, com `--project=solar-ai-cloud --quiet --format=json`, após reconferir os serviços. Se optar por refazer o deploy, precisa de nova verificação das revisões; o script não pausa para smoke antes de publicar. Nunca liberar `allUsers` na API/agente.

Prova do criterio2 nas revisoes reais: API ve o peer169.254.169.126; X-Solar-Client-IP do nginx chega intacto; XFF e header proprio forjados pelo cliente sao sobrescritos no front e nao alteram o IP efetivo/rate limit. Na API, header proprio invalido/multiplo cai para o peer; XFF nao e fonte nesse modo. Provar buckets separados por IP normalizado e ausencia de vazamento de valor em logs. Owners continuam a excecao administrativa registrada na secao7. Peer diferente interrompe, sem ampliar trust.

## 10. Aceite real (critério 10) e registro (critério 11)

O líder estima o consumo de Gemini e solicita aprovação ao Maestro **antes da primeira chamada**. Teto de **20 chamadas** em toda a execução; acompanhar gasto real, inclusive múltiplas chamadas por conversa. Não rodar suíte `-m llm`. Esta preparação local consumiu zero chamadas e não enviou SMTP real.

| Verificação na nuvem | Evidência esperada |
|---|---|
| Health API e agente | `GET /health` de ambos retorna up e `version` igual ao SHA correspondente; agente acessado autenticado pelo líder ou pela API. Não registrar o token. |
| Painel anônimo | Pela URL pública do front, `GET /api/painel/leads` sem cookie retorna 401 e nenhum dado. |
| Swagger/OpenAPI | Na API autenticada na camada IAM, `/openapi/v1.json`, `/swagger` e `/swagger/index.html` retornam 404. Um 404 do nginx isoladamente não prova que a API desativou Swagger. |
| Agente privado | Chamada direta anônima ao agente retorna 403; token de SA não autorizada também não deve permitir invocação. |
| SPA e sessão | Recarregar `/painel` entrega `index.html`; sessão/cookie continuam válidos pelo mesmo endereço do front. |
| Conversa | Conversa completa com a Lia no navegador pela URL pública; registrar resultado e consumo, sem PII ou conteúdo sensível em evidências. |
| Supervisor e e-mail | Supervisor semeado vinculado `3f6b9c21-4d0a-4c7e-9a11-000000000101` entra com senha digitada pelo usuário; troca e-mail `@solar.local` por real; redefinição chega por SMTP Gmail real. Não registrar senha, token/link ou destinatário. Semente é idempotente, não redefine senha já existente. |
| Peers e falsificação | Repetir observação e ataques XFF sintéticos na cadeia final/publicada; IP efetivo e rate limit não podem ser escolhidos pelo cliente. Confirmar TLS e helper interno inacessível. |

Falha em qualquer prova impede declarar o critério 10 concluído. O líder registra comandos sanitizados, data, revisões, URLs verificadas, SHAs, resultados, custos, consumo Gemini, aprovações e limitações no registro da execução (critério 11). Publicação de branches e um PR por repositório alterado contra `develop` cabem exclusivamente ao líder, no momento autorizado pelo briefing; nunca há merge implícito. O título previsto é `S-26 · Deploy dos três serviços e Postgres gerenciado`, com UUID no corpo. No relatório final ao Maestro, incluir critérios 1 a 11 com evidências, URLs, consumo Gemini, tarefas/devoluções, branches, SHAs e PRs reais; comunicar bloqueios quando ocorrerem. O implementador não altera esse registro nem o Notion.

### Primeira prova real API→agente e falha IAM

Na primeira conversa real autorizada da secao10, confirmar que o agente executou. Se IAM recusar antes do agente, nao ha execucao Gemini nem estado no agente; logs da plataforma podem existir. Para um502, fazer **uma unica nova tentativa apos dois minutos**; se falhar novamente, parar e devolver ao Maestro, sem repetir bateria ou alterar IAM/allow-list. A recusa IAM deve ser distinguida de outros502: um502 isolado nao prova custo zero nem ausencia de estado na API; conferir a evidencia sem PII e o estado de negocio.

Contabilizar chamadas efetivas no teto20 aprovado e preservar as provas de falha/rollback na cadeia real. Este procedimento e futuro: nenhuma conversa, Gemini ou SMTP real esta autorizada nesta implementacao local.

## 11. Falhas parciais e recuperação

Os scripts não são transações, não oferecem rollback automático nem retomada por etapa. Uma falha pode ocorrer depois de recursos, usuário SQL, versões, imagens ou revisões terem sido criados. Mensagens externas são sanitizadas; não tentar recuperar detalhes imprimindo corpo/token/segredo.

- Parar e inventariar somente metadados com autorização do líder. Comparar nomes, marca, região, operações SQL, versões numéricas, tags/digests e revisões com o registro da execução.
- Não repetir `Provisionar.ps1 -Etapa Recursos`: recursos já criados conflitam com o requisito de ausência. Não alterar a marca para adotá-los. O líder apresenta um plano de recuperação específico ao Maestro.
- Não repetir `Segredos.ps1`: se o usuário SQL foi criado, o script recusa sobrescrever sua senha. Se faltam versões, a recuperação/rotação precisa de procedimento separado aprovado e entrada protegida pelo usuário; não ler valores existentes para o chat.
- Push com tag imutável já existente exige verificar digest/estado, sem sobrescrever tag. Deploy parcial exige revisar URLs, IAM e revisões antes de novo plano; não publicar o front para contornar falha.
- Nada de apagar recurso alheio, forçar Git, editar checkouts principais ou mudar S-39. Recuperação que exceder os scripts aprovados volta ao Maestro.

## 12. Custos e desmontagem

**Referência regional de 30/09/2026, fornecida pelo líder; não é cotação atual nem orçamento fechado.** Hipótese: API 1 vCPU/512 MiB continuamente alocada, 730 h/mês; SQL Postgres 16 `db-f1-micro`, ZONAL, SSD 10 GiB.

| Item | USD/mês de referência |
|---|---:|
| API CPU + memória | 59,9184 |
| SQL micro | 11,534 |
| SQL SSD 10 GiB | 2,55 |
| SQL subtotal | 14,084 |
| API + SQL | **74,0024** |

Dez dias (240/730 do subtotal): aproximadamente **USD 24,3296**. Exclui backups (habilitados no plano), Artifact Registry, versões/acessos de segredos, tráfego, front, agente e outros recursos. Franquias e créditos trial dependem da conta e não tornam o preço zero. Conferir São Paulo, modalidade por instância da API e tarifas vigentes **antes da aprovação**: [Cloud Run](https://cloud.google.com/run/pricing), [Cloud SQL](https://cloud.google.com/sql/pricing), [Secret Manager](https://cloud.google.com/secret-manager/pricing), [Artifact Registry](https://cloud.google.com/artifact-registry/pricing).

Encerrar navegador ou parar tráfego não para o custo da API mínima/SQL. Ao terminar a demo, submeter teardown; confirmar antes a perda dos dados e a necessidade de retenção/backup. Revisar primeiro o plano, que exige a confirmação mesmo offline:

```powershell
$confirmacao = 'EXCLUIR-' + $execucao
$planoDesmontar = & (Join-Path $scripts 'Desmontar.ps1') -Confirmacao $confirmacao
$planoDesmontar | ConvertTo-Json -Depth 30
# Somente depois de autorizacao explicita da exclusao:
& (Join-Path $scripts 'Desmontar.ps1') -Confirmacao $confirmacao -Executar -PeloLider -AprovacaoMaestro $execucao
```

O plano confere ownership/região e aceita ausência dos nomes previstos. Ordem: `run services delete` de front/API/agente; `sql instances patch solar-s26-3bdd7f92 --no-deletion-protection`; `sql instances delete`; `secrets delete` dos sete nomes; `artifacts repositories delete solar-s26-3bdd7f92 --location=southamerica-east1`; remover binding `roles/cloudsql.client` da SA API; `iam service-accounts delete` das três contas. Run inclui região, todos incluem projeto explícito. Somente recursos encontrados e pertencentes à execução são alvo; qualquer conflito interrompe antes das ações. Banco/usuário estão contidos na instância SQL excluída.

Não desabilita APIs, não exclui projeto, não limpa permissões externas nem recursos com outros nomes. Não cobre automaticamente recursos diagnósticos adicionais ou backups retidos após exclusão: inventariar e tratar separadamente com aprovação, sem presumir custo encerrado. Após teardown, conferir ausência dos recursos, operações concluídas e cobranças residuais. Em falha parcial, novo inventário e revisão precedem qualquer repetição.

## Evidências locais e limites

O líder aprovou 17/17 testes de planos e 33/33 de segredos em **PowerShell 7 e 5.1**, com executores fictícios e nenhuma nuvem. A configuração de produção teve 133/133 em ambos. Essas evidências validam geração, gates, escaping e tratamento de falhas locais; não comprovam IAM, disponibilidade de flags/APIs na conta, peers Cloud Run, SMTP real ou conversa pública. Scripts e este runbook permanecem sujeitos aos gates anteriores antes de qualquer execução remota.
