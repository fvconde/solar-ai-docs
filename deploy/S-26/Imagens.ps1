param([hashtable]$Shas, [switch]$Executar, [switch]$PeloLider, [string]$AprovacaoMaestro)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Planos.ps1')
Invoke-S26Plano (New-S26PlanoImagens -Shas $Shas) -Executar:$Executar -PeloLider:$PeloLider -AprovacaoMaestro $AprovacaoMaestro
