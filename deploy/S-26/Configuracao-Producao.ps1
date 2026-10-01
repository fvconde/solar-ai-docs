# Helper puro: nao le ambiente, arquivos, credenciais ou rede e nao executa deploy.
# Compativel com Windows PowerShell 5.1 e PowerShell 7.

function ConvertTo-S26OrigemHttps {
    param([string]$Valor)
    # Valida antes de Uri normalizar caminhos, escapes ou barras invertidas.
    if ($Valor -cnotmatch '\Ahttps://[a-zA-Z0-9.-]+(?::443)?/?\z') {
        throw 'URL deve ser uma origem HTTPS, sem credenciais, caminho, query ou fragmento.'
    }
    $uri = [Uri]$Valor
    foreach ($rotulo in $uri.DnsSafeHost.Split('.')) {
        if ($rotulo.Length -gt 63 -or $rotulo -notmatch '\A[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\z') {
            throw 'Hostname HTTPS invalido.'
        }
    }
    if ($uri.DnsSafeHost.Length -gt 253 -or $uri.HostNameType -ne [UriHostNameType]::Dns) {
        throw 'A origem HTTPS deve usar um hostname DNS valido.'
    }
    return $uri.GetLeftPart([UriPartial]::Authority).TrimEnd('/')
}

function ConvertTo-S26CidrsObservados {
    param([string[]]$Valores)
    if ($null -eq $Valores -or $Valores.Count -lt 1 -or $Valores.Count -gt 32) {
        throw 'Informe entre 1 e 32 CIDRs explicitamente observados por servico.'
    }
    $resultado = @()
    foreach ($valor in $Valores) {
        if ($valor -notmatch '\A([^/%\s]+)/([1-9][0-9]*)\z') {
            throw 'CIDR invalido; redes /0, escopos e entradas vazias sao proibidos.'
        }
        $enderecoTexto = $Matches[1]
        $prefixoTexto = $Matches[2]
        $endereco = $null
        $prefixo = 0
        if (-not [Net.IPAddress]::TryParse($enderecoTexto, [ref]$endereco) -or
            -not [int]::TryParse($prefixoTexto, [ref]$prefixo)) {
            throw 'CIDR invalido.'
        }
        $bytes = $endereco.GetAddressBytes()
        if ($prefixo -gt ($bytes.Length * 8) -or
            ($bytes.Length -eq 4 -and $endereco.ToString() -cne $enderecoTexto) -or
            ($bytes.Length -eq 16 -and $endereco.IsIPv4MappedToIPv6)) {
            throw 'CIDR invalido ou endereco ambiguo.'
        }
        for ($i = 0; $i -lt $bytes.Length; $i++) {
            $bits = [Math]::Min(8, [Math]::Max(0, $prefixo - 8 * $i))
            $mascara = (255 -shl (8 - $bits)) -band 255
            if (($bytes[$i] -band $mascara) -ne $bytes[$i]) {
                throw 'CIDR deve indicar a rede canonica, sem bits de host.'
            }
        }
        $canonico = $endereco.ToString() + '/' + $prefixo
        if ($resultado -contains $canonico) {
            throw 'CIDRs duplicados nao sao permitidos.'
        }
        $resultado += $canonico
    }
    return $resultado
}

function New-S26ConfiguracaoProducao {
    <#
    .SYNOPSIS
    Gera mapas em memoria; nenhuma operacao externa e executada.
    .DESCRIPTION
    Todos os dados de implantacao devem ser fornecidos explicitamente.
    PeersObservadosConfirmados e uma declaracao do operador, nao uma prova
    automatica: bootstrap e verificacao da cadeia real pertencem ao runbook.
    Segredos contem SOMENTE identificadores propostos do Secret Manager,
    sem valores nem versoes. A tarefa seguinte decide/cria as referencias.
    Porta deve ser aplicada explicitamente ao publicar cada imagem.
    Os mapas nao concedem IAM nem provam os peers: API privada (somente SA
    front invoca), agente privado (somente SA API invoca) e API com CPU sempre
    alocada/minimo 1/maximo 1 continuam obrigatorios na tarefa de deploy.
    #>
    [CmdletBinding()]
    param(
        [string]$UrlFront,
        [string]$UrlApi,
        [string]$UrlAgente,
        [string]$ShaFront,
        [string]$ShaApi,
        [string]$ShaAgente,
        [switch]$PeersObservadosConfirmados
    )
    if (-not $PeersObservadosConfirmados) {
        throw 'Confirme os peers efetivamente observados e aprovados; nao presuma ranges Cloud Run.'
    }
    $front = ConvertTo-S26OrigemHttps $UrlFront
    $api = ConvertTo-S26OrigemHttps $UrlApi
    $agente = ConvertTo-S26OrigemHttps $UrlAgente
    if (@($front, $api, $agente | Select-Object -Unique).Count -ne 3) {
        throw 'Front, API e agente devem ter origens distintas.'
    }
    foreach ($sha in @($ShaFront, $ShaApi, $ShaAgente)) {
        if ($sha -cnotmatch '\A[0-9a-fA-F]{40}\z') {
            throw 'Informe o SHA completo de 40 caracteres hexadecimais de cada servico.'
        }
    }
    # Somente depois de TODAS as validacoes construimos a configuracao.
    $variaveisApi = [ordered]@{
        ASPNETCORE_ENVIRONMENT = 'Production'
        ASPNETCORE_HTTP_PORTS = '8080'
        Agente__BaseUrl = $agente
        Agente__Autenticacao__Ativa = 'true'
        Cors__Origens__0 = $front
        Painel__UrlBaseDoFront = $front
        ProxyTrust__ForwardedForHeaderName = 'X-Solar-Client-IP'
        ProxyTrust__KnownProxies__0 = '169.254.169.126'
        ProxyTrust__ForwardLimit = '1'
        SOLAR_VERSION = $ShaApi.ToLowerInvariant()
        Email__Smtp__Host = 'smtp.gmail.com'
        Email__Smtp__Porta = '587'
        Email__Smtp__StartTls = 'true'
    }
    return [ordered]@{
        Regiao = 'southamerica-east1'
        Servicos = [ordered]@{
            Api = [ordered]@{
                Nome = 'solar-api'
                Porta = 8080
                Variaveis = $variaveisApi
                Segredos = [ordered]@{
                    ConnectionStrings__Postgres = 'solar-postgres-connection-string'
                    Email__Smtp__Usuario = 'solar-smtp-usuario'
                    Email__Smtp__SenhaApp = 'solar-smtp-senha-app'
                    Email__Smtp__Remetente = 'solar-smtp-remetente'
                    Semente__SenhaSupervisor = 'solar-semente-senha-supervisor'
                    Seguranca__ChavePrivacidade = 'solar-chave-privacidade'
                }
            }
            Agente = [ordered]@{
                Nome = 'solar-agente'
                Porta = 8000
                Variaveis = [ordered]@{
                    SOLAR_ENV = 'production'
                    SOLAR_VERSION = $ShaAgente.ToLowerInvariant()
                    GEMINI_MODEL = 'gemini-3.5-flash-lite'
                    GEMINI_EMBEDDING_MODEL = 'gemini-embedding-001'
                }
                Segredos = [ordered]@{ GEMINI_API_KEY = 'solar-gemini-api-key' }
            }
            Front = [ordered]@{
                Nome = 'solar-front'
                Porta = 8080
                Variaveis = [ordered]@{
                    FRONT_AUTH_MODE = 'iam'
                    FRONT_API_URL = $api
                    FRONT_TRUSTED_PROXY_CIDRS = '169.254.169.126/32'
                    FRONT_TRUSTED_HOPS = '1'
                    SOLAR_VERSION = $ShaFront.ToLowerInvariant()
                }
                Segredos = [ordered]@{}
            }
        }
    }
}
