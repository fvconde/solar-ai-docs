---
tipo: decisao
data: 2026-08-21
status: vigente
tags: [decisao, ia, armadilha]
---
# Decisão — LLM é a família Gemini Flash / Flash-Lite, free tier

## Problema

O projeto precisa de um LLM e não pode gastar. E há uma incerteza aberta sobre disponibilidade de cartão internacional, que já afeta o plano de deploy.

## Decisão

Família **Gemini Flash / Flash-Lite**, camada gratuita, em **projeto Google isolado**.

## Motivo

É o único free tier relevante que **não exige cartão de crédito**.

## Armadilha registrada

**Ativar billing num projeto do Google apaga o free tier daquele projeto inteiro.** Daí o projeto isolado — e daí o card S-00 ser pré-requisito de tudo.

Segunda armadilha: a cota é diária e por projeto. Erro `429` em sessão de iteração de prompt é cota queimada, não bug.

## Custo aceito

Teto de requisições por dia durante o desenvolvimento, e dependência de um serviço cuja política gratuita pode mudar.

## Conceitos

[[Gemini free tier]] · [[LangGraph]]

## Relacionadas

- [[Decisao - Arquitetura poliglota Python e NET]]
