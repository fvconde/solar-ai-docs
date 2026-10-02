# S-26 — Aceite final público e entrega

Execução **3bdd7f92-dda2-492e-a399-2e209a1e6238**. Projeto **solar-ai-cloud** (935010665676), região **southamerica-east1**. Data local 02/10/2026, America/Sao_Paulo; horários das provas em UTC. Líder Codex S-26; implementador Codex S-26 Luna; Maestro Claude Code.

## Resultado — critérios 10 e 11

**Aceite funcional encerrado**, com provas técnicas aceitas pelo Maestro e teste do usuário no próprio navegador. Critério 11 consolidado neste relatório e no registro principal. O teto de 20 chamadas foi descumprido: **51 respostas Gemini, excedente 31**, registrado como **desvio de processo**.

O usuário confirmou ter enviado as **40 mensagens /turn** testando a Lia. Segundo a confirmação encaminhada pelo Maestro, **não houve uso externo nem consumo automático**. O Maestro determinou registrar **sem custo financeiro do excedente e sem risco para a cota diária**. São confirmações do usuário/Maestro; não são conclusões sobre identidade obtidas dos logs nem medição de fatura. A infraestrutura aprovada permanece paga e ativa.

Fontes: [evidências sanitizadas](S-26-aceite-publico-evidencias-3bdd7f92-dda2-492e-a399-2e209a1e6238.json), [auditoria por caminho/minuto](S-26-auditoria-consumo-3bdd7f92-dda2-492e-a399-2e209a1e6238.md), [registro completo](S-26-3bdd7f92-dda2-492e-a399-2e209a1e6238.md), [runbook](../deploy/S-26/README.md). As evidências históricas das paradas permanecem preservadas.

## URLs e acesso

| Serviço | URL determinística | status.url anunciado | Acesso final conferido |
|---|---|---|---|
| Front | https://solar-front-935010665676.southamerica-east1.run.app | https://solar-front-4or3sjeksq-rj.a.run.app | Público, allUsers → roles/run.invoker |
| API | https://solar-api-935010665676.southamerica-east1.run.app | https://solar-api-4or3sjeksq-rj.a.run.app | Privado, invoker somente SA front |
| Agente | https://solar-agente-935010665676.southamerica-east1.run.app | https://solar-agente-4or3sjeksq-rj.a.run.app | Privado, invoker somente SA API |

O front recebeu somente o binding isolado, condition=None, projeto/região explícitos, em **01:34:34.5964455 UTC de 02/10**. Não foi executado Deploy.ps1 -LiberarFrontPublico nem redeploy. Três revisões conferidas iguais antes/depois, Ready, 100% do tráfego e ownership correta. API/agente sem allUsers ou allAuthenticatedUsers; nenhum run.invoker acrescentado no projeto.

## SHAs, revisões e digests

Todos os repositórios na branch **feature/S-26**. Imagens construídas integralmente com rede e publicadas uma vez antes do deploy privado; tags de SHA imutáveis. Código de produção permaneceu igual depois do aceite.

| Repositório | SHA implantado | Revisão Cloud Run |
|---|---|---|
| solar-ai-api | 87c491bf88d7ba94be284cdf08ab1ae4efa17724 | solar-api-00001-7w8 |
| solar-ai-front | af366c0672c625b9fbe01cfe1832d343f4a6f6d3 | solar-front-00001-vbt |
| solar-ai | 56ff8e09e616be2a6c2b5bf59cd08d7d1b0662b8 | solar-agente-00001-p77 |
| solar-ai-docs | Base antes do fechamento f40bd80af4808dd1ba5a6fa48291799c24cf6099; scripts 18953c1/7b6afa5, guard 5017d9b | Não é imagem da aplicação |

Registro: southamerica-east1-docker.pkg.dev/solar-ai-cloud/solar-s26-3bdd7f92.

| Imagem | Digest do índice OCI aprovado | Manifesto linux/amd64 executado |
|---|---|---|
| solar-api | sha256:04e395ad894c3732a0c1abecacd3f462b20f6ca1022843e8726db35d60ecf05a | sha256:2bc26e8018a896c78bc290dabf282e5c1eeaffe71662d7f0b513f09d30aebd59 |
| solar-front | sha256:16347dc45c22f638df38c3920c2ba45eb4dc3f320fb71b0fd9bc8343ba032ffe | sha256:6fb1585e4eaa3cbfebf3df33b68b770d49e5d9eb27a14ade9204071c2b992c46 |
| solar-agente | sha256:9b4192d0b3a4068f639898f8d2b5bf17c288abfc8202020ddc700c006ce14c96 | sha256:9c9c1b29ea2837cb03d975dcff77d5553e2b166f83a92c3f57667fc28821ed66 |

## Recursos e configurações

- SQL solar-s26-3bdd7f92: Postgres16 Enterprise db-f1-micro ZONAL, SSD10GiB sem crescimento automático, banco solar, conector obrigatório, nenhuma rede autorizada, backup e proteção de exclusão. Provisionamento aprovado e executado uma vez com inventário prévio.
- Três SAs dedicadas; sete segredos preenchidos **pelo usuário**. Metadados conferidos: exatamente versão **1 ENABLED** em cada segredo; solar_app existe. Nenhum valor acessado pelo líder ou incluído em imagem/commit.
- Todos gen2, CPU1/memória512Mi, max-instances=1. API CPU contínua/min1; front/agente CPU throttling/min0. Max1 na API preserva a premissa da TravaDeConversas em um processo.
- As quatro configurações do card: max-instances=1, CORS somente da origem determinística do front, SOLAR_VERSION com SHA exato e painel protegido por sessão. Swagger/OpenAPI só Development.
- nginx sobrescreve X-Solar-Client-IP; API confia nesse header pelo peer permitido, **não no egress compartilhado**. Peer configurado169.254.169.126, limite1; header inválido/múltiplo removido. Forjas XFF/header próprio pelo front não alteram bucket.
- Binding agente antes da API; sonda privada front→API /api/sessao,401 da aplicação, intervalo60s/até10min; espera restante até5min desde binding agente. Sem endpoint/rota nova, impersonação ou sonda própria API→agente. Primeiro turno real comprovou a cadeia.

## Provas — seções 9 e 10

| Prova | Resultado e fonte |
|---|---|
| Privado, seção9 | 199 chamadas acumuladas: **198 asserções conformes +1 informativa (401)**; aceitas pelo Maestro. [Retomada](S-26-retomada-provas-ip-3bdd7f92-dda2-492e-a399-2e209a1e6238.md). |
| Health | API/agente privados autenticados200/up/SHA esperado; front público /health200/up/SHA API esperado. |
| Proteção | API/agente sem token403; front público painel sem cookie401, sem dados; helper /_solar_identity404. |
| OpenAPI/Swagger/CORS | API Production /openapi/v1.json e /swagger404; CORS só da origem aprovada. Provas privadas preservadas. |
| Buckets e forjas | API separa IPs fictícios A/B pelo header aceito. Front60×401,61ª429; XFF sozinho e X-Solar sozinho forjados429; após janela401. Coorte pública **5,717s**, menor que45s. |
| SPA | HTTP /painel/reload retornam index.html; usuário confirmou **F5 funcionando no próprio navegador**. |
| API→agente | Primeira API POST /conversas/{id}/mensagens200 **01:46:53.978911 UTC**; primeiro /turn agente200 **01:46:54.520219 UTC**. Timestamps do registro, não término exato. Usuário confirmou resposta Lia. |
| Supervisor/e-mail | Usuário testou no próprio navegador; acesso autenticado ao painel/conta observado por status/horário. Confirmou e-mail de redefinição recebido no Gmail dedicado. **Link não clicado**; nenhum endereço ou senha compartilhado. |
| HTTP público automatizado | **70/70 conformes**:3×200,2×403,1×404,61×401,3×429, sem token/cookie. Zero turno enviado pelo líder. |

Os dois turnos inicialmente autorizados ao líder foram cancelados antes do envio e substituídos pelo teste do usuário. Portal não funcionou; aceite visual/JS é a confirmação do usuário no próprio navegador, distinta do smoke HTTP.

## Consumo e desvio de processo

- Linha de base **0**; liderança **0 turnos/0 chamadas Gemini enviadas**.
- Janela medida **01:34:34.5964455–03:03:55.5191273 UTC de02/10**: **43 gerações+8 embeddings=51 respostas HTTP**, todas200. Teto20; excedente31. Embeddings contam no total.
- Já havia28 (25 gerações+3 embeddings) até02:07:17 UTC, primeiro relógio conferido após aviso de término; 21ª chamada01:52:07.200805. Limite detectado e informado; nenhum teste adicional para reproduzir.
- Auditoria **01:34–03:22:19.4899245 UTC**:40 /turn200+1 /health403, zero/resumo, zero após03:03:55. Último/turn02:34:31.430764; última geração02:34:32.571623.
- 43 gerações compatíveis temporalmente com40 /turn e três intervalos de duas gerações/um embedding; nó apresentar prevê segunda chamada. Sem identificador permitido, isso não prova nó individual/autoria.
- Cada resposta HTTP do SDK foi contada, incluindo respostas de tentativas repetidas registradas. **Zero erro HTTP do SDK observado**; retries de conexão/timeout sem resposta não quantificáveis. Três gerações extras não classificadas como retry.
- **Causa confirmada pelo usuário/Maestro:** ele enviou as40 mensagens testando Lia; sem uso externo/consumo automático. **Desvio de processo, sem custo financeiro do excedente e sem risco à cota diária**, conforme o Maestro. O teto permanece registrado como descumprido.

## Critérios 1–11 e evidências locais

| Critério | Commits/evidência final |
|---|---|
| 1 — Swagger/OpenAPI | API d606226; testes HTTP/404 em produção. |
| 2 — confiança/IP | API97f4ca1/c54f5a1/87c491b, frontaf366c0; desenho e buckets aceitos. |
| 3 — identidade agente/resumo | API5248d5b/5e56f39; guard docs5017d9b; primeiro turno real200. |
| 4 — SMTP | APId02c709; dublês e e-mail real recebido pelo usuário. |
| 5 — semente | API5525a76; idempotência Postgres real; teste supervisor pelo usuário. |
| 6 — imagens | API42e7bdb, front5e49ab5/af366c0, agente56ff8e0;3/3 builds completos/pushes/digests. |
| 7 — mapas/configuração | Docse40b56f/18953c1/7b6afa5; gen2/header/peers/IAM aprovados. |
| 8 — recursos/segredos/runbook | Docs493daf3/a28ec64/ef8c8cc; recursos6e85cd5/deployac9fb2c; sete versões1 e solar_app. |
| 9 — quatro configurações | Docs18953c1/ac9fb2c/31b0517/6371a62;198 conformes+1 informativa aceitas. |
| 10 — aceite público | Este relatório: publicação isolada, navegador/Gmail, primeira cadeia real e desvio do teto. |
| 11 — registro | Registro atualizado/histórico mantido; URLs PR acrescentadas após criação; sem merge. |

Resultados locais finais já revisados/repetidos nas etapas anteriores; **não reexecutados nesta finalização**:

| Suíte | Base → final |
|---|---|
| API Postgres isolado |145/145→**196/196**, falhas0/ignorados0; forwarding**28/28** |
| Front Angular |**219/219**, build**1/1**; aviso painel.scss preexistente |
| Helper nginx |**17/17**; smoke Docker**8/8** |
| Agente sem LLM |255→**257 passed**,38 deselected,31 warnings; cache offline |
| PS7.6.6 e PS5.1.26100.9444 |Por versão:nativo15+Planos17+Segredos33+Configuração82+URL92+IAM85=**324/324**, total**648/648** |

Tarefas locais delegadas a Codex S-26 Luna e avaliadas pelo líder. Devoluções/falhas intermediárias preservadas no registro: allow-list vazia, audiência, preparação smoke, stderr/stdout, status.url e prazo/árvore da sonda. Maestro aprovou scripts/API/front/desenho antes da nuvem. Nenhum modelo alterado nesta finalização.

## Desvios e limites

- Diagnóstico encontrou egress compartilhado; não sustenta IP de cliente. Diagnósticos desmontados no mesmo dia. Desenho do header próprio aprovado pelo usuário. Guard de URL considera alias/hash anunciados sem relaxar ownership.
- Asserção138 supunha igualdade das strings do bucket do peer explícito/fallback. Maestro descartou bloqueio de segurança/tornou informativo; hipótese IPv4 mapeado em IPv6 não apresentada como fato. Retomada registrou todos os status sem redeploy.
- Peer bruto não lido; inferência das provas de encaminhamento aceita pelo Maestro. Comparação de IP substituída por buckets relativos; sem arquivo de IP/consulta externa de IP na retomada.
- Logs do aceite sem corpo de conversa, headers, IP, identidade, endereço ou senha. Strings gerenciadas não garantem zeragem; tokens somente em memória.
- E-mail recebido, **link não clicado**. Não se comprovou conclusão da redefinição/login com senha redefinida nem entrega futura de todos os e-mails.
- Metadados são retratos horários, não monitoramento contínuo. Retries sem resposta/fatura real não medidos. Autoria vem da confirmação do usuário.

## Custos e recursos ativos

Excedente Gemini free tier: **sem custo financeiro e sem risco à cota diária, conforme o Maestro**. Infraestrutura: API mínima/CPU contínua, SQL, registro, backups, imagens e segredos seguem ativos/pagos com aprovação. Sem teardown nesta finalização.

Referência do runbook **30/09/2026**,730h/mês: API CPU/memória USD59,9184; SQL micro+SSD10GiB USD14,084; subtotal API+SQL **USD74,0024/mês**. Não é cotação atual/fatura e exclui variáveis do runbook. Desmontagem exige aprovação e revisão de dados/backups.

## Publicação Git e PRs

Ordem final explícita: publicar feature/S-26 nos quatro repositórios alterados e abrir **um PR por repositório contra develop**, título **S-26 · Deploy dos três serviços e Postgres gerenciado**, UUID no corpo. **Sem merge**. Bases remotas consultadas, inventário de PRs existente vazio. Diff do card não altera contrato, migration, consentimento, ESTADO.md, ARQUITETURA.md ou arquivos reservados ao S-39.

Commit do aceite/docs: **aba5370c23a92fad39c6d283bd3ad537eb32bfa3**. Quatro pushes concluídos; quatro PRs **OPEN**, não draft, destino **develop**, título exato e UUID no corpo conferidos por gh. Todos MERGEABLE/CLEAN no retrato dessa conferência; isso não representa aprovação nem merge. As URLs são acrescentadas em commit documental posterior; a ponta de docs será esse commit e o PR acompanha a atualização.

| Repositório | PR contra develop | SHA no momento da criação |
|---|---|---|
| solar-ai-api | [#16](https://github.com/fvconde/solar-ai-api/pull/16) | 87c491bf88d7ba94be284cdf08ab1ae4efa17724 |
| solar-ai-front | [#13](https://github.com/fvconde/solar-ai-front/pull/13) | af366c0672c625b9fbe01cfe1832d343f4a6f6d3 |
| solar-ai | [#9](https://github.com/fvconde/solar-ai/pull/9) | 56ff8e09e616be2a6c2b5bf59cd08d7d1b0662b8 |
| solar-ai-docs | [#18](https://github.com/fvconde/solar-ai-docs/pull/18) | aba5370c23a92fad39c6d283bd3ad537eb32bfa3 |
