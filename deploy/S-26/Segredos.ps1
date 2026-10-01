# Sem -Executar, apenas devolve o plano. Execucao real: usuario no terminal
# do lider, depois da aprovacao do Maestro; valores somente via prompt protegido.
# Falha pode deixar usuario/versoes criados: nao repetir automaticamente.
param([switch]$Executar, [switch]$PeloLider, [switch]$UsuarioPresente, [string]$AprovacaoMaestro)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Segredos-Interno.ps1')
Invoke-S26Segredos -Executar:$Executar -PeloLider:$PeloLider -UsuarioPresente:$UsuarioPresente -AprovacaoMaestro $AprovacaoMaestro
