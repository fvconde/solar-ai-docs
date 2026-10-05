param([string]$Confirmacao, [switch]$Executar, [switch]$PeloLider, [string]$AprovacaoMaestro)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Planos.ps1')
Invoke-S26Plano (New-S26PlanoDesmontar -Confirmacao $Confirmacao) -Executar:$Executar -PeloLider:$PeloLider -AprovacaoMaestro $AprovacaoMaestro
