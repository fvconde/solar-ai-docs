param([hashtable]$Entradas, [hashtable]$VersoesSegredos, [string]$NumeroProjeto,
      [switch]$BootstrapPeersComprovado, [switch]$LiberarFrontPublico,
      [switch]$Executar, [switch]$PeloLider, [string]$AprovacaoMaestro)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Planos.ps1')
$plano = New-S26PlanoDeploy -Entradas $Entradas -VersoesSegredos $VersoesSegredos -NumeroProjeto $NumeroProjeto -BootstrapPeersComprovado:$BootstrapPeersComprovado -LiberarFrontPublico:$LiberarFrontPublico
Invoke-S26Plano $plano -Executar:$Executar -PeloLider:$PeloLider -AprovacaoMaestro $AprovacaoMaestro
