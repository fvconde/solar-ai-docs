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

## Os números, medidos no S-14

- **80 imóveis, 768 dimensões**, `gemini-embedding-001` com `output_dimensionality=768`.
- Boot pelo cache: **0,54 s**. Boot chamando a API: **2,7 s**.
- Busca: **~400 ms**, e o tempo é quase todo o embedding da consulta indo e voltando pela rede — o cosseno sobre 80 vetores em Python puro é ruído ao lado disso.
- Nenhuma dependência nova no `requirements.txt`. `numpy` não entrou: nesta escala não paga o próprio peso.

## Duas coisas que não são óbvias

**Normalizar não é otimização, é correção.** O `gemini-embedding-001` só devolve vetor de norma 1 na dimensão cheia (3072). Truncado em 768 pela MRL, ele vem com norma ~0,59. Sem normalizar na construção, "cosseno" viraria produto escalar de vetores de comprimentos diferentes — e o ranking passaria a premiar vetor comprido em vez de vetor parecido. Normalizados os dois lados, o cosseno **é** o produto escalar, e sai de graça.

**O boot pode falhar sem derrubar o agente.** Índice que não sobe deixa o `/health` em `degraded` com HTTP 200, pelo check `indice_imoveis`. A Lia continua conversando e qualificando; ela só não consulta imóveis. Só `gemini_config` é essencial. Isso foi verificado por acidente no próprio S-14, quando um `429` de cota derrubou a construção e o serviço respondeu `degraded` como projetado.

## De onde vêm os vetores

Do cache versionado em `solar-ai/data/embeddings.json`, quando ele confere com a base; da API, quando não confere. Ver [[Decisao - Cache de embeddings por hash da base]].

## Caminho de produção

pgvector fica registrado no `ARQUITETURA.md` como o passo seguinte. A escolha aqui é de POC, e está declarada como tal — é diferente de não ter pensado no assunto.

## Decisões que dependem disso

- [[Decisao - Indice vetorial em memoria]]
- [[Decisao - Cache de embeddings por hash da base]]
