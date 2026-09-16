---
tipo: decisao
data: 2026-09-16
status: vigente
tags: [decisao, arquitetura, api, front]
---
# Decisão — Prefixo /api separa o painel da rota do SPA

## Problema

O S-42 deixou a API do painel e a página do Angular disputando o mesmo prefixo /painel. O proxy de desenvolvimento precisava listar endpoints individualmente para que a página abrisse, mas esse contorno não era uma regra de deploy e poderia ser perdido no reverse proxy do S-26.

## Decisão

O painel passa a viver no namespace /api/painel, enquanto a página do SPA continua em /painel.

- PainelController e o rate limiting usam /api/painel.
- painel-api.ts e entrar-api.ts chamam /api/painel.
- proxy.conf.json encaminha uma única entrada /api para a API.
- Painel:UrlBaseDoFront continua na raiz do front; o link de redefinição permanece BASE/entrar?token=TOKEN, sem /api.
- /turn, /conversas e /health permanecem fora desta mudança. O contrato congelado do /turn não é reaberto por uma alteração de roteamento do painel.

## Consequências

Recarregar ou abrir diretamente /painel continua sendo responsabilidade do SPA, e as chamadas do painel têm um namespace sem colisão. O reverse proxy de produção precisa encaminhar /api para a API e deixar /painel chegar ao front. A separação foi integrada nos três repositórios em 16/09/2026, pelos PRs 12, 10 e 14.

## Relacionadas

- [[Decisao - Login por corretor substitui a chave unica no painel]]
- [[Decisao - Front do chat em Angular]]
- [[Decisao - Contrato do POST turn congelado]]
- [[Arquitetura poliglota]]
- [[Agente stateless]]
