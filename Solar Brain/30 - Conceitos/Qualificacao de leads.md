---
tipo: conceito
tags: [conceito, produto, ia]
---
# Qualificação de leads

## O que é

Separar quem tem intenção real de comprar de quem está passeando, e classificar por quão perto está da decisão. No mercado imobiliário: orçamento, prazo, região, se já tem financiamento aprovado.

O produto do processo é um **score** e um resumo que o corretor humano lê antes de ligar.

## Como aparece no Solar

Requisito obrigatório do enunciado, e o coração do que a Lia faz. A qualificação acontece dentro da conversa — sem formulário, sem interrogatório — e desde o S-12 ela tem nós próprios no grafo [[LangGraph]]: um antes da chamada ao LLM, que escolhe sobre o que perguntar, e um depois, que pontua.

O score **não** sai do LLM. Ele vem da [[Regua de qualificacao]], uma tabela determinística sobre o perfil. É por isso que [[Decisao - Nenhum ML classico no escopo]] continua de pé: um classificador treinado em base sintética entregaria menos do que uma régua reprodutível e explicável.

O resultado alimenta dois outros requisitos: **resumo inteligente** e **dashboard mínimo**.

## Por que o score deixou de sair do LLM

Medido no S-11: rodando os mesmos roteiros duas vezes, sem mudança relevante de prompt, o score se moveu até **20 pontos** (40→60, 30→20, 10→5). A direção estava certa — lead vago embaixo, decidido em cima —, mas a granularidade não existia: 65 e 75 eram o mesmo lead.

Isso importava porque o painel do S-19 mostra esse número e o corretor decide a quem ligar primeiro. Enquanto vinha de um prompt que também escrevia a resposta, o score era ordinal grosseiro, não medida — e era por isso que nenhum teste em [[Testar a Lia]] afirmava valor de score, só que ele existia.

O S-12 fechou isso: [[Decisao - Score por regua deterministica]]. O score agora é reprodutível, ordenável e justificável em uma frase no pitch, e o valor dele passou a ser asserível em teste **sem gastar cota**.

Tudo o que a Lia coleta aqui é dado pessoal — passa por [[Mascaramento de PII]] e é coberto pelo [[Consentimento na abertura]].

## Decisões que dependem disso

- [[Decisao - Score por regua deterministica]]
- [[Decisao - Nenhum ML classico no escopo]]
- [[Decisao - Identidade de produto Solar e agente Lia]]
