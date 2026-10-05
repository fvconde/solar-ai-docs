<#
.SYNOPSIS
    Script de preparo de infraestrutura para Workload Identity Federation (WIF) do S-27.
.DESCRIPTION
    Cria pool, provedor OIDC dedicado para o GitHub Actions e conta de servico de deploy
    com privilegios minimos para publicacao continua no Cloud Run.
    Por padrao, opera em modo plano puro (dry-run) sem invocar o Google Cloud.
    Requer -Executar explicito e -NumeroProjeto para aplicar as alteracoes.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][string]$NumeroProjeto,
    [switch]$Executar,
    [scriptblock]$Executor
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot '../S-26/Operacoes.ps1')

function New-S27Contexto {
    $c26 = New-S26Contexto
    $execucao = 'df312134-114c-4742-80c3-01ac29034216'
    $sufixo = 'df312134'
    $saPipelineNome = 's27-pipeline-' + $sufixo
    $emailPipeline = $saPipelineNome + '@' + $c26.Projeto + '.iam.gserviceaccount.com'
    $poolId = 'solar-s27-' + $sufixo
    $providerId = 'github-' + $sufixo

    return [ordered]@{
        Execucao = $execucao
        Sufixo = $sufixo
        Projeto = $c26.Projeto
        Regiao = $c26.Regiao
        Gcloud = $c26.Gcloud
        Registro = $c26.Registro
        ServicoApi = 'solar-api'
        ContaApi = Get-S26EmailConta $c26 'Api'
        ContaPipeline = $saPipelineNome
        EmailPipeline = $emailPipeline
        PoolId = $poolId
        ProviderId = $providerId
        Marca = ('s27-execucao=' + $execucao)
        RepositorioGit = 'fvconde/solar-ai-api'
        BranchAlvo = 'refs/heads/main'
        CondicaoWif = "assertion.repository == 'fvconde/solar-ai-api' && assertion.ref == 'refs/heads/main'"
    }
}

function Get-S27ComandosGitHub($Contexto, [string]$NumeroProjeto) {
    $num = if ([string]::IsNullOrWhiteSpace($NumeroProjeto)) { '<NUMERO_DO_PROJETO>' } else { $NumeroProjeto }
    $provider = 'projects/' + $num + '/locations/global/workloadIdentityPools/' + $Contexto.PoolId + '/providers/' + $Contexto.ProviderId
    $repo = $Contexto.RepositorioGit
    return @(
        ('gh variable set GCP_PROJECT_ID --repo ' + $repo + ' --body "' + $Contexto.Projeto + '"'),
        ('gh variable set GCP_REGION --repo ' + $repo + ' --body "' + $Contexto.Regiao + '"'),
        ('gh variable set GCP_ARTIFACT_REGISTRY --repo ' + $repo + ' --body "' + $Contexto.Registro + '"'),
        ('gh variable set GCP_WORKLOAD_IDENTITY_PROVIDER --repo ' + $repo + ' --body "' + $provider + '"'),
        ('gh variable set GCP_DEPLOY_SERVICE_ACCOUNT --repo ' + $repo + ' --body "' + $Contexto.EmailPipeline + '"')
    )
}

function New-S27PlanoPreparoWif([string]$NumeroProjeto = '') {
    $c = New-S27Contexto
    $num = if ([string]::IsNullOrWhiteSpace($NumeroProjeto)) { '<NUMERO_DO_PROJETO>' } else { $NumeroProjeto }
    $principalSet = 'principalSet://iam.googleapis.com/projects/' + $num + '/locations/global/workloadIdentityPools/' + $c.PoolId + '/attribute.repository/' + $c.RepositorioGit

    $acoes = @(
        (New-S26Gcloud $c 'criar-pool' @(
            'iam','workload-identity-pools','create',$c.PoolId,
            '--location=global',
            '--display-name=Solar API Pipeline Pool S-27',
            ('--description=' + $c.Marca)
        )),
        (New-S26Gcloud $c 'criar-provider' @(
            'iam','workload-identity-pools','providers','create-oidc',$c.ProviderId,
            ('--workload-identity-pool=' + $c.PoolId),
            '--location=global',
            '--issuer-uri=https://token.actions.githubusercontent.com',
            '--attribute-mapping=google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.ref=assertion.ref',
            ('--attribute-condition=' + $c.CondicaoWif)
        )),
        (New-S26Gcloud $c 'criar-sa-pipeline' @(
            'iam','service-accounts','create',$c.ContaPipeline,
            '--display-name=Solar API Pipeline S-27',
            ('--description=' + $c.Marca)
        )),
        (New-S26Gcloud $c 'binding-workload-identity' @(
            'iam','service-accounts','add-iam-policy-binding',$c.EmailPipeline,
            '--role=roles/iam.workloadIdentityUser',
            ('--member=' + $principalSet)
        )),
        (New-S26Gcloud $c 'binding-artifact-registry' @(
            'artifacts','repositories','add-iam-policy-binding',$c.Registro,
            ('--location=' + $c.Regiao),
            '--role=roles/artifactregistry.writer',
            ('--member=serviceAccount:' + $c.EmailPipeline)
        )),
        (New-S26Gcloud $c 'binding-run-developer' @(
            'run','services','add-iam-policy-binding',$c.ServicoApi,
            ('--region=' + $c.Regiao),
            '--role=roles/run.developer',
            ('--member=serviceAccount:' + $c.EmailPipeline)
        )),
        (New-S26Gcloud $c 'binding-sa-user' @(
            'iam','service-accounts','add-iam-policy-binding',$c.ContaApi,
            '--role=roles/iam.serviceAccountUser',
            ('--member=serviceAccount:' + $c.EmailPipeline)
        ))
    )

    return [ordered]@{
        Nome = 'Preparo-WIF-S27'
        Contexto = $c
        NumeroProjeto = $num
        Acoes = $acoes
        ComandosGitHub = Get-S27ComandosGitHub $c $num
    }
}

function Get-S27InventarioJson($Contexto, [string]$Id, [string[]]$Argumentos, [scriptblock]$Executor) {
    $raw = Invoke-S26Transporte (New-S26Gcloud $Contexto $Id $Argumentos) $Executor
    if ([string]::IsNullOrWhiteSpace($raw) -or -not $raw.TrimStart().StartsWith('[')) {
        throw "Inventario '$Id' vazio ou indeterminado; nao presumir ausencia."
    }
    if ($raw.Trim() -eq '[]') {
        return @()
    }
    try {
        $dados = ConvertFrom-Json -InputObject $raw
    } catch {
        throw "Falha ao decodificar JSON do inventario '$Id': $($_.Exception.Message)"
    }
    if ($null -eq $dados) {
        throw "Inventario '$Id' nulo; nao presumir ausencia."
    }
    return @($dados)
}

function Invoke-S27Preflight($Contexto, [string]$NumeroProjeto, [scriptblock]$Executor) {
    if ([string]::IsNullOrWhiteSpace($NumeroProjeto) -or $NumeroProjeto -notmatch '^\d{10,14}$') {
        throw 'NumeroProjeto obrigatorio e deve conter entre 10 e 14 digitos numericos para compor WIF.'
    }

    # 1. Conferir projeto e projectNumber
    $rawProj = Invoke-S26Transporte (New-S26Gcloud $Contexto 'preflight-numero-projeto' @('projects','describe',$Contexto.Projeto,'--format=json')) $Executor
    if ([string]::IsNullOrWhiteSpace($rawProj) -or -not $rawProj.TrimStart().StartsWith('{')) {
        throw 'Falha ao consultar projeto no Google Cloud ou JSON invalido.'
    }
    try {
        $proj = ConvertFrom-Json -InputObject $rawProj
    } catch {
        throw "JSON invalido ao consultar projeto: $($_.Exception.Message)"
    }
    if ([string]$proj.projectNumber -cne $NumeroProjeto) {
        throw "Numero real do projeto ($($proj.projectNumber)) diverge do NumeroProjeto fornecido ($NumeroProjeto)."
    }

    # 2. Conferir APIs ativas (incluindo sts.googleapis.com)
    $apisAtivasBrutas = Get-S27InventarioJson $Contexto 'preflight-apis' @('services','list','--enabled','--format=json') $Executor
    $apisAtivas = @($apisAtivasBrutas | ForEach-Object {
        if ($_.config -and $_.config.name) { $_.config.name } else { $_.name }
    })
    $obrigatorias = @(
        'iam.googleapis.com',
        'iamcredentials.googleapis.com',
        'cloudresourcemanager.googleapis.com',
        'artifactregistry.googleapis.com',
        'run.googleapis.com',
        'sts.googleapis.com'
    )
    foreach ($api in $obrigatorias) {
        $encontrada = $apisAtivas | Where-Object { $_ -like "*$api*" }
        if (-not $encontrada) {
            throw "API obrigatoria '$api' nao esta habilitada no projeto '$($Contexto.Projeto)'."
        }
    }

    # 3. Conferir pre-requisitos do S-26 via inventarios list
    $registros = Get-S27InventarioJson $Contexto 'preflight-check-registro' @('artifacts','repositories','list',('--location=' + $Contexto.Regiao),'--format=json') $Executor
    $regEncontrado = $registros | Where-Object {
        $n = if ($_.name) { [string]$_.name } else { '' }
        $n -eq $Contexto.Registro -or $n.EndsWith('/' + $Contexto.Registro)
    }
    if (-not $regEncontrado) {
        throw "Pre-requisito ausente: Artifact Registry '$($Contexto.Registro)' do S-26 nao encontrado."
    }

    $servicosRun = Get-S27InventarioJson $Contexto 'preflight-check-run' @('run','services','list',('--region=' + $Contexto.Regiao),'--format=json') $Executor
    $runEncontrado = $servicosRun | Where-Object {
        $n = if ($_.metadata -and $_.metadata.name) { [string]$_.metadata.name } elseif ($_.name) { [string]$_.name } else { '' }
        $n -eq $Contexto.ServicoApi -or $n.EndsWith('/' + $Contexto.ServicoApi)
    }
    if (-not $runEncontrado) {
        throw "Pre-requisito ausente: Cloud Run service '$($Contexto.ServicoApi)' do S-26 nao encontrado."
    }

    # 4. Conferir Service Accounts (API S-26 e Pipeline S-27)
    $contas = Get-S27InventarioJson $Contexto 'preflight-check-sa' @('iam','service-accounts','list','--format=json') $Executor
    $saApiEncontrada = $contas | Where-Object { [string]$_.email -eq $Contexto.ContaApi }
    if (-not $saApiEncontrada) {
        throw "Pre-requisito ausente: Conta de servico da API '$($Contexto.ContaApi)' do S-26 nao encontrada."
    }

    $saPipeEncontrada = $contas | Where-Object { [string]$_.email -eq $Contexto.EmailPipeline }
    $saPipeExiste = $false
    if ($saPipeEncontrada) {
        if ($saPipeEncontrada.disabled -eq $true) {
            throw "Conta de servico do pipeline '$($Contexto.EmailPipeline)' esta desabilitada."
        }
        if ([string]$saPipeEncontrada.description -cne $Contexto.Marca) {
            throw "Conta de servico do pipeline '$($Contexto.EmailPipeline)' ja existe com descricao/ownership divergente."
        }
        $saPipeExiste = $true
    }

    # 5. Conferir Workload Identity Pools
    $pools = Get-S27InventarioJson $Contexto 'preflight-check-pool' @('iam','workload-identity-pools','list','--location=global','--format=json') $Executor
    $poolEncontrado = $pools | Where-Object {
        $n = if ($_.name) { [string]$_.name } else { '' }
        $n.EndsWith('/workloadIdentityPools/' + $Contexto.PoolId) -or $n -eq $Contexto.PoolId
    }
    $poolExiste = $false
    if ($poolEncontrado) {
        if ([string]$poolEncontrado.state -cne 'ACTIVE') {
            throw "Workload Identity Pool '$($Contexto.PoolId)' existe com estado incompativel ($($poolEncontrado.state))."
        }
        if ([string]$poolEncontrado.description -cne $Contexto.Marca) {
            throw "Workload Identity Pool '$($Contexto.PoolId)' ja existe com ownership divergente."
        }
        $poolExiste = $true
    }

    # 6. Conferir Workload Identity Providers (apenas se pool existe)
    $providerExiste = $false
    if ($poolExiste) {
        $providers = Get-S27InventarioJson $Contexto 'preflight-check-provider' @('iam','workload-identity-pools','providers','list',('--workload-identity-pool=' + $Contexto.PoolId),'--location=global','--format=json') $Executor

        foreach ($prov in $providers) {
            $pName = if ($prov.name) { [string]$prov.name } else { '' }
            if (-not ($pName.EndsWith('/providers/' + $Contexto.ProviderId) -or $pName -eq $Contexto.ProviderId)) {
                throw "Workload Identity Pool '$($Contexto.PoolId)' contem provedor terceiro inesperado: '$pName'."
            }
        }

        $provEncontrado = $providers | Where-Object {
            $n = if ($_.name) { [string]$_.name } else { '' }
            $n.EndsWith('/providers/' + $Contexto.ProviderId) -or $n -eq $Contexto.ProviderId
        }

        if ($provEncontrado) {
            if ([string]$provEncontrado.state -cne 'ACTIVE') {
                throw "Provedor WIF '$($Contexto.ProviderId)' existe com estado incompativel ($($provEncontrado.state))."
            }
            if ([string]$provEncontrado.issuerUri -cne 'https://token.actions.githubusercontent.com') {
                throw "Provedor WIF '$($Contexto.ProviderId)' possui issuerUri divergente ($($provEncontrado.issuerUri))."
            }
            if ([string]$provEncontrado.attributeCondition -cne $Contexto.CondicaoWif) {
                throw "Provedor WIF '$($Contexto.ProviderId)' ja existe com attributeCondition divergente da obrigatoria."
            }

            $mapping = $provEncontrado.attributeMapping
            $temSubject = $false
            $temRepo = $false
            $temRef = $false
            if ($mapping) {
                if ($mapping -is [Collections.IDictionary]) {
                    $temSubject = ($mapping['google.subject'] -eq 'assertion.sub')
                    $temRepo = ($mapping['attribute.repository'] -eq 'assertion.repository')
                    $temRef = ($mapping['attribute.ref'] -eq 'assertion.ref')
                } else {
                    $temSubject = ($mapping.'google.subject' -eq 'assertion.sub')
                    $temRepo = ($mapping.'attribute.repository' -eq 'assertion.repository')
                    $temRef = ($mapping.'attribute.ref' -eq 'assertion.ref')
                }
            }
            if (-not ($temSubject -and $temRepo -and $temRef)) {
                throw "Provedor WIF '$($Contexto.ProviderId)' possui attributeMapping incompleto ou divergente."
            }
            $providerExiste = $true
        }
    }

    return [ordered]@{
        PoolExiste = $poolExiste
        ProviderExiste = $providerExiste
        SaPipeExiste = $saPipeExiste
    }
}

function Invoke-S27PlanoPreparoWif($Plano, [switch]$Executar, [string]$NumeroProjeto, [scriptblock]$Executor) {
    if (-not $Executar) {
        return $Plano
    }

    $estado = Invoke-S27Preflight $Plano.Contexto $NumeroProjeto $Executor

    foreach ($acao in $Plano.Acoes) {
        if ($acao.Id -eq 'criar-pool' -and $estado.PoolExiste) {
            continue
        }
        if ($acao.Id -eq 'criar-provider' -and $estado.ProviderExiste) {
            continue
        }
        if ($acao.Id -eq 'criar-sa-pipeline' -and $estado.SaPipeExiste) {
            continue
        }
        [void](Invoke-S26Transporte $acao $Executor)
    }

    return $Plano
}

if ($MyInvocation.InvocationName -eq '.') {
    return
}

$plano = New-S27PlanoPreparoWif -NumeroProjeto $NumeroProjeto
if (-not $Executar) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " PLANO DE PREPARO WIF S-27 (MODO SECO / SOMENTE LEITURA)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "Projeto Google Cloud : $($plano.Contexto.Projeto)"
    Write-Host "Regiao               : $($plano.Contexto.Regiao)"
    Write-Host "Numero do Projeto    : $($plano.NumeroProjeto)"
    Write-Host "Pool WIF             : $($plano.Contexto.PoolId)"
    Write-Host "Provedor OIDC        : $($plano.Contexto.ProviderId)"
    Write-Host "Conta de Servico     : $($plano.Contexto.EmailPipeline)"
    Write-Host "Condicao WIF         : $($plano.Contexto.CondicaoWif)"
    Write-Host ""
    Write-Host "Acoes planejadas ($($plano.Acoes.Count)):" -ForegroundColor Yellow
    foreach ($a in $plano.Acoes) {
        Write-Host "  [$($a.Id)] gcloud $($a.Argumentos -join ' ')"
    }
    Write-Host ""
    Write-Host "Comandos gh variable set para configuracao manual no GitHub:" -ForegroundColor Yellow
    foreach ($cmd in $plano.ComandosGitHub) {
        Write-Host "  $cmd"
    }
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return $plano
}

$resultado = Invoke-S27PlanoPreparoWif $plano -Executar:$Executar -NumeroProjeto $NumeroProjeto -Executor $Executor

Write-Host "==========================================================================" -ForegroundColor Green
Write-Host " PREPARO WIF S-27 CONCLUIDO COM SUCESSO" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Green
Write-Host "Execute os comandos abaixo para configurar as GitHub Variables no repositorio fvconde/solar-ai-api:" -ForegroundColor Yellow
Write-Host ""
foreach ($cmd in $resultado.ComandosGitHub) {
    Write-Host "  $cmd"
}
Write-Host ""
return $resultado
