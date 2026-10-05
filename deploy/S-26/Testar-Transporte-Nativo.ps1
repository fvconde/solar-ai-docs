$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'Operacoes.ps1')
$script:total = 0
function Exigir([bool]$Condicao) {
    if (-not $Condicao) { throw 'Assercao de transporte nativo falhou; dados omitidos.' }
}
function Caso([string]$Nome, [scriptblock]$Teste) {
    try { & $Teste; $script:total++ }
    catch { throw ('Caso ' + $Nome + ' falhou; dados omitidos.') }
}

# Processos locais reais; nenhum Executor injetado, SDK, rede ou segredo real.
$python = (Get-Command python -CommandType Application | Select-Object -First 1).Source
$pasta = Join-Path ([IO.Path]::GetTempPath()) ('s26-nativo-' + [guid]::NewGuid().ToString('N') + ' com espacos')
$fixture = Join-Path $pasta 'fixture.py'
$launcher = Join-Path $pasta 'launcher.cmd'
$utf8 = New-Object Text.UTF8Encoding($false)
$codigoPython = @'
import json,sys
modo=sys.argv[1]
sys.stderr.write('SENTINELA_STDERR_FICTICIA\n')
if modo=='json':
    print('{"ok":true,"quantidade":2}')
elif modo=='token':
    print('TOKEN_STDOUT_FICTICIO')
elif modo=='argv':
    print(json.dumps(sys.argv[2:]))
elif modo=='falha':
    print('SENTINELA_STDOUT_FICTICIA')
    sys.exit(7)
else:
    sys.exit(9)
'@
try {
    [void][IO.Directory]::CreateDirectory($pasta)
    [IO.File]::WriteAllText($fixture, $codigoPython, $utf8)
    # Mesmo tipo de launcher do SDK: cmd encaminha os argumentos ao interprete.
    [IO.File]::WriteAllText($launcher, ('@echo off' + "`r`n" + '"' + $python + '" "%~dp0fixture.py" %*' + "`r`n" + 'exit /b %errorlevel%' + "`r`n"), $utf8)
    foreach ($tipo in @('exe','cmd')) {
        $programa = if ($tipo -eq 'exe') { $python } else { $launcher }
        $prefixo = if ($tipo -eq 'exe') { @('-B',$fixture) } else { @() }
        Caso ($tipo + ' JSON stdout e aviso stderr exit zero') {
            $capturado = @(Invoke-S26Transporte (New-S26Comando 'teste-json' $programa ($prefixo + @('json'))) *>&1)
            Exigir ($capturado.Count -eq 1 -and $capturado[0] -is [string])
            $objeto = $capturado[0] | ConvertFrom-Json
            Exigir ($objeto.ok -eq $true -and $objeto.quantidade -eq 2)
            Exigir ($capturado[0] -notmatch 'SENTINELA')
        }
        Caso ($tipo + ' token stdout e aviso stderr exit zero') {
            $capturado = @(Invoke-S26Transporte (New-S26Comando 'teste-token' $programa ($prefixo + @('token'))) *>&1)
            Exigir ($capturado.Count -eq 1 -and $capturado[0] -ceq 'TOKEN_STDOUT_FICTICIO')
        }
        Caso ($tipo + ' exit nao zero sanitizado sem stdout stderr ou inner exception') {
            $erro = ''; $capturado = @()
            try { $capturado = @(Invoke-S26Transporte (New-S26Comando 'teste-falha' $programa ($prefixo + @('falha'))) *>&1) }
            catch { $erro = $_.Exception.ToString(); Exigir ($null -eq $_.Exception.InnerException) }
            Exigir ($erro.Contains('Operacao S-26 falhou [') -and $erro -like '*detalhes externos suprimidos*')
            Exigir ($erro -notmatch 'SENTINELA|TOKEN_STDOUT' -and $capturado.Count -eq 0)
        }
        Caso ($tipo + ' argumentos relevantes ao SDK permanecem inteiros') {
            $esperados = @('--project=ficticio','--rotulo=valor com espacos',
                '--cidrs=192.0.2.0/24,198.51.100.0/24','C:\Pasta ficticia\arquivo.json',
                'https://interno.ficticio.test/','--condition=None','--format=json')
            $saida = Invoke-S26Transporte (New-S26Comando 'teste-argv' $programa ($prefixo + @('argv') + $esperados))
            $recebidos = ConvertFrom-Json -InputObject $saida
            Exigir ($recebidos.Count -eq $esperados.Count)
            for ($i=0; $i -lt $esperados.Count; $i++) { Exigir ($recebidos[$i] -ceq $esperados[$i]) }
        }
        foreach ($preferencia in @('Stop','Continue')) {
            Caso ($tipo + ' preserva preferencias ' + $preferencia + ' em sucesso e falha') {
                $ErrorActionPreference = $preferencia
                $PSNativeCommandUseErrorActionPreference = $true
                $PSNativeCommandArgumentPassing = 'Legacy'
                $LASTEXITCODE = 123
                $null = Invoke-S26Transporte (New-S26Comando 'teste-pref' $programa ($prefixo + @('json')))
                Exigir ($ErrorActionPreference -ceq $preferencia -and $PSNativeCommandUseErrorActionPreference -eq $true)
                Exigir ($PSNativeCommandArgumentPassing -ceq 'Legacy' -and $LASTEXITCODE -eq 123)
                $falhou = $false
                try { Invoke-S26Transporte (New-S26Comando 'teste-pref-falha' $programa ($prefixo + @('falha'))) | Out-Null }
                catch { $falhou = $true }
                Exigir ($falhou -and $ErrorActionPreference -ceq $preferencia -and $PSNativeCommandUseErrorActionPreference -eq $true)
                Exigir ($PSNativeCommandArgumentPassing -ceq 'Legacy' -and $LASTEXITCODE -eq 123)
            }
        }
    }
    Caso 'restaura codigo global anterior em sucesso e falha' {
        $global:LASTEXITCODE = 479
        $null = Invoke-S26Transporte (New-S26Comando 'teste-global' $python @('-B',$fixture,'json'))
        Exigir ($global:LASTEXITCODE -eq 479)
        try { Invoke-S26Transporte (New-S26Comando 'teste-global-falha' $python @('-B',$fixture,'falha')) | Out-Null }
        catch { Exigir ($global:LASTEXITCODE -eq 479) }
        Exigir ($global:LASTEXITCODE -eq 479)
    }
    Caso 'mantem codigo global ausente em sucesso e falha' {
        Remove-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
        $null = Invoke-S26Transporte (New-S26Comando 'teste-global-ausente' $python @('-B',$fixture,'json'))
        Exigir ($null -eq (Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue))
        $falhou = $false
        try { Invoke-S26Transporte (New-S26Comando 'teste-global-ausente-falha' $python @('-B',$fixture,'falha')) | Out-Null }
        catch { $falhou = $true }
        Exigir ($falhou -and $null -eq (Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue))
    }
    Caso 'executavel ausente nao usa codigo anterior e nao vaza detalhes' {
        $LASTEXITCODE = 0; $erro = ''
        try { Invoke-S26Transporte (New-S26Comando 'teste-ausente' (Join-Path $pasta 'SENTINELA_AUSENTE.exe') @()) | Out-Null }
        catch { $erro = $_.Exception.ToString() }
        Exigir ($erro -like '*detalhes externos suprimidos*' -and $erro -notmatch 'SENTINELA')
    }
    Write-Output ('PASSOU: ' + $script:total + ' testes de processos nativos reais locais; PowerShell ' + $PSVersionTable.PSVersion + '; nenhum SDK/rede/segredo real.')
} finally {
    # Somente os arquivos ficticios criados aqui; sem remocao recursiva.
    if ([IO.File]::Exists($launcher)) { [IO.File]::Delete($launcher) }
    if ([IO.File]::Exists($fixture)) { [IO.File]::Delete($fixture) }
    if ([IO.Directory]::Exists($pasta)) { [IO.Directory]::Delete($pasta) }
}
