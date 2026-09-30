# Executar com powershell.exe ou pwsh -NoProfile -File <caminho absoluto>.
# Somente fixtures ficticias: dominios .test e redes reservadas para documentacao.
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
    FrontCidrsObservados = @('192.0.2.0/24', '2001:db8:1::/48')
    ApiCidrsObservados = @('198.51.100.17/32', '2001:db8:2::/48')
    SaltosFrontObservados = 2
    SaltosApiObservados = 3
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
        ProxyTrust__ForwardLimit = '3'
        SOLAR_VERSION = ('b' * 40)
        Email__Smtp__Host = 'smtp.gmail.com'
        Email__Smtp__Porta = '587'
        Email__Smtp__StartTls = 'true'
        ProxyTrust__KnownIPNetworks__0 = '198.51.100.17/32'
        ProxyTrust__KnownIPNetworks__1 = '2001:db8:2::/48'
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
        FRONT_TRUSTED_PROXY_CIDRS = '192.0.2.0/24,2001:db8:1::/48'
        FRONT_TRUSTED_HOPS = '2'
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
Testar 'um CIDR nao vira lista de caracteres e oito saltos sao aceitos' {
    $p = $base.Clone()
    $p.FrontCidrsObservados = @('2001:0db8::1/128')
    $p.ApiCidrsObservados = @('203.0.113.2/32')
    $p.SaltosFrontObservados = 1
    $p.SaltosApiObservados = 8
    $config = New-S26ConfiguracaoProducao @p
    Assert-Igual '2001:db8::1/128' $config.Servicos.Front.Variaveis.FRONT_TRUSTED_PROXY_CIDRS
    Assert-Igual '203.0.113.2/32' $config.Servicos.Api.Variaveis.ProxyTrust__KnownIPNetworks__0
    Assert-Igual '8' $config.Servicos.Api.Variaveis.ProxyTrust__ForwardLimit
}
Testar 'chamadas independentes nao compartilham estado nem alteram entrada' {
    $primeiro = New-S26ConfiguracaoProducao @base
    $primeiro.Servicos.Api.Variaveis.Agente__BaseUrl = 'alterado'
    $segundo = New-S26ConfiguracaoProducao @base
    Assert-Igual 'https://agente.test' $segundo.Servicos.Api.Variaveis.Agente__BaseUrl
    Assert-Igual 2 $base.ApiCidrsObservados.Count
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
foreach ($chave in @('SaltosFrontObservados', 'SaltosApiObservados')) {
    foreach ($invalido in @('', 0, -1, 9, '1.5', 'um', '01')) {
        $p = $base.Clone()
        $p[$chave] = $invalido
        Testar-Rejeicao ('limite de saltos invalido em ' + $chave) $p
    }
}
foreach ($chave in @('FrontCidrsObservados', 'ApiCidrsObservados')) {
    foreach ($invalido in @('', '0.0.0.0/0', '::/0', '192.0.2.1',
                            '192.0.2.0/33', '2001:db8::/129', '192.0.2.7/24',
                            '2001:db8::1/64', '127.1/32', '::ffff:192.0.2.1/128',
                            'fe80::%1/64', 'rede/24', '192.0.2.0/24 ')) {
        $p = $base.Clone()
        $p[$chave] = @($invalido)
        Testar-Rejeicao ('CIDR invalido em ' + $chave) $p
    }
    $p = $base.Clone()
    $p[$chave] = @()
    Testar-Rejeicao ('allow-list vazia em ' + $chave) $p
    $p[$chave] = @('192.0.2.0/24', '192.0.2.0/24')
    Testar-Rejeicao ('CIDR duplicado em ' + $chave) $p
    $p[$chave] = @(1..33 | ForEach-Object { '192.0.2.' + $_ + '/32' })
    Testar-Rejeicao ('mais de 32 CIDRs em ' + $chave) $p
}
$p = $base.Clone()
$p.PeersObservadosConfirmados = $false
Testar-Rejeicao 'sem confirmacao explicita de observacao' $p

foreach ($chave in @('UrlFront', 'UrlApi', 'UrlAgente', 'ShaFront', 'ShaApi', 'ShaAgente',
                     'SaltosFrontObservados', 'SaltosApiObservados',
                     'FrontCidrsObservados', 'ApiCidrsObservados')) {
    $p = $base.Clone()
    if ($chave -like '*Cidrs*') {
        $p[$chave] = @("192.0.2.0/24`n")
    } else {
        $p[$chave] = [string]$p[$chave] + "`n"
    }
    Testar-Rejeicao ('quebra de linha proibida em ' + $chave) $p
}

Write-Output ('PASSOU: ' + $script:total + ' testes; nenhuma rede, nuvem ou credencial utilizada.')
