---
tipo: conceito
tags: [conceito, ia, armadilha]
---
# Gemini free tier

## O que é

A família Gemini Flash / Flash-Lite tem camada gratuita de uso via API, com cota **por dia e por projeto**.

## Por que foi escolhido no Solar

É o único free tier relevante que **não exige cartão de crédito** — o que importa porque o plano de deploy do projeto está preso exatamente nessa pergunta (ver riscos do ESTADO.md).

## Duas armadilhas

1. **Ativar billing num projeto do Google apaga o free tier daquele projeto inteiro**, na hora e sem desfazer. Por isso o Solar usa um projeto isolado — e, desde 05/09, dois projetos com papéis fixos. A mecânica completa, incluindo o estado intermediário em que se paga *e* os dados ainda vão para treino, está em [[Billing na Gemini API]].
2. **A cota é diária.** Sessão de iteração de prompt queima rápido. Erro `429` durante o desenvolvimento é cota, não bug no código.

## Contrapartida registrada

No free tier, o conteúdo enviado pode ser usado para treinar produtos do Google. É isso que torna o [[Mascaramento de PII]] um controle necessário e não uma boa prática.

## Decisões que dependem disso

- [[Decisao - LLM Gemini Flash free tier]]
- [[Decisao - Dois projetos Google separados]]
- [[Decisao - Modelo Gemini fixado sem alias]]
