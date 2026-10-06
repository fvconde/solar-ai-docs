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
$script:simularRunApiAusente = $false
$script:simularRunAgenteAusente = $false
$script:simularRunFrontAusente = $false
$script:simularRunApiDivergente = $false
$script:simularRunAgenteDivergente = $false
$script:simularRunFrontDivergente = $false

$script:simularSaApiAusente = $false
$script:simularSaAgenteAusente = $false
$script:simularSaFrontAusente = $false
$script:simularSaApiDisabled = $false
$script:simularSaAgenteDisabled = $false
$script:simularSaFrontDisabled = $false
$script:simularSaApiDivergente = $false
$script:simularSaAgenteDivergente = $false
$script:simularSaFrontDivergente = $false

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

function Invoke-AvaliarCondicaoWifEmissao([string]$CondicaoCel, [string]$Repo, [string]$Ref) {
    $condStr = if ($CondicaoCel.StartsWith('--attribute-condition=')) {
        $CondicaoCel.Substring('--attribute-condition='.Length)
    } else {
        $CondicaoCel
    }

    $repoEscapado = "'$Repo'"
    $refEscapado = "'$Ref'"
    $expr = $condStr
    $expr = $expr.Replace('assertion.repository', $repoEscapado)
    $expr = $expr.Replace('assertion.ref', $refEscapado)
    $expr = $expr.Replace('==', '-eq')
    $expr = $expr.Replace('&&', '-and')
    $expr = $expr.Replace('||', '-or')

    return [bool](Invoke-Expression $expr)
}

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
            $lista = New-Object 'System.Collections.Generic.List[object]'
            if (-not $script:simularRunApiAusente) {
                $meta = [ordered]@{ name = 'solar-api' }
                if ($script:simularRunApiDivergente) {
                    $meta['labels'] = @{ 's26-execucao' = 'outro-dono' }
                }
                $lista.Add([ordered]@{ metadata = $meta })
            }
            if (-not $script:simularRunAgenteAusente) {
                $meta = [ordered]@{ name = 'solar-agente' }
                if ($script:simularRunAgenteDivergente) {
                    $meta['labels'] = @{ 's26-execucao' = 'outro-dono' }
                }
                $lista.Add([ordered]@{ metadata = $meta })
            }
            if (-not $script:simularRunFrontAusente) {
                $meta = [ordered]@{ name = 'solar-front' }
                if ($script:simularRunFrontDivergente) {
                    $meta['labels'] = @{ 's26-execucao' = 'outro-dono' }
                }
                $lista.Add([ordered]@{ metadata = $meta })
            }
            $json = ConvertTo-Json -InputObject $lista.ToArray() -Depth 5
            if (-not $json.TrimStart().StartsWith('[')) { $json = '[' + "`n" + $json + "`n" + ']' }
            return $json
        }
        'preflight-check-sa' {
            $lista = New-Object 'System.Collections.Generic.List[object]'
            if (-not $script:simularSaApiAusente) {
                $desc = if ($script:simularSaApiDivergente) { 'outro-dono' } else { 's26-execucao=3bdd7f92' }
                $item = [ordered]@{ email = "s26-api-3bdd7f92@solar-ai-cloud.iam.gserviceaccount.com"; description = $desc }
                if ($script:simularSaApiDisabled) { $item['disabled'] = $true }
                $lista.Add($item)
            }
            if (-not $script:simularSaAgenteAusente) {
                $desc = if ($script:simularSaAgenteDivergente) { 'outro-dono' } else { 's26-execucao=3bdd7f92' }
                $item = [ordered]@{ email = "s26-agente-3bdd7f92@solar-ai-cloud.iam.gserviceaccount.com"; description = $desc }
                if ($script:simularSaAgenteDisabled) { $item['disabled'] = $true }
                $lista.Add($item)
            }
            if (-not $script:simularSaFrontAusente) {
                $desc = if ($script:simularSaFrontDivergente) { 'outro-dono' } else { 's26-execucao=3bdd7f92' }
                $item = [ordered]@{ email = "s26-front-3bdd7f92@solar-ai-cloud.iam.gserviceaccount.com"; description = $desc }
                if ($script:simularSaFrontDisabled) { $item['disabled'] = $true }
                $lista.Add($item)
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
                $cond = if ($script:simularProviderDivergenteCond) {
                    "assertion.repository == 'outro/repo'"
                } else {
                    "(assertion.repository == 'fvconde/solar-ai-api' || assertion.repository == 'fvconde/solar-ai' || assertion.repository == 'fvconde/solar-ai-front') && assertion.ref == 'refs/heads/main'"
                }
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
    $script:simularRunApiAusente = $false
    $script:simularRunAgenteAusente = $false
    $script:simularRunFrontAusente = $false
    $script:simularRunApiDivergente = $false
    $script:simularRunAgenteDivergente = $false
    $script:simularRunFrontDivergente = $false

    $script:simularSaApiAusente = $false
    $script:simularSaAgenteAusente = $false
    $script:simularSaFrontAusente = $false
    $script:simularSaApiDisabled = $false
    $script:simularSaAgenteDisabled = $false
    $script:simularSaFrontDisabled = $false
    $script:simularSaApiDivergente = $false
    $script:simularSaAgenteDivergente = $false
    $script:simularSaFrontDivergente = $false

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
    Exigir ($res.Acoes.Count -eq 13) 'Plano deve conter exatamente 13 acoes de mutacao.'
}

Caso 'Condicao WIF no provedor e exata e chega intacta ao transporte nativo' {
    Reset-Mocks
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    $acaoProv = $p.Acoes | Where-Object Id -eq 'criar-provider'
    Exigir ($null -ne $acaoProv) 'Acao criar-provider deve existir.'
    $condEsperada = "--attribute-condition=(assertion.repository == 'fvconde/solar-ai-api' || assertion.repository == 'fvconde/solar-ai' || assertion.repository == 'fvconde/solar-ai-front') && assertion.ref == 'refs/heads/main'"
    Exigir ($acaoProv.Argumentos -contains $condEsperada) 'Condicao WIF literal deve conter aspas simples, || e && intactos.'
    Exigir ($acaoProv.Argumentos -contains ('--description=' + $p.Contexto.Marca)) 'Acao criar-provider deve incluir description com a Marca da execucao.'

    Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake | Out-Null
    $chamadaProv = $script:chamadas | Where-Object Id -eq 'criar-provider'
    Exigir ($null -ne $chamadaProv) 'Acao criar-provider deve ser despachada para o transporte.'
    Exigir ($chamadaProv.Argumentos -contains $condEsperada) 'O transporte deve receber o argumento com ||, && e aspas inalterados.'
}

Caso 'Nota (b) Maestro: avaliacao dinamica da condicao WIF emitida aceita os 3 repos na main e recusa qualquer outro caso' {
    Reset-Mocks
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    $acaoProv = $p.Acoes | Where-Object Id -eq 'criar-provider'
    $argCond = @($acaoProv.Argumentos | Where-Object { $_ -like '--attribute-condition=*' })[0]

    # 1. Aceitar cada um dos tres repositorios na main
    Exigir (Invoke-AvaliarCondicaoWifEmissao $argCond 'fvconde/solar-ai-api' 'refs/heads/main') 'Deve aceitar fvconde/solar-ai-api na main.'
    Exigir (Invoke-AvaliarCondicaoWifEmissao $argCond 'fvconde/solar-ai' 'refs/heads/main') 'Deve aceitar fvconde/solar-ai na main.'
    Exigir (Invoke-AvaliarCondicaoWifEmissao $argCond 'fvconde/solar-ai-front' 'refs/heads/main') 'Deve aceitar fvconde/solar-ai-front na main.'

    # 2. Recusar quarto repositorio na main
    Exigir (-not (Invoke-AvaliarCondicaoWifEmissao $argCond 'fvconde/solar-ai-outro' 'refs/heads/main')) 'Deve recusar quarto repo fvconde/solar-ai-outro.'
    Exigir (-not (Invoke-AvaliarCondicaoWifEmissao $argCond 'outro/repo' 'refs/heads/main')) 'Deve recusar outro/repo na main.'
    Exigir (-not (Invoke-AvaliarCondicaoWifEmissao $argCond '' 'refs/heads/main')) 'Deve recusar repo vazio.'

    # 3. Recusar branches diferentes de main para cada repositorio permitido
    foreach ($repo in @('fvconde/solar-ai-api', 'fvconde/solar-ai', 'fvconde/solar-ai-front')) {
        Exigir (-not (Invoke-AvaliarCondicaoWifEmissao $argCond $repo 'refs/heads/develop')) ("Deve recusar develop em $repo.")
        Exigir (-not (Invoke-AvaliarCondicaoWifEmissao $argCond $repo 'refs/heads/feature/S-28')) ("Deve recusar feature/S-28 em $repo.")
        Exigir (-not (Invoke-AvaliarCondicaoWifEmissao $argCond $repo 'refs/pull/1/merge')) ("Deve recusar pull request merge em $repo.")
        Exigir (-not (Invoke-AvaliarCondicaoWifEmissao $argCond $repo 'main')) ("Deve recusar 'main' sem refs/heads/ em $repo.")
        Exigir (-not (Invoke-AvaliarCondicaoWifEmissao $argCond $repo '')) ("Deve recusar ref vazio em $repo.")
    }
}

Caso 'Comandos e argumentos esperados para criacao e bindings' {
    Reset-Mocks
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    $ids = @($p.Acoes | ForEach-Object { $_.Id })
    $esperados = @(
        'criar-pool',
        'criar-provider',
        'criar-sa-pipeline',
        'binding-workload-identity-api',
        'binding-workload-identity-agente',
        'binding-workload-identity-front',
        'binding-artifact-registry',
        'binding-run-developer-api',
        'binding-run-developer-agente',
        'binding-run-developer-front',
        'binding-sa-user-api',
        'binding-sa-user-agente',
        'binding-sa-user-front'
    )
    Exigir ($ids.Count -eq $esperados.Count) ("Quantidade de acoes difere do esperado: $($ids.Count) vs $($esperados.Count)")
    for ($i = 0; $i -lt $ids.Count; $i++) {
        Exigir ($ids[$i] -ceq $esperados[$i]) ("Acao na ordem inesperada: " + $ids[$i] + " vs " + $esperados[$i])
    }
}

Caso 'IAM nos recursos certos com menor privilegio' {
    Reset-Mocks
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    $c = $p.Contexto

    # Workload Identity por repositorio exato
    foreach ($par in @(@('api','fvconde/solar-ai-api'), @('agente','fvconde/solar-ai'), @('front','fvconde/solar-ai-front'))) {
        $idAcao = 'binding-workload-identity-' + $par[0]
        $repo = $par[1]
        $bWif = $p.Acoes | Where-Object Id -eq $idAcao
        Exigir ($null -ne $bWif) ("Binding $idAcao ausente.")
        Exigir ($bWif.Argumentos -contains $c.EmailPipeline) 'WorkloadIdentityUser deve vincular na SA do pipeline.'
        Exigir ($bWif.Argumentos -contains '--role=roles/iam.workloadIdentityUser') 'Papel deve ser roles/iam.workloadIdentityUser.'
        Exigir ($bWif.Argumentos -contains ('--member=principalSet://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/' + $c.PoolId + '/attribute.repository/' + $repo)) ("PrincipalSet deve restringir ao repositorio $repo.")
    }

    # Artifact Registry writer exclusivo no registro S-26
    $bReg = $p.Acoes | Where-Object Id -eq 'binding-artifact-registry'
    Exigir ($bReg.Argumentos -contains $c.Registro) 'Writer deve apontar para o registro S26.'
    Exigir ($bReg.Argumentos -contains ('--location=' + $c.Regiao)) 'Localizacao deve ser a regiao do registro.'
    Exigir ($bReg.Argumentos -contains '--role=roles/artifactregistry.writer') 'Papel deve ser roles/artifactregistry.writer.'
    Exigir ($bReg.Argumentos -contains ('--member=serviceAccount:' + $c.EmailPipeline)) 'Membro deve ser a SA do pipeline.'

    # Run Developer apenas nos 3 servicos respectivos
    foreach ($par in @(@('api','solar-api'), @('agente','solar-agente'), @('front','solar-front'))) {
        $idAcao = 'binding-run-developer-' + $par[0]
        $srv = $par[1]
        $bRun = $p.Acoes | Where-Object Id -eq $idAcao
        Exigir ($null -ne $bRun) ("Binding $idAcao ausente.")
        Exigir ($bRun.Argumentos -contains $srv) ("Run.developer deve ser restrito ao servico $srv.")
        Exigir ($bRun.Argumentos -contains ('--region=' + $c.Regiao)) 'Regiao deve ser southamerica-east1.'
        Exigir ($bRun.Argumentos -contains '--role=roles/run.developer') 'Papel deve ser roles/run.developer.'
        Exigir ($bRun.Argumentos -contains ('--member=serviceAccount:' + $c.EmailPipeline)) 'Membro deve ser a SA do pipeline.'
    }

    # Service Account User apenas nas 3 contas runtime respectivas
    foreach ($par in @(@('api',$c.ContaApi), @('agente',$c.ContaAgente), @('front',$c.ContaFront))) {
        $idAcao = 'binding-sa-user-' + $par[0]
        $saAlvo = $par[1]
        $bSa = $p.Acoes | Where-Object Id -eq $idAcao
        Exigir ($null -ne $bSa) ("Binding $idAcao ausente.")
        Exigir ($bSa.Argumentos -contains $saAlvo) ("ServiceAccountUser deve ser restrito a SA runtime $saAlvo.")
        Exigir ($bSa.Argumentos -contains '--role=roles/iam.serviceAccountUser') 'Papel deve ser roles/iam.serviceAccountUser.'
        Exigir ($bSa.Argumentos -contains ('--member=serviceAccount:' + $c.EmailPipeline)) 'Membro deve ser a SA do pipeline.'
    }

    # Confirmar ausencia de papeis administrativos ou globais
    foreach ($a in $p.Acoes) {
        Exigir (-not ($a.Argumentos -match 'roles/editor|roles/owner|roles/admin|roles/resourcemanager')) 'Nenhum papel amplo ou administrativo pode ser concedido.'
    }
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
    Exigir ($script:chamadas.Count -ge 18) 'Devem ocorrer consultas de preflight e acoes de criacao/binding sem PropertyNotFoundException.'
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
    Exigir ($bindings.Count -eq 10) 'Os 10 bindings de permissao ainda devem ser garantidos.'
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
    # Registro ausente
    Reset-Mocks
    $script:simularRegistroAusente = $true
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'Artifact Registry'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Nenhuma mutacao pode ocorrer se registro estiver ausente.'

    # Servico Cloud Run da API ausente
    Reset-Mocks
    $script:simularRunApiAusente = $true
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'solar-api'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Nenhuma mutacao pode ocorrer se servico solar-api estiver ausente.'

    # Servico Cloud Run do Agente ausente
    Reset-Mocks
    $script:simularRunAgenteAusente = $true
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'solar-agente'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Nenhuma mutacao pode ocorrer se servico solar-agente estiver ausente.'

    # Servico Cloud Run do Front ausente
    Reset-Mocks
    $script:simularRunFrontAusente = $true
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'solar-front'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Nenhuma mutacao pode ocorrer se servico solar-front estiver ausente.'

    # Conta SA da API ausente
    Reset-Mocks
    $script:simularSaApiAusente = $true
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'Conta de servico Api'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Nenhuma mutacao pode ocorrer se SA Api estiver ausente.'

    # Conta SA do Agente ausente
    Reset-Mocks
    $script:simularSaAgenteAusente = $true
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'Conta de servico Agente'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Nenhuma mutacao pode ocorrer se SA Agente estiver ausente.'

    # Conta SA do Front ausente
    Reset-Mocks
    $script:simularSaFrontAusente = $true
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'Conta de servico Front'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Nenhuma mutacao pode ocorrer se SA Front estiver ausente.'
}

Caso 'Preflight fail-closed: recusa SA do agente ou do front desabilitada ou com ownership divergente' {
    # SA Agente desabilitada
    Reset-Mocks
    $script:simularSaAgenteDisabled = $true
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'desabilitada'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Nenhuma mutacao pode ocorrer se SA do agente estiver desabilitada.'

    # SA Front desabilitada
    Reset-Mocks
    $script:simularSaFrontDisabled = $true
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'desabilitada'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Nenhuma mutacao pode ocorrer se SA do front estiver desabilitada.'

    # SA Agente com ownership divergente
    Reset-Mocks
    $script:simularSaAgenteDivergente = $true
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'description/ownership divergente'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Nenhuma mutacao pode ocorrer se SA do agente tiver ownership divergente.'

    # SA Front com ownership divergente
    Reset-Mocks
    $script:simularSaFrontDivergente = $true
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'description/ownership divergente'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Nenhuma mutacao pode ocorrer se SA do front tiver ownership divergente.'
}

Caso 'Preflight fail-closed: recusa servico Cloud Run com ownership divergente' {
    Reset-Mocks
    $script:simularRunAgenteDivergente = $true
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Recusa { Invoke-S27PlanoPreparoWif $p -Executar -NumeroProjeto '123456789012' -Executor $fake } 'ownership divergente'
    $mutacoes = @($script:chamadas | Where-Object { $_.Id -like 'criar-*' -or $_.Id -like 'binding-*' })
    Exigir ($mutacoes.Count -eq 0) 'Nenhuma mutacao pode ocorrer se servico solar-agente tiver ownership divergente.'
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

Caso 'Comandos gh variable set contem as 5 variaveis para cada um dos tres repositorios (15 comandos)' {
    Reset-Mocks
    $p = New-S27PlanoPreparoWif -NumeroProjeto '123456789012'
    Exigir ($p.ComandosGitHub.Count -eq 15) ("Devem ser exatamente 15 comandos gh variable set, obtido: " + $p.ComandosGitHub.Count)

    $reposEsperados = @('fvconde/solar-ai-api', 'fvconde/solar-ai', 'fvconde/solar-ai-front')
    foreach ($repo in $reposEsperados) {
        $cmdsRepo = @($p.ComandosGitHub | Where-Object { $_.Contains('--repo ' + $repo + ' ') })
        Exigir ($cmdsRepo.Count -eq 5) ("Devem existir exatamente 5 comandos para o repositorio $repo.")
        $txt = $cmdsRepo -join "`n"
        Exigir ($txt.Contains("GCP_PROJECT_ID --repo $repo --body `"solar-ai-cloud`"")) ("GCP_PROJECT_ID incorreto para $repo.")
        Exigir ($txt.Contains("GCP_REGION --repo $repo --body `"southamerica-east1`"")) ("GCP_REGION incorreto para $repo.")
        Exigir ($txt.Contains("GCP_ARTIFACT_REGISTRY --repo $repo --body `"solar-s26-3bdd7f92`"")) ("GCP_ARTIFACT_REGISTRY incorreto para $repo.")
        Exigir ($txt.Contains("GCP_WORKLOAD_IDENTITY_PROVIDER --repo $repo --body `"projects/123456789012/locations/global/workloadIdentityPools/solar-s27-df312134/providers/github-df312134`"")) ("GCP_WORKLOAD_IDENTITY_PROVIDER incorreto para $repo.")
        Exigir ($txt.Contains("GCP_DEPLOY_SERVICE_ACCOUNT --repo $repo --body `"s27-pipeline-df312134@solar-ai-cloud.iam.gserviceaccount.com`"")) ("GCP_DEPLOY_SERVICE_ACCOUNT incorreto para $repo.")
    }

    $txtGeral = $p.ComandosGitHub -join "`n"
    Exigir (-not $txtGeral.Contains('.json')) 'Nao pode haver mencao a chave JSON nos comandos gh.'
}

Caso 'Teste stdout da invocacao direta sem -Executar exibe plano legivel e comandos completos (15 comandos)' {
    $caminhoScript = Join-Path $PSScriptRoot 'Preparo-Wif.ps1'
    $psExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell.exe' }
    $saida = & $psExe -NoProfile -File $caminhoScript -NumeroProjeto '123456789012'
    $textoCompleto = $saida -join "`n"

    Exigir ($textoCompleto.Contains('PLANO DE PREPARO WIF S-27')) 'Cabecalho do plano ausente.'
    Exigir ($textoCompleto.Contains('Projeto Google Cloud : solar-ai-cloud')) 'Projeto nao exibido legivelmente.'
    Exigir ($textoCompleto.Contains('Pool WIF             : solar-s27-df312134')) 'Pool nao exibido legivelmente.'
    $condEsperadaExibicao = "Condicao WIF         : (assertion.repository == 'fvconde/solar-ai-api' || assertion.repository == 'fvconde/solar-ai' || assertion.repository == 'fvconde/solar-ai-front') && assertion.ref == 'refs/heads/main'"
    Exigir ($textoCompleto.Contains($condEsperadaExibicao)) 'Condicao WIF expandida nao exibida.'
    Exigir ($textoCompleto.Contains('gh variable set GCP_PROJECT_ID --repo fvconde/solar-ai-api --body "solar-ai-cloud"')) 'Comando gh API ausente.'
    Exigir ($textoCompleto.Contains('gh variable set GCP_PROJECT_ID --repo fvconde/solar-ai --body "solar-ai-cloud"')) 'Comando gh Agente ausente.'
    Exigir ($textoCompleto.Contains('gh variable set GCP_PROJECT_ID --repo fvconde/solar-ai-front --body "solar-ai-cloud"')) 'Comando gh Front ausente.'
    Exigir ($textoCompleto.Contains('gh variable set GCP_DEPLOY_SERVICE_ACCOUNT --repo fvconde/solar-ai-front --body "s27-pipeline-df312134@solar-ai-cloud.iam.gserviceaccount.com"')) 'Comando gh GCP_DEPLOY_SERVICE_ACCOUNT Front ausente.'
}

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " SUCESSO: Todos os $script:total testes passaram com executor falso." -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan
