---
tipo: decisao
data: 2026-09-05
status: vigente
tags: [decisao, ia, infra, armadilha]
---
# Decisão — Dois projetos Google separados, `solar-ai` e `solar-ai-cloud`

## Problema

Confirmou-se em 05/09 que há cartão internacional disponível, o que destrava Cloud Run e fecha o risco "plano de deploy indefinido". A tentação natural é ativar faturamento no mesmo projeto `solar-ai` que já hospeda a chave da Gemini — um projeto a menos para administrar.

## Decisão

Dois projetos, com papéis fixos:

- **`solar-ai`** — chave da Gemini, free tier, **billing nunca ativado**. É o plano B permanente.
- **`solar-ai-cloud`** — conta de faturamento vinculada, trial de US$ 300, Cloud Run dos dois serviços. Se um dia houver tier pago da Gemini, a chave nova nasce aqui.

## Motivo

Juntar os dois papéis num projeto só custaria o free tier de forma **irreversível**, e sem entregar em troca a garantia de não-treino: existe um estado intermediário em que se paga por chamada e os dados continuam indo para treino. Ver [[Billing na Gemini API]].

O ganho de juntar era um nome a menos no seletor de projetos. A perda seria o plano B inteiro, sem desfazer, a 24 dias da entrega.

## Custo aceito

Dois projetos para administrar, e a disciplina de conferir, depois de criar a conta de faturamento, que o Google não vinculou billing ao `solar-ai` sozinho.

## Conceitos

[[Billing na Gemini API]] · [[Gemini free tier]] · [[Arquitetura poliglota]]

## Relacionadas

- [[Decisao - LLM Gemini Flash free tier]]
- [[Decisao - Modelo Gemini fixado sem alias]]
