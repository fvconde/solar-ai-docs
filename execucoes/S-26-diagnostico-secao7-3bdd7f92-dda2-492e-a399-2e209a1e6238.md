# S-26 — diagnóstico da seção 7: entrega local e comandos para revisão

Execução `3bdd7f92-dda2-492e-a399-2e209a1e6238`. Ordem do Maestro aprovada pelo usuário em 01/10/2026, arquivo de origem `S-26-gate-secao7-ordem.md` no scratchpad do Maestro. **Primeiro passo local concluído; nenhum comando de nuvem deste relatório foi executado.**

Revisão do Maestro em 01/10: eco `ae8342d` e comandos P1–P5 aprovados. O transporte nativo foi bloqueado por misturar stderr com stdout. Correção local `d1ac704f17d3a8427aa076f8eabf6b5635f5c307`, avaliada pelo líder: stdout exclusivo, stderr descartado, sucesso determinado pelo código nativo e erros sanitizados. **15/15 testes com processos reais locais, 17/17 planos, 33/33 segredos e 133/133 configuração em PowerShell 7.6.6 e Windows PowerShell 5.1.26100.9444**, repetidos independentemente. O preflight e `Invoke-DiagGcloud` abaixo reutilizam esse transporte. Aguarda revisão curta do Maestro antes de qualquer gcloud; nenhuma chamada ao SDK foi usada nesta validação.

## Entrega e avaliação do líder

- Implementação Luna: `ae8342d134b1dbf858c7e45fd3f4fff0ce80cd89`, somente `deploy/S-26/diagnostico/eco.py`, `Dockerfile` e `test_eco.py`; 728 linhas adicionadas. Modelo observado no terminal nesta tarefa: GPT-6.1-Sol high; não alterado pelo líder.
- Líder leu o diff integral dos três arquivos, conferiu o commit e o escopo e repetiu **20/20 testes offline**, **1/1 build Docker** e **4/4 checks de smoke** (usuário/conteúdo da imagem, eco e ocultação de valores, URL do cliente recusada, inicialização inválida silenciosa). Container exclusivo com `--network none`, sem porta publicada, removido ao final; stdout/stderr do serviço vazios. Nenhum token, IP externo, SMTP, Gemini, `.env` ou metadata real usado.
- O Docker Desktop estava parado; o líder iniciou o aplicativo em segundo plano, sem executar Compose. Testes iniciais do implementador passaram com 17 casos; ele acrescentou cobertura de timeout, concorrência e orçamento total de headers e concluiu com 20 casos. Zero devoluções do líder nesta tarefa.
- Serviço stdlib em `PORT` (8080 por padrão), `DIAG_MODE=eco` ou `encadear`; este último exige `DIAG_INTERNAL_URL` como origem HTTPS. GET somente em `/`. Eco retorna `peerTCP`, listas de valores de `X-Forwarded-For`, `Forwarded` e `X-Forwarded-Proto`, e `nomesHeaders`; nunca valores dos demais headers. Encadeamento retorna essas observações em `borda` e `interno`, com token obtido do metadata para a audiência canônica do interno. Somente os três headers diagnósticos são encaminhados; a identidade em `X-Serverless-Authorization` é gerada pela borda, não copiada do cliente.
- Sem logs de aplicação, proxy de ambiente, redirects, persistência ou cache de token. TLS padrão, limites de tempo/tamanho/concorrência e validação do JSON interno. Strings gerenciadas não têm zeragem garantida. **IAM, peers reais e P1–P5 ainda não foram testados.**
- Proposta PowerShell conferida pelo líder em PowerShell 7 e Windows PowerShell 5.1: **7/7 blocos com sintaxe válida, 30/30 arrays de argumentos atômicos** e construtor do cliente HTTP válido, sem executar gcloud/Docker/HTTP nessa conferência. Concatenações em arrays estão parentizadas para preservar cada flag como argumento único.

Para conferir o diff entregue, sem mutação:

```powershell
$repoDocs = 'C:/Users/felip/Documents/FIAP/Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS/solar/worktrees/S-26/solar-ai-docs'
git -C $repoDocs show ae8342d134b1dbf858c7e45fd3f4fff0ce80cd89 -- deploy/S-26/diagnostico
git -C $repoDocs diff ae8342d134b1dbf858c7e45fd3f4fff0ce80cd89^ ae8342d134b1dbf858c7e45fd3f4fff0ce80cd89 --check
python -B -m unittest discover -s (Join-Path $repoDocs 'deploy/S-26/diagnostico') -p test_eco.py
```

## Correção do transporte — revisão antes da nuvem

Commit do implementador `d1ac704f17d3a8427aa076f8eabf6b5635f5c307`, somente `Operacoes.ps1` e `Testar-Transporte-Nativo.ps1` (136 linhas adicionadas, 2 removidas). O líder conferiu o diff inteiro e repetiu as quatro suítes nos dois PowerShells. Os 15 testes nativos usam Python e launcher `.cmd` fictícios, sem executor simulado: JSON e token com aviso em stderr, falha com sentinelas e mensagem sanitizada, argumentos, preferências e código global presente/ausente. A revisão parcial identificou referência mutável no código global anterior; o implementador corrigiu e acrescentou cobertura antes do commit.

O líder também conferiu **8/8 blocos de sintaxe e 4/4 casos reais do preflight/helper atualizado** nos dois PowerShells: JSON do preflight, JSON do helper, token fictício e falha sanitizada. Apenas a definição do helper extraída do relatório foi executada, apontando para Python local; comandos remotos não foram executados. A preparação inicial com Python `-c` e aspas falhou em PS5.1; o fixture final em arquivo temporário passou e foi removido. O transporte não altera o modo de passagem de argumentos do chamador.

Comandos locais reproduzíveis, sem SDK:

```powershell
git -C $repoDocs show d1ac704f17d3a8427aa076f8eabf6b5635f5c307 -- deploy/S-26/Operacoes.ps1 deploy/S-26/Testar-Transporte-Nativo.ps1
$scripts = Join-Path $repoDocs 'deploy/S-26'
foreach ($shell in @('pwsh','powershell.exe')) {
    foreach ($teste in @('Testar-Transporte-Nativo.ps1','Testar-Planos.ps1','Testar-Segredos.ps1','Testar-Configuracao-Producao.ps1')) {
        & $shell -NoProfile -File (Join-Path $scripts $teste)
        if ($LASTEXITCODE -ne 0) { throw 'Validacao local falhou.' }
    }
}
```

## Comandos concretos propostos — não executados nesta etapa

O gate reduzido autoriza APIs e recursos de diagnóstico. Estes blocos são apresentados ao Maestro **antes da nuvem**, para a revisão solicitada. Não executar o provisionamento de recursos da aplicação, segredos, imagens da aplicação ou deploy final. Nenhum binding é aplicado no nível do projeto. Nunca imprimir o token ou as observações brutas.

### 1. Preflight local da conta e habilitação autorizada de APIs

```powershell
$ErrorActionPreference = 'Stop'
$gcloud = 'C:/Users/felip/AppData/Local/Google/Cloud SDK/google-cloud-sdk/bin/gcloud.cmd'
$projeto = 'solar-ai-cloud'
$regiao = 'southamerica-east1'
$execucao = '3bdd7f92-dda2-492e-a399-2e209a1e6238'
$marca = 's26-execucao=' + $execucao
$scripts = Join-Path $repoDocs 'deploy/S-26'
$diag = Join-Path $scripts 'diagnostico'
$shaEco = 'ae8342d134b1dbf858c7e45fd3f4fff0ce80cd89'
$registroDiag = 'solar-s26-diag-3bdd7f92'
$saBorda = 's26-diag-borda-3bdd7f92'
$saInterno = 's26-diag-interno-3bdd7f92'
$emailBorda = $saBorda + '@' + $projeto + '.iam.gserviceaccount.com'
$emailInterno = $saInterno + '@' + $projeto + '.iam.gserviceaccount.com'

. (Join-Path $scripts 'Operacoes.ps1')
$textoConfig = Invoke-S26Transporte (New-S26Comando 'diag-preflight' $gcloud @('config','list','--format=json'))
$config = $textoConfig | ConvertFrom-Json
if ($config.core.project -cne $projeto -or [string]::IsNullOrWhiteSpace($config.core.account)) { throw 'Conta/projeto incorretos.' }
# Este plano requer operador com conta de usuario Google; outra identidade exige revisao.
if ($config.core.account -notmatch '^[^\s@]+@[^\s@]+$' -or $config.core.account.EndsWith('.gserviceaccount.com')) { throw 'Revisar identidade do operador.' }
$membroOperador = 'user:' + $config.core.account
$config = $null; $textoConfig = $null

function Invoke-DiagGcloud {
    param([string[]]$Argumentos)
    $argvDiag = @($Argumentos) + @(('--project=' + $projeto), '--quiet')
    return Invoke-S26Transporte (New-S26Comando 'diag-gcloud' $gcloud $argvDiag)
}
& (Join-Path $scripts 'Provisionar.ps1') -Etapa Apis -Executar -PeloLider -AprovacaoMaestro $execucao
```

O UUID registra a execução; a autorização vem da ordem recebida, não dos switches. O preflight consulta configuração sem sobrescrever artificialmente o projeto selecionado.

### 2. Inventários, conflitos e permissões herdadas

```powershell
$registros = Invoke-DiagGcloud -Argumentos @('artifacts','repositories','list',('--location=' + $regiao),'--format=json') | ConvertFrom-Json
$contas = Invoke-DiagGcloud -Argumentos @('iam','service-accounts','list','--format=json') | ConvertFrom-Json
$servicos = Invoke-DiagGcloud -Argumentos @('run','services','list',('--region=' + $regiao),'--format=json') | ConvertFrom-Json
$iamProjeto = Invoke-DiagGcloud -Argumentos @('projects','get-iam-policy',$projeto,'--format=json') | ConvertFrom-Json
```

Antes de criar qualquer recurso, conferir que as três respostas de inventário são arrays JSON válidos, sem itens indeterminados. Recusar colisão de **qualquer** um dos cinco nomes planejados: registro, duas SAs e dois serviços. Não adotar recursos mesmo que tenham marca parecida. Avaliar permissões herdadas do operador: a ausência de um binding direto não prova que ele não pode invocar o interno. Não alterar IAM de projeto, pasta ou organização para forçar P5. Recursos sem labels, como SAs, recebem a marca exata em `description`.

### 3. Registro exclusivo, duas SAs e imagem exclusiva do eco

```powershell
[void](Invoke-DiagGcloud -Argumentos @('artifacts','repositories','create',$registroDiag,('--location=' + $regiao),'--repository-format=docker','--immutable-tags',('--labels=' + $marca),'--format=json'))
[void](Invoke-DiagGcloud -Argumentos @('iam','service-accounts','create',$saBorda,('--description=' + $marca),'--format=json'))
[void](Invoke-DiagGcloud -Argumentos @('iam','service-accounts','create',$saInterno,('--description=' + $marca),'--format=json'))
$imagemEco = $regiao + '-docker.pkg.dev/' + $projeto + '/' + $registroDiag + '/eco:' + $shaEco
$statusDocs = & git -C $repoDocs status --porcelain --untracked-files=all
if ($LASTEXITCODE -ne 0 -or $statusDocs) { throw 'Worktree docs deve estar limpo.' }
$branchDocs = & git -C $repoDocs branch --show-current
if ($LASTEXITCODE -ne 0 -or $branchDocs -cne 'feature/S-26') { throw 'Branch incorreta.' }
$mudancasEco = & git -C $repoDocs diff $shaEco -- deploy/S-26/diagnostico
if ($LASTEXITCODE -ne 0 -or $mudancasEco) { throw 'Conteudo do eco diverge do commit avaliado.' }
[void](Invoke-DiagGcloud -Argumentos @('auth','configure-docker',($regiao + '-docker.pkg.dev')))
& docker build --platform=linux/amd64 -t $imagemEco $diag
if ($LASTEXITCODE -ne 0) { throw 'Build do eco falhou.' }
& docker push $imagemEco
if ($LASTEXITCODE -ne 0) { throw 'Push do eco falhou.' }
```

Não criar/tocar `solar-s26-3bdd7f92`, nenhuma imagem da aplicação ou chave de conta de serviço. O contexto do build é apenas a pasta diagnóstica, e o Dockerfile copia somente `eco.py`. Registrar o digest da imagem e o SHA do código, sem observações brutas.

### 4. Duas fronteiras privadas, ambiente e CPU explícitos

Proposta: **gen2 e ingress all** para as duas fronteiras; ingress all permite o caminho normal HTTPS sem VPC adicional, enquanto IAM exige identidade. Borda usa CPU por requisição, como o front; interno usa CPU por instância, como a API. Ambos têm mínimo zero **por determinação do gate diagnóstico**; a API final continuará com mínimo 1. Propor o mesmo pin `--execution-environment=gen2` no `Deploy.ps1` antes de usar a topologia como evidência do deploy final. Esse arquivo **não foi alterado** nesta tarefa.

```powershell
$numeroProjeto = Invoke-DiagGcloud -Argumentos @('projects','describe',$projeto,'--format=value(projectNumber)')
if ($numeroProjeto -cnotmatch '\A[1-9][0-9]{5,19}\z') { throw 'Numero do projeto invalido.' }
$urlInterno = 'https://s26-diag-interno-' + $numeroProjeto + '.' + $regiao + '.run.app'
$urlBorda = 'https://s26-diag-borda-' + $numeroProjeto + '.' + $regiao + '.run.app'
$comuns = @(('--region=' + $regiao),('--image=' + $imagemEco),'--execution-environment=gen2','--ingress=all','--port=8080','--cpu=1','--memory=512Mi','--min-instances=0','--max-instances=1','--no-allow-unauthenticated','--invoker-iam-check','--clear-secrets',('--labels=' + $marca),'--format=json')
function Publish-DiagRodada {
    param([ValidateSet('d1','d2','d3')][string]$rodada)
    [void](Invoke-DiagGcloud -Argumentos (@('run','deploy','s26-diag-interno',('--service-account=' + $emailInterno),'--no-cpu-throttling','--set-env-vars=DIAG_MODE=eco',('--revision-suffix=' + $rodada)) + $comuns))
    [void](Invoke-DiagGcloud -Argumentos (@('run','deploy','s26-diag-borda',('--service-account=' + $emailBorda),'--cpu-throttling',('--set-env-vars=DIAG_MODE=encadear,DIAG_INTERNAL_URL=' + $urlInterno),('--revision-suffix=' + $rodada)) + $comuns))
    if ($rodada -eq 'd1') {
        [void](Invoke-DiagGcloud -Argumentos @('run','services','add-iam-policy-binding','s26-diag-borda',('--region=' + $regiao),('--member=' + $membroOperador),'--role=roles/run.invoker','--condition=None','--format=json'))
        [void](Invoke-DiagGcloud -Argumentos @('run','services','add-iam-policy-binding','s26-diag-interno',('--region=' + $regiao),('--member=serviceAccount:' + $emailBorda),'--role=roles/run.invoker','--condition=None','--format=json'))
    }
    $borda = Invoke-DiagGcloud -Argumentos @('run','services','describe','s26-diag-borda',('--region=' + $regiao),'--format=json') | ConvertFrom-Json
    $interno = Invoke-DiagGcloud -Argumentos @('run','services','describe','s26-diag-interno',('--region=' + $regiao),'--format=json') | ConvertFrom-Json
    if ($borda.status.url -cne $urlBorda -or $interno.status.url -cne $urlInterno) { throw 'URL/audiencia diverge; parar.' }
}
Publish-DiagRodada -rodada d1
# Depois de conferir d1 e executar as sondagens, somente se nao houver condicao de parada:
# Publish-DiagRodada -rodada d2
# Repetir as sondagens/avaliacao em d2 antes de:
# Publish-DiagRodada -rodada d3
```

A função executa **uma rodada**; d2/d3 ficam comentadas para exigir avaliação entre os deploys. Cada nova revisão instancia containers novos. Conferir `status.latestReadyRevisionName`, `status.traffic` e prontidão antes de aceitar as amostras. Garantir invoker exclusivamente operador→borda e SA borda→interno, consultando políticas de ambos os serviços; não adicionar operador ao interno nem `allUsers` a qualquer um deles. Se uma rodada já existir, parar/revisar a recuperação, sem sobrescrever/adotar nomes ou revisões alheias.

### 5. Sondagens P1–P5: somente em memória

Helper proposto para a sessão do líder. Retorna objetos **somente para atribuição a variáveis**, nunca para o terminal. Não retorna corpo de erro IAM, headers de autenticação ou token. Não segue redirects.

```powershell
Add-Type -AssemblyName System.Net.Http
function Invoke-DiagSondagem {
    param([string]$Url,[hashtable]$Headers)
    $handlerDiag = New-Object Net.Http.HttpClientHandler
    $handlerDiag.AllowAutoRedirect = $false
    $clientDiag = New-Object Net.Http.HttpClient($handlerDiag)
    $clientDiag.Timeout = [TimeSpan]::FromSeconds(15)
    $requestDiag = New-Object Net.Http.HttpRequestMessage([Net.Http.HttpMethod]::Get, ($Url + '/'))
    $responseDiag = $null
    try {
        foreach ($nomeHeader in $Headers.Keys) { [void]$requestDiag.Headers.TryAddWithoutValidation($nomeHeader,[string]$Headers[$nomeHeader]) }
        $responseDiag = $clientDiag.SendAsync($requestDiag).GetAwaiter().GetResult()
        $observacaoDiag = $null
        if ([int]$responseDiag.StatusCode -eq 200) {
            $corpoDiag = $responseDiag.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            if ($corpoDiag.Length -gt 16384) { throw 'Resposta excessiva.' }
            $observacaoDiag = $corpoDiag | ConvertFrom-Json
        }
        return [pscustomobject]@{Status=[int]$responseDiag.StatusCode;Observacao=$observacaoDiag}
    } catch { throw 'Sondagem falhou; detalhes externos suprimidos.' }
    finally {
        $corpoDiag = $null
        if ($responseDiag) { $responseDiag.Dispose() }
        $requestDiag.Dispose(); $clientDiag.Dispose()
    }
}
$tokenOperador = Invoke-DiagGcloud -Argumentos @('auth','print-identity-token')
try {
    $semPrefixo = Invoke-DiagSondagem -Url $urlBorda -Headers @{Authorization=('Bearer ' + $tokenOperador)}
    $prefixoForjado = Invoke-DiagSondagem -Url $urlBorda -Headers @{Authorization=('Bearer ' + $tokenOperador);'X-Forwarded-For'='203.0.113.41, 198.51.100.42'}
    $headerServerless = Invoke-DiagSondagem -Url $urlBorda -Headers @{'X-Serverless-Authorization'=('Bearer ' + $tokenOperador)}
    $internoAnonimo = Invoke-DiagSondagem -Url $urlInterno -Headers @{}
    $internoOperador = Invoke-DiagSondagem -Url $urlInterno -Headers @{Authorization=('Bearer ' + $tokenOperador)}
} finally { $tokenOperador = $null }
```

- Repetir estas cinco sondagens em d1, d2 e d3: três observações por fronteira, com/sem XFF sintético e presença do header serverless nas revisões novas. Os dois IPs escritos acima são valores fictícios de documentação, não peers presumidos.
- P1: peer TCP da borda; P2: comparar XFF sem prefixo e com prefixo, preservando ordem e quantidade de entradas. P3: comparar XFF da borda com XFF do interno e identificar entradas acrescentadas, peer TCP e eventual egress compartilhado. Encadear encaminha o XFF recebido; não simula a normalização final do nginx, cuja prova sobre a cadeia real continua pendente.
- P4: verificar **somente o nome** `x-serverless-authorization` em `nomesHeaders`. Essa observação distingue presença/ausência, sem inspecionar assinatura/valor. P5: exigir/registrar os status do interno anônimo e com token do operador; 403 é pergunta de teste, não premissa. Se permissões herdadas permitirem chamada do operador, registrar a falha de isolamento sem alterar IAM alheio.
- Consultar o catálogo oficial `https://www.gstatic.com/ipranges/cloud.json` e sua data para classificar os IPs acrescentados. Pertencer a esse catálogo não prova exclusividade da borda. A documentação descreve o [pool dinâmico de saída do Cloud Run](https://docs.cloud.google.com/run/docs/configuring/static-outbound-ip) e o [catálogo de IPs utilizáveis por clientes Google Cloud](https://docs.cloud.google.com/vpc/docs/access-apis-external-ip).
- Antes de escrever qualquer evidência, substituir o IP do operador por `<operador>` **em todas as observações**, incluindo XFF/Forwarded herdados no interno; não exportar JSON bruto. Se não for possível identificar com segurança quais entradas pertencem ao operador, ocultar conservadoramente as entradas herdadas da borda e registrar a limitação. Não colocar tokens em argv, chat, log ou evidência.
- Se P3 indicar egress compartilhado ou faltar garantia de exclusividade, **parar as sondagens**, realizar o teardown no mesmo dia e devolver o desenho ao Maestro. Não ampliar allow-list, usar `/0`, inferir CIDRs exclusivos de IPs isolados nem criar SQL para continuar. A condição de parada tem precedência sobre completar as três rodadas.

Referência para token do operador: [autenticação de desenvolvedores](https://docs.cloud.google.com/run/docs/authenticating/developers). Para a borda: [identidade de serviço e metadata](https://docs.cloud.google.com/run/docs/authenticating/service-to-service). Tudo acima é proposta ainda não executada.

### 6. Teardown no mesmo dia, inclusive após falha parcial

Inventariar novamente antes de cada exclusão. Para Run/registro exigir label exata `s26-execucao`; para as SAs exigir `description` exata com a marca; confirmar região dos recursos regionais. Executar os comandos abaixo **somente para nomes encontrados e comprovadamente criados nesta execução**. Ausência é evidência de limpeza; erro de inventário não equivale a ausência. Se houver colisão/marca divergente, parar e avisar o Maestro.

```powershell
$runFinal = Invoke-DiagGcloud -Argumentos @('run','services','list',('--region=' + $regiao),'--format=json') | ConvertFrom-Json
$sasFinais = Invoke-DiagGcloud -Argumentos @('iam','service-accounts','list','--format=json') | ConvertFrom-Json
$regsFinais = Invoke-DiagGcloud -Argumentos @('artifacts','repositories','list',('--location=' + $regiao),'--format=json') | ConvertFrom-Json
# Depois de conferir ownership/presenca dos cinco nomes:
[void](Invoke-DiagGcloud -Argumentos @('run','services','delete','s26-diag-borda',('--region=' + $regiao),'--format=json'))
[void](Invoke-DiagGcloud -Argumentos @('run','services','delete','s26-diag-interno',('--region=' + $regiao),'--format=json'))
[void](Invoke-DiagGcloud -Argumentos @('iam','service-accounts','delete',$emailBorda,'--format=json'))
[void](Invoke-DiagGcloud -Argumentos @('iam','service-accounts','delete',$emailInterno,'--format=json'))
[void](Invoke-DiagGcloud -Argumentos @('artifacts','repositories','delete',$registroDiag,('--location=' + $regiao),'--format=json'))
$runDepois = Invoke-DiagGcloud -Argumentos @('run','services','list',('--region=' + $regiao),'--format=json') | ConvertFrom-Json
$sasDepois = Invoke-DiagGcloud -Argumentos @('iam','service-accounts','list','--format=json') | ConvertFrom-Json
$regsDepois = Invoke-DiagGcloud -Argumentos @('artifacts','repositories','list',('--location=' + $regiao),'--format=json') | ConvertFrom-Json
```

O trecho de exclusão é lista de comandos supervisionada, não script automático de teardown: em falha parcial, pular nomes ausentes e aplicar os guards de ownership antes de cada ação. Não usar `Desmontar.ps1` da aplicação. Confirmar ausência dos cinco nomes, revisões/serviços removidos e permissões de invoker removidas com os serviços; reportar qualquer resíduo. Não remover outros registros, SAs ou serviços.

## Custos, privacidade e próximo relatório

Expectativa da ordem: próximo de zero, mínimo zero, poucas dezenas de requisições e teardown no mesmo dia. Ainda não há custo real medido porque não houve criação/execução remota. CPU por instância no interno pode ser faturada durante a vida da instância mesmo com mínimo zero; registry cobra armazenamento enquanto existir. Reportar duração, requisições, tamanho armazenado e custo efetivo disponível após o diagnóstico, distinguindo estimativa de cobrança ainda não consolidada. Fontes: [Cloud Run](https://cloud.google.com/run/pricing) e [Artifact Registry](https://cloud.google.com/artifact-registry/pricing).

O eco não produz logs. **Os logs de requisição do Cloud Run guardam o IP do operador por 30 dias**, conforme limitação explicitada na ordem; teardown dos serviços não apaga automaticamente esses logs. O repositório é público: IP do operador nunca entra nos registros e tokens nunca entram em evidências/chat/logs.

Após execução, preencher P1–P5 com evidências sanitizadas, revisões e configuração efetiva; apresentar CIDRs/saltos justificados para cada fronteira **ou declarar que a topologia não permite a garantia exigida**; confirmar teardown. Na etapa local atual todos esses resultados permanecem pendentes. O líder envia ao Maestro uma linha com o caminho deste relatório; SQL/segredos/imagens da aplicação/Deploy/Gemini/SMTP permanecem fora deste gate.
