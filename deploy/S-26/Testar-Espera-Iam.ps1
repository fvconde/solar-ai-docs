# Testes exclusivamente offline: transporte, relogio e sleep ficticios.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'Planos.ps1')
$script:total = 0
function Exigir([bool]$Valor) { if (-not $Valor) { throw 'Assercao falhou.' } }
function Caso([string]$Nome, [scriptblock]$Teste) {
    try { & $Teste } catch { throw ('Caso ' + $Nome + ': ' + $_.Exception.Message) }
    $script:total++
}
function Preparar {
    $script:estado = @{
        Agora=[datetime]::SpecifyKind([datetime]'2026-01-01', [DateTimeKind]::Utc)
        Chamadas=(New-Object 'System.Collections.Generic.List[object]')
        Sleeps=(New-Object 'System.Collections.Generic.List[double]')
        Respostas=@([pscustomobject]@{StatusCode=401;Corpo='{"codigo":"sessao_invalida"}'})
        Duracao=0; Falha=$false; SleepExtra=0; SleepIncompleto=$false
    }
    $script:binding = $script:estado.Agora
}
$relogio = { $script:estado.Agora }
$dormir = {
    param($segundos)
    $script:estado.Sleeps.Add($segundos)
    if (-not $script:estado.SleepIncompleto) {
        $script:estado.Agora = $script:estado.Agora.AddSeconds($segundos + $script:estado.SleepExtra)
    }
}
$fake = {
    param($a)
    $script:estado.Chamadas.Add($a)
    if ($a.Tipo -eq 'SondaIam') {
        Exigir ($a.Metodo -ceq 'GET' -and $a.Uri -ceq 'https://front.test/api/sessao')
        Exigir ($a.Keys -notcontains 'Token' -and $a.Keys -notcontains 'Cookie')
        Exigir ($a.TimeoutSegundos -gt 0 -and $a.TimeoutSegundos -le 20)
        if ($script:estado.Falha) { throw 'SENTINELA_TOKEN_CORPO_TLS' }
        $script:estado.Agora = $script:estado.Agora.AddSeconds($script:estado.Duracao)
        $indice = @($script:estado.Chamadas | Where-Object Tipo -eq 'SondaIam').Count - 1
        return $script:estado.Respostas[[Math]::Min($indice, $script:estado.Respostas.Count - 1)]
    }
    if ($a.Id -like 'inventario-*') { return '[]' }
    if ($a.Id -eq 'invoker-solar-api') { $script:estado.Agora = $script:estado.Agora.AddSeconds(20) }
    if ($a.Id -eq 'conferir-url-publicada') {
        return '{"metadata":{"name":"solar-front","labels":{"s26-execucao":"3bdd7f92-dda2-492e-a399-2e209a1e6238"},"annotations":{"run.googleapis.com/urls":"[\"https://solar-front-123456789012.southamerica-east1.run.app\"]"}},"status":{"url":"https://solar-front-123456789012.southamerica-east1.run.app"}}'
    }
    return '{}'
}
function Esperar([string]$Origem='https://front.test') {
    Wait-S26IamFrontApi -OrigemFront $Origem -BindingAgenteUtc $script:binding -Executor $fake -Relogio $relogio -Dormir $dormir
}
function Recusa([scriptblock]$Teste) {
    $falhou = $false
    try { & $Teste | Out-Null } catch {
        $falhou = $true
        Exigir (-not $_.Exception.Message.Contains('SENTINELA'))
        Exigir (-not $_.Exception.Message.Contains('valor-ficticio'))
    }
    Exigir $falhou
}
Caso 'sucesso nao emite logs ou corpos em nenhum stream' {
    Preparar
    $capturado = @(Esperar *>&1)
    Exigir ($capturado.Count -eq 0)
}
Caso 'erro nao vaza sentinela em streams ou excecao' {
    Preparar; $script:estado.Falha = $true
    $capturado = @(& { try { Esperar } catch { $_.Exception.Message } } *>&1)
    Exigir ($capturado.Count -eq 1)
    Exigir ([string]$capturado[0] -ceq 'Espera IAM S-26 interrompida; detalhes externos suprimidos. Agente permanece sem prova.')
}
Caso 'restante de cinco minutos nao cumprido e recusado' {
    Preparar
    $sleepParcial = { param($s) if ($s -eq 60) { $script:estado.Agora = $script:estado.Agora.AddSeconds($s) } }
    Recusa { Wait-S26IamFrontApi -OrigemFront 'https://front.test' -BindingAgenteUtc $script:binding -Executor $fake -Relogio $relogio -Dormir $sleepParcial }
    Exigir ($script:estado.Chamadas.Count -eq 1)
}
Caso 'relogio recua apos transporte e interrompe' {
    Preparar; $script:estado.Duracao = -1
    Recusa { Esperar }
    Exigir ($script:estado.Chamadas.Count -eq 1)
}
Caso 'primeira sonda apos 60 e restante ate cinco minutos' {
    Preparar; Esperar
    Exigir ($script:estado.Chamadas.Count -eq 1)
    Exigir ($script:estado.Sleeps.Count -eq 2 -and $script:estado.Sleeps[0] -eq 60 -and $script:estado.Sleeps[1] -eq 240)
    Exigir (($script:estado.Agora - $script:binding).TotalSeconds -eq 300)
}
Caso '403 e 502 repetem em 60 segundos, 401 JSON confirma' {
    Preparar
    $script:estado.Respostas = @(
        [pscustomobject]@{StatusCode=403;Corpo='valor-ficticio'}
        [pscustomobject]@{StatusCode=502;Corpo='valor-ficticio'}
        [pscustomobject]@{StatusCode=401;Corpo='{"codigo":"sessao_invalida","mensagem":"fixture"}'})
    Esperar
    Exigir ($script:estado.Chamadas.Count -eq 3)
    Exigir (($script:estado.Sleeps -join ',') -ceq '60,60,60,120')
}
Caso 'sucesso na decima sonda, sem espera adicional nem sonda agente' {
    Preparar
    $script:estado.Respostas = @((1..9 | ForEach-Object { [pscustomobject]@{StatusCode=403;Corpo=''} })) +
        @([pscustomobject]@{StatusCode=401;Corpo='{"codigo":"sessao_invalida"}'})
    Esperar
    Exigir ($script:estado.Chamadas.Count -eq 10 -and $script:estado.Sleeps.Count -eq 10)
    Exigir (($script:estado.Agora - $script:binding).TotalSeconds -eq 600)
    Exigir (-not @($script:estado.Chamadas | Where-Object { $_.Uri -like '*agente*' }).Count)
}
foreach ($status in @(403,502)) {
    Caso ('esgota dez tentativas: ' + $status) {
        Preparar; $script:estado.Respostas = @([pscustomobject]@{StatusCode=$status;Corpo='valor-ficticio'})
        Recusa { Esperar }
        Exigir ($script:estado.Chamadas.Count -eq 10 -and $script:estado.Sleeps.Count -eq 10)
    }
}
foreach ($status in @(200,201,204,301,302,303,307,308,400,404,429,500,503)) {
    Caso ('status sem retry: ' + $status) {
        Preparar; $script:estado.Respostas = @([pscustomobject]@{StatusCode=$status;Corpo='SENTINELA_TOKEN_CORPO_TLS'})
        Recusa { Esperar }
        Exigir ($script:estado.Chamadas.Count -eq 1 -and $script:estado.Sleeps.Count -eq 1)
    }
}
foreach ($corpo in @('', '<html>401 valor-ficticio</html>', 'invalid', '[]', 'null', '{}',
    '{"codigo":"outro"}', '{"codigo":401}', '{"codigo":"SESSAO_INVALIDA"}',
    '{"codigo":"sessao_invalida"', '{"codigo":"sessao_invalida",}',
    '{/* comentario */"codigo":"sessao_invalida"}', '{"Codigo":"sessao_invalida"}',
    '{"codigo":"outro","codigo":"sessao_invalida"}',
    ('{"codigo":"sessao_invalida","extra":"' + ('a'*8192) + '"}'))) {
    Caso '401 corpo invalido sem retry' {
        Preparar; $script:estado.Respostas = @([pscustomobject]@{StatusCode=401;Corpo=$corpo})
        Recusa { Esperar }
        Exigir ($script:estado.Chamadas.Count -eq 1 -and $script:estado.Sleeps.Count -eq 1)
    }
}
Caso 'TLS/transporte falha quieta sem retry' {
    Preparar; $script:estado.Falha = $true
    Recusa { Esperar }
    Exigir ($script:estado.Chamadas.Count -eq 1)
}
Caso 'latencia da sonda integra prazo e impede tentativa tardia' {
    Preparar; $script:estado.Duracao = 20
    $script:estado.Respostas = @([pscustomobject]@{StatusCode=502;Corpo=''})
    Recusa { Esperar }
    Exigir ($script:estado.Chamadas.Count -eq 7)
    Exigir (($script:estado.Agora - $script:binding).TotalSeconds -eq 560)
}
Caso 'resposta recebida depois do prazo e recusada' {
    Preparar; $script:estado.Duracao = 541
    Recusa { Esperar }
    Exigir ($script:estado.Chamadas.Count -eq 1)
}
Caso 'sleep ultrapassa dez minutos sem transporte' {
    Preparar; $script:estado.SleepExtra = 541
    Recusa { Esperar }
    Exigir ($script:estado.Chamadas.Count -eq 0)
}
Caso 'sleep que nao avanca relogio e recusado' {
    Preparar; $script:estado.SleepIncompleto = $true
    Recusa { Esperar }
    Exigir ($script:estado.Chamadas.Count -eq 0)
}
Caso 'binding antigo nao repete cinco minutos' {
    Preparar; $script:binding = $script:binding.AddMinutes(-10)
    Esperar
    Exigir ($script:estado.Sleeps.Count -eq 1)
}
Caso 'binding futuro e recusado antes de transporte' {
    Preparar; $script:binding = $script:binding.AddSeconds(1)
    Recusa { Esperar }; Exigir ($script:estado.Chamadas.Count -eq 0)
}
Caso 'binding sem UTC e recusado' {
    Preparar; $script:binding = [datetime]::SpecifyKind($script:binding,[DateTimeKind]::Unspecified)
    Recusa { Esperar }; Exigir ($script:estado.Chamadas.Count -eq 0)
}
foreach ($origem in @('http://front.test','https://user:senha@front.test','https://front.test/path',
    'https://front.test?url=https://agente.test','https://front.test/','https://FRONT.test',
    'https://front.test:443','https://front.test\x')) {
    Caso 'origem invalida nao normalizada nem sondada' {
        Preparar; Recusa { Esperar $origem }; Exigir ($script:estado.Chamadas.Count -eq 0)
    }
}
function Plano-Fixture {
    $p = New-S26Plano 'fixture-espera'
    $p.Acoes = @((New-S26Comando 'invoker-solar-agente' 'ficticio' @()),
        (New-S26Comando 'invoker-solar-api' 'ficticio' @()))
    $p.EsperaIam = [ordered]@{OrigemFront='https://front.test'}
    $p.VerificacoesFinais = @([ordered]@{Tipo='UrlPublicada';Servico='solar-front'
        Url='https://solar-front-123456789012.southamerica-east1.run.app'})
    $p.PublicarDepoisDeVerificar = New-S26Comando 'publicar-fixture' 'ficticio' @()
    return $p
}
function Executar-Fixture($Plano) {
    Invoke-S26Plano $Plano -Executar -PeloLider -AprovacaoMaestro (New-S26Contexto).Execucao -Executor $fake -Relogio $relogio -Dormir $dormir
}
Caso 'plano offline nao autentica nao espera nao transporta' {
    Preparar; $p = Plano-Fixture
    $obtido = Invoke-S26Plano $p -Executor $fake -Relogio $relogio -Dormir $dormir
    Exigir ([object]::ReferenceEquals($p,$obtido) -and $script:estado.Chamadas.Count -eq 0 -and $script:estado.Sleeps.Count -eq 0)
}
Caso 'integracao binding agente primeiro e publicacao somente depois sonda e URL' {
    Preparar; $p = Plano-Fixture; [void](Executar-Fixture $p)
    $ids = @($script:estado.Chamadas | ForEach-Object { $_.Id })
    Exigir ([array]::IndexOf($ids,'invoker-solar-agente') -lt [array]::IndexOf($ids,'invoker-solar-api'))
    Exigir ([array]::IndexOf($ids,'sonda-iam-front-api') -lt [array]::IndexOf($ids,'conferir-url-publicada'))
    Exigir ($ids[-1] -ceq 'publicar-fixture')
    Exigir (($script:estado.Sleeps -join ',') -ceq '60,220')
}
Caso 'sonda recusada bloqueia URL e publicacao no plano real' {
    Preparar; $script:estado.Falha = $true; $p = Plano-Fixture
    Recusa { Executar-Fixture $p }
    Exigir (-not @($script:estado.Chamadas | Where-Object { $_.Id -in @('conferir-url-publicada','publicar-fixture') }).Count)
}
Caso 'sem binding agente bloqueia sonda e publicacao' {
    Preparar; $p = Plano-Fixture; $p.Acoes = @()
    Recusa { Executar-Fixture $p }
    Exigir (-not @($script:estado.Chamadas | Where-Object { $_.Tipo -eq 'SondaIam' -or $_.Id -eq 'publicar-fixture' }).Count)
}
Caso 'plano deploy gerado fixa gen2 e ordem bindings antes da espera' {
    $e = @{UrlFront='https://solar-front-123456789012.southamerica-east1.run.app'
        UrlApi='https://solar-api-123456789012.southamerica-east1.run.app'
        UrlAgente='https://solar-agente-123456789012.southamerica-east1.run.app'
        ShaFront=('a'*40);ShaApi=('b'*40);ShaAgente=('c'*40);PeersObservadosConfirmados=$true}
    $v = @{}; $ctx = New-S26Contexto
    foreach ($nome in ($ctx.SegredosApi + $ctx.SegredosAgente)) { $v[$nome]='1' }
    $p = New-S26PlanoDeploy -Entradas $e -VersoesSegredos $v -NumeroProjeto '123456789012' -BootstrapPeersComprovado
    Exigir ($p.EsperaIam.OrigemFront -ceq $e.UrlFront)
    foreach ($acao in @($p.Acoes | Where-Object Id -like 'deploy-*')) { Exigir ($acao.Argumentos -contains '--execution-environment=gen2') }
    $ids = @($p.Acoes | ForEach-Object { $_.Id })
    Exigir ($ids[-2] -ceq 'invoker-solar-agente' -and $ids[-1] -ceq 'invoker-solar-api')
    Exigir (-not $p.Contains('PublicarDepoisDeVerificar'))
}
Write-Output ('PASSOU: ' + $script:total + ' testes espera IAM offline; zero SDK/rede/espera real.')
