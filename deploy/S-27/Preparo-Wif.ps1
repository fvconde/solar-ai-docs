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
    return @(
        ('gh variable set GCP_PROJECT_ID --body "' + $Contexto.Projeto + '"'),
        ('gh variable set GCP_REGION --body "' + $Contexto.Regiao + '"'),
        ('gh variable set GCP_ARTIFACT_REGISTRY --body "' + $Contexto.Registro + '"'),
        ('gh variable set GCP_WORKLOAD_IDENTITY_PROVIDER --body "' + $provider + '"'),
        ('gh variable set GCP_DEPLOY_SERVICE_ACCOUNT --body "' + $Contexto.EmailPipeline + '"')
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

function Invoke-S27Preflight($Contexto, [string]$NumeroProjeto, [scriptblock]$Executor) {
    if ([string]::IsNullOrWhiteSpace($NumeroProjeto) -or $NumeroProjeto -notmatch '^\d{10,14}$') {
        throw 'NumeroProjeto obrigatorio e deve conter entre 10 e 14 digitos numericos para compor WIF.'
    }

    # 1. Conferir projeto e projectNumber
    $rawProj = Invoke-S26Transporte (New-S26Gcloud $Contexto 'preflight-numero-projeto' @('projects','describe',$Contexto.Projeto,'--format=json')) $Executor
    if ([string]::IsNullOrWhiteSpace($rawProj)) { throw 'Falha ao consultar projeto no Google Cloud.' }
    $proj = $rawProj | ConvertFrom-Json
    if ([string]$proj.projectNumber -cne $NumeroProjeto) {
        throw "Numero real do projeto ($($proj.projectNumber)) diverge do NumeroProjeto fornecido ($NumeroProjeto)."
    }

    # 2. Conferir APIs ativas
    $rawApis = Invoke-S26Transporte (New-S26Gcloud $Contexto 'preflight-apis' @('services','list','--enabled','--format=json')) $Executor
    if ([string]::IsNullOrWhiteSpace($rawApis)) { throw 'Falha ao consultar APIs ativas no Google Cloud.' }
    $apisAtivas = @(($rawApis | ConvertFrom-Json) | ForEach-Object {
        if ($_.config -and $_.config.name) { $_.config.name } else { $_.name }
    })
    $obrigatorias = @('iam.googleapis.com', 'iamcredentials.googleapis.com', 'cloudresourcemanager.googleapis.com', 'artifactregistry.googleapis.com', 'run.googleapis.com')
    foreach ($api in $obrigatorias) {
        $encontrada = $apisAtivas | Where-Object { $_ -like "*$api*" }
        if (-not $encontrada) {
            throw "API obrigatoria '$api' nao esta habilitada no projeto '$($Contexto.Projeto)'."
        }
    }

    # 3. Conferir pre-requisitos do S-26 (falha fechada se ausente)
    try {
        $rawReg = Invoke-S26Transporte (New-S26Gcloud $Contexto 'preflight-check-registro' @('artifacts','repositories','describe',$Contexto.Registro,('--location=' + $Contexto.Regiao),'--format=json')) $Executor
        if ([string]::IsNullOrWhiteSpace($rawReg)) { throw 'Registro nao encontrado.' }
    } catch {
        throw "Pre-requisito ausente: Artifact Registry '$($Contexto.Registro)' do S-26 nao encontrado."
    }

    try {
        $rawRun = Invoke-S26Transporte (New-S26Gcloud $Contexto 'preflight-check-run' @('run','services','describe',$Contexto.ServicoApi,('--region=' + $Contexto.Regiao),'--format=json')) $Executor
        if ([string]::IsNullOrWhiteSpace($rawRun)) { throw 'Servico Run nao encontrado.' }
    } catch {
        throw "Pre-requisito ausente: Cloud Run service '$($Contexto.ServicoApi)' do S-26 nao encontrado."
    }

    try {
        $rawSaApi = Invoke-S26Transporte (New-S26Gcloud $Contexto 'preflight-check-sa-api' @('iam','service-accounts','describe',$Contexto.ContaApi,'--format=json')) $Executor
        if ([string]::IsNullOrWhiteSpace($rawSaApi)) { throw 'Conta API nao encontrada.' }
    } catch {
        throw "Pre-requisito ausente: Conta de servico da API '$($Contexto.ContaApi)' do S-26 nao encontrada."
    }

    # 4. Conferir recursos S-27 se ja existem (rejeitar divergencias)
    try {
        $rawPool = Invoke-S26Transporte (New-S26Gcloud $Contexto 'preflight-check-pool' @('iam','workload-identity-pools','describe',$Contexto.PoolId,'--location=global','--format=json')) $Executor
        if (-not [string]::IsNullOrWhiteSpace($rawPool) -and $rawPool.Trim().StartsWith('{')) {
            $poolObj = $rawPool | ConvertFrom-Json
            if ($poolObj.description -cne $Contexto.Marca) {
                throw "Workload Identity Pool '$($Contexto.PoolId)' ja existe com ownership divergente."
            }
        }
    } catch {
        if ($_.Exception.Message -like "*ja existe com ownership divergente*") { throw }
    }

    try {
        $rawProv = Invoke-S26Transporte (New-S26Gcloud $Contexto 'preflight-check-provider' @('iam','workload-identity-pools','providers','describe',$Contexto.ProviderId,('--workload-identity-pool=' + $Contexto.PoolId),'--location=global','--format=json')) $Executor
        if (-not [string]::IsNullOrWhiteSpace($rawProv) -and $rawProv.Trim().StartsWith('{')) {
            $provObj = $rawProv | ConvertFrom-Json
            if ($provObj.attributeCondition -cne $Contexto.CondicaoWif) {
                throw "Provedor WIF '$($Contexto.ProviderId)' ja existe com attributeCondition divergente da obrigatoria."
            }
        }
    } catch {
        if ($_.Exception.Message -like "*ja existe com attributeCondition divergente*") { throw }
    }

    try {
        $rawSaPipe = Invoke-S26Transporte (New-S26Gcloud $Contexto 'preflight-check-sa-pipeline' @('iam','service-accounts','describe',$Contexto.EmailPipeline,'--format=json')) $Executor
        if (-not [string]::IsNullOrWhiteSpace($rawSaPipe) -and $rawSaPipe.Trim().StartsWith('{')) {
            $saPipeObj = $rawSaPipe | ConvertFrom-Json
            if ($saPipeObj.description -cne $Contexto.Marca) {
                throw "Conta de servico do pipeline '$($Contexto.EmailPipeline)' ja existe com descricao/ownership divergente."
            }
        }
    } catch {
        if ($_.Exception.Message -like "*ja existe com descricao/ownership divergente*") { throw }
    }
}

function Invoke-S27PlanoPreparoWif($Plano, [switch]$Executar, [string]$NumeroProjeto, [scriptblock]$Executor) {
    if (-not $Executar) {
        return $Plano
    }

    Invoke-S27Preflight $Plano.Contexto $NumeroProjeto $Executor

    foreach ($acao in $Plano.Acoes) {
        [void](Invoke-S26Transporte $acao $Executor)
    }

    return $Plano
}

if ($MyInvocation.InvocationName -eq '.') {
    return
}

$plano = New-S27PlanoPreparoWif -NumeroProjeto $NumeroProjeto
if (-not $Executar) {
    return $plano
}

return (Invoke-S27PlanoPreparoWif $plano -Executar:$Executar -NumeroProjeto $NumeroProjeto -Executor $Executor)
