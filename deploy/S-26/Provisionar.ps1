param([ValidateSet('Apis','Recursos')][string]$Etapa='Recursos',
      [switch]$Executar, [switch]$PeloLider, [string]$AprovacaoMaestro)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Planos.ps1')
Invoke-S26Plano (New-S26PlanoProvisionar -Etapa $Etapa) -Executar:$Executar -PeloLider:$PeloLider -AprovacaoMaestro $AprovacaoMaestro
