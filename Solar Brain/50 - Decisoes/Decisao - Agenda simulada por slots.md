---
tipo: decisao
data: 2026-08-21
status: vigente
tags: [decisao, produto]
---
# Decisão — Agenda simulada por tabela de slots, sem Google Calendar

## Problema

Agendamento de reuniões é requisito obrigatório. Integrar com Google Calendar significa OAuth, consentimento, credenciais e tratamento de erro de rede — para um resultado que, na demo, é idêntico.

## Decisão

Tabela de slots no banco da API .NET. Sem integração externa.

## Motivo

Custo alto, ganho baixo para uma POC. O requisito é *agendar*, não *agendar no Google*.

## Custo aceito

Nenhum do ponto de vista do requisito. Google Calendar vai para o roadmap do README.

## Conceitos

[[Orcamento de esforco]]

## Relacionadas

- [[Decisao - Canal da demo e chat web com Telegram cortavel]] — mesma lógica: o requisito é o comportamento, não a integração
