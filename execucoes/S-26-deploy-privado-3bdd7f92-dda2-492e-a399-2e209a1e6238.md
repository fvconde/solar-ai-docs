# S-26 — Deploy privado e bloqueio das provas — 01/10/2026

Execução `3bdd7f92-dda2-492e-a399-2e209a1e6238`, líder Codex S-26, projeto `solar-ai-cloud`, região `southamerica-east1`. Data local 01/10, America/Sao_Paulo; horários abaixo em UTC de **02/10**. PowerShell **7.6.6**; caminhos absolutos, branches `feature/S-26`.

## Estado: PARADO, sem publicar

O usuário executou `Segredos.ps1` no próprio PowerShell; o Maestro forneceu as sete versões `1` e autorizou conferência por metadados, deploy privado e provas da seção 9, com parada em qualquer falha. Publicação e primeira chamada ao Gemini têm gates próprios.

- Sete segredos conferidos: **exatamente uma versão, `1 ENABLED`, em cada um**. Usuário SQL `solar_app` existe uma vez. Nenhum valor de segredo foi acessado pelo líder.
- `Deploy.ps1` privado executado **uma vez**, sem `-LiberarFrontPublico`, código **0**, **00:21:52.304–00:28:05.632 UTC**. Espera IAM aprovada e guard das três URLs concluídos.
- Metadados das três revisões conferidos; IAM continua privado. Nove grupos de provas HTTP concluídos; **falha na requisição 138**, às **00:37:44.116 UTC**, antes das provas de forja via front.
- **Parei na falha.** Nenhuma chamada à nuvem, repetição de prova/deploy, mudança de configuração ou teardown depois dela. Nenhum binding `allUsers`, turno Gemini ou envio SMTP solicitado. Serviços e SQL permanecem ativos; não foi autorizado desmontá-los nesta ordem.

[Evidências estruturadas e fonte integral do driver HTTP](S-26-deploy-privado-evidencias-3bdd7f92-dda2-492e-a399-2e209a1e6238.json). O arquivo não contém valores de segredos/tokens, identidade do operador ou seu IP; os endereços dos casos de teste são fictícios ou o peer fixado pelo desenho.

## Bloqueio concreto e limite da evidência

Nas chamadas diretas autenticadas como operador, `GET /api/painel/leads`:

1. Header próprio com IP fictício A: **60 respostas 401; a 61ª foi 429**.
2. Header próprio com IP fictício B: **401**, em bucket separado de A.
3. Sem header próprio: **60 respostas 401; a 61ª foi 429**.
4. Logo depois, `X-Solar-Client-IP: 169.254.169.126`: o driver esperava **429**, para comparar o bucket do IP explícito com o bucket de fallback sem header. **A resposta não foi 429**, e o driver encerrou com código **1**.

O driver registrou o predicado que falhou, mas não reteve o código HTTP observado nesse último caso. **Não afirmo que foi 401.** Fonte da asserção e contador de chamadas estão no JSON. A janela de cada coorte de 60 chamadas foi limitada a menos de 45 segundos, para não ultrapassar a janela de rate limit de um minuto.

A aceitação dos IPs A/B, com a configuração de um único `KnownProxy`, permite inferência de correspondência com o peer confiado; **não houve leitura direta do endereço bruto do socket da API**. A igualdade dos buckets de fallback/IP explícito não foi comprovada. Não declaro peer divergente, causa determinada, vulnerabilidade ou critério 2 aprovado em produção a partir dessa falha.

Não foram executados os casos seguintes: valores próprios inválidos/com espaço/vírgula/múltiplos, XFF ignorado no fallback, IPv6, exaustão do bucket via front, forjas de XFF/X-Solar-Client-IP via front e comparação do IP normalizado entre front e API. **Header intacto e forjas sem efeito na cadeia final continuam pendentes.** Não houve correção ou ampliação de trust.

## Metadados antes do deploy

Conferência concluída às **00:14:50.113 UTC**: projeto/conta/APIs conferidos, ownership dos 12 recursos, três nomes Cloud Run ausentes, projeto número `935010665676` obtido ao vivo. SHAs/worktrees limpos:

| Repositório | SHA |
|---|---|
| solar-ai-api | `87c491bf88d7ba94be284cdf08ab1ae4efa17724` |
| solar-ai-front | `af366c0672c625b9fbe01cfe1832d343f4a6f6d3` |
| solar-ai | `56ff8e09e616be2a6c2b5bf59cd08d7d1b0662b8` |
| solar-ai-docs | `6e85cd575edbb6db0aaf6e1c36b86362e1229db3` |

| Segredo | Quantidade de versões | Versão/estado |
|---|---:|---|
| solar-postgres-connection-string | 1 | 1 ENABLED |
| solar-gemini-api-key | 1 | 1 ENABLED |
| solar-smtp-usuario | 1 | 1 ENABLED |
| solar-smtp-senha-app | 1 | 1 ENABLED |
| solar-smtp-remetente | 1 | 1 ENABLED |
| solar-semente-senha-supervisor | 1 | 1 ENABLED |
| solar-chave-privacidade | 1 | 1 ENABLED |

Listagens `secrets versions list` e `sql users list` somente; nenhum `versions access`. Valores informados pelo usuário não foram solicitados, observados nem auditados pelo líder.

O agente chama a construção do índice no boot. Antes de publicar sua revisão, o líder validou o cache **na imagem aprovada**, em container local `--network none --read-only`, sem iniciar o servidor: `ler_cache(carregar(), 'gemini-embedding-001')` retornou 80 vetores para 80 imóveis. A configuração implantada usa esse mesmo modelo; health do agente depois ficou `up`. Não foi gerado cache nem solicitado embedding/turno real ao Gemini. Os dois containers locais exclusivos de inspeção foram removidos por `--rm`.

## Revisões e configurações conferidas

Conferência de metadados concluída às **00:32:40.046 UTC**. Três serviços `Ready`, latest created = latest ready, ownership/região corretas, SAs dedicadas, um container, CPU **1**, memória **512Mi**, ambiente e URLs conforme plano.

| Serviço | Revisão | CPU/min/max | Segredos referenciados |
|---|---|---|---:|
| solar-agente | `solar-agente-00001-p77` | throttling / 0 / 1 | 1, versão 1 |
| solar-api | `solar-api-00001-7w8` | contínua / 1 / 1 | 6, versão 1 |
| solar-front | `solar-front-00001-vbt` | throttling / 0 / 1 | 0 |

Todos `gen2`; portas agente 8000, API/front 8080. API em Production, conector Cloud SQL e configuração de proxy fixa, header `X-Solar-Client-IP`, peer conhecido `169.254.169.126`, ForwardLimit 1; agente em production; front IAM/CIDR169.254.169.126/32/hops1. Mapas não secretos comparados ao plano; referências de segredos conferidas por nome/versão, sem valores.

IAM direto: agente somente SA API; API somente SA front; front sem binding invoker. Nenhum `allUsers`/`allAuthenticatedUsers` ou `roles/run.invoker` no projeto; projeto sem ancestrais de organização/pasta. Owners/permissões administrativas efetivas permanecem a exceção documentada; os acessos diretos do operador não provam a cadeia API→agente.

URLs determinísticas privadas usadas nas chamadas:

- `https://solar-front-935010665676.southamerica-east1.run.app`
- `https://solar-api-935010665676.southamerica-east1.run.app`
- `https://solar-agente-935010665676.southamerica-east1.run.app`

`status.url` usa os aliases `https://solar-{front|api|agente}-4or3sjeksq-rj.a.run.app`; o guard aprovado conferiu os aliases e as URLs determinísticas anunciadas. Isso não torna os serviços públicos.

### Digests das revisões

Cloud Run seleciona o manifesto `linux/amd64` do índice OCI publicado. O índice foi consultado **por digest**, e cada revisão corresponde ao único manifesto dessa plataforma.

| Serviço | Digest do índice aprovado | Manifesto executado |
|---|---|---|
| agente | `sha256:9b4192d0b3a4068f639898f8d2b5bf17c288abfc8202020ddc700c006ce14c96` | `sha256:9c9c1b29ea2837cb03d975dcff77d5553e2b166f83a92c3f57667fc28821ed66` |
| API | `sha256:04e395ad894c3732a0c1abecacd3f462b20f6ca1022843e8726db35d60ecf05a` | `sha256:2bc26e8018a896c78bc290dabf282e5c1eeaffe71662d7f0b513f09d30aebd59` |
| front | `sha256:16347dc45c22f638df38c3920c2ba45eb4dc3f320fb71b0fd9bc8343ba032ffe` | `sha256:6fb1585e4eaa3cbfebf3df33b68b770d49e5d9eb27a14ade9204071c2b992c46` |

Duas suposições do conferidor local de metadados foram ajustadas somente por leituras: comparar o manifesto de plataforma em vez do índice OCI e aceitar CPU `1` como equivalente a `1000m`. A conferência final passou; nenhuma nova imagem ou revisão foi criada nesses ajustes. Esses ajustes são distintos da posterior falha HTTP, na qual houve parada.

## Provas HTTP concluídas e privacidade

Driver iniciou às **00:37:19.126 UTC**, terminou bloqueado às **00:37:44.116 UTC**, após **138 requisições**. Nove grupos registrados como concluídos:

- IAM sem identidade: 403 nos três serviços.
- Health API/agente e health via front: 200, `up` e SHAs corretos; API saudável com SQL.
- Front autenticado no Cloud Run, sem cookie da aplicação: `/api/sessao` 401, `sessao_invalida`, sem Set-Cookie.
- Helper `/_solar_identity` 404; Swagger/OpenAPI da API 404.
- CORS responde somente à origem do front aprovada, sem permitir origem fictícia alheia.
- Amostra do IP do próprio operador localizada por trace sintético de `/health`, em logs de requisição do front, utilizada somente em memória; IP não persistido nem impresso.
- IP fictício A: 60×401 e 61=429.
- IP fictício B: bucket separado; inferência de aceitação pelo único KnownProxy, com limite explicado acima.
- Sem header próprio: 60×401 e 61=429.

HTTP com TLS padrão, redirects/proxies de ambiente/cookies desabilitados, timeout20s, corpo limitado8192B. Token do operador obtido pelo helper bounded aprovado, somente em memória; sem impersonação. Não foram feitos login, cadastro, recuperação de senha, POST de turno ou acesso a dados autenticados. GETs rejeitados não criaram dados da aplicação. Logs da plataforma continuam sob a política existente; não foram modificados nem apagados. Strings gerenciadas não têm zeragem garantida.

## Próxima decisão do Maestro

Chamada histórica do deploy (não repetir para investigar): `Deploy.ps1 -Entradas $entradas -VersoesSegredos $versoes -NumeroProjeto '935010665676' -BootstrapPeersComprovado -Executar -PeloLider -AprovacaoMaestro '3bdd7f92-dda2-492e-a399-2e209a1e6238'`, via `pwsh -NoProfile -File` e wrapper com caminhos absolutos, sem switch de publicação. URLs, SHAs, referências `:1`, ambiente e cinco ações concretas estão em `EntradasNaoSecretas` do JSON de evidências.

O deploy não deve ser repetido para investigar. Proponho uma próxima ordem delimitada: leitura de metadados dos logs da revisão API no intervalo **00:37:19–00:37:45 UTC**, projetando somente timestamp/status do caso final, sem IP/identidade/headers; depois, se autorizado, nova prova dirigida com código HTTP observado registrado e análise da igualdade de buckets. Não executar essa proposta até a ordem do Maestro. Não adicionar endpoint, mudar trust, publicar ou chamar Gemini para contornar a pendência.

API com CPU contínua/min1, SQL, imagens, segredos e demais recursos permanecem ativos e sujeitos a custo; fatura real não apurada nesta etapa. Nenhum teardown foi autorizado. Se o Maestro solicitar alteração de produção, ela volta ao fluxo de implementação/revisão do S-26, preservando S-39.

Critério 2 em produção e seção 9 **não concluídos**; publicação e primeira chamada Gemini continuam bloqueadas por seus gates. Critério 10 e conclusão do card pendentes. Código da aplicação/scripts de produção intactos; nenhum push Git, PR, merge, Notion ou alteração de modelo.

Oito arquivos temporários de texto desta etapa removidos por caminhos exatos depois de consolidar as evidências e a fonte do driver no JSON versionado. `api-runtime-publicado`, da etapa anterior, permaneceu intacto conforme ordem do Maestro.
