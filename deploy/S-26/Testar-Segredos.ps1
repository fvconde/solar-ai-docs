$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'Segredos-Interno.ps1')
# Barreiras locais: uma regressao nunca pode chamar rede, gcloud ou prompt real.
function Invoke-S26Nativo { throw 'Transporte real proibido no teste offline.' }
function Read-Host { throw 'Prompt real proibido no teste offline.' }
$ctx = New-S26Contexto
$script:total=0
function Exigir([bool]$C) { if (-not $C) { throw 'Assercao de segredo falhou (dados omitidos).' } }
function Caso([string]$Nome,[scriptblock]$Teste) {
    try { & $Teste; $script:total++ } catch { throw ('Caso ' + $Nome + ' falhou; dados omitidos.') }
}
$script:leituras=0
$script:mutacoes=0
$script:argv=New-Object 'System.Collections.Generic.List[string]'
$script:sqlConferido=$false
$script:conexaoConferida=$false
$script:usuarioExiste=$false
$script:falhaRest=$false
$script:falhaNaMutacao=0
$script:falhaEspera=$false
$script:inventarioSql='[]'
$script:donoInvalido=$false
$script:versaoResposta=$null
$script:protegidos=New-Object 'System.Collections.Generic.List[System.Security.SecureString]'
$script:corpos=New-Object 'System.Collections.Generic.List[object]'
# Somente sentinela sintetica; aspas e ponto-e-virgula exercitam escaping.
$ficticio = 'SENTINELA_FICTICIA;com"aspas=e=unicode-' + [char]0x00e3
$leitor = {
    param($rotulo)
    $script:leituras++
    $entrada=ConvertTo-SecureString $ficticio -AsPlainText -Force
    $script:protegidos.Add($entrada)
    return $entrada
}
$fake = {
    param($a)
    if ($a.Tipo -eq 'Comando') {
        $script:argv.Add(($a.Argumentos -join ' '))
        switch ($a.Id) {
            'inventario-Sql' {
                $marca=if ($script:donoInvalido) {'outra-execucao'} else {$ctx.Execucao}
                return ConvertTo-Json -InputObject @(@{name=$ctx.Instancia;region=$ctx.Regiao;
                    settings=@{userLabels=@{'s26-execucao'=$marca}}}) -Depth 10
            }
            'inventario-Segredo' {
                return ConvertTo-Json -InputObject @(($ctx.SegredosApi + $ctx.SegredosAgente) | ForEach-Object {
                    @{name=$_;labels=@{'s26-execucao'=$ctx.Execucao}}
                }) -Depth 10
            }
            'conferir-config' { return '{"core":{"project":"solar-ai-cloud","account":"ficticio"}}' }
            'conferir-apis' {
                return ConvertTo-Json -InputObject @('run','artifactregistry','sqladmin','secretmanager','iam' | ForEach-Object {
                    @{config=@{name=($_+'.googleapis.com')}}
                }) -Depth 5
            }
            'conferir-usuario-sql' {
                if ($script:usuarioExiste) { return '[{"name":"solar_app"}]' }
                return $script:inventarioSql
            }
            'aguardar-sql' {
                if ($script:falhaEspera) { throw ('EXTERNO:' + $ficticio) }
                return '{}'
            }
            default { throw 'Comando inesperado no executor ficticio.' }
        }
    }
    $script:mutacoes++
    Exigir ($script:protegidos.Count -eq 7)
    $script:corpos.Add($a.Corpo)
    if ($script:falhaRest -or $script:mutacoes -eq $script:falhaNaMutacao) { throw ('EXTERNO:' + $ficticio) }
    if ($a.Id -eq 'criar-usuario-sql-protegido') {
        Exigir ($a.Corpo.password -ceq $ficticio -and $a.Corpo.name -eq 'solar_app')
        Exigir ($a.Uri -eq ('https://sqladmin.googleapis.com/v1/projects/solar-ai-cloud/instances/' + $ctx.Instancia + '/users'))
        $script:sqlConferido=$true
        return '{"name":"operacao-sql-ficticia"}'
    }
    $decodificado = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($a.Corpo.payload.data))
    if ($a.Uri -like '*solar-postgres-connection-string:addVersion') {
        $builder=New-Object System.Data.Common.DbConnectionStringBuilder
        $builder.set_ConnectionString($decodificado)
        Exigir ($builder['Password'] -ceq $ficticio)
        Exigir ($builder['Host'] -ceq ('/cloudsql/solar-ai-cloud:southamerica-east1:' + $ctx.Instancia))
        Exigir ($builder['Database'] -ceq 'solar' -and $builder['Username'] -ceq 'solar_app')
        $script:conexaoConferida=$true
    } else { Exigir ($decodificado -ceq $ficticio) }
    $nome=($a.Uri -split '/secrets/')[1].Replace(':addVersion','')
    if ($null -ne $script:versaoResposta) { return $script:versaoResposta }
    return '{"name":"projects/123456789012/secrets/' + $nome + '/versions/7"}'
}
Caso 'plano nao pergunta nem invoca executor' {
    $p=Invoke-S26Segredos -Executor {throw 'Proibido'} -LeitorProtegido {throw 'Proibido'}
    Exigir ($p.EntradasProtegidas.Count -eq 7 -and $p.OperacoesProtegidas.Count -eq 8)
}
Caso 'usuario presente e aprovacao sao obrigatorios' {
    $falhou=$false
    try { Invoke-S26Segredos -Executar -PeloLider -AprovacaoMaestro $ctx.Execucao -Executor $fake -LeitorProtegido $leitor | Out-Null } catch { $falhou=$true }
    Exigir ($falhou -and $script:leituras -eq 0 -and $script:mutacoes -eq 0)
}
Caso 'SQL REST e sete versoes somente em memoria, saida sem valor' {
    $r=Invoke-S26Segredos -Executar -PeloLider -UsuarioPresente -AprovacaoMaestro $ctx.Execucao -Executor $fake -LeitorProtegido $leitor
    Exigir ($script:leituras -eq 7 -and $script:mutacoes -eq 8)
    Exigir ($script:sqlConferido -and $script:conexaoConferida)
    Exigir ($r.Count -eq 7 -and @($r.Values | Where-Object { $_ -ne '7' }).Count -eq 0)
    Exigir (-not (($r | ConvertTo-Json) -match 'SENTINELA'))
    Exigir (-not (($script:argv -join ' ') -match 'SENTINELA|--password|payload|Bearer'))
}
Caso 'usuario preexistente bloqueia sem pedir segredo ou mutar' {
    $script:usuarioExiste=$true
    $antes=$script:mutacoes; $lidos=$script:leituras; $falhou=$false
    try { Invoke-S26Segredos -Executar -PeloLider -UsuarioPresente -AprovacaoMaestro $ctx.Execucao -Executor $fake -LeitorProtegido $leitor | Out-Null } catch { $falhou=$true }
    Exigir ($falhou -and $script:mutacoes -eq $antes -and $script:leituras -eq $lidos)
    $script:usuarioExiste=$false
}
Caso 'falha externa nao vaza corpo, senha, token ou inner exception' {
    $script:protegidos.Clear()
    $script:falhaRest=$true; $erro=''
    try { Invoke-S26Segredos -Executar -PeloLider -UsuarioPresente -AprovacaoMaestro $ctx.Execucao -Executor $fake -LeitorProtegido $leitor | Out-Null } catch { $erro=$_.Exception.ToString() }
    Exigir ($erro -like '*detalhes sensiveis suprimidos*' -and $erro -notmatch 'SENTINELA|EXTERNO:')
    $script:falhaRest=$false
}
Caso 'leitor plaintext recusado antes de escrita' {
    $antes=$script:mutacoes; $falhou=$false
    try { Invoke-S26Segredos -Executar -PeloLider -UsuarioPresente -AprovacaoMaestro $ctx.Execucao -Executor $fake -LeitorProtegido {return 'plaintext-proibido'} | Out-Null } catch { $falhou=$true }
    Exigir ($falhou -and $script:mutacoes -eq $antes)
}
function Reiniciar {
    $script:leituras=0; $script:mutacoes=0
    $script:protegidos.Clear(); $script:corpos.Clear(); $script:argv.Clear()
}
function ExecutarFake {
    Invoke-S26Segredos -Executar -PeloLider -UsuarioPresente -AprovacaoMaestro $ctx.Execucao -Executor $fake -LeitorProtegido $leitor
}
function ExigirLimpeza {
    foreach ($entrada in $script:protegidos) {
        $descartada=$false
        try { $copia=$entrada.Copy(); $copia.Dispose() } catch [ObjectDisposedException] { $descartada=$true }
        Exigir $descartada
    }
    foreach ($corpo in $script:corpos) {
        if ($corpo.ContainsKey('password')) { Exigir ($null -eq $corpo.password) }
        if ($corpo.ContainsKey('payload')) { Exigir ($null -eq $corpo.payload.data) }
    }
}
Caso 'sucesso descarta entradas e referencias de payload' {
    Reiniciar
    $null=ExecutarFake
    ExigirLimpeza
}
foreach ($gate in @('lider','aprovacao ausente','aprovacao incorreta')) {
    Caso ('bloqueia ' + $gate) {
        Reiniciar; $falhou=$false
        $p=@{Executar=$true;PeloLider=($gate -ne 'lider');UsuarioPresente=$true;
            AprovacaoMaestro=$ctx.Execucao;Executor=$fake;LeitorProtegido=$leitor}
        if ($gate -eq 'aprovacao ausente') { $p.AprovacaoMaestro='' }
        if ($gate -eq 'aprovacao incorreta') { $p.AprovacaoMaestro='outra-execucao' }
        try { Invoke-S26Segredos @p | Out-Null } catch { $falhou=$true }
        Exigir ($falhou -and $script:argv.Count -eq 0 -and $script:leituras -eq 0 -and $script:mutacoes -eq 0)
    }
}
Caso 'ownership alheio bloqueia antes do prompt' {
    Reiniciar; $script:donoInvalido=$true; $falhou=$false
    try { ExecutarFake | Out-Null } catch { $falhou=$true } finally { $script:donoInvalido=$false }
    Exigir ($falhou -and $script:leituras -eq 0 -and $script:mutacoes -eq 0)
}
foreach ($inventario in @('', '{}', '[null]', '[{}]', '[{"name":""}]', '[invalido')) {
    Caso 'inventario SQL indeterminado bloqueia antes do prompt' {
        Reiniciar; $script:inventarioSql=$inventario; $falhou=$false
        try { ExecutarFake | Out-Null } catch { $falhou=$true } finally { $script:inventarioSql='[]' }
        Exigir ($falhou -and $script:leituras -eq 0 -and $script:mutacoes -eq 0)
    }
}
foreach ($posicao in 1..8) {
    Caso ('falha parcial na escrita ' + $posicao + ' interrompe sem vazar e limpa memoria') {
        Reiniciar; $script:falhaNaMutacao=$posicao; $erro=''
        try { ExecutarFake | Out-Null } catch { $erro=$_.Exception.ToString() } finally { $script:falhaNaMutacao=0 }
        Exigir ($erro -like '*estado parcial*' -and $erro -notmatch 'SENTINELA|EXTERNO:')
        Exigir ($script:mutacoes -eq $posicao)
        ExigirLimpeza
    }
}
Caso 'falha na espera SQL nao grava versao' {
    Reiniciar; $script:falhaEspera=$true; $erro=''
    try { ExecutarFake | Out-Null } catch { $erro=$_.Exception.ToString() } finally { $script:falhaEspera=$false }
    Exigir ($erro -like '*estado parcial*' -and $erro -notmatch 'SENTINELA|EXTERNO:' -and $script:mutacoes -eq 1)
    ExigirLimpeza
}
foreach ($resposta in @('{}', 'JSON_INVALIDO', '{"name":"projects/123456789012/secrets/outro/versions/7"}',
    '{"name":"projects/solar-ai-cloud/secrets/solar-postgres-connection-string/versions/latest"}',
    '{"name":"projects/solar-ai-cloud/secrets/solar-postgres-connection-string/versions/0"}')) {
    Caso 'versao invalida interrompe apos primeira versao' {
        Reiniciar; $script:versaoResposta=$resposta; $falhou=$false
        try { ExecutarFake | Out-Null } catch { $falhou=$true } finally { $script:versaoResposta=$null }
        Exigir ($falhou -and $script:mutacoes -eq 2)
        ExigirLimpeza
    }
}
foreach ($modo in @('vazio','erro')) {
    Caso ('prompt ' + $modo + ' descarta entradas anteriores e nao escreve') {
        Reiniciar; $falhou=$false
        $leitorFalho={
            param($rotulo)
            if ($script:leituras -lt 3) { return & $leitor $rotulo }
            if ($modo -eq 'erro') { throw ('EXTERNO:' + $ficticio) }
            $v=New-Object Security.SecureString
            $script:protegidos.Add($v)
            return $v
        }
        try { Invoke-S26Segredos -Executar -PeloLider -UsuarioPresente -AprovacaoMaestro $ctx.Execucao -Executor $fake -LeitorProtegido $leitorFalho | Out-Null }
        catch { $falhou=$true; Exigir ($_.Exception.ToString() -notmatch 'SENTINELA|EXTERNO:') }
        Exigir ($falhou -and $script:mutacoes -eq 0)
        ExigirLimpeza
    }
}
Write-Output ('PASSOU: ' + $script:total + ' testes locais de segredos sinteticos; nenhuma credencial/rede real.')
