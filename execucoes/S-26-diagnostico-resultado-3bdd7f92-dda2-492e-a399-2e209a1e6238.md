# S-26 — resultado do diagnóstico remoto da seção 7

Execução 3bdd7f92-dda2-492e-a399-2e209a1e6238, 01/10/2026. Gate reduzido e transporte d1ac704/1cfc3b0 aprovados pelo Maestro; execução pelo líder em PowerShell 7.6.6. Código eco ae8342d134b1dbf858c7e45fd3f4fff0ce80cd89.
Nenhum IP do operador ou token neste arquivo. Entradas herdadas da borda ocultadas conservadoramente; nomes de headers apenas, sem valores de auth/cookie.
- Preflight reconferido; conta de usuario/projeto corretos, identificador omitido. APIs ja habilitadas na etapa anterior.
Papeis diretos do operador no projeto: roles/owner. Heranca completa nao provada; nenhuma politica de projeto/pasta/organizacao alterada.
- Inventarios validos, cinco nomes ausentes e codigo eco/branch/worktree conferidos.
- Registro diagnostico exclusivo criado.
- Duas SAs diagnosticas criadas com marca em description; nenhuma chave criada.
- Build da imagem exclusiva do eco concluido.
Imagem publicada: southamerica-east1-docker.pkg.dev/solar-ai-cloud/solar-s26-diag-3bdd7f92/eco@sha256:5aa935fc428de96e6b74401ee27c67bf0e8ae7960945d3ae5b20cdd958f31a49.
- Push do eco concluido; digest capturado, nenhuma imagem da aplicacao.
- BLOQUEIO na etapa rodada-d1; detalhes externos suprimidos. Nao repetir mutacoes; inventariar para teardown.

## P1–P5: não executados

| Prova | Estado observado |
|---|---|
| P1 — peer TCP da borda | Não medido: bloqueio durante d1, antes das sondagens. |
| P2 — XFF original/forjado | Não medido; nenhuma requisição de diagnóstico executada. |
| P3 — cadeia/egress do interno | Não medido. Não há evidência para afirmar egress exclusivo ou compartilhado nesta execução. |
| P4 — presença do header serverless | Não medida; token de identidade das sondagens não solicitado. |
| P5 — interno anônimo/operador | Não medido. `roles/owner` do operador é um limite identificado, não substitui a prova HTTP. |

Os dois serviços existiam no inventário usado pelo teardown e tinham a marca correta. Isso não comprova prontidão, tráfego, URLs ou IAM efetivo de d1. O detalhe da falha foi suprimido; a causa exata não foi estabelecida. O bloco aprovado inclui chamadas de deploy/IAM/describe e a comparação entre `status.url` e URL determinística; possível divergência de URL é **hipótese**, não resultado confirmado. Consulta administrativa somente de métodos/códigos de auditoria após a limpeza também ficou indisponível, sem retorno de registros brutos.

**Parada operacional aplicada, sem repetir mutações:** d2/d3 não executados, CIDRs/saltos de confiança não propostos. Próximo passo depende do Maestro: localizar a chamada/guard que falhou em d1 e conferir URL/audiência antes de autorizar nova criação diagnóstica. A topologia e o nginx final continuam sem prova. O [pool dinâmico padrão do Cloud Run](https://docs.cloud.google.com/run/docs/configuring/static-outbound-ip) permanece um limite documental; não ampliar allow-list nem usar `/0` para contornar a falta de evidência.

## Teardown no mesmo dia
- Removido recurso exclusivo s26-diag-borda.
- Removido recurso exclusivo s26-diag-interno.
- Removido recurso exclusivo s26-diag-borda-3bdd7f92.
- Removido recurso exclusivo s26-diag-interno-3bdd7f92.
- Removido recurso exclusivo solar-s26-diag-3bdd7f92.
- Inventarios finais validos: ausencia dos dois servicos, duas SAs e registro diag confirmada (5/5). Bindings invoker dos servicos removidos com os servicos.

## Duracao, custo e limites
Inicio UTC 2026-10-01T17:39:10.3432555Z; fim UTC 2026-10-01T17:41:47.0891799Z; duracao 2.61 min. Cobranca efetiva ainda nao consolidada/disponivel; nao declarar zero. CPU por instancia do interno e armazenamento/trafego do registry podem ser cobrados ate a remocao.
APIs permanecem habilitadas; credential helper Docker e imagem local do eco permanecem. Logs Cloud Run retêm IP do operador por30dias; teardown nao os apaga. Eco sem logs de aplicacao; nenhum log bruto coletado.
Sem SQL/segredos/imagens da aplicacao/Deploy/Gemini/SMTP, sem IAM de projeto, sem chave de SA, sem push de Git/PR/Notion/merge. Pin gen2 no Deploy.ps1 e desenho final pendentes de gate proprio.
Driver temporário do líder continha somente comandos revisados e guards de ownership, sem tokens/observações; removido após execução. Nenhum script de produção alterado. Cobrança real pendente: nenhuma exportação de faturamento foi criada ou custo zero declarado. Não houve sondagem externa ao eco, chamadas Gemini ou SMTP.

Estado: **bloqueado na etapa d1, com teardown concluído e ausência 5/5 confirmada**. Aguardar decisão do Maestro antes de qualquer nova mutação.
