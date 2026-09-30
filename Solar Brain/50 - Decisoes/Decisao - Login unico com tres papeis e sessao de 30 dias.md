---
tipo: decisao
data: 2026-09-29
status: vigente
tags: [decisao, seguranca, lgpd, painel, autenticacao, s-44]
---
# Decisão — Login único com três papéis e sessão de 30 dias

Emenda [[Decisao - Login por corretor substitui a chave unica no painel]], de 15/09, na parte da sessão: a sessão permanente e a falta de logout, aceitas no S-42, deixam de valer.

## Problema

O S-42 deixou o login só para corretores, com cookie de dez anos e sem `DELETE` de sessão. Uma sessão só morria quando a senha era redefinida, então um dispositivo perdido mantinha acesso à fila de leads. O lead, por sua vez, não tinha conta: a conversa era só um UUID no `localStorage`, e o histórico se perdia ao trocar de navegador.

## Decisão

Uma porta de entrada para todo mundo, sob `/api`, com contrato congelado antes do front começar (`execucoes/contrato-S-44-0a7099b3-7fe0-4e3b-90e7-81245441c62a.md`).

- Três papéis na mesma tabela `corretores`: `cliente`, `corretor` e `supervisor`. Corretor nasce `em_analise` e só entra na `EscolhaDeCorretor` depois da aprovação do supervisor.
- Sessão de 30 dias renovada com o uso, e `DELETE /api/sessao` revoga a sessão no servidor. Trocar e-mail ou senha revoga as outras sessões.
- Erro de login único para e-mail inexistente e senha errada. O bloqueio de 5 tentativas do S-42 continua.
- A conversa ganha dono (`conversas.conta_id`). Conversa com dono só é lida ou escrita com a sessão dessa conta; sem ela, `404`. Conversa sem dono continua funcionando por UUID.
- A deduplicação de lead por contato deixa de ser global e passa a valer só entre conversas sem dono ou do mesmo dono.

## Consequências

O risco da sessão que não expira sai de **Riscos abertos**. A exclusão de conta reaproveita a eliminação do S-29 e não apaga conversa de outra conta. Não há SMTP: aprovação, recusa e redefinição de senha só aparecem no log de Development, e o deploy do S-26 herda essa limitação. A tabela `corretores` guarda também clientes, com `status_corretor` nulo; quem ler o schema pelo nome da tabela vai se enganar. Integrado em 29/09/2026 pelos PRs API #14, front #12 e docs #16.

## Relacionadas

- [[Decisao - Login por corretor substitui a chave unica no painel]]
- [[Decisao - Prefixo api separa painel do SPA]]
- [[Decisao - S-29 reenquadrado com endpoint de exclusao]]
- [[Decisao - Encaminhamento ao corretor com contato fora do LLM]]
