. (Join-Path $PSScriptRoot 'Planos.ps1')

function New-S26PlanoSegredos {
    $p = New-S26Plano 'Usuario-Sql-e-Versoes'
    Add-S26Preflight $p
    $c = $p.Contexto
    $p.Recursos += New-S26Recurso 'Sql' $c.Instancia 'Owned'
    foreach ($nome in ($c.SegredosApi + $c.SegredosAgente)) {
        $p.Recursos += New-S26Recurso 'Segredo' $nome 'Owned'
    }
    $p.EntradasProtegidas = @('Senha SQL solar_app','Chave Gemini','Usuario SMTP',
        'Senha de app SMTP','Remetente SMTP','Senha inicial supervisor','Chave de privacidade')
    $p.OperacoesProtegidas = @(
        [ordered]@{Metodo='POST'; Uri=('https://sqladmin.googleapis.com/v1/projects/' +
            $c.Projeto + '/instances/' + $c.Instancia + '/users'); Corpo='SOMENTE EM MEMORIA APOS Read-Host -AsSecureString'}
    )
    foreach ($nome in ($c.SegredosApi + $c.SegredosAgente)) {
        $p.OperacoesProtegidas += [ordered]@{Metodo='POST';Uri=('https://secretmanager.googleapis.com/v1/projects/' +
            $c.Projeto + '/secrets/' + $nome + ':addVersion'); Corpo='payload.data BASE64 SOMENTE EM MEMORIA'}
    }
    return $p
}
function ConvertFrom-S26SecureString([Security.SecureString]$Valor) {
    $ponteiro = [IntPtr]::Zero
    try {
        $ponteiro = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Valor)
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ponteiro)
    } finally {
        if ($ponteiro -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ponteiro) }
    }
}
function New-S26ConnectionString($Contexto, [string]$Senha) {
    # DbConnectionStringBuilder cita aspas/ponto-e-virgula corretamente.
    $builder = New-Object System.Data.Common.DbConnectionStringBuilder
    $builder['Host'] = '/cloudsql/' + $Contexto.Projeto + ':' + $Contexto.Regiao + ':' + $Contexto.Instancia
    $builder['Database'] = $Contexto.Banco
    $builder['Username'] = $Contexto.UsuarioSql
    $builder['Password'] = $Senha
    return $builder.ConnectionString
}
function Invoke-S26AdicionarVersao($Contexto, [string]$Nome, [string]$Valor, [scriptblock]$Executor) {
    $bytes = $null
    $corpo = $null
    $resposta = $null
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Valor)
        $corpo = @{payload=@{data=[Convert]::ToBase64String($bytes)}}
        $uri = 'https://secretmanager.googleapis.com/v1/projects/' + $Contexto.Projeto + '/secrets/' + $Nome + ':addVersion'
        $resposta = (Invoke-S26Transporte (New-S26Rest 'adicionar-versao-protegida' 'POST' $uri $corpo) $Executor) | ConvertFrom-Json
        # Google pode retornar numero do projeto; aceitar apenas o recurso pedido.
        $padrao = '\Aprojects/(?:' + [regex]::Escape($Contexto.Projeto) + '|[0-9]+)/secrets/' +
            [regex]::Escape($Nome) + '/versions/([1-9][0-9]*)\z'
        if ([string]$resposta.name -notmatch $padrao) { throw 'Referencia de versao invalida.' }
        return $Matches[1]
    } finally {
        if ($bytes) { [Array]::Clear($bytes, 0, $bytes.Length) }
        if ($corpo) { $corpo.payload.data = $null }
        $Valor = $null; $resposta = $null
    }
}
function Invoke-S26Segredos {
    param([switch]$Executar, [switch]$PeloLider, [switch]$UsuarioPresente,
          [string]$AprovacaoMaestro, [scriptblock]$Executor, [scriptblock]$LeitorProtegido)
    $plano = New-S26PlanoSegredos
    if (-not $Executar) { return $plano }
    Assert-S26Autorizacao -Executar -PeloLider:$PeloLider -AprovacaoMaestro $AprovacaoMaestro
    if (-not $UsuarioPresente) { throw 'Somente o usuario presente pode digitar os segredos.' }
    $c = $plano.Contexto
    $presentes = Assert-S26Recursos $plano $Executor
    foreach ($v in $plano.Verificacoes) { Invoke-S26Verificacao $c $v $Executor $presentes }
    $usuariosJson = Invoke-S26Transporte (New-S26Gcloud $c 'conferir-usuario-sql' @(
        'sql','users','list',('--instance=' + $c.Instancia))) $Executor
    if ([string]::IsNullOrWhiteSpace($usuariosJson) -or -not $usuariosJson.TrimStart().StartsWith('[')) {
        throw 'Inventario de usuarios SQL indeterminado.'
    }
    $usuarios = ConvertFrom-Json -InputObject $usuariosJson
    foreach ($usuario in $usuarios) {
        if ([string]::IsNullOrWhiteSpace([string](Get-S26Campo $usuario 'name'))) {
            throw 'Inventario de usuarios SQL indeterminado.'
        }
    }
    if (@($usuarios | Where-Object { $_.name -ceq $c.UsuarioSql }).Count) {
        throw 'Usuario SQL ja existe. Nao sobrescrever senha/adotar usuario; revisar recuperacao ou rotacao separadamente.'
    }
    $entradas = [ordered]@{}
    $nomes = [ordered]@{
        Sql='Senha SQL solar_app'
        'solar-gemini-api-key'='Chave Gemini'
        'solar-smtp-usuario'='Usuario SMTP'
        'solar-smtp-senha-app'='Senha de app SMTP'
        'solar-smtp-remetente'='Remetente SMTP'
        'solar-semente-senha-supervisor'='Senha inicial supervisor'
        'solar-chave-privacidade'='Chave de privacidade'
    }
    $sqlCorpo = $null; $senha = $null; $valor = $null; $conexao = $null
    try {
        # Todos os prompts antecedem a primeira escrita. Nao ha parametro plaintext.
        foreach ($nome in $nomes.Keys) {
            $seguro = if ($LeitorProtegido) { & $LeitorProtegido $nomes[$nome] } else {
                Read-Host -Prompt $nomes[$nome] -AsSecureString
            }
            if ($seguro -isnot [Security.SecureString] -or $seguro.Length -eq 0) {
                if ($seguro -is [Security.SecureString]) { $seguro.Dispose() }
                throw 'Entrada protegida ausente.'
            }
            $entradas[$nome] = $seguro
        }
        $senha = ConvertFrom-S26SecureString $entradas.Sql
        $sqlCorpo = @{name=$c.UsuarioSql;password=$senha;type='BUILT_IN'}
        $uriSql = 'https://sqladmin.googleapis.com/v1/projects/' + $c.Projeto + '/instances/' + $c.Instancia + '/users'
        $operacao = (Invoke-S26Transporte (New-S26Rest 'criar-usuario-sql-protegido' 'POST' $uriSql $sqlCorpo) $Executor) | ConvertFrom-Json
        $sqlCorpo.password = $null
        Invoke-S26EsperaSql $c $operacao $Executor
        $versoes = [ordered]@{}
        $conexao = New-S26ConnectionString $c $senha
        $versoes['solar-postgres-connection-string'] = Invoke-S26AdicionarVersao $c 'solar-postgres-connection-string' $conexao $Executor
        $conexao = $null; $senha = $null
        foreach ($nome in @($nomes.Keys | Where-Object { $_ -ne 'Sql' })) {
            $valor = ConvertFrom-S26SecureString $entradas[$nome]
            $versoes[$nome] = Invoke-S26AdicionarVersao $c $nome $valor $Executor
            $valor = $null
        }
        # Unica saida: nomes e NUMEROS das versoes; nunca payload nem REST bruto.
        return $versoes
    } catch {
        throw 'Gravacao de segredos interrompida; detalhes sensiveis suprimidos. Revisar estado parcial antes de repetir.'
    } finally {
        # Strings gerenciadas nao permitem zeragem garantida; reduzir referencias
        # e descartar SecureString nao equivale a apagar todas as copias da memoria.
        if ($sqlCorpo) { $sqlCorpo.password = $null }
        $senha = $null; $valor = $null; $conexao = $null
        foreach ($seguro in $entradas.Values) { $seguro.Dispose() }
        $entradas.Clear()
    }
}
