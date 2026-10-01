# Executar com powershell.exe ou pwsh -NoProfile -File <caminho absoluto>.
# Dominios .test e SHAs ficticios; constantes aprovadas sem interacao com nuvem.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'Configuracao-Producao.ps1')

$script:total = 0
function Assert-Igual($Esperado, $Obtido) {
    if ($Esperado -cne $Obtido) { throw 'Valor diferente do esperado.' }
}
function Assert-Mapa($Esperado, $Obtido) {
    Assert-Igual $Esperado.Count $Obtido.Count
    foreach ($chave in $Esperado.Keys) {
        if (-not $Obtido.Contains($chave)) { throw 'Chave esperada ausente.' }
        Assert-Igual $Esperado[$chave] $Obtido[$chave]
    }
}
function Testar([string]$Nome, [scriptblock]$Acao) {
    & $Acao
    $script:total++
    Write-Output ('OK: ' + $Nome)
}
function Testar-Rejeicao([string]$Nome, [hashtable]$Parametros) {
    Testar $Nome {
        $emitidos = New-Object 'System.Collections.Generic.List[object]'
        $falhou = $false
        try {
            New-S26ConfiguracaoProducao @Parametros | ForEach-Object { $emitidos.Add($_) }
        } catch { $falhou = $true }
        if (-not $falhou) { throw 'Entrada invalida foi aceita.' }
        Assert-Igual 0 $emitidos.Count
    }
}

$base = @{
    UrlFront = 'https://front.test'
    UrlApi = 'https://api.test'
    UrlAgente = 'https://agente.test'
    ShaFront = ('a' * 40)
    ShaApi = ('b' * 40)
    ShaAgente = ('c' * 40)
    PeersObservadosConfirmados = $true
}

Testar 'mapas API completos, allow-list indexada e SMTP com STARTTLS' {
    $config = New-S26ConfiguracaoProducao @base
    Assert-Mapa ([ordered]@{
        ASPNETCORE_ENVIRONMENT = 'Production'
        ASPNETCORE_HTTP_PORTS = '8080'
        Agente__BaseUrl = 'https://agente.test'
        Agente__Autenticacao__Ativa = 'true'
        Cors__Origens__0 = 'https://front.test'
        Painel__UrlBaseDoFront = 'https://front.test'
        ProxyTrust__ForwardLimit = '1'
        ProxyTrust__ForwardedForHeaderName = 'X-Solar-Client-IP'
        ProxyTrust__KnownProxies__0 = '169.254.169.126'
        SOLAR_VERSION = ('b' * 40)
        Email__Smtp__Host = 'smtp.gmail.com'
        Email__Smtp__Porta = '587'
        Email__Smtp__StartTls = 'true'
    }) $config.Servicos.Api.Variaveis
}
Testar 'mapas agente com modelos atuais e front IAM' {
    $config = New-S26ConfiguracaoProducao @base
    Assert-Mapa ([ordered]@{
        SOLAR_ENV = 'production'
        SOLAR_VERSION = ('c' * 40)
        GEMINI_MODEL = 'gemini-3.5-flash-lite'
        GEMINI_EMBEDDING_MODEL = 'gemini-embedding-001'
    }) $config.Servicos.Agente.Variaveis
    Assert-Mapa ([ordered]@{
        FRONT_AUTH_MODE = 'iam'
        FRONT_API_URL = 'https://api.test'
        FRONT_TRUSTED_PROXY_CIDRS = '169.254.169.126/32'
        FRONT_TRUSTED_HOPS = '1'
        SOLAR_VERSION = ('a' * 40)
    }) $config.Servicos.Front.Variaveis
}
Testar 'referencias Secret Manager separadas, sem valores nos mapas comuns' {
    $config = New-S26ConfiguracaoProducao @base
    Assert-Mapa ([ordered]@{
        ConnectionStrings__Postgres = 'solar-postgres-connection-string'
        Email__Smtp__Usuario = 'solar-smtp-usuario'
        Email__Smtp__SenhaApp = 'solar-smtp-senha-app'
        Email__Smtp__Remetente = 'solar-smtp-remetente'
        Semente__SenhaSupervisor = 'solar-semente-senha-supervisor'
        Seguranca__ChavePrivacidade = 'solar-chave-privacidade'
    }) $config.Servicos.Api.Segredos
    Assert-Mapa ([ordered]@{ GEMINI_API_KEY = 'solar-gemini-api-key' }) $config.Servicos.Agente.Segredos
    Assert-Igual 0 $config.Servicos.Front.Segredos.Count
    foreach ($servico in $config.Servicos.Values) {
        foreach ($chave in $servico.Segredos.Keys) {
            if ($servico.Variaveis.Contains($chave)) { throw 'Segredo no mapa de variaveis comuns.' }
        }
    }
}
Testar 'regiao, nomes e portas explicitas dos tres servicos' {
    $config = New-S26ConfiguracaoProducao @base
    Assert-Igual 'southamerica-east1' $config.Regiao
    Assert-Igual 3 $config.Servicos.Count
    Assert-Igual 'solar-api' $config.Servicos.Api.Nome
    Assert-Igual 'solar-agente' $config.Servicos.Agente.Nome
    Assert-Igual 'solar-front' $config.Servicos.Front.Nome
    Assert-Igual 8080 $config.Servicos.Api.Porta
    Assert-Igual 8000 $config.Servicos.Agente.Porta
    Assert-Igual 8080 $config.Servicos.Front.Porta
}
Testar 'origem canonica retira barra raiz/443 e normaliza SHA' {
    $p = $base.Clone()
    $p.UrlApi = 'https://API.test:443/'
    $p.ShaApi = ('D' * 40)
    $config = New-S26ConfiguracaoProducao @p
    Assert-Igual 'https://api.test' $config.Servicos.Front.Variaveis.FRONT_API_URL
    Assert-Igual ('d' * 40) $config.Servicos.Api.Variaveis.SOLAR_VERSION
}
foreach ($chave in @('FrontCidrsObservados','ApiCidrsObservados','SaltosFrontObservados','SaltosApiObservados')) {
    $p = $base.Clone()
    $p[$chave] = 'entrada-livre-proibida'
    Testar-Rejeicao ('parametro livre removido: ' + $chave) $p
}
Testar 'chamadas independentes nao compartilham estado nem alteram entrada' {
    $primeiro = New-S26ConfiguracaoProducao @base
    $primeiro.Servicos.Api.Variaveis.Agente__BaseUrl = 'alterado'
    $segundo = New-S26ConfiguracaoProducao @base
    Assert-Igual 'https://agente.test' $segundo.Servicos.Api.Variaveis.Agente__BaseUrl
    Assert-Igual 7 $base.Count
}

foreach ($chave in $base.Keys) {
    $p = $base.Clone()
    $p.Remove($chave)
    Testar-Rejeicao ('ausencia de ' + $chave) $p
}
foreach ($chave in @('UrlFront', 'UrlApi', 'UrlAgente')) {
    foreach ($invalida in @('', 'http://api.test', 'https://user:senha@api.test',
                            'https://api.test/caminho', 'https://api.test/a/..',
                            'https://api.test?x=1', 'https://api.test#fragmento',
                            'https://api.test:8443', 'https://api.test\caminho',
                            'https://api.test/%2f', 'https://api..test', 'https://-api.test',
                            ' https://api.test', 'https://127.0.0.1')) {
        $p = $base.Clone()
        $p[$chave] = $invalida
        Testar-Rejeicao ('origem invalida em ' + $chave) $p
    }
}
$p = $base.Clone()
$p.UrlApi = 'https://front.test:443/'
Testar-Rejeicao 'servicos com a mesma origem apos normalizar' $p
foreach ($chave in @('ShaFront', 'ShaApi', 'ShaAgente')) {
    foreach ($invalido in @('', ('a' * 39), ('a' * 41), ('g' * 40), ('a' * 39 + ' '))) {
        $p = $base.Clone()
        $p[$chave] = $invalido
        Testar-Rejeicao ('SHA invalido em ' + $chave) $p
    }
}
$p = $base.Clone()
$p.PeersObservadosConfirmados = $false
Testar-Rejeicao 'sem confirmacao explicita de observacao' $p

foreach ($chave in @('UrlFront', 'UrlApi', 'UrlAgente', 'ShaFront', 'ShaApi', 'ShaAgente')) {
    $p = $base.Clone()
    $p[$chave] = [string]$p[$chave] + "`n"
    Testar-Rejeicao ('quebra de linha proibida em ' + $chave) $p
}

Write-Output ('PASSOU: ' + $script:total + ' testes; nenhuma rede, nuvem ou credencial utilizada.')
