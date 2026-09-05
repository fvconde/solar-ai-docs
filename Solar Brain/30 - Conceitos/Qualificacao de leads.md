---
tipo: conceito
tags: [conceito, produto, ia]
---
# Qualificação de leads

## O que é

Separar quem tem intenção real de comprar de quem está passeando, e classificar por quão perto está da decisão. No mercado imobiliário: orçamento, prazo, região, se já tem financiamento aprovado.

O produto do processo é um **score** e um resumo que o corretor humano lê antes de ligar.

## Como aparece no Solar

Requisito obrigatório do enunciado, e o coração do que a Lia faz. Um nó do grafo [[LangGraph]] conduz a qualificação dentro da conversa — sem formulário, sem interrogatório.

O score sai desse nó, via LLM. É por isso que [[Decisao - Nenhum ML classico no escopo]] existe: treinar um classificador em base sintética custaria 3–6h para provar menos do que o nó já entrega.

O resultado alimenta dois outros requisitos: **resumo inteligente** e **dashboard mínimo**.

Tudo o que a Lia coleta aqui é dado pessoal — passa por [[Mascaramento de PII]] e é coberto pelo [[Consentimento na abertura]].

## Decisões que dependem disso

- [[Decisao - Nenhum ML classico no escopo]]
- [[Decisao - Identidade de produto Solar e agente Lia]]
