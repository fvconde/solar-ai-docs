. (Join-Path $PSScriptRoot 'Operacoes.ps1')

function Add-S26Preflight($Plano) {
    $Plano.Verificacoes += @([ordered]@{Tipo='Projeto'}, [ordered]@{Tipo='Apis'})
}
function Add-S26RecursosBase($Plano, [string]$Modo) {
    $c = $Plano.Contexto
    $Plano.Recursos += New-S26Recurso 'Registro' $c.Registro $Modo
    $Plano.Recursos += New-S26Recurso 'Sql' $c.Instancia $Modo
    foreach ($servico in $c.Contas.Keys) {
        $Plano.Recursos += New-S26Recurso 'Conta' (Get-S26EmailConta $c $servico) $Modo
    }
    foreach ($segredo in ($c.SegredosApi + $c.SegredosAgente)) {
        $Plano.Recursos += New-S26Recurso 'Segredo' $segredo $Modo
    }
}
function New-S26PlanoProvisionar {
    param([ValidateSet('Apis','Recursos')][string]$Etapa='Recursos')
    $p = New-S26Plano ('Provisionar-' + $Etapa)
    $c = $p.Contexto
    $p.Verificacoes += [ordered]@{Tipo='Projeto'}
    if ($Etapa -eq 'Apis') {
        $p.Acoes += New-S26Gcloud $c 'habilitar-apis' @('services','enable',
            'run.googleapis.com','artifactregistry.googleapis.com','sqladmin.googleapis.com',
            'secretmanager.googleapis.com','iam.googleapis.com')
        return $p
    }
    $p.Verificacoes += [ordered]@{Tipo='Apis'}
    Add-S26RecursosBase $p 'Absent'
    # Cloud Run pode ja existir: qualquer colisao aqui tambem impede provisionar.
    foreach ($nome in @('solar-api','solar-agente','solar-front')) {
        $p.Recursos += New-S26Recurso 'Run' $nome 'Absent'
    }
    $p.Acoes += New-S26Gcloud $c 'criar-registro' @('artifacts','repositories','create',$c.Registro,
        ('--location=' + $c.Regiao),'--repository-format=docker','--immutable-tags',('--labels=' + $c.Marca))
    # REST aplica ownership atomicamente; gcloud sql instances create nao expoe labels.
    $p.Acoes += New-S26Rest 'criar-sql' 'POST' ('https://sqladmin.googleapis.com/v1/projects/' + $c.Projeto + '/instances') ([ordered]@{
        name=$c.Instancia; region=$c.Regiao; databaseVersion='POSTGRES_16'
        settings=[ordered]@{
            tier='db-f1-micro'; edition='ENTERPRISE'; availabilityType='ZONAL'
            dataDiskType='PD_SSD'; dataDiskSizeGb='10'; storageAutoResize=$false
            userLabels=@{'s26-execucao'=$c.Execucao}
            ipConfiguration=@{ipv4Enabled=$true; authorizedNetworks=@()}
            connectorEnforcement='REQUIRED'
            backupConfiguration=@{enabled=$true; startTime='03:00'; location=$c.Regiao}
            deletionProtectionEnabled=$true
        }
    })
    $p.Acoes += New-S26Gcloud $c 'criar-banco' @('sql','databases','create',$c.Banco,('--instance=' + $c.Instancia))
    foreach ($servico in $c.Contas.Keys) {
        $p.Acoes += New-S26Gcloud $c ('criar-sa-' + $servico) @('iam','service-accounts','create',
            $c.Contas[$servico], ('--description=' + $c.Marca))
    }
    foreach ($segredo in ($c.SegredosApi + $c.SegredosAgente)) {
        $p.Acoes += New-S26Gcloud $c ('criar-' + $segredo) @('secrets','create',$segredo,
            '--replication-policy=user-managed',('--locations=' + $c.Regiao),('--labels=' + $c.Marca))
    }
    $p.Acoes += New-S26Gcloud $c 'api-cloudsql-client' @('projects','add-iam-policy-binding',$c.Projeto,
        ('--member=serviceAccount:' + (Get-S26EmailConta $c 'Api')),'--role=roles/cloudsql.client','--condition=None')
    foreach ($servico in @('Api','Agente')) {
        $segredos = if ($servico -eq 'Api') { $c.SegredosApi } else { $c.SegredosAgente }
        foreach ($segredo in $segredos) {
            $p.Acoes += New-S26Gcloud $c ('acesso-' + $segredo) @('secrets','add-iam-policy-binding',$segredo,
                ('--member=serviceAccount:' + (Get-S26EmailConta $c $servico)),
                '--role=roles/secretmanager.secretAccessor','--condition=None')
        }
    }
    return $p
}
function Assert-S26Shas([Collections.IDictionary]$Shas) {
    if ($null -eq $Shas -or $Shas.Count -ne 3) { throw 'Forneca os tres SHAs completos: Api, Agente e Front.' }
    foreach ($servico in @('Api','Agente','Front')) {
        if ([string]$Shas[$servico] -cnotmatch '\A[0-9a-f]{40}\z') { throw 'SHA completo minusculo invalido.' }
    }
}
function Get-S26Imagem($Contexto, [string]$Servico, [string]$Sha) {
    return $Contexto.Regiao + '-docker.pkg.dev/' + $Contexto.Projeto + '/' +
        $Contexto.Registro + '/solar-' + $Servico.ToLowerInvariant() + ':' + $Sha
}
function New-S26PlanoImagens {
    param([Collections.IDictionary]$Shas)
    Assert-S26Shas $Shas
    $p = New-S26Plano 'Build-Push'
    $c = $p.Contexto
    Add-S26Preflight $p
    $p.Recursos += New-S26Recurso 'Registro' $c.Registro 'Owned'
    foreach ($servico in @('Api','Agente','Front')) {
        $pasta = switch ($servico) { 'Api' {'solar-ai-api'} 'Agente' {'solar-ai'} 'Front' {'solar-ai-front'} }
        $p.Verificacoes += [ordered]@{ Tipo='Git'; Repositorio=($c.Raiz + '/' + $pasta); Sha=$Shas[$servico] }
    }
    $p.Acoes += New-S26Gcloud $c 'credencial-docker-local' @(
        'auth','configure-docker',($c.Regiao + '-docker.pkg.dev'))
    foreach ($v in @($p.Verificacoes | Where-Object { $_.Tipo -eq 'Git' })) {
        $servico = switch (($v.Repositorio -split '/')[-1]) { 'solar-ai-api' {'Api'} 'solar-ai' {'Agente'} 'solar-ai-front' {'Front'} }
        $imagem = Get-S26Imagem $c $servico $v.Sha
        $p.Acoes += New-S26Comando ('build-' + $servico) 'docker' @('build','--platform=linux/amd64','-t',$imagem,$v.Repositorio)
        $p.Acoes += New-S26Comando ('push-' + $servico) 'docker' @('push',$imagem)
    }
    return $p
}
function New-S26PlanoDeploy {
    param([hashtable]$Entradas, [Collections.IDictionary]$VersoesSegredos,
          [string]$NumeroProjeto, [switch]$BootstrapPeersComprovado,
          [switch]$LiberarFrontPublico)
    if (-not $BootstrapPeersComprovado) { throw 'Bootstrap privado e prova de peers exigem gate do lider/Maestro.' }
    if ($NumeroProjeto -cnotmatch '\A[1-9][0-9]{5,19}\z') { throw 'Numero do projeto real e obrigatorio.' }
    if ($null -eq $Entradas) { throw 'Entradas reais de configuracao ausentes.' }
    $config = New-S26ConfiguracaoProducao @Entradas
    $p = New-S26Plano 'Deploy'
    $c = $p.Contexto
    Add-S26Preflight $p
    Add-S26RecursosBase $p 'Owned'
    $p.Verificacoes += [ordered]@{Tipo='NumeroProjeto'; Numero=$NumeroProjeto}
    $p.Verificacoes += [ordered]@{Tipo='Iam'}
    $p.VerificacoesFinais = @()
    $todosSegredos = @($c.SegredosApi + $c.SegredosAgente)
    if ($null -eq $VersoesSegredos -or $VersoesSegredos.Count -ne $todosSegredos.Count) {
        throw 'Forneca versoes numericas explicitas dos sete segredos.'
    }
    foreach ($nome in $todosSegredos) {
        if ([string]$VersoesSegredos[$nome] -cnotmatch '\A[1-9][0-9]*\z') { throw 'Versao explicita ausente/invalida; latest nao e aceito.' }
    }
    foreach ($servico in @('Agente','Api','Front')) {
        $s = $config.Servicos[$servico]
        $urlEsperada = 'https://' + $s.Nome + '-' + $NumeroProjeto + '.' + $c.Regiao + '.run.app'
        if (($s.Nome.Length + 1 + $NumeroProjeto.Length) -gt 63) { throw 'Segmento DNS excede 63 caracteres.' }
        $urlEntrada = ConvertTo-S26OrigemHttps $Entradas[('Url' + $servico)]
        if ($urlEntrada -cne $urlEsperada) { throw 'URL deve corresponder ao numero real do projeto e nome do servico.' }
        $p.Recursos += New-S26Recurso 'Run' $s.Nome 'OwnedOrAbsent'
        $sha = $s.Variaveis.SOLAR_VERSION
        $argumentos = @('run','deploy',$s.Nome,('--region=' + $c.Regiao),
            ('--image=' + (Get-S26Imagem $c $servico $sha)),
            ('--service-account=' + (Get-S26EmailConta $c $servico)),
            ('--port=' + $s.Porta),'--cpu=1','--memory=512Mi','--max-instances=1',
            '--no-allow-unauthenticated','--invoker-iam-check',('--labels=' + $c.Marca))
        if ($servico -eq 'Api') {
            $argumentos += @('--no-cpu-throttling','--min-instances=1',
                ('--set-cloudsql-instances=' + $c.Projeto + ':' + $c.Regiao + ':' + $c.Instancia))
        } else { $argumentos += @('--cpu-throttling','--min-instances=0') }
        if ($s.Segredos.Count) {
            $refs = @($s.Segredos.Keys | ForEach-Object {
                $_ + '=' + $s.Segredos[$_] + ':' + $VersoesSegredos[$s.Segredos[$_]]
            })
            $argumentos += '--set-secrets=' + ($refs -join ',')
        } else { $argumentos += '--clear-secrets' }
        $acao = New-S26Gcloud $c ('deploy-' + $servico) $argumentos
        $acao.Ambiente = $s.Variaveis
        $p.Acoes += $acao
        $p.VerificacoesFinais += [ordered]@{Tipo='UrlPublicada'; Servico=$s.Nome; Url=$urlEntrada}
    }
    foreach ($par in @(@('solar-api','Front'), @('solar-agente','Api'))) {
        $p.Acoes += New-S26Gcloud $c ('invoker-' + $par[0]) @('run','services','add-iam-policy-binding',
            $par[0],('--region=' + $c.Regiao),'--role=roles/run.invoker',
            ('--member=serviceAccount:' + (Get-S26EmailConta $c $par[1])),'--condition=None')
    }
    # Publicacao e separada e acontece APOS conferir todas as URLs.
    if ($LiberarFrontPublico) {
        $p.PublicarDepoisDeVerificar = New-S26Gcloud $c 'publicar-somente-front' @(
            'run','services','add-iam-policy-binding','solar-front',('--region=' + $c.Regiao),
            '--member=allUsers','--role=roles/run.invoker','--condition=None')
    }
    return $p
}
function New-S26PlanoDesmontar {
    param([string]$Confirmacao)
    $p = New-S26Plano 'Desmontar'
    $c = $p.Contexto
    if ($Confirmacao -cne ('EXCLUIR-' + $c.Execucao)) { throw 'Confirmacao de exclusao exata obrigatoria, inclusive para revisar plano.' }
    Add-S26Preflight $p
    Add-S26RecursosBase $p 'OwnedOrAbsent'
    foreach ($nome in @('solar-front','solar-api','solar-agente')) {
        $p.Recursos += New-S26Recurso 'Run' $nome 'OwnedOrAbsent'
        $a = New-S26Gcloud $c ('excluir-' + $nome) @('run','services','delete',$nome,('--region=' + $c.Regiao))
        $a.SomenteSeExiste = $nome; $p.Acoes += $a
    }
    $a = New-S26Gcloud $c 'desproteger-sql-owned' @('sql','instances','patch',$c.Instancia,'--no-deletion-protection')
    $a.SomenteSeExiste = $c.Instancia; $p.Acoes += $a
    $a = New-S26Gcloud $c 'excluir-sql-owned' @('sql','instances','delete',$c.Instancia)
    $a.SomenteSeExiste = $c.Instancia; $p.Acoes += $a
    foreach ($segredo in ($c.SegredosApi + $c.SegredosAgente)) {
        $a = New-S26Gcloud $c ('excluir-' + $segredo) @('secrets','delete',$segredo)
        $a.SomenteSeExiste = $segredo; $p.Acoes += $a
    }
    $a = New-S26Gcloud $c 'excluir-registro-owned' @('artifacts','repositories','delete',$c.Registro,('--location=' + $c.Regiao))
    $a.SomenteSeExiste = $c.Registro; $p.Acoes += $a
    $emailApi = Get-S26EmailConta $c 'Api'
    $a = New-S26Gcloud $c 'remover-binding-cloudsql-owned' @('projects','remove-iam-policy-binding',$c.Projeto,
        ('--member=serviceAccount:' + $emailApi),'--role=roles/cloudsql.client','--condition=None')
    $a.SomenteSeExiste = $emailApi; $p.Acoes += $a
    foreach ($servico in $c.Contas.Keys) {
        $email = Get-S26EmailConta $c $servico
        $a = New-S26Gcloud $c ('excluir-sa-' + $servico) @('iam','service-accounts','delete',$email)
        $a.SomenteSeExiste = $email; $p.Acoes += $a
    }
    return $p
}
