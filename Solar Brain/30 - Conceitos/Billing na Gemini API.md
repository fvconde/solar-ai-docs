---
tipo: conceito
tags: [conceito, ia, infra, armadilha]
---
# Billing na Gemini API

## O que é

O mecanismo que decide em qual *tier* um projeto Google roda a Gemini API — e, com ele, quanto se paga, qual a cota, e **se o conteúdo enviado ao modelo pode ser usado para treinar produtos do Google**.

## Como funciona, na prática

Três estados, não dois:

| estado | cobrança | dados vão para treino? |
|---|---|---|
| sem billing | grátis, cota diária | **sim** |
| billing vinculado, abaixo do limiar de upgrade | por chamada | **sim** |
| tier pago (billing + pré-pago mínimo) | por chamada | não |

O estado do meio é o perigoso: paga-se **e** os dados continuam indo para treino. Vincular billing não é o mesmo que estar no tier pago; a conta precisa atingir um limiar de upgrade antes de o AI Studio trocar o rótulo da chave.

## As três armadilhas

1. **Vincular billing apaga o free tier do projeto na hora e para sempre.** Não há franquia residual como em BigQuery ou Cloud Storage — toda chamada passa a ser cobrada do primeiro token. Desvincular depois não restaura.
2. **O crédito de US$ 300 do trial do Google Cloud não vale para a Gemini API.** A doc é literal: *"the Google Cloud Welcome credit or free trial credit can't be used towards the Gemini API or AI Studio"*. O trial cobre Cloud Run; o LLM sai do cartão, à parte.
3. **O mínimo de pré-pagamento é US$ 5**, não os US$ 10 que o card S-00 registrou em 31/08.

## Como o Solar se protege

Dois projetos Google, nunca um só — ver [[Decisao - Dois projetos Google separados]]. Cloud Run não precisa morar no mesmo projeto da chave da Gemini, e nada na [[Arquitetura poliglota]] amarra os dois: o [[Agente stateless]] lê a chave de variável de ambiente e não sabe em que projeto ela nasceu.

## Consequência para a privacidade

Enquanto a chave do Solar estiver no free tier, o conteúdo enviado ao modelo pode ser usado para treino. Isso torna o [[Mascaramento de PII]] o único controle real e obriga o [[Consentimento na abertura]] a declarar o fato — ver [[LGPD e GDPR]].

## Relacionadas

[[Gemini free tier]] · [[Decisao - LLM Gemini Flash free tier]] · [[Decisao - Dois projetos Google separados]]
