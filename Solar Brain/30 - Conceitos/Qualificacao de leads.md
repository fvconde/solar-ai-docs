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

## O score ainda não é ordenável

Medido no S-11: rodando os mesmos roteiros duas vezes, sem mudança relevante de prompt, o score se moveu até **20 pontos** (40→60, 30→20, 10→5). A direção está certa — lead vago fica embaixo, lead decidido em cima —, mas a granularidade não existe: hoje 65 e 75 são o mesmo lead.

Isso importa porque o painel do S-19 mostra esse número e o corretor decide a quem ligar primeiro. Enquanto vier de um prompt que também escreve a resposta, o score é ordinal grosseiro, não medida. É o argumento concreto a favor de o nó do S-12 ter trabalho próprio — e a razão de nenhum teste em [[Testar a Lia]] afirmar valor de score, só que ele existe.

Tudo o que a Lia coleta aqui é dado pessoal — passa por [[Mascaramento de PII]] e é coberto pelo [[Consentimento na abertura]].

## Decisões que dependem disso

- [[Decisao - Nenhum ML classico no escopo]]
- [[Decisao - Identidade de produto Solar e agente Lia]]
