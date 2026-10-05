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
$script:apisAtivasSimuladas = @('iam.googleapis.com', 'iamcredentials.googleapis.com', 'cloudresourcemanager.googleapis.com', 'artifactregistry.googleapis.com', 'run.googleapis.com', 'sts.googleapis.com')

$script:simularRegistroAusente = $false
$script:simularRunAusente = $false
$script:simularSaApiAusente = $false

$script:simularPoolExiste = $false
$script:simularPoolDivergente = $false
$script:simularPoolDisabled = $false
$script:simularPoolDeleted = $false
$script:simularPoolOmitirDisabled = $true

$script:simularProviderExiste = $false
$script:simularProviderDivergenteCond = $false
$script:simularProviderDivergenteDesc = $false
$script:simularProviderTerceiro = $false
$script:simularProviderDisabled = $false
$script:simularProviderDeleted = $false
$script:simularProviderIssuerInvalido = $false
$script:simularProviderOidcAusente = $false
$script:simularProviderMappingInvalido = $false
$script:simularProviderOmitirDisabled = $true

$script:simularSaPipeExiste = $false
$script:simularSaPipeDivergente = $false
$script:simularSaPipeDisabled = $false
$script:simularSaPipeOmitirDisabled = $true

$script:respostaEspecialPorId = @{}

$fake = {
    param($a)
    $script:chamadas.Add($a)

    if ($null -ne $script:falharNoId -and $a.Id -eq $script:falharNoId) {
        throw "Erro simulado na operacao $($a.Id)"
    }

    if ($script:respostaEspecialPorId.ContainsKey($a.Id)) {
        $esp = $script:respostaEspecialPorId[$a.Id]
        if ($esp -is [scriptblock]) { return (& $esp $a) }
        return $esp
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
            if ($script:simularRegistroAusente) { return '[]' }
            return '[{"name":"solar-s26-3bdd7f92"}]'
        }
        'preflight-check-run' {
            if ($script:simularRunAusente) { return '[]' }
            return '[{"metadata":{"name":"solar-api"}}]'
        }
        'preflight-check-sa' {
            $lista = New-Object 'System.Collections.Generic.List[object]'
            if (-not $script:simularSaApiAusente) {
                # SA da API padrao com disabled omitido
                $lista.Add([ordered]@{ email = "s26-api-3bdd7f92@solar-ai-cloud.iam.gserviceaccount.com"; description = "s26-execucao=3bdd7f92" })
            }
            if ($script:simularSaPipeExiste) {
                $desc = if ($script:simularSaPipeDivergente) { 'outro-dono' } else { 's27-execucao=df312134-114c-4742-80c3-01ac29034216' }
                $item = [ordered]@{
                    email = "s27-pipeline-df312134@solar-ai-cloud.iam.gserviceaccount.com"
                    description = $desc
                }
                if (-not $script:simularSaPipeOmitirDisabled -or $script:simularSaPipeDisabled) {
                    $item['disabled'] = [bool]$script:simularSaPipeDisabled
                }
                $lista.Add($item)
            }
            $json = ConvertTo-Json -InputObject $lista.ToArray() -Depth 5
            if (-not $json.TrimStart().StartsWith('[')) { $json = '[' + "`n" + $json + "`n" + ']' }
            return $json
        }
        'preflight-check-pool' {
            if ($script:simularPoolExiste) {
                $desc = if ($script:simularPoolDivergente) { 'outro-dono' } else { 's27-execucao=df312134-114c-4742-80c3-01ac29034216' }
                $st = if ($script:simularPoolDeleted) { 'DELETED' } else { 'ACTIVE' }
                $item = [ordered]@{
                    name = "projects/123456789012/locations/global/workloadIdentityPools/solar-s27-df312134"
                    description = $desc
                    state = $st
                }
                if (-not $script:simularPoolOmitirDisabled -or $script:simularPoolDisabled) {
                    $item['disabled'] = [bool]$script:simularPoolDisabled
                }
                $lista = @($item)
                $json = ConvertTo-Json -InputObject $lista -Depth 5
                if (-not $json.TrimStart().StartsWith('[')) { $json = '[' + "`n" + $json + "`n" + ']' }
                return $json
            }
            return '[]'
        }
        'preflight-check-provider' {
            if ($script:simularProviderExiste) {
                $lista = New-Object 'System.Collections.Generic.List[object]'
                $desc = if ($script:simularProviderDivergenteDesc) { 'outro-dono' } else { 's27-execucao=df312134-114c-4742-80c3-01ac29034216' }
                $cond = if ($script:simularProviderDivergenteCond) { "assertion.repository == 'outro/repo'" } else { "assertion.repository == 'fvconde/solar-ai-api' && assertion.ref == 'refs/heads/main'" }
                $st = if ($script:simularProviderDeleted) { 'DELETED' } else { 'ACTIVE' }
                $iss = if ($script:simularProviderIssuerInvalido) { 'https://token.invalido.com' } else { 'https://token.actions.githubusercontent.com' }
                $map = if ($script:simularProviderMappingInvalido) { @{ 'google.subject' = 'assertion.sub' } } else {
                    [ordered]@{
                        'google.subject' = 'assertion.sub'
                        'attribute.actor' = 'assertion.actor'
                        'attribute.repository' = 'assertion.repository'
                        'attribute.ref' = 'assertion.ref'
                    }
                }

                $item = [ordered]@{
                    name = "projects/123456789012/locations/global/workloadIdentityPools/solar-s27-df312134/providers/github-df312134"
                    description = $desc
                    state = $st
                    attributeCondition = $cond
                    attributeMapping = $map
                }
                if (-not $script:simularProviderOmitirDisabled -or $script:simularProviderDisabled) {
                    $item['disabled'] = [bool]$script:simularProviderDisabled
                }
                if (-not $script:simularProviderOidcAusente) {
                    $item['oidc'] = [ordered]@{
                        issuerUri = $iss
                    }
                }

                $lista.Add($item)

                if ($script:simularProviderTerceiro) {
                    $lista.Add([ordered]@{
                        name = "projects/123456789012/locations/global/workloadIdentityPools/solar-s27-df312134/providers/provider-estranho"
                        state = 'ACTIVE'
                    })
                }
                $json = ConvertTo-Json -InputObject $lista.ToArray() -Depth 5
                if (-not $json.TrimStart().StartsWith('[')) { $json = '[' + "`n" + $json + "`n" + ']' }
                return $json
            }
            return '[]'
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
    $script:apisAtivasSimuladas = @('iam.googleapis.com', 'iamcredentials.googleapis.com', 'cloudresourcemanager.googleapis.com', 'artifactregistry.googleapis.com', 'run.googleapis.com', 'sts.googleapis.com')

    $script:simularRegistroAusente = $false
    $script:simularRunAusente = $false
    $script:simularSaApiAusente = $false

    $script:simularPoolExiste = $false
    $script:simularPoolDivergente = $false
    $script:simularPoolDisabled = $false
    $script:simularPoolDeleted = $false
    $script:simularPoolOmitirDisabled = $true

    $script:simularProviderExiste = $false
    $script:simularProviderDivergenteCond = $false
    $script:simularProviderDivergenteDesc = $false
    $script:simularProviderTerceiro = $false
    $script:simularProviderDisabled = $false
    $script:simularProviderDeleted = $false
    $script:simularProviderIssuerInvalido = $false
    $script:simularProviderOidcAusente = $false
    $script:simularProviderMappingInvalido = $false
    $script:simularProviderOmitirDisabled = $true

    $script:simularSaPipeExiste = $false
    $script:simularSaPipeDivergente = $false
    $script:simularSaPipeDisabled = $false
    $script:simularSaPipeOmitirDisabled = $true

    $script:respostaEspecialPorId = @{}
}

Caso 'Plano padrao nao invoca executor e nao chama gcloud' {
    Reset-Mocks
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    $res = Invoke-S27PlanoPreparoWif $p -NumeroProjeto '123456789012' -Executor $fake
    Exigir ($script:chamadas.Count -eq 0) 'Nenhuma chamada gcloud deve ocorrer sem -Executar.'
    Exigir ($res.Acoes.Count -eq 7) 'Plano deve conter exatamente 7 acoes de mutacao.'
}

Caso 'Condicao WIF no provedor e exata e chega intacta ao transporte nativo' {
    Reset-Mocks
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    $acaoProv = $p.Acoes | Where-Object Id -eq 'criar-provider'
    Exigir ($null -ne $acaoProv) 'Acao criar-provider deve existir.'
    $condEsperada = "--attribute-condition=assertion.repository == 'fvconde/solar-ai-api' && assertion.ref == 'refs/heads/main'"
    Exigir ($acaoProv.Argumentos -contains $condEsperada) 'Condicao WIF literal deve conter && e aspas simples intactas.'
    Exigir ($acaoProv.Argumentos -contains ('--description=' + $p.Contexto.Marca)) 'Acao criar-provider deve incluir description com a Marca da execucao.'

    Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake | Out-Null
    $chamadaProv = $script:chamadas | Where-Object Id -eq 'criar-provider'
    Exigir ($null -ne $chamadaProv) 'Acao criar-provider deve ser despachada para o transporte.'
    Exigir ($chamadaProv.Argumentos -contains $condEsperada) 'O transporte deve receber o argumento com && e aspas inalterados.'
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

    $bWif = $p.Acoes | Where-Object Id -eq 'binding-workload-identity'
    Exigir ($bWif.Argumentos -contains $c.EmailPipeline) 'WorkloadIdentityUser deve vincular na SA do pipeline.'
    Exigir ($bWif.Argumentos -contains '--role=roles/iam.workloadIdentityUser') 'Papel deve ser roles/iam.workloadIdentityUser.'
    Exigir ($bWif.Argumentos -contains ('--member=principalSet://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/' + $c.PoolId + '/attribute.repository/' + $c.RepositorioGit)) 'PrincipalSet deve restringir ao repositorio do card.'

    $bReg = $p.Acoes | Where-Object Id -eq 'binding-artifact-registry'
    Exigir ($bReg.Argumentos -contains $c.Registro) 'Writer deve apontar para o registro S26.'
    Exigir ($bReg.Argumentos -contains ('--location=' + $c.Regiao)) 'Localizacao deve ser a regiao do registro.'
    Exigir ($bReg.Argumentos -contains '--role=roles/artifactregistry.writer') 'Papel deve ser roles/artifactregistry.writer.'
    Exigir ($bReg.Argumentos -contains ('--member=serviceAccount:' + $c.EmailPipeline)) 'Membro deve ser a SA do pipeline.'

    $bRun = $p.Acoes | Where-Object Id -eq 'binding-run-developer'
    Exigir ($bRun.Argumentos -contains $c.ServicoApi) 'Run.developer deve ser restrito ao servico solar-api.'
    Exigir ($bRun.Argumentos -contains ('--region=' + $c.Regiao)) 'Regiao deve ser southamerica-east1.'
    Exigir ($bRun.Argumentos -contains '--role=roles/run.developer') 'Papel deve ser roles/run.developer.'
    Exigir ($bRun.Argumentos -contains ('--member=serviceAccount:' + $c.EmailPipeline)) 'Membro deve ser a SA do pipeline.'

    $bSa = $p.Acoes | Where-Object Id -eq 'binding-sa-user'
    Exigir ($bSa.Argumentos -contains $c.ContaApi) 'ServiceAccountUser deve ser restrito a SA da API S-26.'
    Exigir ($bSa.Argumentos -contains '--role=roles/iam.serviceAccountUser') 'Papel deve ser roles/iam.serviceAccountUser.'
    Exigir ($bSa.Argumentos -contains ('--member=serviceAccount:' + $c.EmailPipeline)) 'Membro deve ser a SA do pipeline.'
}

Caso 'Inclusao de sts.googleapis.com nas APIs obrigatorias do preflight' {
    Reset-Mocks
    $script:apisAtivasSimuladas = @('iam.googleapis.com', 'iamcredentials.googleapis.com', 'cloudresourcemanager.googleapis.com', 'artifactregistry.googleapis.com', 'run.googleapis.com') # falta sts
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'sts.googleapis.com'
}

Caso 'Consultas de pools e providers utilizam --show-deleted' {
    Reset-Mocks
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake | Out-Null
    $poolQuery = $script:chamadas | Where-Object Id -eq 'preflight-check-pool'
    Exigir ($poolQuery.Argumentos -contains '--show-deleted') 'Consulta de pools deve incluir --show-deleted.'
}

Caso 'Execucao completa com sucesso lida com propriedades opcionais ausentes no protobuf/JSON' {
    Reset-Mocks
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    # Default: disabled omitido na SA, pool e provider
    $res = Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake
    Exigir ($script:chamadas.Count -ge 12) 'Devem ocorrer consultas de preflight e acoes de criacao/binding sem PropertyNotFoundException.'
}

Caso 'Idempotencia: reexecucao propria com esquema REST pula criacao de recursos existentes' {
    Reset-Mocks
    $script:simularPoolExiste = $true
    $script:simularProviderExiste = $true
    $script:simularSaPipeExiste = $true

    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake | Out-Null

    $criacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' })
    Exigir ($criacoes.Count -eq 0) 'Nenhuma mutacao de criacao deve ocorrer quando pool, provider e SA ja existem e estao validos.'

    $bindings = @($script:chamadas | Where-Object { $_.Id -like 'binding-*' })
    Exigir ($bindings.Count -eq 4) 'Os bindings de permissao ainda devem ser garantidos.'
}

Caso 'Divergencia de NumeroProjeto falha preflight antes de qualquer mutacao' {
    Reset-Mocks
    $script:projNumeroSimulado = '999999999999'
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'diverge'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Nenhuma mutacao pode ocorrer se o NumeroProjeto divergir.'
}

Caso 'Ausencia de pre-requisito S-26 falha preflight antes de mutacao' {
    Reset-Mocks
    $script:simularRegistroAusente = $true
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'Pre-requisito ausente'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Nenhuma mutacao pode ocorrer se pre-requisito do S-26 estiver ausente.'
}

Caso 'Falha de consulta no inventario (transporte) bloqueia antes de qualquer mutacao' {
    foreach ($idFalha in @('preflight-check-pool', 'preflight-check-sa', 'preflight-check-registro', 'preflight-check-run')) {
        Reset-Mocks
        $script:falharNoId = $idFalha
        $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
        Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake }
        $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
        Exigir ($mutacoes.Count -eq 0) ("Falha na consulta $idFalha nao deve permitir mutacoes.")
    }
}

Caso 'Falha de consulta com JSON vazio ou whitespace bloqueia antes de qualquer mutacao' {
    foreach ($idVazio in @('preflight-check-pool', 'preflight-check-sa', 'preflight-check-registro', 'preflight-check-run', 'preflight-apis')) {
        Reset-Mocks
        $script:respostaEspecialPorId[$idVazio] = '   '
        $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
        Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'vazio ou indeterminado'
        $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
        Exigir ($mutacoes.Count -eq 0) ("JSON vazio na consulta $idVazio nao deve permitir mutacoes.")
    }
}

Caso 'Falha de consulta com JSON malformado bloqueia antes de qualquer mutacao' {
    foreach ($idQuebrado in @('preflight-check-pool', 'preflight-check-sa', 'preflight-check-registro', 'preflight-check-run')) {
        Reset-Mocks
        $script:respostaEspecialPorId[$idQuebrado] = 'ERRO: gcloud internal server error'
        $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
        Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'vazio ou indeterminado'
        $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
        Exigir ($mutacoes.Count -eq 0) ("JSON malformado em $idQuebrado nao deve permitir mutacoes.")
    }
}

Caso 'Pool com state ACTIVE mas disabled=true bloqueia mutacoes' {
    Reset-Mocks
    $script:simularPoolExiste = $true
    $script:simularPoolDisabled = $true
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'desabilitado'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Pool desabilitado deve bloquear antes de mutacoes.'
}

Caso 'Pool com state DELETED bloqueia mutacoes' {
    Reset-Mocks
    $script:simularPoolExiste = $true
    $script:simularPoolDeleted = $true
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'estado incompativel'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Pool deletado deve bloquear antes de mutacoes.'
}

Caso 'Provider com state ACTIVE mas disabled=true bloqueia mutacoes' {
    Reset-Mocks
    $script:simularPoolExiste = $true
    $script:simularProviderExiste = $true
    $script:simularProviderDisabled = $true
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'desabilitado'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Provider desabilitado deve bloquear antes de mutacoes.'
}

Caso 'Provider com state DELETED bloqueia mutacoes' {
    Reset-Mocks
    $script:simularPoolExiste = $true
    $script:simularProviderExiste = $true
    $script:simularProviderDeleted = $true
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'estado incompativel'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Provider deletado deve bloquear antes de mutacoes.'
}

Caso 'Provider com description divergente (foreign) bloqueia mutacoes' {
    Reset-Mocks
    $script:simularPoolExiste = $true
    $script:simularProviderExiste = $true
    $script:simularProviderDivergenteDesc = $true
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'description/ownership divergente'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Provider com descricao estranha deve bloquear mutacoes.'
}

Caso 'Provider com condicao ou issuerUri divergente bloqueia mutacoes' {
    # 1. Condicao divergente
    Reset-Mocks
    $script:simularPoolExiste = $true
    $script:simularProviderExiste = $true
    $script:simularProviderDivergenteCond = $true
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'divergente da obrigatoria'

    # 2. IssuerUri divergente
    Reset-Mocks
    $script:simularPoolExiste = $true
    $script:simularProviderExiste = $true
    $script:simularProviderIssuerInvalido = $true
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'issuerUri divergente'
}

Caso 'Provedor terceiro no pool bloqueia execucao' {
    Reset-Mocks
    $script:simularPoolExiste = $true
    $script:simularProviderExiste = $true
    $script:simularProviderTerceiro = $true
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'provedor terceiro inesperado'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Nenhuma mutacao pode ocorrer se houver provedor terceiro no pool.'
}

Caso 'Falha em comando interrompe execucao imediatamente (fail-closed)' {
    Reset-Mocks
    $script:falharNoId = 'criar-pool'
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'Operacao S-26 falhou [criar-pool]'
    $posteriores = @($script:chamadas | Where-Object { $_.Id -eq 'criar-provider' -or $_.Id -like 'binding-*' })
    Exigir ($posteriores.Count -eq 0) 'Falha ao criar o pool deve interromper o pipeline antes de criar provedor ou bindings.'
}

Caso 'Comandos gh variable set contem --repo fvconde/solar-ai-api para todos os 5 itens' {
    Reset-Mocks
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Exigir ($p.ComandosGitHub.Count -eq 5) 'Devem ser exatamente 5 comandos gh variable set.'
    foreach ($cmd in $p.ComandosGitHub) {
        Exigir ($cmd.Contains('--repo fvconde/solar-ai-api')) ("Comando gh nao contem --repo fvconde/solar-ai-api: " + $cmd)
    }
    $txt = $p.ComandosGitHub -join "`n"
    Exigir ($txt.Contains('GCP_PROJECT_ID --repo fvconde/solar-ai-api --body "solar-ai-cloud"')) 'GCP_PROJECT_ID incorreto.'
    Exigir ($txt.Contains('GCP_REGION --repo fvconde/solar-ai-api --body "southamerica-east1"')) 'GCP_REGION incorreto.'
    Exigir ($txt.Contains('GCP_ARTIFACT_REGISTRY --repo fvconde/solar-ai-api --body "solar-s26-3bdd7f92"')) 'GCP_ARTIFACT_REGISTRY incorreto.'
    Exigir ($txt.Contains('GCP_WORKLOAD_IDENTITY_PROVIDER --repo fvconde/solar-ai-api --body "projects/123456789012/locations/global/workloadIdentityPools/solar-s27-df312134/providers/github-df312134"')) 'GCP_WORKLOAD_IDENTITY_PROVIDER incorreto.'
    Exigir ($txt.Contains('GCP_DEPLOY_SERVICE_ACCOUNT --repo fvconde/solar-ai-api --body "s27-pipeline-df312134@solar-ai-cloud.iam.gserviceaccount.com"')) 'GCP_DEPLOY_SERVICE_ACCOUNT incorreto.'
    Exigir (-not $txt.Contains('.json')) 'Nao pode haver mencao a chave JSON.'
}

Caso 'Teste stdout da invocacao direta sem -Executar exibe plano legivel e comandos completos' {
    $caminhoScript = Join-Path $PSScriptRoot 'Preparo-Wif.ps1'
    $psExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell.exe' }
    $saida = & $psExe -NoProfile -File $caminhoScript -NumeroProjeto '123456789012'
    $textoCompleto = $saida -join "`n"

    Exigir ($textoCompleto.Contains('PLANO DE PREPARO WIF S-27 (MODO SECO / SOMENTE LEITURA)')) 'Cabecalho do plano ausente.'
    Exigir ($textoCompleto.Contains('Projeto Google Cloud : solar-ai-cloud')) 'Projeto nao exibido legivelmente.'
    Exigir ($textoCompleto.Contains('Pool WIF             : solar-s27-df312134')) 'Pool nao exibido legivelmente.'
    Exigir ($textoCompleto.Contains('Condicao WIF         : assertion.repository == ''fvconde/solar-ai-api'' && assertion.ref == ''refs/heads/main''')) 'Condicao WIF nao exibida.'
    Exigir ($textoCompleto.Contains('gh variable set GCP_PROJECT_ID --repo fvconde/solar-ai-api --body "solar-ai-cloud"')) 'Comando gh GCP_PROJECT_ID ausente.'
    Exigir ($textoCompleto.Contains('gh variable set GCP_DEPLOY_SERVICE_ACCOUNT --repo fvconde/solar-ai-api --body "s27-pipeline-df312134@solar-ai-cloud.iam.gserviceaccount.com"')) 'Comando gh GCP_DEPLOY_SERVICE_ACCOUNT ausente.'
}

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " SUCESSO: Todos os $script:total testes passaram com executor falso." -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan
