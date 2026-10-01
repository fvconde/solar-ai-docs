# Sonda privada front -> API. Nao comprova a invocacao API -> agente.
function Invoke-S26SondaIamNativa($Acao) {
    $token = $null; $cliente = $null; $requisicao = $null
    $resposta = $null; $stream = $null; $cancelamento = $null
    try {
        $origem = ConvertTo-S26OrigemHttps $Acao.OrigemFront
        if ($origem -cne $Acao.OrigemFront -or $Acao.Uri -cne ($origem + '/api/sessao')) {
            throw 'Destino invalido.'
        }
        $ctx = New-S26Contexto
        if ([datetime]::UtcNow -ge $Acao.LimiteUtc) { throw 'Prazo esgotado.' }
        # Token do operador autenticado; sem impersonacao, audience ou token no argv.
        $token = Invoke-S26Nativo (New-S26Comando 'token-sonda-em-memoria' $ctx.Gcloud @(
            'auth','print-identity-token',('--project=' + $ctx.Projeto),'--quiet'))
        if ([string]::IsNullOrWhiteSpace($token)) { throw 'Token ausente.' }
        $timeout = [Math]::Min($Acao.TimeoutSegundos, ($Acao.LimiteUtc - [datetime]::UtcNow).TotalSeconds)
        if ($timeout -le 0) { throw 'Prazo esgotado.' }
        Add-Type -AssemblyName System.Net.Http
        $handler = New-Object Net.Http.HttpClientHandler
        $handler.AllowAutoRedirect = $false
        $handler.UseCookies = $false
        $cliente = New-Object Net.Http.HttpClient($handler)
        $cancelamento = New-Object Threading.CancellationTokenSource
        $cancelamento.CancelAfter([TimeSpan]::FromSeconds($timeout))
        $cliente.Timeout = [TimeSpan]::FromSeconds($timeout)
        $requisicao = New-Object Net.Http.HttpRequestMessage
        $requisicao.Method = [Net.Http.HttpMethod]::Get
        $requisicao.RequestUri = [Uri]$Acao.Uri
        $requisicao.Headers.Authorization = New-Object Net.Http.Headers.AuthenticationHeaderValue('Bearer', $token)
        $resposta = $cliente.SendAsync($requisicao, [Net.Http.HttpCompletionOption]::ResponseHeadersRead,
            $cancelamento.Token).GetAwaiter().GetResult()
        $codigo = [int]$resposta.StatusCode
        $corpo = ''
        # Apenas o 401 esperado precisa de corpo; nenhum corpo externo e registrado.
        if ($codigo -eq 401) {
            $stream = $resposta.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
            $bytes = New-Object byte[] 8193
            $total = 0
            do {
                $lidos = $stream.ReadAsync($bytes, $total, ($bytes.Length - $total),
                    $cancelamento.Token).GetAwaiter().GetResult()
                $total += $lidos
                if ($total -gt 8192) { throw 'Corpo excede limite.' }
            } while ($lidos -gt 0)
            $utf8 = New-Object Text.UTF8Encoding($false, $true)
            $corpo = $utf8.GetString($bytes, 0, $total)
        }
        return [pscustomobject]@{ StatusCode=$codigo; Corpo=$corpo }
    } finally {
        if ($stream) { $stream.Dispose() }
        if ($resposta) { $resposta.Dispose() }
        if ($requisicao) { $requisicao.Dispose() }
        if ($cliente) { $cliente.Dispose() }
        if ($cancelamento) { $cancelamento.Dispose() }
        $token = $null
    }
}

function Wait-S26IamFrontApi {
    param([string]$OrigemFront, [datetime]$BindingAgenteUtc, [scriptblock]$Executor,
        [scriptblock]$Relogio = { [datetime]::UtcNow },
        [scriptblock]$Dormir = { param([double]$Segundos) Start-Sleep -Milliseconds ([int][Math]::Ceiling($Segundos * 1000)) })
    try {
        $origem = ConvertTo-S26OrigemHttps $OrigemFront
        if ($origem -cne $OrigemFront) { throw 'Origem nao canonica.' }
        $inicio = & $Relogio
        if ($inicio -isnot [datetime] -or $inicio.Kind -ne [DateTimeKind]::Utc -or
            $BindingAgenteUtc.Kind -ne [DateTimeKind]::Utc -or $BindingAgenteUtc -gt $inicio) {
            throw 'Relogio ou binding invalido.'
        }
        $limite = $inicio.AddMinutes(10)
        $anterior = $inicio
        $confirmado = $false
        for ($tentativa = 1; $tentativa -le 10; $tentativa++) {
            $agora = & $Relogio
            if ($agora -lt $anterior -or $agora.AddSeconds(60) -gt $limite) { throw 'Prazo excedido.' }
            & $Dormir 60 | Out-Null
            $agora = & $Relogio
            if ($agora -lt $anterior.AddSeconds(60) -or $agora -gt $limite) { throw 'Espera ou prazo invalido.' }
            $anterior = $agora
            $acao = [ordered]@{ Id='sonda-iam-front-api'; Tipo='SondaIam'; Metodo='GET'
                OrigemFront=$origem; Uri=($origem + '/api/sessao')
                LimiteUtc=$limite
                TimeoutSegundos=[Math]::Max(0.001, [Math]::Min(20, ($limite - $agora).TotalSeconds)) }
            $resposta = Invoke-S26Transporte $acao $Executor
            $agora = & $Relogio
            if ($agora -lt $anterior -or $agora -gt $limite) { throw 'Prazo excedido.' }
            $anterior = $agora
            if ($resposta.StatusCode -eq 401) {
                if ($resposta.Corpo -isnot [string] -or [Text.Encoding]::UTF8.GetByteCount($resposta.Corpo) -gt 8192 -or
                    $resposta.Corpo -notmatch '\A\s*\{') { throw 'Corpo invalido.' }
                # ConvertFrom-Json aceita extensoes diferentes entre PS7 e 5.1.
                # Recusar comentarios/virgula final e codigo ambiguo nos dois shells.
                $stringJson = '"(?:[^"\\\x00-\x1f]|\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4}))*"'
                $semStrings = [regex]::Replace($resposta.Corpo, $stringJson, '""')
                if ($semStrings -match '/|,\s*[}\]]' -or
                    [regex]::Matches($resposta.Corpo, '"codigo"\s*:').Count -ne 1) { throw 'JSON ambiguo/invalido.' }
                $json = $resposta.Corpo | ConvertFrom-Json -ErrorAction Stop
                if ($null -eq $json -or $json.codigo -isnot [string] -or $json.codigo -cne 'sessao_invalida') {
                    throw 'Resposta nao comprova front/API.'
                }
                $confirmado = $true
                break
            }
            if ($resposta.StatusCode -notin @(403,502)) { throw 'Status inesperado.' }
        }
        if (-not $confirmado) { throw 'Sonda esgotada.' }
        # Somente estabilizacao temporal do binding. Prova do agente segue pendente.
        $restante = ($BindingAgenteUtc.AddMinutes(5) - $agora).TotalSeconds
        if ($restante -gt 0) {
            & $Dormir $restante | Out-Null
            $fim = & $Relogio
            if ($fim -lt $BindingAgenteUtc.AddMinutes(5) -or $fim -lt $agora) { throw 'Espera incompleta.' }
        }
    } catch {
        throw 'Espera IAM S-26 interrompida; detalhes externos suprimidos. Agente permanece sem prova.'
    }
}
