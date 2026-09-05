---
tipo: conceito
tags: [conceito, ia, infra]
---
# Índice vetorial em memória

## O que é

Guardar os embeddings num array em RAM e fazer a busca por similaridade em cima dele, em vez de num banco vetorial (pgvector, Qdrant, Pinecone).

Vale quando a base é pequena e estática. Deixa de valer quando ela cresce, muda em runtime, ou quando o custo de reconstruir no boot passa a incomodar.

## Como aparece no Solar

A base de imóveis é simulada, pequena e carrega em segundos. O índice é reconstruído no boot de cada réplica — o que é obrigatório, já que o [[Agente stateless]] não tem onde guardar.

Alimenta o [[RAG]] da Lia.

## Caminho de produção

pgvector fica registrado no `ARQUITETURA.md` como o passo seguinte. A escolha aqui é de POC, e está declarada como tal — é diferente de não ter pensado no assunto.

## Decisões que dependem disso

- [[Decisao - Indice vetorial em memoria]]
