# S-26 — implementação local do desenho de IP

Execução: 3bdd7f92-dda2-492e-a399-2e209a1e6238. Data: 01/10/2026.
Líder: Codex S-26. Implementador: Codex S-26 Luna.
Escopo: decisão de desenho de IP aprovada pelo Maestro, incluindo as duas clarificações sobre IAM e a linha do Program.cs.

## Estado

Implementação local para revisão do Maestro. Nenhuma nuvem, gcloud/Google Cloud SDK real, Gemini, SMTP real, push, PR ou merge nesta etapa. Nenhum segredo foi impresso ou gravado; a repetição aprovada dos testes usa somente fixtures fictícias. Diagnóstico remoto anterior encerrado com teardown5/5, conforme passo C; não foi repetido. Próximo gate: aprovação de custo pelo usuário para Provisionar -Etapa Recursos, ainda não dada. Aceite global dos critérios2/8/9/10/11 e do card depende das provas de produção restantes.

## Commits e diff

| Repositório | Commit | Arquivos |
|---|---|---|
| API | 87c491bf88d7ba94be284cdf08ab1ae4efa17724 | ConfiancaDeProxies.cs, ForwardedHeadersHttpTeste.cs e uma linha autorizada Program.cs |
| Front | af366c0672c625b9fbe01cfe1832d343f4a6f6d3 | nginx.conf.template, test_front.py, smoke_docker.py e um campo em fake_backend.py |
| Agente | 56ff8e09e616be2a6c2b5bf59cd08d7d1b0662b8 | Sem alteração nesta etapa |
| Docs — runbook | 8b0dec1a505d85c76cde87ca3e1ff51385a14bb4 | README.md |
| Docs — planos/IAM | 18953c173804283daa1b1228e022a1e7114f7334 | Configuracao-Producao.ps1, Planos.ps1, Operacoes.ps1, Espera-Iam.ps1 e três suites |
| Docs — correção do prazo nativo | 7b6afa5467a8fffd8c3c54c7331cd5bbe9c8afed | Espera-Iam.ps1 e Testar-Espera-Iam.ps1 |

Líder leu os diffs integrais das entregas. Correção também lida integralmente, incluindo interop, stdout, herança restrita de handles, encerramento da árvore e fixtures. Uma devolução dos scripts: prazo inicialmente não encerrava o processo nativo de leitura do token; correção e prova local de timeout descritas abaixo. Nenhuma devolução de API/front nesta etapa; líder não corrigiu código do implementador. Mesma Luna, sem alteração de modelo. Quatro branches feature/S-26; limpeza/check reconferidos ao fechar o commit documental. Diff contra origin/develop sem contratos/migrations/consentimento/privacidade/expurgo/ESTADO/ARQUITETURA. Program.cs altera somente Configure para Registrar; hunk S-39 intacto.

## Desenho aplicado

- API: allow-list exata de ProxyTrust:ForwardedForHeaderName: X-Forwarded-For padrão ou X-Solar-Client-IP. Registrar mantém configuração anterior e registra IStartupFilter somente no modo próprio. Filtro remove header inválido, vírgula, linhas repetidas e espaços; conserva o peer e não produz400 nem log de valor. IPv6 válido aceito; peer desconhecido não ganha confiança. Modo XFF anterior comprovado; rate limit usa o IP aceito.
- Nginx: sobrescreve X-Solar-Client-IP com $client_ip normalizado; mantém XFF e os demais clears/rotas. Cliente não pode escolher esse header na passagem pelo front.
- Produção fixa, sem entradas livres: front 169.254.169.126/32 e um salto; API KnownProxies__0=169.254.169.126, ForwardLimit=1, ForwardedForHeaderName=X-Solar-Client-IP. Nenhuma KnownIPNetworks na configuração gerada. Todos os três comandos de deploy usam --execution-environment=gen2.
- Evidência aprovada do passo C sustenta somente o peer TCP link-local e a última entrada do XFF recebida no front. A API confia no header sobrescrito e na fronteira IAM: SA front invoca API; SA API invoca agente. Egress da chamada front→API não é allow-list de IP do cliente.
- Limite aceito: owners/administradores autorizados do projeto podem invocar diretamente e forjar o header. IAM por serviço limita identidades ordinárias; não impede o owner. Mudança do peer observado na aplicação real exige parada e devolução ao Maestro, sem ampliar confiança.

## Espera IAM

Binding do agente aplicado antes do binding da API. Sonda privada com token do operador só em memória e sem cookie: GET /api/sessao no front, esperando401 JSON codigo=sessao_invalida da aplicação. Primeira após60s;403/502 podem repetir com intervalo60s, no máximo dez sondas e prazo de600s incluindo latência. Redirect, status inesperado, TLS/transporte ou JSON inválido interrompem com erro sanitizado, sem publicação. HTTP sem redirects/cookies, TLS padrão e corpo limitado8KiB. Token e HTTP compartilham orçamento máximo20s dentro do deadline total. Helper exclusivo Windows, sem alterar Invoke-S26Nativo geral: processo suspenso associado a Job Object antes de executar, somente handles stdout/NUL herdados, stdout limitado32KiB em RAM e stderr NUL; ao esgotar o prazo, encerra e confere somente a árvore criada, com reserva de tempo para cleanup.

Após sucesso front→API, esperar apenas o restante até cinco minutos desde o binding do agente. Sem endpoint/rota nova, sonda de agente ou impersonação. Espera temporal não prova API→agente. Essa prova continua no primeiro turno real da seção10, sob gate de cota: em502, somente uma tentativa adicional após dois minutos; nova falha exige parada. Custo Gemini zero somente se evidência confirmar recusa IAM anterior à execução do agente;502 isolado não permite essa conclusão nem comprova ausência de efeitos na API.

## Validação independente do líder

| Validação | Resultado final |
|---|---|
| API completa, Postgres16 dedicado | 196/196, zero falhas/ignorados |
| API forwarding focado | 28/28 |
| Front Angular ChromeHeadless154 | 219/219 |
| Build Angular | 1/1 |
| Agente .venv, pytest padrão sem LLM | 257 passed,38 deselected,31 warnings |
| Front deploy, pytest .venv | 17/17 |
| Smoke Docker | 8/8, API runtime87c491b e front af366c0 |
| Transporte nativo PS7/PS5.1 | 15/15 em cada versão |
| Planos PS7/PS5.1 | 17/17 em cada versão |
| Segredos PS7/PS5.1 | 33/33 em cada versão |
| Configuração PS7/PS5.1 | 82/82 em cada versão |
| URLs publicadas PS7/PS5.1 | 92/92 em cada versão |
| Espera IAM PS7/PS5.1 | 85/85 em cada versão; 324/324 somando as seis suites por versão |
| Runbook parser | 11/11 em cada PowerShell |
| Runbook parâmetros | 12 chamadas em cada PowerShell |
| Runbook planos | 5/5 offline em cada PowerShell |

Contagens: API178→196, +18 casos; forwarding10→28. Front deploy16→17, smoke7→8. Configuração133→82:55 cenários dependentes das quatro entradas removidas substituídos por quatro recusas dessas entradas; mapas constantes conferidos integralmente. Planos continuam17 com novos asserts. IAM 85 (58 de política/integração fake +27 de processos reais locais) casos novos. Agente257 e front219 preservados.

Comandos independentes, todos com caminhos absolutos:

- API: variável ConnectionStrings__PostgresTest apontando só para fixture fictícia em127.0.0.1:15427, banco solar_test; dotnet test <raiz>/solar-ai-api/tests/Solar.Api.Tests/Solar.Api.Tests.csproj --no-restore --verbosity quiet; filtro FullyQualifiedName~ForwardedHeadersHttpTeste.
- Front: npm.cmd test -- --watch=false --browsers=ChromeHeadless e npm.cmd run build, workdir <raiz>/solar-ai-front.
- Agente: <raiz>/solar-ai/.venv/Scripts/python.exe -m pytest --verbosity=0 --disable-warnings, workdir <raiz>/solar-ai. Nenhuma suite -m llm.
- Front deploy: mesma .venv com -B -m pytest <raiz>/solar-ai-front/deploy/tests/test_front.py --verbosity=0 --disable-warnings.
- Smoke: S26_FRONT_SMOKE_IMAGE=solar-ai-front:s26-header-lider-local e python -B <raiz>/solar-ai-front/deploy/tests/smoke_docker.py; tag API :s26-local temporariamente apontada à imagem nova e restaurada em finally.
- PS: pwsh e powershell.exe -NoProfile -File <raiz>/solar-ai-docs/deploy/S-26/Testar-{Transporte-Nativo,Planos,Segredos,Configuracao-Producao,Url-Publicada,Espera-Iam}.ps1, cada arquivo separadamente. PS7.6.6 e PS5.1.26100.9444.

Raiz = C:/Users/felip/Documents/FIAP/Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS/solar/worktrees/S-26.

## Ambiente, falhas iniciais e limites

- Primeira execução independente da API sem ConnectionStrings__PostgresTest explícita:115 aprovados/81 falhas de conexão, total196. O helper permitia fallback para o .env local existente; nenhum valor foi impresso e a conexão não se estabeleceu. Corrigi a invocação antes do aceite para impedir esse fallback. Repetição com rede Docker --internal interrompida ao confirmar porta inacessível ao host. Corrigida somente a fixture do líder: rede exclusiva bridge, bind127.0.0.1:15427, label da execução e tmpfs, dados fictícios. Após confirmação TCP/pg_isready, suíte196 e filtro28 passaram. Container733e5846 e sua rede efcf834d removidos com Id/label conferidos. Nenhum container do usuário/S-39 tocado.
- Build Angular preserva aviso preexistente painel.scss (7,15KiB versus6KiB). Warnings do agente não equivalem a chamadas LLM.
- Rebuild integral do Dockerfile front falhou offline no implementador. API não teve tentativa integral com download: SDK/ASP.NET10 não presentes no cache. Líder publicou API com dotnet publish --no-restore -c Release e montou overlay sobre runtime local cacheado; front overlay copia front.py/template. Ambos docker build --network=none --pull=false, sem segredo no contexto. Isso comprova runtime local, não rebuild integral das imagens finais de produção.
- Imagem runtime API: sha256:f621b67c09e4c60f867b0c1a481c2f2ea958469b4417542211eec0700aa57b77. Front runtime do líder: sha256:34c2d8b7b7e1724569884cf458c77ce66a0d329089ea17fb0dc238ac825f0ab6. Baseline API sha256:2ad9797037a73d23fe02cde4182160a7e3db008283e70b93e3108675187b5aa3 restaurada.
- Smoke: certificados/dados fictícios, OpenSSL Git do host, rede interna e nenhuma porta publicada; cleanup de containers/rede conferido. Smoke da API real prova health/version/painel/SPAs; testes de header do front usam backend fictício; cadeia IAM/peer/header da aplicação em Cloud Run permanece pendente.
- Testes PS de transporte geral usam processos Python/.cmd reais locais; demais planos/segredos usam dublês. Espera IAM usa relógio/transporte/sleep fictícios e 27 casos de processos Python/.cmd reais locais, inclusive fluxo SondaIam abortado antes de qualquer HTTP. HTTP/token reais do Google Cloud SDK/IAM não exercitados. Strings gerenciadas não permitem zeragem garantida.
- Custos do runbook são referências datadas; devem ser reconferidos antes do futuro gate. Nenhum custo remoto novo nesta implementação local; cobrança do diagnóstico anterior não foi declarada zero.


Medições independentes da correção7b6afa5: PS7 timeout2s máximo1,551s/deadline1,2s máximo0,945s; PS5.1 máximo1,546s/0,952s. A árvore com filho/neto teve no mínimo3 PIDs no executável direto e4 no launcher.cmd; todos ausentes ao término. Processo de controle fora do job permaneceu ativo durante os asserts e foi removido em cleanup. Não se criou fallback ao transporte sem timeout.

## Diff concreto para revisão

A raiz absoluta consta acima. Exemplos executáveis:

```powershell
git -C 'C:/Users/felip/Documents/FIAP/Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS/solar/worktrees/S-26/solar-ai-api' show 87c491bf88d7ba94be284cdf08ab1ae4efa17724
git -C 'C:/Users/felip/Documents/FIAP/Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS/solar/worktrees/S-26/solar-ai-front' show af366c0672c625b9fbe01cfe1832d343f4a6f6d3
git -C 'C:/Users/felip/Documents/FIAP/Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS/solar/worktrees/S-26/solar-ai-docs' show 8b0dec1a505d85c76cde87ca3e1ff51385a14bb4
git -C 'C:/Users/felip/Documents/FIAP/Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS/solar/worktrees/S-26/solar-ai-docs' show 18953c173804283daa1b1228e022a1e7114f7334
git -C 'C:/Users/felip/Documents/FIAP/Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS/solar/worktrees/S-26/solar-ai-docs' show 7b6afa5467a8fffd8c3c54c7331cd5bbe9c8afed
```

## Repetição concreta das seis suites PowerShell

```powershell
$s26Scripts='C:/Users/felip/Documents/FIAP/Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS/solar/worktrees/S-26/solar-ai-docs/deploy/S-26'
foreach($motor in @('pwsh','powershell.exe')) {
    foreach($nome in @('Testar-Transporte-Nativo.ps1','Testar-Planos.ps1','Testar-Segredos.ps1','Testar-Configuracao-Producao.ps1','Testar-Url-Publicada.ps1','Testar-Espera-Iam.ps1')) {
        & $motor -NoProfile -File (Join-Path $s26Scripts $nome)
        if($LASTEXITCODE -ne 0){throw ('Suite falhou: '+$motor+' '+$nome)}
    }
}
```

## Repetição do smoke com os runtimes novos

As tags de runtime são locais e não substituem o rebuild integral de produção. Este comando exige as imagens identificadas no relatório e restaura a tag anterior da API em finally:

```powershell
$apiAnterior=docker image inspect --format '{{.Id}}' solar-ai-api:s26-local
if($apiAnterior -ne 'sha256:2ad9797037a73d23fe02cde4182160a7e3db008283e70b93e3108675187b5aa3'){throw 'Tag anterior mudou; revisar antes do smoke'}
try {
    docker tag sha256:f621b67c09e4c60f867b0c1a481c2f2ea958469b4417542211eec0700aa57b77 solar-ai-api:s26-local
    if($LASTEXITCODE -ne 0){throw 'Tag temporaria falhou'}
    $env:S26_FRONT_SMOKE_IMAGE='solar-ai-front:s26-header-lider-local'
    & 'C:/Users/felip/Documents/FIAP/Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS/solar/worktrees/S-26/solar-ai/.venv/Scripts/python.exe' -B 'C:/Users/felip/Documents/FIAP/Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS/solar/worktrees/S-26/solar-ai-front/deploy/tests/smoke_docker.py'
    if($LASTEXITCODE -ne 0){throw 'Smoke falhou'}
} finally {
    docker tag $apiAnterior solar-ai-api:s26-local
    if($LASTEXITCODE -ne 0){throw 'Restauracao da tag falhou'}
}

```
