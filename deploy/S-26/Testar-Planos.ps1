$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'Planos.ps1')
$script:total = 0
function Exigir([bool]$Condicao, [string]$Mensagem='Assercao falhou.') {
    if (-not $Condicao) { throw $Mensagem }
}
function Caso([string]$Nome, [scriptblock]$Teste) {
    try { & $Teste } catch { throw ('Caso ' + $Nome + ': ' + $_.Exception.Message) }
    $script:total++
}
function Recusa([scriptblock]$Teste, [string]$Trecho='') {
    $recusou = $false
    try { & $Teste | Out-Null } catch {
        $recusou = $true
        if ($Trecho) { Exigir ($_.Exception.Message.Contains($Trecho)) 'Mensagem inesperada.' }
    }
    Exigir $recusou 'Deveria recusar.'
}
$ctx = New-S26Contexto
$script:chamadas = New-Object 'System.Collections.Generic.List[object]'
$script:inventario = @{}
$fake = {
    param($a)
    $script:chamadas.Add($a)
    if ($a.Id -like 'inventario-*') {
        $tipo = $a.Id.Substring(11)
        if ($script:inventario.ContainsKey($tipo)) { return ConvertTo-Json -InputObject @($script:inventario[$tipo]) -Depth 20 -Compress }
        return '[]'
    }
    switch ($a.Id) {
        'conferir-config' { return '{"core":{"project":"solar-ai-cloud","account":"operador-ficticio"}}' }
        'conferir-apis' {
            return ConvertTo-Json -InputObject @('run','artifactregistry','sqladmin','secretmanager','iam' | ForEach-Object {
                @{config=@{name=($_ + '.googleapis.com')}}
            }) -Depth 5
        }
        'criar-sql' { return '{"name":"operacao-ficticia"}' }
        'iam-projeto' { return '{"bindings":[]}' }
        'numero-projeto' { return '{"projectNumber":"123456789012"}' }
        'conferir-url-publicada' {
            return '{"status":{"url":"https://' + $a.Argumentos[3] + '-123456789012.southamerica-east1.run.app"}}'
        }
        default {
            if ($a.Id -like 'iam-*') { return '{"bindings":[]}' }
            return '{}'
        }
    }
}
function Preparar-Owned($Plano) {
    $script:inventario = @{}
    foreach ($r in $Plano.Recursos) {
        if ($r.Modo -eq 'Absent' -or $r.Tipo -eq 'Run') { continue }
        $item = @{name=$r.Nome;labels=@{'s26-execucao'=$ctx.Execucao}}
        if ($r.Tipo -eq 'Conta') { $item=@{email=$r.Nome;description=$ctx.Marca} }
        if ($r.Tipo -eq 'Sql') { $item=@{name=$r.Nome;region=$ctx.Regiao;settings=@{userLabels=@{'s26-execucao'=$ctx.Execucao}}} }
        if (-not $script:inventario.ContainsKey($r.Tipo)) { $script:inventario[$r.Tipo]=@() }
        $script:inventario[$r.Tipo] += $item
    }
}
$shas = @{Api=('a'*40);Agente=('b'*40);Front=('c'*40)}
$entradas = @{
    UrlApi='https://solar-api-123456789012.southamerica-east1.run.app'
    UrlAgente='https://solar-agente-123456789012.southamerica-east1.run.app'
    UrlFront='https://solar-front-123456789012.southamerica-east1.run.app'
    ShaApi=$shas.Api;ShaAgente=$shas.Agente;ShaFront=$shas.Front
    FrontCidrsObservados=@('192.0.2.0/24','2001:db8::/32')
    ApiCidrsObservados=@('198.51.100.0/24')
    SaltosFrontObservados=1;SaltosApiObservados=2;PeersObservadosConfirmados=$true
}
$versoes = @{}
foreach ($nome in ($ctx.SegredosApi + $ctx.SegredosAgente)) { $versoes[$nome]='1' }
$provisionar = New-S26PlanoProvisionar
$imagens = New-S26PlanoImagens -Shas $shas
$deploy = New-S26PlanoDeploy -Entradas $entradas -VersoesSegredos $versoes -NumeroProjeto '123456789012' -BootstrapPeersComprovado -LiberarFrontPublico
$desmontar = New-S26PlanoDesmontar -Confirmacao ('EXCLUIR-' + $ctx.Execucao)

Caso 'padrao nao invoca executor, nao le credencial e nao escreve arquivos' {
    foreach ($p in @($provisionar,$imagens,$deploy,$desmontar)) {
        $r = Invoke-S26Plano $p -Executor { throw 'Executor nao pode rodar.' }
        Exigir ($r.Nome -eq $p.Nome)
    }
}
Caso 'execucao exige todas as confirmacoes' {
    Recusa { Invoke-S26Plano $provisionar -Executar -Executor $fake }
    Recusa { Invoke-S26Plano $provisionar -Executar -PeloLider -AprovacaoMaestro 'errada' -Executor $fake }
    Exigir ($script:chamadas.Count -eq 0)
}
Caso 'provisionamento com inventario todo ausente e espera SQL via fake' {
    [void](Invoke-S26Plano $provisionar -Executar -PeloLider -AprovacaoMaestro $ctx.Execucao -Executor $fake)
    Exigir (@($script:chamadas | Where-Object Id -eq 'aguardar-sql').Count -eq 1)
    $ids = @($script:chamadas | ForEach-Object { $_.Id })
    Exigir ([array]::IndexOf($ids,'inventario-Run') -lt [array]::IndexOf($ids,'criar-registro'))
}
Caso 'comandos tem argumentos atomicos, projeto/regiao explicitos' {
    foreach ($p in @($provisionar,$imagens,$deploy,$desmontar)) {
        foreach ($a in $p.Acoes) {
            if ($a.Tipo -ne 'Comando' -or $a.Programa -ne $ctx.Gcloud) { continue }
            Exigir ($a.Argumentos -contains '--project=solar-ai-cloud')
            Exigir ($a.Argumentos -contains '--quiet')
            Exigir (-not @($a.Argumentos | Where-Object { $_ -match '\A--[^=]+=\z' }).Count)
            if ($a.Argumentos[0] -eq 'run') { Exigir ($a.Argumentos -contains '--region=southamerica-east1') }
            if ($a.Argumentos[0] -eq 'artifacts') { Exigir ($a.Argumentos -contains '--location=southamerica-east1') }
        }
    }
}
Caso 'SQL16 enterprise micro zonal SSD10 sem redes autorizadas' {
    $sql = @($provisionar.Acoes | Where-Object Id -eq 'criar-sql')[0].Corpo
    Exigir ($sql.databaseVersion -eq 'POSTGRES_16' -and $sql.region -eq $ctx.Regiao)
    Exigir ($sql.settings.tier -eq 'db-f1-micro' -and $sql.settings.edition -eq 'ENTERPRISE')
    Exigir ($sql.settings.availabilityType -eq 'ZONAL' -and $sql.settings.dataDiskSizeGb -eq '10')
    Exigir ($sql.settings.dataDiskType -eq 'PD_SSD' -and -not $sql.settings.storageAutoResize)
    Exigir ($sql.settings.ipConfiguration.authorizedNetworks.Count -eq 0)
    Exigir ($sql.settings.connectorEnforcement -eq 'REQUIRED')
}
Caso 'somente sete grants de segredo no recurso, front sem acesso' {
    $grants = @($provisionar.Acoes | Where-Object { $_.Tipo -eq 'Comando' -and $_.Argumentos -contains '--role=roles/secretmanager.secretAccessor' })
    Exigir ($grants.Count -eq 7)
    foreach ($g in $grants) {
        Exigir ($g.Argumentos[0] -eq 'secrets')
        Exigir (-not (($g.Argumentos -join ' ') -like '*s26-front-*'))
    }
}
Caso 'conflito alheio impede todas as mutacoes' {
    $script:chamadas.Clear()
    $script:inventario = @{Segredo=@(@{name='solar-gemini-api-key';labels=@{}})}
    Recusa { Invoke-S26Plano $provisionar -Executar -PeloLider -AprovacaoMaestro $ctx.Execucao -Executor $fake } 'Conflito'
    Exigir (-not @($script:chamadas | Where-Object Id -like 'criar-*').Count)
}
Caso 'falha no inventario nao e ausencia e erro externo e sanitizado' {
    $script:chamadas.Clear()
    Recusa { Invoke-S26Plano $provisionar -Executar -PeloLider -AprovacaoMaestro $ctx.Execucao -Executor { throw 'SENTINELA_NAO_VAZAR' } } 'detalhes externos suprimidos'
}
Caso 'owned exige label exata e mesma regiao' {
    $r = New-S26Recurso 'Sql' $ctx.Instancia 'Owned'
    Recusa { Assert-S26Dono $ctx $r @{region=$ctx.Regiao;settings=@{userLabels=@{}}} }
    Recusa { Assert-S26Dono $ctx $r @{region='us-central1';settings=@{userLabels=@{'s26-execucao'=$ctx.Execucao}}} }
}
Caso 'imagens SHAfull, contexts absolutos e checks dos tres repos' {
    Exigir (@($imagens.Verificacoes | Where-Object Tipo -eq 'Git').Count -eq 3)
    foreach ($a in @($imagens.Acoes | Where-Object Id -like 'build-*')) {
        Exigir ($a.Argumentos[-1].StartsWith($ctx.Raiz + '/'))
        Exigir ($a.Argumentos[3] -match ':[a-f0-9]{40}\z')
    }
}
Caso 'git sujo bloqueia antes de configurar docker e construir' {
    Preparar-Owned $imagens
    $script:chamadas.Clear()
    $fakeGit = {
        param($a)
        if ($a.Id -eq 'git-branch') { return 'feature/S-26' }
        if ($a.Id -eq 'git-limpo') { return ' M arquivo' }
        if ($a.Id -eq 'git-sha') { return $shas.Api }
        & $fake $a
    }
    Recusa { Invoke-S26Plano $imagens -Executar -PeloLider -AprovacaoMaestro $ctx.Execucao -Executor $fakeGit }
    Exigir (-not @($script:chamadas | Where-Object Id -eq 'credencial-docker-local').Count)
}
Caso 'deploy privado, limites CPU API e secretversions explicitas' {
    foreach ($a in @($deploy.Acoes | Where-Object Id -like 'deploy-*')) {
        Exigir ($a.Argumentos -contains '--no-allow-unauthenticated')
        Exigir ($a.Argumentos -contains '--cpu=1' -and $a.Argumentos -contains '--memory=512Mi')
        Exigir ($a.Argumentos -contains '--max-instances=1')
        if ($a.Id -eq 'deploy-Api') {
            Exigir ($a.Argumentos -contains '--no-cpu-throttling' -and $a.Argumentos -contains '--min-instances=1')
        } else { Exigir ($a.Argumentos -contains '--cpu-throttling' -and $a.Argumentos -contains '--min-instances=0') }
        Exigir (-not (($a.Argumentos -join ' ') -match ':latest'))
    }
}
Caso 'virgulas CIDR preservadas em arquivo JSON e removido ao final' {
    Preparar-Owned $deploy
    $script:chamadas.Clear()
    $script:arquivos = @()
    $fakeDeploy = {
        param($a)
        if ($a.Id -like 'deploy-*') {
            $arg = @($a.Argumentos | Where-Object { $_ -like '--env-vars-file=*' })[0]
            $arquivo = $arg.Substring(16)
            $script:arquivos += $arquivo
            $vars = Get-Content -LiteralPath $arquivo -Raw | ConvertFrom-Json
            if ($a.Id -eq 'deploy-Front') { Exigir ($vars.FRONT_TRUSTED_PROXY_CIDRS -ceq '192.0.2.0/24,2001:db8::/32') }
        }
        & $fake $a
    }
    [void](Invoke-S26Plano $deploy -Executar -PeloLider -AprovacaoMaestro $ctx.Execucao -Executor $fakeDeploy)
    foreach ($f in $script:arquivos) { Exigir (-not (Test-Path -LiteralPath $f)) }
    $ids = @($script:chamadas | ForEach-Object { $_.Id })
    Exigir ($ids[-1] -eq 'publicar-somente-front')
    Exigir (@($ids | Where-Object { $_ -eq 'conferir-url-publicada' }).Count -eq 3)
}
Caso 'URL divergente bloqueia publicacao' {
    Preparar-Owned $deploy
    $script:chamadas.Clear()
    $fakeUrl = { param($a)
        if ($a.Id -eq 'conferir-url-publicada') { return '{"status":{"url":"https://outra.test"}}' }
        & $fake $a
    }
    Recusa { Invoke-S26Plano $deploy -Executar -PeloLider -AprovacaoMaestro $ctx.Execucao -Executor $fakeUrl } 'status.url'
    Exigir (-not @($script:chamadas | Where-Object Id -eq 'publicar-somente-front').Count)
}
Caso 'sem peers/bootstrap ou com latest recusa planejamento' {
    Recusa { New-S26PlanoDeploy -Entradas $entradas -VersoesSegredos $versoes -NumeroProjeto '123456789012' }
    $ruins = $versoes.Clone(); $ruins['solar-gemini-api-key']='latest'
    Recusa { New-S26PlanoDeploy -Entradas $entradas -VersoesSegredos $ruins -NumeroProjeto '123456789012' -BootstrapPeersComprovado }
}
Caso 'teardown nao remove APIs/projeto e ausencia nao aciona delete' {
    $script:inventario=@{}; $script:chamadas.Clear()
    [void](Invoke-S26Plano $desmontar -Executar -PeloLider -AprovacaoMaestro $ctx.Execucao -Executor $fake)
    Exigir (-not @($script:chamadas | Where-Object Id -like 'excluir-*').Count)
    Exigir (-not @($desmontar.Acoes | Where-Object { $_.Argumentos[0] -eq 'services' }).Count)
}
Caso 'teardown owned executa nomes exatos e recusa alheios' {
    Preparar-Owned $desmontar
    $script:chamadas.Clear()
    [void](Invoke-S26Plano $desmontar -Executar -PeloLider -AprovacaoMaestro $ctx.Execucao -Executor $fake)
    Exigir (@($script:chamadas | Where-Object Id -eq 'excluir-sql-owned').Count -eq 1)
    $script:inventario['Registro'][0].labels=@{}
    $script:chamadas.Clear()
    Recusa { Invoke-S26Plano $desmontar -Executar -PeloLider -AprovacaoMaestro $ctx.Execucao -Executor $fake }
    Exigir (-not @($script:chamadas | Where-Object Id -like 'excluir-*').Count)
}
Write-Output ('PASSOU: ' + $script:total + ' testes locais de planos/executor FAKE; zero nuvem.')
