---
tipo: decisao
data: 2026-08-21
status: vigente
tags: [decisao, ia, infra]
---
# Decisão — Índice vetorial em memória, não pgvector

## Problema

O [[RAG]] precisa de busca por similaridade. A resposta de produção é pgvector — e traz junto uma curva de aprendizado de banco no meio do prazo, para alguém que se declara iniciante em banco de dados.

## Decisão

Índice vetorial **em memória**, reconstruído no boot.

## Motivo

Três razões que se somam:

- a base de imóveis é pequena e carrega em segundos;
- mantém o [[Agente stateless]] — não há dependência externa a inicializar;
- evita uma curva de aprendizado de banco exatamente na fase em que o prazo é mais fino.

## Custo aceito

Reconstrução no boot de cada réplica. Irrelevante nesta escala.

## Caminho de produção

pgvector fica registrado no `ARQUITETURA.md`. Escolha de POC, declarada como tal.

## Conceitos

[[Indice vetorial em memoria]] · [[RAG]] · [[Agente stateless]]

## Relacionadas

- [[Decisao - Agente Python stateless]]
