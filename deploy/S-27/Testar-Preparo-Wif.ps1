$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'Preparo-Wif.ps1')

$script:total = 0
function Exigir([bool]$Condicao, [string]$Mensagem = 'Assercao falhou.') {
    if (-not $Condicao) { throw $Mensagem }
}

function Caso([string]$Nome, [scriptblock]$Teste) {
    try {
        & $Teste
        Write-Host " [PASS] $Nome" -ForegroundColor Green
    } catch {
        Write-Host " [FAIL] $Nome : $($_.Exception.Message)" -ForegroundColor Red
        throw ('Caso ' + $Nome + ': ' + $_.Exception.Message)
    }
    $script:total++
}

function Recusa([scriptblock]$Teste, [string]$Trecho = '') {
    $recusou = $false
    try {
        & $Teste | Out-Null
    } catch {
        $recusou = $true
        if ($Trecho) {
            Exigir ($_.Exception.Message.Contains($Trecho)) ("Mensagem inesperada: " + $_.Exception.Message)
        }
    }
    Exigir $recusou 'Deveria ter recusado a operacao.'
}

$script:chamadas = New-Object 'System.Collections.Generic.List[object]'
$script:falharNoId = $null
$script:projNumeroSimulado = '123456789012'
$script:apisAtivasSimuladas = @('iam.googleapis.com', 'iamcredentials.googleapis.com', 'cloudresourcemanager.googleapis.com', 'artifactregistry.googleapis.com', 'run.googleapis.com')
$script:simularRegistroAusente = $false
$script:simularRunAusente = $false
$script:simularSaApiAusente = $false
$script:simularPoolDivergente = $false
$script:simularProviderDivergente = $false
$script:simularSaPipeDivergente = $false

$fake = {
    param($a)
    $script:chamadas.Add($a)

    if ($null -ne $script:falharNoId -and $a.Id -eq $script:falharNoId) {
        throw "Erro simulado na operacao $($a.Id)"
    }

    switch ($a.Id) {
        'preflight-numero-projeto' {
            return (@{ projectNumber = $script:projNumeroSimulado } | ConvertTo-Json -Compress)
        }
        'preflight-apis' {
            return ConvertTo-Json -InputObject @($script:apisAtivasSimuladas | ForEach-Object {
                @{ config = @{ name = $_ } }
            }) -Depth 5
        }
        'preflight-check-registro' {
            if ($script:simularRegistroAusente) { throw 'NotFound' }
            return '{"name":"solar-s26-3bdd7f92"}'
        }
        'preflight-check-run' {
            if ($script:simularRunAusente) { throw 'NotFound' }
            return '{"metadata":{"name":"solar-api"}}'
        }
        'preflight-check-sa-api' {
            if ($script:simularSaApiAusente) { throw 'NotFound' }
            return '{"email":"s26-api-3bdd7f92@solar-ai-cloud.iam.gserviceaccount.com"}'
        }
        'preflight-check-pool' {
            if ($script:simularPoolDivergente) {
                return '{"name":"solar-s27-df312134","description":"dono-estranho"}'
            }
            throw 'NotFound'
        }
        'preflight-check-provider' {
            if ($script:simularProviderDivergente) {
                return '{"name":"github-df312134","attributeCondition":"condicao-invalida"}'
            }
            throw 'NotFound'
        }
        'preflight-check-sa-pipeline' {
            if ($script:simularSaPipeDivergente) {
                return '{"email":"s27-pipeline-df312134@solar-ai-cloud.iam.gserviceaccount.com","description":"dono-estranho"}'
            }
            throw 'NotFound'
        }
        default {
            return '{}'
        }
    }
}

function Reset-Mocks {
    $script:chamadas.Clear()
    $script:falharNoId = $null
    $script:projNumeroSimulado = '123456789012'
    $script:apisAtivasSimuladas = @('iam.googleapis.com', 'iamcredentials.googleapis.com', 'cloudresourcemanager.googleapis.com', 'artifactregistry.googleapis.com', 'run.googleapis.com')
    $script:simularRegistroAusente = $false
    $script:simularRunAusente = $false
    $script:simularSaApiAusente = $false
    $script:simularPoolDivergente = $false
    $script:simularProviderDivergente = $false
    $script:simularSaPipeDivergente = $false
}

Caso 'Plano padrao nao invoca executor e nao chama gcloud' {
    Reset-Mocks
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    $res = Invoke-S27PlanoPreparoWif $p -NumeroProjeto '123456789012' -Executor $fake
    Exigir ($script:chamadas.Count -eq 0) 'Nenhuma chamada gcloud deve ocorrer sem -Executar.'
    Exigir ($res.Acoes.Count -eq 7) 'Plano deve conter exatamente 7 acoes de mutacao.'
}

Caso 'Condicao WIF no provedor e exata' {
    Reset-Mocks
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    $acaoProv = $p.Acoes | Where-Object Id -eq 'criar-provider'
    Exigir ($null -ne $acaoProv) 'Acao criar-provider deve existir.'
    $condEsperada = "--attribute-condition=assertion.repository == 'fvconde/solar-ai-api' && assertion.ref == 'refs/heads/main'"
    Exigir ($acaoProv.Argumentos -contains $condEsperada) 'Condicao WIF deve exigir repository fvconde/solar-ai-api E ref refs/heads/main.'
    Exigir ($acaoProv.Argumentos -contains '--issuer-uri=https://token.actions.githubusercontent.com') 'Issuer URI deve ser do GitHub Actions.'
}

Caso 'Comandos e argumentos esperados para criacao e bindings' {
    Reset-Mocks
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    $ids = @($p.Acoes | ForEach-Object { $_.Id })
    $esperados = @('criar-pool', 'criar-provider', 'criar-sa-pipeline', 'binding-workload-identity', 'binding-artifact-registry', 'binding-run-developer', 'binding-sa-user')
    Exigir ($ids.Count -eq $esperados.Count) 'Quantidade de acoes difere do esperado.'
    for ($i = 0; $i -lt $ids.Count; $i++) {
        Exigir ($ids[$i] -ceq $esperados[$i]) ("Acao na ordem inesperada: " + $ids[$i] + " vs " + $esperados[$i])
    }
}

Caso 'IAM nos recursos certos com menor privilegio' {
    Reset-Mocks
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    $c = $p.Contexto

    # 1. Workload Identity User no pipeline SA
    $bWif = $p.Acoes | Where-Object Id -eq 'binding-workload-identity'
    Exigir ($bWif.Argumentos -contains $c.EmailPipeline) 'WorkloadIdentityUser deve vincular na SA do pipeline.'
    Exigir ($bWif.Argumentos -contains '--role=roles/iam.workloadIdentityUser') 'Papel deve ser roles/iam.workloadIdentityUser.'
    Exigir ($bWif.Argumentos -contains ('--member=principalSet://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/' + $c.PoolId + '/attribute.repository/' + $c.RepositorioGit)) 'PrincipalSet deve restringir ao repositorio do card.'

    # 2. Artifact Registry writer no registro S26
    $bReg = $p.Acoes | Where-Object Id -eq 'binding-artifact-registry'
    Exigir ($bReg.Argumentos -contains $c.Registro) 'Writer deve apontar para o registro S26.'
    Exigir ($bReg.Argumentos -contains ('--location=' + $c.Regiao)) 'Localizacao deve ser a regiao do registro.'
    Exigir ($bReg.Argumentos -contains '--role=roles/artifactregistry.writer') 'Papel deve ser roles/artifactregistry.writer.'
    Exigir ($bReg.Argumentos -contains ('--member=serviceAccount:' + $c.EmailPipeline)) 'Membro deve ser a SA do pipeline.'

    # 3. run.developer apenas solar-api
    $bRun = $p.Acoes | Where-Object Id -eq 'binding-run-developer'
    Exigir ($bRun.Argumentos -contains $c.ServicoApi) 'Run.developer deve ser restrito ao servico solar-api.'
    Exigir ($bRun.Argumentos -contains ('--region=' + $c.Regiao)) 'Regiao deve ser southamerica-east1.'
    Exigir ($bRun.Argumentos -contains '--role=roles/run.developer') 'Papel deve ser roles/run.developer.'
    Exigir ($bRun.Argumentos -contains ('--member=serviceAccount:' + $c.EmailPipeline)) 'Membro deve ser a SA do pipeline.'

    # 4. serviceAccountUser apenas na SA da API S26
    $bSa = $p.Acoes | Where-Object Id -eq 'binding-sa-user'
    Exigir ($bSa.Argumentos -contains $c.ContaApi) 'ServiceAccountUser deve ser restrito a SA da API S-26.'
    Exigir ($bSa.Argumentos -contains '--role=roles/iam.serviceAccountUser') 'Papel deve ser roles/iam.serviceAccountUser.'
    Exigir ($bSa.Argumentos -contains ('--member=serviceAccount:' + $c.EmailPipeline)) 'Membro deve ser a SA do pipeline.'
}

Caso 'Execucao completa com sucesso chama preflight e todas as mutacoes' {
    Reset-Mocks
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    $res = Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake
    Exigir ($script:chamadas.Count -ge 12) 'Devem ocorrer todas as consultas de preflight e acoes de criacao/binding.'
    Exigir ($script:chamadas[0].Id -eq 'preflight-numero-projeto') 'Primeira chamada deve ser a verificacao do NumeroProjeto.'
}

Caso 'Divergencia de NumeroProjeto falha preflight antes de qualquer mutacao' {
    Reset-Mocks
    $script:projNumeroSimulado = '999999999999'
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'diverge'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Nenhuma mutacao pode ocorrer se o NumeroProjeto divergir.'
}

Caso 'Ausencia de API obrigatoria falha preflight antes de mutacao' {
    Reset-Mocks
    $script:apisAtivasSimuladas = @('run.googleapis.com')
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'API obrigatoria'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Nenhuma mutacao pode ocorrer se houver API obrigatoria ausente.'
}

Caso 'Ausencia de pre-requisito S-26 falha preflight antes de mutacao' {
    Reset-Mocks
    $script:simularRegistroAusente = $true
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'Pre-requisito ausente'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Nenhuma mutacao pode ocorrer se pre-requisito do S-26 estiver ausente.'
}

Caso 'Provedor WIF existente com condicao divergente falha preflight' {
    Reset-Mocks
    $script:simularProviderDivergente = $true
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'divergente'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Nenhuma mutacao pode ocorrer com condicao divergente.'
}

Caso 'Recurso existente com dono divergente falha preflight' {
    Reset-Mocks
    $script:simularPoolDivergente = $true
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'ownership divergente'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Nenhuma mutacao pode ocorrer com ownership divergente.'
}

Caso 'Falha em comando interrompe execucao imediatamente (fail-closed)' {
    Reset-Mocks
    $script:falharNoId = 'criar-pool'
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'Operacao S-26 falhou [criar-pool]'
    $posteriores = @($script:chamadas | Where-Object { $_.Id -eq 'criar-provider' -or $_.Id -like 'binding-*' })
    Exigir ($posteriores.Count -eq 0) 'Falha ao criar o pool deve interromper o pipeline antes de criar provedor ou bindings.'
}

Caso 'Comandos gh variable set sao gerados corretamente sem chave JSON' {
    Reset-Mocks
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Exigir ($p.ComandosGitHub.Count -eq 5) 'Devem ser exatamente 5 comandos gh variable set.'
    $txt = $p.ComandosGitHub -join "`n"
    Exigir ($txt.Contains('GCP_PROJECT_ID --body "solar-ai-cloud"')) 'GCP_PROJECT_ID incorreto.'
    Exigir ($txt.Contains('GCP_REGION --body "southamerica-east1"')) 'GCP_REGION incorreto.'
    Exigir ($txt.Contains('GCP_ARTIFACT_REGISTRY --body "solar-s26-3bdd7f92"')) 'GCP_ARTIFACT_REGISTRY incorreto.'
    Exigir ($txt.Contains('GCP_WORKLOAD_IDENTITY_PROVIDER --body "projects/123456789012/locations/global/workloadIdentityPools/solar-s27-df312134/providers/github-df312134"')) 'GCP_WORKLOAD_IDENTITY_PROVIDER incorreto.'
    Exigir ($txt.Contains('GCP_DEPLOY_SERVICE_ACCOUNT --body "s27-pipeline-df312134@solar-ai-cloud.iam.gserviceaccount.com"')) 'GCP_DEPLOY_SERVICE_ACCOUNT incorreto.'
    Exigir (-not $txt.Contains('.json')) 'Nao pode haver mencao a chave JSON.'
}

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " SUCESSO: Todos os $script:total testes passaram com executor falso." -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan
