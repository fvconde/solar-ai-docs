# S-26 — passo B: nova d1 e diagnóstico remoto

Execução 3bdd7f92-dda2-492e-a399-2e209a1e6238, 01/10/2026. Passo B condicional autorizado pelo Maestro apos causa identificada no passo A e comandos corrigidos em 2273fe2; execução pelo líder em PowerShell 7.6.6. Código eco ae8342d134b1dbf858c7e45fd3f4fff0ce80cd89.
Nenhum IP do operador ou token neste arquivo. Entradas herdadas da borda ocultadas conservadoramente; nomes de headers apenas, sem valores de auth/cookie.
- Preflight reconferido; conta de usuario/projeto corretos, identificador omitido. APIs ja habilitadas na etapa anterior.
Passo A: [causa do bloqueio original](S-26-diagnostico-passo-A-3bdd7f92-dda2-492e-a399-2e209a1e6238.md). Correcao restrita ao relatorio; Operacoes/Planos/Deploy intactos.
Papeis diretos do operador no projeto: roles/owner. Heranca completa nao provada; nenhuma politica de projeto/pasta/organizacao alterada.
- Inventarios validos, cinco nomes ausentes e codigo eco/branch/worktree conferidos.
- Registro diagnostico exclusivo criado.
- Duas SAs diagnosticas criadas com marca em description; nenhuma chave criada.
- Build da imagem exclusiva do eco concluido.
Imagem publicada: southamerica-east1-docker.pkg.dev/solar-ai-cloud/solar-s26-diag-3bdd7f92/eco@sha256:ccd0f6bae66fd0af3c8b1d810992674ca29a060fbe464489cfa89288ce117ecc.
- Push do eco concluido; digest capturado, nenhuma imagem da aplicacao.
- Rodada d1 implantada com duas fronteiras privadas e bindings por servico.
Servico s26-diag-borda: revisao s26-diag-borda-d1, Ready=True, trafego100%; URL https://s26-diag-borda-4or3sjeksq-rj.a.run.app; execucao gen2, CPU throttling true, min 0 (padrao), max 1; ingress all; SA exclusiva e IAM direto conferidos. Env nao secreto: DIAG_MODE=encadear; DIAG_INTERNAL_URL=https://s26-diag-interno-935010665676.southamerica-east1.run.app.
Servico s26-diag-interno: revisao s26-diag-interno-d1, Ready=True, trafego100%; URL https://s26-diag-interno-4or3sjeksq-rj.a.run.app; execucao gen2, CPU throttling false, min 0 (padrao), max 1; ingress all; SA exclusiva e IAM direto conferidos. Env nao secreto: DIAG_MODE=eco.

## P1–P5 e condicao de parada
Amostra sem-prefixo: HTTP borda 502.
Amostra prefixo-forjado: HTTP borda 502.
Amostra header-serverless: HTTP borda 502.
P5: interno direto anonimo HTTP 403; token do operador HTTP 200. Operador tem roles/owner direto; nao adicionado ao IAM direto do interno e nenhuma permissao herdada alterada.
Catalogo: [cloud.json](https://www.gstatic.com/ipranges/cloud.json), creationTime 10/01/2026 07:08:35.
Requests: cinco sondagens externas d1; 0 observacoes encadeadas validas (borda e interno). Tokens somente em memoria.
**BLOQUEIO de encadeamento, antes de d2/d3:** as três respostas da borda foram 502; o helper descarta corpos de erro, portanto nenhuma observação de peer/headers foi recuperada. P1–P4 não foram medidos. **P3 não mostrou egress compartilhado nem exclusivo nesta execução.** O [pool dinâmico padrão documentado](https://docs.cloud.google.com/run/docs/configuring/static-outbound-ip) é contexto, não substitui a prova ausente. Sem novos deploys, sem proposta de CIDR/saltos, sem ampliação de allow-list ou `/0`.

| Prova | Resultado |
|---|---|
| P1 — peer TCP da borda | Não medido, devido aos 502. |
| P2 — XFF sem/com prefixo | Não medido; sem corpo de sucesso para comparar. |
| P3 — cadeia e egress no interno | Não medido; chamadas encadeadas negadas. |
| P4 — nome do header serverless | Não medido; nenhuma observação encadeada válida. |
| P5 — interno direto | Anônimo403; operador200. A hipótese de operador403 não se confirmou; `roles/owner` herdado do projeto permanece e não foi alterado. |

### Projeção de status para localizar o bloqueio

Consulta somente leitura depois do teardown, restrita aos dois serviços e à janela da rodada, com projeção **somente timestamp, nome do serviço e HTTP status**. Sem IP, e-mail, URL da requisição, headers ou corpos nos registros. Oito requisições Cloud Run registradas, correspondentes a cinco sondagens externas e três chamadas internas; não inclui comandos administrativos/probes de plataforma.

| UTC | Serviço | HTTP |
|---|---|---|
| 18:12:55.306784 | borda, sem prefixo | 502 |
| 18:12:55.579611 | interno, chamada encadeada | 403 |
| 18:12:55.700835 | borda, prefixo forjado | 502 |
| 18:12:55.773849 | interno, chamada encadeada | 403 |
| 18:12:55.853854 | borda, header serverless | 502 |
| 18:12:55.928649 | interno, chamada encadeada | 403 |
| 18:12:56.074986 | interno, anônimo direto | 403 |
| 18:12:56.376137 | interno, operador direto | 200 |

Auditoria Admin Activity da rodada confirmou CreateService às18:12:21.836892/18:12:31.225247, SetIamPolicy às18:12:39.401344/18:12:41.953514 e DeleteService às18:13:03.811574/18:13:14.014082, todos sem status de erro, com a mesma projeção sem identidade do passo A. Campos públicos dos describe registrados pelo SDK confirmaram as SAs esperadas e as revisões d1 prontas. Os bindings diretos foram conferidos: somente operador→borda e SA borda→interno; nenhum `allUsers`.

O primeiro 403 encadeado ocorreu cerca de **13,6s após o binding do interno**. [Propagação IAM](https://docs.cloud.google.com/iam/docs/access-change-propagation) é uma hipótese relevante: alterações de política são eventualmente consistentes. O fato de URL/audiência determinística estar anunciada não comprova sozinho aceitação do token neste momento; a [regra de audiência do Cloud Run](https://docs.cloud.google.com/run/docs/authenticating/service-to-service) também deve ser verificada. **Causa exata dos 403 não estabelecida**, sem ler/registrar claims ou valores de tokens e sem mudar audiência, IAM, scripts ou rede para contornar.

Próxima proposta para o Maestro: caso autorize novo diagnóstico, definir espera/backoff limitado após IAM e prova explícita de autorização da SA antes de medir P1–P4; conservar audiência e escopo até evidência contrária. Guard do deploy final continua apenas proposta no [passo A](S-26-diagnostico-passo-A-3bdd7f92-dda2-492e-a399-2e209a1e6238.md). Nenhuma nova tentativa foi executada após estes 403.

## Teardown no mesmo dia
- Removido recurso exclusivo s26-diag-borda.
- Removido recurso exclusivo s26-diag-interno.
- Removido recurso exclusivo s26-diag-borda-3bdd7f92.
- Removido recurso exclusivo s26-diag-interno-3bdd7f92.
- Removido recurso exclusivo solar-s26-diag-3bdd7f92.
- Inventarios finais validos: ausencia dos dois servicos, duas SAs e registro diag confirmada (5/5). Bindings invoker dos servicos removidos com os servicos.

## Duracao, custo e limites
Inicio UTC 2026-10-01T18:11:38.5328442Z; fim UTC 2026-10-01T18:13:43.3143213Z; duracao 2.08 min. Cobranca efetiva ainda nao consolidada/disponivel; nao declarar zero. CPU por instancia do interno e armazenamento/trafego do registry podem ser cobrados ate a remocao.
APIs permanecem habilitadas; credential helper Docker e imagem local do eco permanecem. Logs Cloud Run retêm IP do operador por30dias; teardown nao os apaga. Eco sem logs de aplicacao; nenhum log bruto publicado ou copiado para o repositorio.
Sem SQL/segredos/imagens da aplicacao/Deploy/Gemini/SMTP, sem IAM de projeto, sem chave de SA, sem push de Git/PR/Notion/merge. Pin gen2 no Deploy.ps1 e desenho final pendentes de gate proprio.
Preparação inicial do driver temporário falhou no parser por expansão de substituição de texto; corrigida e parseada antes do primeiro comando remoto do passo B. Driver removido ao concluir; apenas relatório/registro editados. Nenhum log bruto copiado para o repositório.

Estado: **bloqueado no encadeamento borda→interno (403→502), com teardown concluído e ausência 5/5 confirmada**. d2/d3 não executados; devolver relatório ao Maestro antes de nova mutação.
