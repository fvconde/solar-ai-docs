# S-26 — passo C e guard UrlPublicada

Execucao 3bdd7f92-dda2-492e-a399-2e209a1e6238, 01/10/2026. Ordem: S-26-decisao-passo-C.md do Maestro. Duas frentes autorizadas; implementacao nova de producao nao utilizada na nuvem.

## Resultado remoto do passo C

- Novas criacoes depois de preflight e inventario de ausencia dos cinco nomes. Fonte do eco ae8342d134b1dbf858c7e45fd3f4fff0ce80cd89; transporte/configuracao e comandos copiados do docs 429acb46cfe93dc98f627e3533fe6f1c83b33159 limpo, com hashes iguais antes da escrita da Luna.
- Ultimo binding concluido no relogio local UTC 18:39:33.7341435. Sondagens iniciadas aos 60,93 s (borda502/interno403) e 120,56 s (borda200/interno200). A audiencia e o alvo continuaram deterministicas; nenhuma claim de token lida. URL hash/d1b nao usados.
- O resultado e compativel com propagacao IAM. Isso e uma inferencia, nao uma medicao da causa interna do Google; a documentacao informa que alteracoes de politica tipicamente levam cerca de dois minutos e podem demorar mais. [Propagacao IAM](https://docs.cloud.google.com/iam/docs/access-change-propagation).
- d1, d2 e d3: latestReadyRevisionName e trafego100% conferidos; reconferencia200 antes de medir d2/d3. Tres amostras encadeadas200 por rodada, com/sem XFF ficticio e com X-Serverless-Authorization. Mesmo gen2/ingress all/min0/max1; borda CPU por requisicao, interno por instancia.
- P1: peer TCP observado em ambas as fronteiras 169.254.169.126, nas nove amostras.
- P2/P3: XFF da borda preservado como prefixo no interno; uma entrada nova por chamada. Sem prefixo ficticio:1→2 entradas; com 203.0.113.41,198.51.100.42:3→4. IP do operador e entradas herdadas ocultados.
- **P3 inconclusivo:** a entrada nova nao foi classificada em cloud.json; o valor foi ocultado conservadoramente e nao persistido. Nao houve evidencia positiva de faixa compartilhada neste ensaio, nem prova de exclusividade. d2/d3 foram realizadas sob a condicao do passo C de seguir apos200, sem constatacao de faixa compartilhada. Nao preencher KnownProxies/KnownNetworks de producao a partir destas amostras.
- P4: nome x-serverless-authorization ausente na borda com Authorization e presente quando enviado pelo operador; presente no interno em todas as nove chamadas. Apenas nomes, nunca valores/claims. Forwarded tem um valor por fronteira, oculto; X-Forwarded-Proto=https.
- P5: interno anonimo403 e token do operador200 em cada rodada. Operador tem roles/owner direto no projeto; isso nao prova recusa de outra identidade restrita. Bindings diretos: somente operador→borda e SA borda→interno, conferidos a cada rodada; nenhuma permissao de projeto alterada.
- Os argumentos aprovados --no-allow-unauthenticated causaram SetIamPolicy implicito do SDK tambem em d2/d3: quatro eventos adicionais. Nao alegar ausencia de chamadas IAM nessas rodadas; membros permitidos permaneceram iguais nas verificacoes.
- Evidencia somente de timestamp/servico/status:32 HTTP (borda12×200+1×502; interno15×200+4×403). Sao19 sondagens externas e13 chamadas encadeadas. Admin Activity14 registros, sem codigo de erro:2 CreateService,4 ReplaceService,6 SetIamPolicy,2 DeleteService.
- Teardown no mesmo dia concluido; inventarios finais validos comprovam ausencia5/5. Janela do driver18:38:34.142–18:43:34.459 UTC,5,01min. Cobranca real nao consolidada/disponivel; sem declaracao de custo zero.
- APIs, helper Docker, imagem local e logs da plataforma permanecem conforme gate. Sem SQL, segredos, imagens da aplicacao, Deploy, Gemini, SMTP, IAM de projeto, chave de SA, Git push, PR, Notion ou merge.

## Desenho devolvido ao Maestro

A audiencia deterministica funcionou com token obtido por metadata e SA da borda; nao ha evidencia neste resultado para trocar as audiencias de producao por hash. O guard deve validar URLs anunciadas, conforme a frente local.

A prova de confianca do IP continua aberta. O peer link-local e a cadeia observada nao identificam exclusivamente a borda; a entrada nao classificada nao pode virar uma allow-list. Nenhum CIDR amplo ou /0 proposto. Antes de producao, definir uma fronteira autenticada que normalize o IP e prove sua proveniencia para a API, ou avaliar topologia com egress dedicado e repetir sua prova sob novo gate de custo. Cloud Run usa pool dinamico por padrao; egress estatico exige configuracao de rede propria. [Egress estatico Cloud Run](https://docs.cloud.google.com/run/docs/configuring/static-outbound-ip). A autenticação por identidade de serviço permanece um controle separado da proveniencia do IP. [Servico a servico](https://docs.cloud.google.com/run/docs/authenticating/service-to-service).

Nao houve deploy das aplicacoes; a normalizacao do nginx e o ForwardedHeaders real da API continuam pendentes. O diagnostico remoto encerrou suas tres rodadas e fez teardown; o desenho final permanece bloqueado, sem novo comando de nuvem autorizado.

## Frente local — revisao independente do lider

Commit da Luna 5017d9b03507526f9a028b469521dc673b48311e sobre 429acb46cfe93dc98f627e3533fe6f1c83b33159, feature/S-26. Escopo: Operacoes.ps1, novo Testar-Url-Publicada.ps1 e somente fixture de describe em Testar-Planos.ps1 (complemento autorizado pelo lider);203 insercoes/6 remocoes.

Guard aceita status.url com hash quando URL esperada e status.url constam exatamente em run.googleapis.com/urls. Exige metadata.name e marca s26-execucao exatas, array JSON de1..8 strings com origens HTTPS canonicas run.app, valida formato antes de converter. Sem normalizar URLs invalidas. Envelope JSON preserva arrays vazios/unitarios/aninhados nos dois shells; nao usa NoEnumerate em PS5.1. Falhas sanitizadas sem innerException.

O lider leu o diff integral abaixo e repetiu de forma independente, com -NoProfile -File e caminhos absolutos:

| Suite | PowerShell7.6.6 | Windows PowerShell5.1.26100.9444 |
| --- | --- | --- |
| Transporte nativo real local | 15/15 | 15/15 |
| Planos, executor ficticio | 17/17 | 17/17 |
| Segredos sinteticos | 33/33 | 33/33 |
| Configuracao-Producao | 133/133 | 133/133 |
| UrlPublicada, executor ficticio | 92/92 | 92/92 |
| Total | **290/290** | **290/290** |

Os92 casos incluem hash/lista deterministica, escapes/espacos JSON, limite de oito, lista ausente/malformada/comentarios/virgula final, JSON de tipo errado, origem de outro servico sem esperada, path/credenciais/port/query/fragmento/host invalido, nome/ownership divergentes, arrays unitarios em campos escalares e conferência exata do argv describe. Transporte real do SDK bloqueado nesta suite. Nenhuma devolucao ao implementador; fixture foi ampliado dentro do escopo de testes autorizado.

Worktree estava limpo antes da escrita deste relatorio; git diff 5017d9b^ 5017d9b --check sem erros. Sem alteracao em Planos.ps1, Deploy.ps1, eco, README, repos de aplicacao, configuracao de modelo ou recursos S-39. Nenhum gcloud/rede/nuvem pela frente local. O lider ja tinha carregado os dois scripts antigos congelados no processo C antes das edicoes da Luna.

**Revisao do Maestro pendente:** o aceite do lider e local. Nao usar a implementacao nova em nuvem antes da revisao do Maestro, como exigido na ordem. Criterios8 global,10 e11/conclusao do card nao foram encerrados por esta entrega.

Reproducao da revisao completa do commit:

```powershell
git -C 'C:/Users/felip/Documents/FIAP/Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS/solar/worktrees/S-26/solar-ai-docs' show 5017d9b03507526f9a028b469521dc673b48311e
git -C 'C:/Users/felip/Documents/FIAP/Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS/solar/worktrees/S-26/solar-ai-docs' diff 5017d9b^ 5017d9b --check
```


## Evidencia sanitizada do driver

O ramo de hash nao foi exercitado: a segunda sondagem ja retornou200. Durante revisao local posterior, o nome de parametro -NomeEsperado no ramo nao utilizado foi corrigido para -Nome; nenhum comando remoto foi repetido. Parser do driver e oito blocos aprovado antes da execucao; o comando inicial de parser teve expansao de variaveis pelo shell externo, corrigida usando arquivo -File antes de qualquer nuvem. Nenhum destes detalhes altera as medicoes executadas.


## Diff integral da frente local

```diff
diff --git a/deploy/S-26/Operacoes.ps1 b/deploy/S-26/Operacoes.ps1
index 320a547..0b2e6dc 100644
--- a/deploy/S-26/Operacoes.ps1
+++ b/deploy/S-26/Operacoes.ps1
@@ -273,11 +273,52 @@ function Invoke-S26Verificacao($Contexto, $Verificacao, [scriptblock]$Executor,
             if ([string]$projeto.projectNumber -cne $Verificacao.Numero) { throw 'Numero real do projeto diverge da entrada.' }
         }
         'UrlPublicada' {
-            $servico = (Invoke-S26Transporte (New-S26Gcloud $Contexto 'conferir-url-publicada' @(
-                'run','services','describe',$Verificacao.Servico,('--region=' + $Contexto.Regiao))) $Executor) | ConvertFrom-Json
-            $url = ConvertTo-S26OrigemHttps $servico.status.url
-            if ($url -cne $Verificacao.Url) {
-                throw 'status.url diverge da URL/audiencia fornecida. Manter privado e revisar configuracao.'
+            $recusa = 'status.url/URLs anunciadas ou nome/ownership invalidos. Manter privado e revisar configuracao.'
+            $jsonServico = Invoke-S26Transporte (New-S26Gcloud $Contexto 'conferir-url-publicada' @(
+                'run','services','describe',$Verificacao.Servico,('--region=' + $Contexto.Regiao))) $Executor
+            if ($jsonServico -isnot [string] -or -not $jsonServico.TrimStart().StartsWith('{')) { throw $recusa }
+            try { $servico = ConvertFrom-Json -InputObject $jsonServico -ErrorAction Stop }
+            catch { throw $recusa }
+            # Preservar o tipo original de cada campo (array unitario nao vira
+            # string/objeto escalar pela enumeracao do pipeline).
+            $campo = {
+                param($objeto, [string]$chave)
+                if ($objeto -isnot [pscustomobject]) { return }
+                $propriedade = $objeto.PSObject.Properties[$chave]
+                if ($null -ne $propriedade) { return ,$propriedade.Value }
+            }
+            $metadata = & $campo $servico 'metadata'
+            $nome = & $campo $metadata 'name'
+            $labels = & $campo $metadata 'labels'
+            $dono = & $campo $labels 's26-execucao'
+            if ($nome -isnot [string] -or $nome -cne $Verificacao.Servico -or
+                $dono -isnot [string] -or $dono -cne $Contexto.Execucao) { throw $recusa }
+            $annotations = & $campo $metadata 'annotations'
+            $jsonUrls = & $campo $annotations 'run.googleapis.com/urls'
+            # Schema restrito de JSON: array de strings (nao comentarios, tipos
+            # mistos ou virgula final aceitos por alguns parsers PowerShell).
+            $stringJson = '"(?:[^"\\\x00-\x1f]|\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4}))*"'
+            $espacoJson = '[ \t\r\n]*'
+            $arrayJson = '\A' + $espacoJson + '\[' + $espacoJson + '(?:' + $stringJson +
+                $espacoJson + '(?:,' + $espacoJson + $stringJson + $espacoJson + ')*)?\]' + $espacoJson + '\z'
+            if ($jsonUrls -isnot [string] -or $jsonUrls -cnotmatch $arrayJson) { throw $recusa }
+            try {
+                # Envelope preserva arrays vazios/unitarios/aninhados em 5.1 e 7,
+                # sem usar -NoEnumerate (inexistente no ConvertFrom-Json de 5.1).
+                $envelope = ConvertFrom-Json -InputObject ('{"urls":' + $jsonUrls + '}') -ErrorAction Stop
+                $urls = $envelope.urls
+            } catch { throw $recusa }
+            if ($urls -isnot [array] -or $urls.Count -lt 1 -or $urls.Count -gt 8) { throw $recusa }
+            $status = & $campo $servico 'status'
+            $statusUrl = & $campo $status 'url'
+            foreach ($url in @($Verificacao.Url, $statusUrl) + $urls) {
+                if ($url -isnot [string] -or $url -cnotmatch '\Ahttps://[a-z0-9-]+(?:\.[a-z0-9-]+)*\.run\.app\z') {
+                    throw $recusa
+                }
+                try { [void](ConvertTo-S26OrigemHttps $url) } catch { throw $recusa }
+            }
+            if ($Verificacao.Url -cnotin $urls -or $statusUrl -cnotin $urls) {
+                throw $recusa
             }
         }
         'Iam' {
diff --git a/deploy/S-26/Testar-Planos.ps1 b/deploy/S-26/Testar-Planos.ps1
index a66e6ae..d688d7c 100644
--- a/deploy/S-26/Testar-Planos.ps1
+++ b/deploy/S-26/Testar-Planos.ps1
@@ -39,7 +39,13 @@ $fake = {
         'iam-projeto' { return '{"bindings":[]}' }
         'numero-projeto' { return '{"projectNumber":"123456789012"}' }
         'conferir-url-publicada' {
-            return '{"status":{"url":"https://' + $a.Argumentos[3] + '-123456789012.southamerica-east1.run.app"}}'
+            $nome = $a.Argumentos[3]
+            $url = 'https://' + $nome + '-123456789012.southamerica-east1.run.app'
+            return ConvertTo-Json -InputObject @{
+                metadata=@{name=$nome;labels=@{'s26-execucao'=$ctx.Execucao};
+                    annotations=@{'run.googleapis.com/urls'=('[' + '"' + $url + '"]')}}
+                status=@{url=$url}
+            } -Depth 10 -Compress
         }
         default {
             if ($a.Id -like 'iam-*') { return '{"bindings":[]}' }
diff --git a/deploy/S-26/Testar-Url-Publicada.ps1 b/deploy/S-26/Testar-Url-Publicada.ps1
new file mode 100644
index 0000000..447b21e
--- /dev/null
+++ b/deploy/S-26/Testar-Url-Publicada.ps1
@@ -0,0 +1,150 @@
+$ErrorActionPreference = 'Stop'
+Set-StrictMode -Version Latest
+. (Join-Path $PSScriptRoot 'Operacoes.ps1')
+function Invoke-S26Nativo { throw 'Transporte real proibido na suite offline.' }
+$ctx = New-S26Contexto
+$esperada = 'https://solar-api-123456789012.southamerica-east1.run.app'
+$hash = 'https://solar-api-hashficticio-uc.a.run.app'
+$script:total = 0
+$script:chamadas = 0
+function Exigir([bool]$Condicao) {
+    if (-not $Condicao) { throw 'Assercao URL publicada falhou; dados omitidos.' }
+}
+function Caso([string]$Nome, [scriptblock]$Teste) {
+    try { & $Teste; $script:total++ }
+    catch { throw ('Caso ' + $Nome + ' falhou; dados omitidos.') }
+}
+function Servico-Valido {
+    return @{
+        metadata=@{name='solar-api';labels=@{'s26-execucao'=$ctx.Execucao};
+            annotations=@{'run.googleapis.com/urls'=('[' + '"' + $esperada + '","' + $hash + '"]')}}
+        status=@{url=$hash}
+    }
+}
+function Conferir($Servico, [bool]$Aceitar, [string]$UrlEsperada=$esperada) {
+    $script:jsonServico = ConvertTo-Json -InputObject $Servico -Depth 15 -Compress
+    Conferir-Json $Aceitar $UrlEsperada
+}
+function Conferir-Json([bool]$Aceitar, [string]$UrlEsperada=$esperada) {
+    $script:chamadas = 0
+    $fake = {
+        param($acao)
+        $script:chamadas++
+        Exigir ($acao.Id -ceq 'conferir-url-publicada' -and $acao.Tipo -ceq 'Comando')
+        Exigir ($acao.Programa -ceq $ctx.Gcloud)
+        $argv = @('run','services','describe','solar-api','--region=southamerica-east1',
+            '--project=solar-ai-cloud','--quiet','--format=json')
+        Exigir ($acao.Argumentos.Count -eq $argv.Count)
+        for ($i=0; $i -lt $argv.Count; $i++) { Exigir ($acao.Argumentos[$i] -ceq $argv[$i]) }
+        return $script:jsonServico
+    }
+    $verificacao = @{Tipo='UrlPublicada';Servico='solar-api';Url=$UrlEsperada}
+    $falhou=$false; $saida=@()
+    try { $saida=@(Invoke-S26Verificacao $ctx $verificacao $fake @{}) }
+    catch {
+        $falhou=$true
+        Exigir ($_.Exception.Message.Contains('status.url/URLs anunciadas'))
+        Exigir ($null -eq $_.Exception.InnerException)
+    }
+    Exigir ($falhou -eq (-not $Aceitar) -and $saida.Count -eq 0 -and $script:chamadas -eq 1)
+}
+
+Caso 'status com hash e deterministica anunciados' { Conferir (Servico-Valido) $true }
+Caso 'status deterministico e lista unitaria preservada' {
+    $s=Servico-Valido; $s.status.url=$esperada
+    $s.metadata.annotations['run.googleapis.com/urls']='["' + $esperada + '"]'
+    Conferir $s $true
+}
+Caso 'JSON com espacos e escape valido preserva origem exata' {
+    $s=Servico-Valido
+    $s.metadata.annotations['run.googleapis.com/urls']="[ `n" + '"' + $esperada.Replace('https://','https:\/\/') + '","' + $hash + '"' + "`n ]"
+    Conferir $s $true
+}
+Caso 'oito origens validas anunciadas' {
+    $s=Servico-Valido
+    $urls=@($esperada,$hash) + @(1..6 | ForEach-Object {'https://alias-' + $_ + '.run.app'})
+    $s.metadata.annotations['run.googleapis.com/urls']=ConvertTo-Json -InputObject $urls -Compress
+    Conferir $s $true
+}
+foreach ($lista in @($null,'',' ','[]','{}','null','"origem"','[invalido]',
+    '[null]','[1]','[true]', ('[["' + $esperada + '"]]'),
+    ('["' + $esperada + '",null]'), ('["' + $esperada + '",]'),
+    ('[/*comentario*/"' + $esperada + '"]'))) {
+    Caso 'lista ausente ou JSON/schema invalido recusado' {
+        $s=Servico-Valido; $s.metadata.annotations['run.googleapis.com/urls']=$lista
+        Conferir $s $false
+    }
+}
+Caso 'mais de oito origens recusadas' {
+    $s=Servico-Valido
+    $urls=@($esperada,$hash) + @(1..7 | ForEach-Object {'https://alias-' + $_ + '.run.app'})
+    $s.metadata.annotations['run.googleapis.com/urls']=ConvertTo-Json -InputObject $urls -Compress
+    Conferir $s $false
+}
+Caso 'deterministica ausente da lista' {
+    $s=Servico-Valido; $s.metadata.annotations['run.googleapis.com/urls']='["' + $hash + '"]'
+    Conferir $s $false
+}
+Caso 'status ausente da lista' {
+    $s=Servico-Valido; $s.metadata.annotations['run.googleapis.com/urls']='["' + $esperada + '"]'
+    Conferir $s $false
+}
+Caso 'origens de outro servico nao substituem esperada' {
+    $s=Servico-Valido; $s.status.url='https://solar-front-hashficticio.a.run.app'
+    $s.metadata.annotations['run.googleapis.com/urls']='["https://solar-front-123456789012.southamerica-east1.run.app","https://solar-front-hashficticio.a.run.app"]'
+    Conferir $s $false
+}
+foreach ($nome in @($null,'','solar-front','Solar-api',@('solar-api'))) {
+    Caso 'nome ausente diferente ou tipo invalido recusado' {
+        $s=Servico-Valido; $s.metadata.name=$nome; Conferir $s $false
+    }
+}
+foreach ($dono in @($null,'','outra-execucao',$ctx.Execucao.ToUpperInvariant(),@($ctx.Execucao))) {
+    Caso 'ownership ausente divergente ou tipo invalido recusado' {
+        $s=Servico-Valido; $s.metadata.labels['s26-execucao']=$dono; Conferir $s $false
+    }
+}
+foreach ($url in @('http://solar-api.run.app','https://solar-api.run.app/caminho',
+    'https://usuario:senha@solar-api.run.app','https://solar-api.run.app/',
+    'https://solar-api.run.app:443','https://Solar-api.run.app','https://solar-api.run.app?x=1',
+    'https://solar-api.run.app#fragmento','https://solar-api.run.app.evil.test',
+    'https://solar-api.test','https://-solar-api.run.app','https://solar-api-.run.app',
+    'https://solar-api..run.app','https://solar-api%2e.run.app','https://solar-api.run.app\caminho')) {
+    Caso 'item anunciado nao canonico recusado mesmo com esperada e status validos' {
+        $s=Servico-Valido
+        $s.metadata.annotations['run.googleapis.com/urls']=ConvertTo-Json -InputObject @($esperada,$hash,$url) -Compress
+        Conferir $s $false
+    }
+    Caso 'status invalido nao e normalizado' {
+        $s=Servico-Valido; $s.status.url=$url; Conferir $s $false
+    }
+    Caso 'URL esperada invalida nao e normalizada' { Conferir (Servico-Valido) $false $url }
+}
+Caso 'metadata ausente recusada' { Conferir @{status=@{url=$hash}} $false }
+Caso 'ownership fora de metadata nao e adotado' {
+    $s=Servico-Valido; $s.metadata.Remove('labels'); $s.labels=@{'s26-execucao'=$ctx.Execucao}
+    Conferir $s $false
+}
+Caso 'annotations ausentes recusadas' {
+    $s=Servico-Valido; $s.metadata.Remove('annotations'); Conferir $s $false
+}
+Caso 'status ausente recusado' { $s=Servico-Valido; $s.Remove('status'); Conferir $s $false }
+foreach ($campoArray in @('metadata','labels','annotations','status.url','lista')) {
+    Caso ('array unitario no campo ' + $campoArray + ' nao vira escalar') {
+        $s=Servico-Valido
+        switch ($campoArray) {
+            'metadata' { $s.metadata=@($s.metadata) }
+            'labels' { $s.metadata.labels=@($s.metadata.labels) }
+            'annotations' { $s.metadata.annotations=@($s.metadata.annotations) }
+            'status.url' { $s.status.url=@($s.status.url) }
+            'lista' { $s.metadata.annotations['run.googleapis.com/urls']=@($s.metadata.annotations['run.googleapis.com/urls']) }
+        }
+        Conferir $s $false
+    }
+}
+foreach ($json in @('','null','[]','[{}]','{invalido}')) {
+    Caso 'describe indeterminado ou JSON errado recusado' {
+        $script:jsonServico=$json; Conferir-Json $false
+    }
+}
+Write-Output ('PASSOU: ' + $script:total + ' casos UrlPublicada via transporte fake; PowerShell ' + $PSVersionTable.PSVersion + '; zero SDK/rede/nuvem.')

```

## Anexo: observacoes sanitizadas da execucao

```text
# S-26 — passo C: propagacao IAM e audiencia

Execucao 3bdd7f92-dda2-492e-a399-2e209a1e6238, 01/10/2026. Passo C autorizado pelo Maestro em S-26-decisao-passo-C.md. Transporte e configuracao copiados byte a byte de 429acb46cfe93dc98f627e3533fe6f1c83b33159, limpo antes da copia; guard de producao novo nao carregado. Eco ae8342d134b1dbf858c7e45fd3f4fff0ce80cd89.
Nenhum IP do operador ou token neste arquivo. Entradas herdadas da borda ocultadas conservadoramente; nomes de headers apenas, sem valores de auth/cookie.
- Preflight reconferido; conta de usuario/projeto corretos, identificador omitido. APIs ja habilitadas na etapa anterior.
Passos A/B: guard local corrigido apenas no diagnostico; B pronto, tres borda502/interno403 13,6 s apos binding. C espera ate dez minutos; nao usa nova implementacao UrlPublicada.
Papeis diretos do operador no projeto: roles/owner. Heranca completa nao provada; nenhuma politica de projeto/pasta/organizacao alterada.
- Inventarios validos, cinco nomes ausentes e codigo eco/branch/worktree conferidos.
- Registro diagnostico exclusivo criado.
- Duas SAs diagnosticas criadas com marca em description; nenhuma chave criada.
- Build da imagem exclusiva do eco concluido.
Imagem publicada: southamerica-east1-docker.pkg.dev/solar-ai-cloud/solar-s26-diag-3bdd7f92/eco@sha256:dcfa8fb340a40be72ffda43277064f645bee490b075e04260e1aadd1ba6b4f39.
- Push do eco concluido; digest capturado, nenhuma imagem da aplicacao.
Ultimo binding concluido UTC 2026-10-01T18:39:33.7341435Z.
- Rodada d1 implantada com duas fronteiras privadas e bindings por servico.
Servico s26-diag-borda: revisao s26-diag-borda-d1, Ready=True, trafego100%; URL https://s26-diag-borda-4or3sjeksq-rj.a.run.app; execucao gen2, CPU throttling true, min 0 (padrao), max 1; ingress all; SA exclusiva e IAM direto conferidos. Env nao secreto: DIAG_MODE=encadear; DIAG_INTERNAL_URL=https://s26-diag-interno-935010665676.southamerica-east1.run.app.
Servico s26-diag-interno: revisao s26-diag-interno-d1, Ready=True, trafego100%; URL https://s26-diag-interno-4or3sjeksq-rj.a.run.app; execucao gen2, CPU throttling false, min 0 (padrao), max 1; ingress all; SA exclusiva e IAM direto conferidos. Env nao secreto: DIAG_MODE=eco.
- Sonda IAM 1/10 UTC 2026-10-01T18:40:34.6595107Z: borda HTTP 502.
- Sonda IAM 2/10 UTC 2026-10-01T18:41:34.2990479Z: borda HTTP 200.
Primeiro 200 encadeado: 120.56 s desde o ultimo binding.
- Medicao P1-P5 d1.

## P1–P5 e condicao de parada
Amostra sem-prefixo: HTTP borda 200.
P1/P2/P3 sem-prefixo: peer borda 169.254.169.126; XFF borda ["<operador/ou herdado>"] (1 entradas); peer interno 169.254.169.126; XFF interno ["<operador/ou herdado>","<egress sem classificacao>"] (2 entradas); prefixo borda preservado=True; novas entradas=1.
P4 sem-prefixo: nome x-serverless-authorization na borda=False, no interno=True. Valores jamais inspecionados/exportados. Forwarded: 1/1 valores (ocultos); X-Forwarded-Proto: https/https.
Amostra prefixo-forjado: HTTP borda 200.
P1/P2/P3 prefixo-forjado: peer borda 169.254.169.126; XFF borda ["203.0.113.41","198.51.100.42","<operador/ou herdado>"] (3 entradas); peer interno 169.254.169.126; XFF interno ["203.0.113.41","198.51.100.42","<operador/ou herdado>","<egress sem classificacao>"] (4 entradas); prefixo borda preservado=True; novas entradas=1.
P4 prefixo-forjado: nome x-serverless-authorization na borda=False, no interno=True. Valores jamais inspecionados/exportados. Forwarded: 1/1 valores (ocultos); X-Forwarded-Proto: https/https.
Amostra header-serverless: HTTP borda 200.
P1/P2/P3 header-serverless: peer borda 169.254.169.126; XFF borda ["<operador/ou herdado>"] (1 entradas); peer interno 169.254.169.126; XFF interno ["<operador/ou herdado>","<egress sem classificacao>"] (2 entradas); prefixo borda preservado=True; novas entradas=1.
P4 header-serverless: nome x-serverless-authorization na borda=True, no interno=True. Valores jamais inspecionados/exportados. Forwarded: 1/1 valores (ocultos); X-Forwarded-Proto: https/https.
P5: interno direto anonimo HTTP 403; token do operador HTTP 200. Operador tem roles/owner direto; nao adicionado ao IAM direto do interno e nenhuma permissao herdada alterada.
Catalogo: [cloud.json](https://www.gstatic.com/ipranges/cloud.json), creationTime 10/01/2026 07:08:35.
Rodada d1: tres observacoes validas por fronteira; P5 anonimo=403, operador=200.
- Reconferencia d2: borda HTTP 200.
- Medicao P1-P5 d2.

## P1–P5 e condicao de parada
Amostra sem-prefixo: HTTP borda 200.
P1/P2/P3 sem-prefixo: peer borda 169.254.169.126; XFF borda ["<operador/ou herdado>"] (1 entradas); peer interno 169.254.169.126; XFF interno ["<operador/ou herdado>","<egress sem classificacao>"] (2 entradas); prefixo borda preservado=True; novas entradas=1.
P4 sem-prefixo: nome x-serverless-authorization na borda=False, no interno=True. Valores jamais inspecionados/exportados. Forwarded: 1/1 valores (ocultos); X-Forwarded-Proto: https/https.
Amostra prefixo-forjado: HTTP borda 200.
P1/P2/P3 prefixo-forjado: peer borda 169.254.169.126; XFF borda ["203.0.113.41","198.51.100.42","<operador/ou herdado>"] (3 entradas); peer interno 169.254.169.126; XFF interno ["203.0.113.41","198.51.100.42","<operador/ou herdado>","<egress sem classificacao>"] (4 entradas); prefixo borda preservado=True; novas entradas=1.
P4 prefixo-forjado: nome x-serverless-authorization na borda=False, no interno=True. Valores jamais inspecionados/exportados. Forwarded: 1/1 valores (ocultos); X-Forwarded-Proto: https/https.
Amostra header-serverless: HTTP borda 200.
P1/P2/P3 header-serverless: peer borda 169.254.169.126; XFF borda ["<operador/ou herdado>"] (1 entradas); peer interno 169.254.169.126; XFF interno ["<operador/ou herdado>","<egress sem classificacao>"] (2 entradas); prefixo borda preservado=True; novas entradas=1.
P4 header-serverless: nome x-serverless-authorization na borda=True, no interno=True. Valores jamais inspecionados/exportados. Forwarded: 1/1 valores (ocultos); X-Forwarded-Proto: https/https.
P5: interno direto anonimo HTTP 403; token do operador HTTP 200. Operador tem roles/owner direto; nao adicionado ao IAM direto do interno e nenhuma permissao herdada alterada.
Catalogo: [cloud.json](https://www.gstatic.com/ipranges/cloud.json), creationTime 10/01/2026 07:08:35.
Rodada d2: tres observacoes validas por fronteira; P5 anonimo=403, operador=200.
- Reconferencia d3: borda HTTP 200.
- Medicao P1-P5 d3.

## P1–P5 e condicao de parada
Amostra sem-prefixo: HTTP borda 200.
P1/P2/P3 sem-prefixo: peer borda 169.254.169.126; XFF borda ["<operador/ou herdado>"] (1 entradas); peer interno 169.254.169.126; XFF interno ["<operador/ou herdado>","<egress sem classificacao>"] (2 entradas); prefixo borda preservado=True; novas entradas=1.
P4 sem-prefixo: nome x-serverless-authorization na borda=False, no interno=True. Valores jamais inspecionados/exportados. Forwarded: 1/1 valores (ocultos); X-Forwarded-Proto: https/https.
Amostra prefixo-forjado: HTTP borda 200.
P1/P2/P3 prefixo-forjado: peer borda 169.254.169.126; XFF borda ["203.0.113.41","198.51.100.42","<operador/ou herdado>"] (3 entradas); peer interno 169.254.169.126; XFF interno ["203.0.113.41","198.51.100.42","<operador/ou herdado>","<egress sem classificacao>"] (4 entradas); prefixo borda preservado=True; novas entradas=1.
P4 prefixo-forjado: nome x-serverless-authorization na borda=False, no interno=True. Valores jamais inspecionados/exportados. Forwarded: 1/1 valores (ocultos); X-Forwarded-Proto: https/https.
Amostra header-serverless: HTTP borda 200.
P1/P2/P3 header-serverless: peer borda 169.254.169.126; XFF borda ["<operador/ou herdado>"] (1 entradas); peer interno 169.254.169.126; XFF interno ["<operador/ou herdado>","<egress sem classificacao>"] (2 entradas); prefixo borda preservado=True; novas entradas=1.
P4 header-serverless: nome x-serverless-authorization na borda=True, no interno=True. Valores jamais inspecionados/exportados. Forwarded: 1/1 valores (ocultos); X-Forwarded-Proto: https/https.
P5: interno direto anonimo HTTP 403; token do operador HTTP 200. Operador tem roles/owner direto; nao adicionado ao IAM direto do interno e nenhuma permissao herdada alterada.
Catalogo: [cloud.json](https://www.gstatic.com/ipranges/cloud.json), creationTime 10/01/2026 07:08:35.
Rodada d3: tres observacoes validas por fronteira; P5 anonimo=403, operador=200.
Requests externos de diagnostico: 19. Sondagens IAM limitadas a dez; teste hash unico, ate tres sondagens; tokens somente RAM.

## Teardown no mesmo dia
- Removido recurso exclusivo s26-diag-borda.
- Removido recurso exclusivo s26-diag-interno.
- Removido recurso exclusivo s26-diag-borda-3bdd7f92.
- Removido recurso exclusivo s26-diag-interno-3bdd7f92.
- Removido recurso exclusivo solar-s26-diag-3bdd7f92.
- Inventarios finais validos: ausencia dos dois servicos, duas SAs e registro diag confirmada (5/5). Bindings invoker dos servicos removidos com os servicos.

## Duracao, custo e limites
Inicio UTC 2026-10-01T18:38:34.1420273Z; fim UTC 2026-10-01T18:43:34.4590555Z; duracao 5.01 min. Cobranca efetiva ainda nao consolidada/disponivel; nao declarar zero. CPU por instancia do interno e armazenamento/trafego do registry podem ser cobrados ate a remocao.
APIs permanecem habilitadas; credential helper Docker e imagem local do eco permanecem. Logs Cloud Run retêm IP do operador por30dias; teardown nao os apaga. Eco sem logs de aplicacao; nenhum log bruto coletado.
Sem SQL/segredos/imagens da aplicacao/Deploy/Gemini/SMTP, sem IAM de projeto, sem chave de SA, sem push de Git/PR/Notion/merge. Pin gen2 no Deploy.ps1 e desenho final pendentes de gate proprio.
Estado: medicoes d1/d2/d3 concluidas; confianca no IP pendente; cinco recursos diagnosticos removidos.
```

## Anexo: projecao de auditoria e status

Somente campos enumerados; nenhuma identidade, callerIp, requestMetadata, token, header ou corpo.

```json
{
  "Requests": [
    {
      "Utc": "2026-10-01T18:40:37.175339Z",
      "Servico": "s26-diag-borda",
      "Status": 502
    },
    {
      "Utc": "2026-10-01T18:40:37.448512Z",
      "Servico": "s26-diag-interno",
      "Status": 403
    },
    {
      "Utc": "2026-10-01T18:41:36.592077Z",
      "Servico": "s26-diag-borda",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:41:36.803904Z",
      "Servico": "s26-diag-interno",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:41:38.559067Z",
      "Servico": "s26-diag-borda",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:41:38.764471Z",
      "Servico": "s26-diag-interno",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:41:38.853307Z",
      "Servico": "s26-diag-borda",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:41:38.916836Z",
      "Servico": "s26-diag-interno",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:41:38.998709Z",
      "Servico": "s26-diag-borda",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:41:39.198482Z",
      "Servico": "s26-diag-interno",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:41:39.361895Z",
      "Servico": "s26-diag-interno",
      "Status": 403
    },
    {
      "Utc": "2026-10-01T18:41:39.679893Z",
      "Servico": "s26-diag-interno",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:42:10.526188Z",
      "Servico": "s26-diag-borda",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:42:10.802079Z",
      "Servico": "s26-diag-interno",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:42:12.2626Z",
      "Servico": "s26-diag-borda",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:42:12.462765Z",
      "Servico": "s26-diag-interno",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:42:12.552302Z",
      "Servico": "s26-diag-borda",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:42:12.620415Z",
      "Servico": "s26-diag-interno",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:42:12.705603Z",
      "Servico": "s26-diag-borda",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:42:12.770698Z",
      "Servico": "s26-diag-interno",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:42:12.924662Z",
      "Servico": "s26-diag-interno",
      "Status": 403
    },
    {
      "Utc": "2026-10-01T18:42:13.211542Z",
      "Servico": "s26-diag-interno",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:42:45.378563Z",
      "Servico": "s26-diag-borda",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:42:45.679947Z",
      "Servico": "s26-diag-interno",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:42:47.170713Z",
      "Servico": "s26-diag-borda",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:42:47.368014Z",
      "Servico": "s26-diag-interno",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:42:47.461391Z",
      "Servico": "s26-diag-borda",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:42:47.530394Z",
      "Servico": "s26-diag-interno",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:42:47.614471Z",
      "Servico": "s26-diag-borda",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:42:47.704977Z",
      "Servico": "s26-diag-interno",
      "Status": 200
    },
    {
      "Utc": "2026-10-01T18:42:47.791859Z",
      "Servico": "s26-diag-interno",
      "Status": 403
    },
    {
      "Utc": "2026-10-01T18:42:48.08027Z",
      "Servico": "s26-diag-interno",
      "Status": 200
    }
  ],
  "Admin": [
    {
      "Utc": "2026-10-01T18:39:15.470062Z",
      "Metodo": "google.cloud.run.v1.Services.CreateService",
      "Recurso": "namespaces/solar-ai-cloud/services/s26-diag-interno",
      "Codigo": null
    },
    {
      "Utc": "2026-10-01T18:39:23.882753Z",
      "Metodo": "google.cloud.run.v1.Services.CreateService",
      "Recurso": "namespaces/solar-ai-cloud/services/s26-diag-borda",
      "Codigo": null
    },
    {
      "Utc": "2026-10-01T18:39:32.503432Z",
      "Metodo": "google.cloud.run.v1.Services.SetIamPolicy",
      "Recurso": "projects/solar-ai-cloud/locations/southamerica-east1/services/s26-diag-borda",
      "Codigo": null
    },
    {
      "Utc": "2026-10-01T18:39:35.175338Z",
      "Metodo": "google.cloud.run.v1.Services.SetIamPolicy",
      "Recurso": "projects/solar-ai-cloud/locations/southamerica-east1/services/s26-diag-interno",
      "Codigo": null
    },
    {
      "Utc": "2026-10-01T18:41:42.970861Z",
      "Metodo": "google.cloud.run.v1.Services.ReplaceService",
      "Recurso": "namespaces/solar-ai-cloud/services/s26-diag-interno",
      "Codigo": null
    },
    {
      "Utc": "2026-10-01T18:41:43.988719Z",
      "Metodo": "google.cloud.run.v1.Services.SetIamPolicy",
      "Recurso": "projects/solar-ai-cloud/locations/southamerica-east1/services/s26-diag-interno",
      "Codigo": null
    },
    {
      "Utc": "2026-10-01T18:41:52.112127Z",
      "Metodo": "google.cloud.run.v1.Services.ReplaceService",
      "Recurso": "namespaces/solar-ai-cloud/services/s26-diag-borda",
      "Codigo": null
    },
    {
      "Utc": "2026-10-01T18:41:53.18209Z",
      "Metodo": "google.cloud.run.v1.Services.SetIamPolicy",
      "Recurso": "projects/solar-ai-cloud/locations/southamerica-east1/services/s26-diag-borda",
      "Codigo": null
    },
    {
      "Utc": "2026-10-01T18:42:15.967592Z",
      "Metodo": "google.cloud.run.v1.Services.ReplaceService",
      "Recurso": "namespaces/solar-ai-cloud/services/s26-diag-interno",
      "Codigo": null
    },
    {
      "Utc": "2026-10-01T18:42:17.088652Z",
      "Metodo": "google.cloud.run.v1.Services.SetIamPolicy",
      "Recurso": "projects/solar-ai-cloud/locations/southamerica-east1/services/s26-diag-interno",
      "Codigo": null
    },
    {
      "Utc": "2026-10-01T18:42:26.359485Z",
      "Metodo": "google.cloud.run.v1.Services.ReplaceService",
      "Recurso": "namespaces/solar-ai-cloud/services/s26-diag-borda",
      "Codigo": null
    },
    {
      "Utc": "2026-10-01T18:42:27.381663Z",
      "Metodo": "google.cloud.run.v1.Services.SetIamPolicy",
      "Recurso": "projects/solar-ai-cloud/locations/southamerica-east1/services/s26-diag-borda",
      "Codigo": null
    },
    {
      "Utc": "2026-10-01T18:42:54.683733Z",
      "Metodo": "google.cloud.run.v1.Services.DeleteService",
      "Recurso": "namespaces/solar-ai-cloud/services/s26-diag-borda",
      "Codigo": null
    },
    {
      "Utc": "2026-10-01T18:43:04.399363Z",
      "Metodo": "google.cloud.run.v1.Services.DeleteService",
      "Recurso": "namespaces/solar-ai-cloud/services/s26-diag-interno",
      "Codigo": null
    }
  ]
}
```
