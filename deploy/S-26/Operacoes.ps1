# Infraestrutura de execucao da tarefa 8. Dot-source nao executa comandos.
. (Join-Path $PSScriptRoot 'Configuracao-Producao.ps1')
. (Join-Path $PSScriptRoot 'Espera-Iam.ps1')

function New-S26Contexto {
    $id = '3bdd7f92-dda2-492e-a399-2e209a1e6238'
    return [ordered]@{
        Execucao = $id
        Projeto = 'solar-ai-cloud'
        Regiao = 'southamerica-east1'
        Gcloud = 'C:/Users/felip/AppData/Local/Google/Cloud SDK/google-cloud-sdk/bin/gcloud.cmd'
        Raiz = ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..')).TrimEnd('\', '/') -replace '\\', '/')
        Registro = 'solar-s26-3bdd7f92'
        Instancia = 'solar-s26-3bdd7f92'
        Banco = 'solar'
        UsuarioSql = 'solar_app'
        Marca = ('s26-execucao=' + $id)
        Contas = [ordered]@{
            Front = 's26-front-3bdd7f92'
            Api = 's26-api-3bdd7f92'
            Agente = 's26-agente-3bdd7f92'
        }
        SegredosApi = @('solar-postgres-connection-string', 'solar-smtp-usuario',
            'solar-smtp-senha-app', 'solar-smtp-remetente',
            'solar-semente-senha-supervisor', 'solar-chave-privacidade')
        SegredosAgente = @('solar-gemini-api-key')
    }
}
function Get-S26EmailConta($Contexto, [string]$Servico) {
    return $Contexto.Contas[$Servico] + '@' + $Contexto.Projeto + '.iam.gserviceaccount.com'
}
function New-S26Comando([string]$Id, [string]$Programa, [string[]]$Argumentos) {
    return [ordered]@{ Id=$Id; Tipo='Comando'; Programa=$Programa; Argumentos=$Argumentos }
}
function New-S26Gcloud($Contexto, [string]$Id, [string[]]$Argumentos) {
    return New-S26Comando $Id $Contexto.Gcloud ($Argumentos + @(
        ('--project=' + $Contexto.Projeto), '--quiet', '--format=json'))
}
function New-S26Rest([string]$Id, [string]$Metodo, [string]$Uri, $Corpo) {
    return [ordered]@{ Id=$Id; Tipo='Rest'; Metodo=$Metodo; Uri=$Uri; Corpo=$Corpo }
}
function New-S26Recurso([string]$Tipo, [string]$Nome, [string]$Modo) {
    return [ordered]@{ Tipo=$Tipo; Nome=$Nome; Modo=$Modo }
}
function New-S26Plano([string]$Nome) {
    return [ordered]@{ Nome=$Nome; Contexto=(New-S26Contexto)
        Recursos=@(); Verificacoes=@(); Acoes=@() }
}
function Assert-S26Autorizacao([switch]$Executar, [switch]$PeloLider, [string]$AprovacaoMaestro) {
    if (-not $Executar) { return }
    if (-not $PeloLider -or $AprovacaoMaestro -cne (New-S26Contexto).Execucao) {
        throw 'Execucao exige -PeloLider e -AprovacaoMaestro com UUID, somente apos aprovacao real do Maestro.'
    }
}
function Invoke-S26Transporte($Acao, [scriptblock]$Executor) {
    try {
        if ($Executor) { return & $Executor $Acao }
        return Invoke-S26Nativo $Acao
    } catch {
        # Nao propagar stderr, corpo REST, inner exception ou valores recebidos.
        throw ('Operacao S-26 falhou [' + $Acao.Id + ']; detalhes externos suprimidos.')
    }
}
function Invoke-S26Nativo($Acao) {
    if ($Acao.Tipo -eq 'Comando') {
        $argumentos = @($Acao.Argumentos)
        $preferenciaErro = $ErrorActionPreference
        $variavelCodigoAnterior = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
        $codigoAnterior = if ($null -ne $variavelCodigoAnterior) { $variavelCodigoAnterior.Value } else { $null }
        # Variavel local: PS7 nao transforma exit nao zero em erro PowerShell;
        # PS5.1 ignora esta preferencia. O chamador mantem seu proprio valor.
        $PSNativeCommandUseErrorActionPreference = $false
        try {
            # PS5.1 pode produzir RemoteException ao redirecionar stderr com Stop.
            # Capturar somente stdout e decidir pelo codigo do processo real.
            $ErrorActionPreference = 'Continue'
            # O engine grava LASTEXITCODE global; uma variavel local o ocultaria.
            $global:LASTEXITCODE = $null
            $saida = & $Acao.Programa @argumentos 2>$null | Out-String
            $codigo = $global:LASTEXITCODE
        } finally {
            $ErrorActionPreference = $preferenciaErro
            if ($null -ne $variavelCodigoAnterior) { $global:LASTEXITCODE = $codigoAnterior }
            else { Remove-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue }
        }
        if ($null -eq $codigo -or $codigo -ne 0) { throw 'Falha de processo.' }
        return $saida.Trim()
    }
    if ($Acao.Tipo -eq 'SondaIam') { return Invoke-S26SondaIamNativa $Acao }
    if ($Acao.Tipo -ne 'Rest') { throw 'Tipo de operacao desconhecido.' }
    # Auth e HTTP somente na execucao real. Token jamais e argumento de processo.
    $ctx = New-S26Contexto
    $token = $null
    $cliente = $null
    $requisicao = $null
    $resposta = $null
    try {
        $token = Invoke-S26Nativo (New-S26Comando 'token-em-memoria' $ctx.Gcloud @(
            'auth', 'print-access-token', ('--project=' + $ctx.Projeto), '--quiet'))
        if ([string]::IsNullOrWhiteSpace($token)) { throw 'Token ausente.' }
        Add-Type -AssemblyName System.Net.Http
        $handler = New-Object Net.Http.HttpClientHandler
        $handler.AllowAutoRedirect = $false
        $cliente = New-Object Net.Http.HttpClient($handler)
        $cliente.Timeout = [TimeSpan]::FromSeconds(120)
        $requisicao = New-Object Net.Http.HttpRequestMessage
        $requisicao.Method = New-Object Net.Http.HttpMethod($Acao.Metodo)
        $requisicao.RequestUri = [Uri]$Acao.Uri
        if ($requisicao.RequestUri.Scheme -ne 'https' -or
            $requisicao.RequestUri.Host -notin @('sqladmin.googleapis.com', 'secretmanager.googleapis.com')) {
            throw 'Destino REST nao permitido.'
        }
        $requisicao.Headers.Authorization = New-Object Net.Http.Headers.AuthenticationHeaderValue('Bearer', $token)
        if ($null -ne $Acao.Corpo) {
            $json = $Acao.Corpo | ConvertTo-Json -Depth 30 -Compress
            $requisicao.Content = New-Object Net.Http.StringContent($json, [Text.Encoding]::UTF8, 'application/json')
        }
        $resposta = $cliente.SendAsync($requisicao).GetAwaiter().GetResult()
        if (-not $resposta.IsSuccessStatusCode) { throw 'Falha REST.' }
        return $resposta.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    } finally {
        $token = $null; $json = $null
        if ($resposta) { $resposta.Dispose() }
        if ($requisicao) { $requisicao.Dispose() }
        if ($cliente) { $cliente.Dispose() }
    }
}
function Get-S26Inventario($Contexto, [string]$Tipo, [scriptblock]$Executor) {
    $argumentos = switch ($Tipo) {
        'Registro' { @('artifacts','repositories','list',('--location=' + $Contexto.Regiao)) }
        'Sql' { @('sql','instances','list') }
        'Conta' { @('iam','service-accounts','list') }
        'Segredo' { @('secrets','list') }
        'Run' { @('run','services','list',('--region=' + $Contexto.Regiao)) }
        default { throw 'Tipo de recurso desconhecido.' }
    }
    $json = Invoke-S26Transporte (New-S26Gcloud $Contexto ('inventario-' + $Tipo) $argumentos) $Executor
    if ([string]::IsNullOrWhiteSpace($json) -or -not $json.TrimStart().StartsWith('[')) {
        throw 'Inventario vazio/indeterminado; nao presumir ausencia.'
    }
    $dados = ConvertFrom-Json -InputObject $json
    foreach ($item in $dados) {
        if ($null -eq $item) { throw 'Item de inventario indeterminado.' }
        Write-Output $item
    }
}
function Get-S26Campo($Objeto, [string]$Nome) {
    if ($null -eq $Objeto) { return $null }
    if ($Objeto -is [Collections.IDictionary]) { return $Objeto[$Nome] }
    $prop = $Objeto.PSObject.Properties[$Nome]
    if ($prop) { return $prop.Value }
    return $null
}
function Assert-S26Dono($Contexto, $Recurso, $Encontrado) {
    $marca = switch ($Recurso.Tipo) {
        'Conta' { Get-S26Campo $Encontrado 'description' }
        'Sql' { Get-S26Campo (Get-S26Campo (Get-S26Campo $Encontrado 'settings') 'userLabels') 's26-execucao' }
        'Run' {
            $labels = Get-S26Campo (Get-S26Campo $Encontrado 'metadata') 'labels'
            if (-not $labels) { $labels = Get-S26Campo $Encontrado 'labels' }
            Get-S26Campo $labels 's26-execucao'
        }
        default { Get-S26Campo (Get-S26Campo $Encontrado 'labels') 's26-execucao' }
    }
    $esperado = $Contexto.Execucao
    if ($Recurso.Tipo -eq 'Conta') { $esperado = $Contexto.Marca }
    if ($marca -cne $esperado) { throw ('Ownership nao comprovada: ' + $Recurso.Nome) }
    if ($Recurso.Tipo -eq 'Sql' -and (Get-S26Campo $Encontrado 'region') -cne $Contexto.Regiao) {
        throw 'Instancia SQL fora da regiao autorizada.'
    }
}
function Assert-S26Recursos($Plano, [scriptblock]$Executor) {
    $inventarios = @{}
    $presentes = @{}
    foreach ($recurso in $Plano.Recursos) {
        if (-not $inventarios.ContainsKey($recurso.Tipo)) {
            $inventarios[$recurso.Tipo] = @(Get-S26Inventario $Plano.Contexto $recurso.Tipo $Executor)
        }
        $encontrados = @($inventarios[$recurso.Tipo] | Where-Object {
            $nome = Get-S26Campo $_ 'name'
            if ($recurso.Tipo -eq 'Conta') { $nome = Get-S26Campo $_ 'email' }
            if ($recurso.Tipo -eq 'Run') {
                $metadataNome = Get-S26Campo (Get-S26Campo $_ 'metadata') 'name'
                if ($metadataNome) { $nome = $metadataNome }
            }
            ($nome -split '/')[-1] -ceq $recurso.Nome
        })
        if ($encontrados.Count -gt 1) { throw 'Inventario ambiguo.' }
        if ($encontrados.Count -eq 0) {
            if ($recurso.Modo -eq 'Owned') { throw ('Recurso obrigatorio ausente: ' + $recurso.Nome) }
            continue
        }
        if ($recurso.Modo -eq 'Absent') { throw ('Conflito de nome; nada sera adotado: ' + $recurso.Nome) }
        Assert-S26Dono $Plano.Contexto $recurso $encontrados[0]
        $presentes[$recurso.Nome] = $encontrados[0]
    }
    return $presentes
}
function Invoke-S26EsperaSql($Contexto, $Operacao, [scriptblock]$Executor) {
    $nome = Get-S26Campo $Operacao 'name'
    if ($nome -notmatch '\A[a-zA-Z0-9-]+\z') { throw 'Operacao SQL sem identificador valido.' }
    # Espera da CLI nao recebe senha nem corpo da operacao.
    [void](Invoke-S26Transporte (New-S26Gcloud $Contexto 'aguardar-sql' @(
        'sql','operations','wait',$nome,'--timeout=1800')) $Executor)
}
function Invoke-S26Plano($Plano, [switch]$Executar, [switch]$PeloLider,
                         [string]$AprovacaoMaestro, [scriptblock]$Executor,
    [scriptblock]$Relogio = { [datetime]::UtcNow },
    [scriptblock]$Dormir = { param([double]$Segundos) Start-Sleep -Milliseconds ([int][Math]::Ceiling($Segundos * 1000)) }) {
    if (-not $Executar) { return $Plano }
    Assert-S26Autorizacao -Executar -PeloLider:$PeloLider -AprovacaoMaestro $AprovacaoMaestro
    $presentes = Assert-S26Recursos $Plano $Executor
    foreach ($verificacao in $Plano.Verificacoes) {
        Invoke-S26Verificacao $Plano.Contexto $verificacao $Executor $presentes
    }
    $bindingAgenteUtc = $null
    foreach ($acao in $Plano.Acoes) {
        if ($acao.Contains('SomenteSeExiste') -and -not $presentes.ContainsKey($acao.SomenteSeExiste)) { continue }
        $arquivo = $null
        try {
            $executavel = $acao
            if ($acao.Contains('Ambiente')) {
                # JSON e YAML valido. Evita delimitadores/virgulas no argv do gcloud.cmd.
                $arquivo = Join-Path ([IO.Path]::GetTempPath()) ('s26-env-' + [guid]::NewGuid().ToString('N') + '.json')
                [IO.File]::WriteAllText($arquivo, ($acao.Ambiente | ConvertTo-Json -Depth 10),
                                      (New-Object Text.UTF8Encoding($false)))
                $executavel = New-S26Comando $acao.Id $acao.Programa ($acao.Argumentos + @('--env-vars-file=' + $arquivo))
            }
            $saida = Invoke-S26Transporte $executavel $Executor
            if ($Plano.Contains('EsperaIam') -and $acao.Id -eq 'invoker-solar-agente') {
                $bindingAgenteUtc = & $Relogio
            }
            if ($acao.Tipo -eq 'Rest' -and $acao.Uri -like 'https://sqladmin.googleapis.com/*') {
                Invoke-S26EsperaSql $Plano.Contexto ($saida | ConvertFrom-Json) $Executor
            }
        } finally {
            if ($arquivo -and [IO.File]::Exists($arquivo)) { [IO.File]::Delete($arquivo) }
        }
    }
    if ($Plano.Contains('EsperaIam')) {
        if ($null -eq $bindingAgenteUtc) { throw 'Binding do agente nao concluido; verificacoes/publicacao bloqueadas.' }
        Wait-S26IamFrontApi -OrigemFront $Plano.EsperaIam.OrigemFront -BindingAgenteUtc $bindingAgenteUtc `
            -Executor $Executor -Relogio $Relogio -Dormir $Dormir
    }
    if ($Plano.Contains('VerificacoesFinais')) {
        foreach ($verificacao in $Plano.VerificacoesFinais) {
            Invoke-S26Verificacao $Plano.Contexto $verificacao $Executor $presentes
        }
    }
    if ($Plano.Contains('PublicarDepoisDeVerificar')) {
        [void](Invoke-S26Transporte $Plano.PublicarDepoisDeVerificar $Executor)
    }
    return [ordered]@{ Execucao=$Plano.Contexto.Execucao; Etapa=$Plano.Nome; Concluida=$true }
}

function Invoke-S26Verificacao($Contexto, $Verificacao, [scriptblock]$Executor, $Presentes) {
    switch ($Verificacao.Tipo) {
        'Projeto' {
            $config = (Invoke-S26Transporte (New-S26Gcloud $Contexto 'conferir-config' @('config','list')) $Executor) | ConvertFrom-Json
            if ($config.core.project -cne $Contexto.Projeto -or [string]::IsNullOrWhiteSpace($config.core.account)) {
                throw 'Conta ativa/projeto devem ser conferidos pelo lider antes de executar.'
            }
        }
        'Apis' {
            $habilitadas = (Invoke-S26Transporte (New-S26Gcloud $Contexto 'conferir-apis' @(
                'services','list','--enabled')) $Executor) | ConvertFrom-Json
            foreach ($api in @('run.googleapis.com','artifactregistry.googleapis.com',
                                'sqladmin.googleapis.com','secretmanager.googleapis.com','iam.googleapis.com')) {
                if ($api -notin @($habilitadas | ForEach-Object { $_.config.name })) {
                    throw 'APIs ausentes. Revisar/executar etapa Apis separadamente antes do inventario.'
                }
            }
        }
        'Git' {
            $repo = $Verificacao.Repositorio
            $branch = Invoke-S26Transporte (New-S26Comando 'git-branch' 'git' @('-C',$repo,'branch','--show-current')) $Executor
            $status = Invoke-S26Transporte (New-S26Comando 'git-limpo' 'git' @('-C',$repo,'status','--porcelain','--untracked-files=all')) $Executor
            $head = Invoke-S26Transporte (New-S26Comando 'git-sha' 'git' @('-C',$repo,'rev-parse','HEAD')) $Executor
            if ($branch -cne 'feature/S-26' -or $status -ne '' -or $head -cne $Verificacao.Sha) {
                throw 'Build/push exige worktree feature/S-26 limpo e HEAD igual ao SHA informado.'
            }
        }
        'NumeroProjeto' {
            $projeto = (Invoke-S26Transporte (New-S26Gcloud $Contexto 'numero-projeto' @(
                'projects','describe',$Contexto.Projeto)) $Executor) | ConvertFrom-Json
            if ([string]$projeto.projectNumber -cne $Verificacao.Numero) { throw 'Numero real do projeto diverge da entrada.' }
        }
        'UrlPublicada' {
            $recusa = 'status.url/URLs anunciadas ou nome/ownership invalidos. Manter privado e revisar configuracao.'
            $jsonServico = Invoke-S26Transporte (New-S26Gcloud $Contexto 'conferir-url-publicada' @(
                'run','services','describe',$Verificacao.Servico,('--region=' + $Contexto.Regiao))) $Executor
            if ($jsonServico -isnot [string] -or -not $jsonServico.TrimStart().StartsWith('{')) { throw $recusa }
            try { $servico = ConvertFrom-Json -InputObject $jsonServico -ErrorAction Stop }
            catch { throw $recusa }
            # Preservar o tipo original de cada campo (array unitario nao vira
            # string/objeto escalar pela enumeracao do pipeline).
            $campo = {
                param($objeto, [string]$chave)
                if ($objeto -isnot [pscustomobject]) { return }
                $propriedade = $objeto.PSObject.Properties[$chave]
                if ($null -ne $propriedade) { return ,$propriedade.Value }
            }
            $metadata = & $campo $servico 'metadata'
            $nome = & $campo $metadata 'name'
            $labels = & $campo $metadata 'labels'
            $dono = & $campo $labels 's26-execucao'
            if ($nome -isnot [string] -or $nome -cne $Verificacao.Servico -or
                $dono -isnot [string] -or $dono -cne $Contexto.Execucao) { throw $recusa }
            $annotations = & $campo $metadata 'annotations'
            $jsonUrls = & $campo $annotations 'run.googleapis.com/urls'
            # Schema restrito de JSON: array de strings (nao comentarios, tipos
            # mistos ou virgula final aceitos por alguns parsers PowerShell).
            $stringJson = '"(?:[^"\\\x00-\x1f]|\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4}))*"'
            $espacoJson = '[ \t\r\n]*'
            $arrayJson = '\A' + $espacoJson + '\[' + $espacoJson + '(?:' + $stringJson +
                $espacoJson + '(?:,' + $espacoJson + $stringJson + $espacoJson + ')*)?\]' + $espacoJson + '\z'
            if ($jsonUrls -isnot [string] -or $jsonUrls -cnotmatch $arrayJson) { throw $recusa }
            try {
                # Envelope preserva arrays vazios/unitarios/aninhados em 5.1 e 7,
                # sem usar -NoEnumerate (inexistente no ConvertFrom-Json de 5.1).
                $envelope = ConvertFrom-Json -InputObject ('{"urls":' + $jsonUrls + '}') -ErrorAction Stop
                $urls = $envelope.urls
            } catch { throw $recusa }
            if ($urls -isnot [array] -or $urls.Count -lt 1 -or $urls.Count -gt 8) { throw $recusa }
            $status = & $campo $servico 'status'
            $statusUrl = & $campo $status 'url'
            foreach ($url in @($Verificacao.Url, $statusUrl) + $urls) {
                if ($url -isnot [string] -or $url -cnotmatch '\Ahttps://[a-z0-9-]+(?:\.[a-z0-9-]+)*\.run\.app\z') {
                    throw $recusa
                }
                try { [void](ConvertTo-S26OrigemHttps $url) } catch { throw $recusa }
            }
            if ($Verificacao.Url -cnotin $urls -or $statusUrl -cnotin $urls) {
                throw $recusa
            }
        }
        'Iam' {
            $politica = (Invoke-S26Transporte (New-S26Gcloud $Contexto 'iam-projeto' @(
                'projects','get-iam-policy',$Contexto.Projeto)) $Executor) | ConvertFrom-Json
            $membrosRuntime = @($Contexto.Contas.Keys | ForEach-Object {
                'serviceAccount:' + (Get-S26EmailConta $Contexto $_)
            })
            foreach ($binding in @(Get-S26Campo $politica 'bindings')) {
                if ($binding.role -eq 'roles/run.invoker') { throw 'Invoker no projeto impede isolamento por servico.' }
                if ($binding.role -eq 'roles/secretmanager.secretAccessor' -and
                    @($binding.members | Where-Object { $_ -in $membrosRuntime }).Count) {
                    throw 'SecretAccessor de runtime no projeto e amplo demais.'
                }
            }
            foreach ($papel in @('Api','Agente','Front')) {
                $nome = 'solar-' + $papel.ToLowerInvariant()
                if (-not $Presentes.ContainsKey($nome)) { continue }
                $iam = (Invoke-S26Transporte (New-S26Gcloud $Contexto ('iam-' + $papel) @(
                    'run','services','get-iam-policy',$nome,('--region=' + $Contexto.Regiao))) $Executor) | ConvertFrom-Json
                $permitido = switch ($papel) {
                    'Api' { 'serviceAccount:' + (Get-S26EmailConta $Contexto 'Front') }
                    'Agente' { 'serviceAccount:' + (Get-S26EmailConta $Contexto 'Api') }
                    'Front' { 'allUsers' }
                }
                foreach ($binding in @(Get-S26Campo $iam 'bindings')) {
                    if ($binding.role -eq 'roles/run.invoker' -and
                        @($binding.members | Where-Object { $_ -cne $permitido }).Count) {
                        throw 'Invoker inesperado no servico; nao alterar/adotar politica alheia.'
                    }
                }
            }
        }
        default { throw 'Verificacao desconhecida.' }
    }
}
