$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'Operacoes.ps1')
function Invoke-S26Nativo { throw 'Transporte real proibido na suite offline.' }
$ctx = New-S26Contexto
$esperada = 'https://solar-api-123456789012.southamerica-east1.run.app'
$hash = 'https://solar-api-hashficticio-uc.a.run.app'
$script:total = 0
$script:chamadas = 0
function Exigir([bool]$Condicao) {
    if (-not $Condicao) { throw 'Assercao URL publicada falhou; dados omitidos.' }
}
function Caso([string]$Nome, [scriptblock]$Teste) {
    try { & $Teste; $script:total++ }
    catch { throw ('Caso ' + $Nome + ' falhou; dados omitidos.') }
}
function Servico-Valido {
    return @{
        metadata=@{name='solar-api';labels=@{'s26-execucao'=$ctx.Execucao};
            annotations=@{'run.googleapis.com/urls'=('[' + '"' + $esperada + '","' + $hash + '"]')}}
        status=@{url=$hash}
    }
}
function Conferir($Servico, [bool]$Aceitar, [string]$UrlEsperada=$esperada) {
    $script:jsonServico = ConvertTo-Json -InputObject $Servico -Depth 15 -Compress
    Conferir-Json $Aceitar $UrlEsperada
}
function Conferir-Json([bool]$Aceitar, [string]$UrlEsperada=$esperada) {
    $script:chamadas = 0
    $fake = {
        param($acao)
        $script:chamadas++
        Exigir ($acao.Id -ceq 'conferir-url-publicada' -and $acao.Tipo -ceq 'Comando')
        Exigir ($acao.Programa -ceq $ctx.Gcloud)
        $argv = @('run','services','describe','solar-api','--region=southamerica-east1',
            '--project=solar-ai-cloud','--quiet','--format=json')
        Exigir ($acao.Argumentos.Count -eq $argv.Count)
        for ($i=0; $i -lt $argv.Count; $i++) { Exigir ($acao.Argumentos[$i] -ceq $argv[$i]) }
        return $script:jsonServico
    }
    $verificacao = @{Tipo='UrlPublicada';Servico='solar-api';Url=$UrlEsperada}
    $falhou=$false; $saida=@()
    try { $saida=@(Invoke-S26Verificacao $ctx $verificacao $fake @{}) }
    catch {
        $falhou=$true
        Exigir ($_.Exception.Message.Contains('status.url/URLs anunciadas'))
        Exigir ($null -eq $_.Exception.InnerException)
    }
    Exigir ($falhou -eq (-not $Aceitar) -and $saida.Count -eq 0 -and $script:chamadas -eq 1)
}

Caso 'status com hash e deterministica anunciados' { Conferir (Servico-Valido) $true }
Caso 'status deterministico e lista unitaria preservada' {
    $s=Servico-Valido; $s.status.url=$esperada
    $s.metadata.annotations['run.googleapis.com/urls']='["' + $esperada + '"]'
    Conferir $s $true
}
Caso 'JSON com espacos e escape valido preserva origem exata' {
    $s=Servico-Valido
    $s.metadata.annotations['run.googleapis.com/urls']="[ `n" + '"' + $esperada.Replace('https://','https:\/\/') + '","' + $hash + '"' + "`n ]"
    Conferir $s $true
}
Caso 'oito origens validas anunciadas' {
    $s=Servico-Valido
    $urls=@($esperada,$hash) + @(1..6 | ForEach-Object {'https://alias-' + $_ + '.run.app'})
    $s.metadata.annotations['run.googleapis.com/urls']=ConvertTo-Json -InputObject $urls -Compress
    Conferir $s $true
}
foreach ($lista in @($null,'',' ','[]','{}','null','"origem"','[invalido]',
    '[null]','[1]','[true]', ('[["' + $esperada + '"]]'),
    ('["' + $esperada + '",null]'), ('["' + $esperada + '",]'),
    ('[/*comentario*/"' + $esperada + '"]'))) {
    Caso 'lista ausente ou JSON/schema invalido recusado' {
        $s=Servico-Valido; $s.metadata.annotations['run.googleapis.com/urls']=$lista
        Conferir $s $false
    }
}
Caso 'mais de oito origens recusadas' {
    $s=Servico-Valido
    $urls=@($esperada,$hash) + @(1..7 | ForEach-Object {'https://alias-' + $_ + '.run.app'})
    $s.metadata.annotations['run.googleapis.com/urls']=ConvertTo-Json -InputObject $urls -Compress
    Conferir $s $false
}
Caso 'deterministica ausente da lista' {
    $s=Servico-Valido; $s.metadata.annotations['run.googleapis.com/urls']='["' + $hash + '"]'
    Conferir $s $false
}
Caso 'status ausente da lista' {
    $s=Servico-Valido; $s.metadata.annotations['run.googleapis.com/urls']='["' + $esperada + '"]'
    Conferir $s $false
}
Caso 'origens de outro servico nao substituem esperada' {
    $s=Servico-Valido; $s.status.url='https://solar-front-hashficticio.a.run.app'
    $s.metadata.annotations['run.googleapis.com/urls']='["https://solar-front-123456789012.southamerica-east1.run.app","https://solar-front-hashficticio.a.run.app"]'
    Conferir $s $false
}
foreach ($nome in @($null,'','solar-front','Solar-api',@('solar-api'))) {
    Caso 'nome ausente diferente ou tipo invalido recusado' {
        $s=Servico-Valido; $s.metadata.name=$nome; Conferir $s $false
    }
}
foreach ($dono in @($null,'','outra-execucao',$ctx.Execucao.ToUpperInvariant(),@($ctx.Execucao))) {
    Caso 'ownership ausente divergente ou tipo invalido recusado' {
        $s=Servico-Valido; $s.metadata.labels['s26-execucao']=$dono; Conferir $s $false
    }
}
foreach ($url in @('http://solar-api.run.app','https://solar-api.run.app/caminho',
    'https://usuario:senha@solar-api.run.app','https://solar-api.run.app/',
    'https://solar-api.run.app:443','https://Solar-api.run.app','https://solar-api.run.app?x=1',
    'https://solar-api.run.app#fragmento','https://solar-api.run.app.evil.test',
    'https://solar-api.test','https://-solar-api.run.app','https://solar-api-.run.app',
    'https://solar-api..run.app','https://solar-api%2e.run.app','https://solar-api.run.app\caminho')) {
    Caso 'item anunciado nao canonico recusado mesmo com esperada e status validos' {
        $s=Servico-Valido
        $s.metadata.annotations['run.googleapis.com/urls']=ConvertTo-Json -InputObject @($esperada,$hash,$url) -Compress
        Conferir $s $false
    }
    Caso 'status invalido nao e normalizado' {
        $s=Servico-Valido; $s.status.url=$url; Conferir $s $false
    }
    Caso 'URL esperada invalida nao e normalizada' { Conferir (Servico-Valido) $false $url }
}
Caso 'metadata ausente recusada' { Conferir @{status=@{url=$hash}} $false }
Caso 'ownership fora de metadata nao e adotado' {
    $s=Servico-Valido; $s.metadata.Remove('labels'); $s.labels=@{'s26-execucao'=$ctx.Execucao}
    Conferir $s $false
}
Caso 'annotations ausentes recusadas' {
    $s=Servico-Valido; $s.metadata.Remove('annotations'); Conferir $s $false
}
Caso 'status ausente recusado' { $s=Servico-Valido; $s.Remove('status'); Conferir $s $false }
foreach ($campoArray in @('metadata','labels','annotations','status.url','lista')) {
    Caso ('array unitario no campo ' + $campoArray + ' nao vira escalar') {
        $s=Servico-Valido
        switch ($campoArray) {
            'metadata' { $s.metadata=@($s.metadata) }
            'labels' { $s.metadata.labels=@($s.metadata.labels) }
            'annotations' { $s.metadata.annotations=@($s.metadata.annotations) }
            'status.url' { $s.status.url=@($s.status.url) }
            'lista' { $s.metadata.annotations['run.googleapis.com/urls']=@($s.metadata.annotations['run.googleapis.com/urls']) }
        }
        Conferir $s $false
    }
}
foreach ($json in @('','null','[]','[{}]','{invalido}')) {
    Caso 'describe indeterminado ou JSON errado recusado' {
        $script:jsonServico=$json; Conferir-Json $false
    }
}
Write-Output ('PASSOU: ' + $script:total + ' casos UrlPublicada via transporte fake; PowerShell ' + $PSVersionTable.PSVersion + '; zero SDK/rede/nuvem.')
