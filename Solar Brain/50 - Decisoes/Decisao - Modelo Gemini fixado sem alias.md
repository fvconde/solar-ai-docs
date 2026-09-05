---
tipo: decisao
data: 2026-09-05
status: vigente
tags: [decisao, ia, armadilha]
---
# Decisão — Modelo fixado em `gemini-3.5-flash-lite`, nunca um alias

## Problema

O smoke test do S-00 escolhia o modelo sozinho, ordenando os candidatos e pegando o último. Como `'f'` vem depois de `'3'` na ordem alfabética, `gemini-flash-lite-latest` ganhou de `gemini-3.5-flash-lite` por acidente de ordenação, não por ser mais novo.

Pior que o acidente é o que foi escolhido: `*-latest` é **ponteiro móvel**. O Google troca o modelo por trás dele sem aviso. Num projeto com congelamento de código em 24/09, isso significa que o comportamento dos prompts da Lia pode mudar entre o congelamento e a banca, sem que uma linha de código tenha mudado — e sem tempo de reajustar.

## Decisão

`GEMINI_MODEL=gemini-3.5-flash-lite` no `.env`, fixo. O `scripts/smoke_gemini.py` passou a:

- ler o `.env` sozinho;
- usar exatamente o modelo fixado, sem escolher nada;
- sair com código 3 se o modelo fixado não estiver entre os visíveis para a chave, em vez de cair silenciosamente em outro;
- manter a escolha automática apenas sob a flag `--sugerir`.

## Motivo

Reprodutibilidade vale mais que "sempre o mais novo" quando existe data de entrega. Falhar alto (código 3) é melhor que substituir o modelo em silêncio — um modelo trocado sem aviso é o tipo de bug que só aparece na demo.

## Custo aceito

Ficar preso a uma versão que envelhece. Irrelevante numa janela de 24 dias.

## Fallback

Se a cota apertar e o `429` virar crônico, trocar para `gemini-2.5-flash-lite`. Está anotado no `.env.example`.

## Medido em 05/09

40 modelos visíveis para a chave, latência de 834 ms na chamada real, 95 tokens totais.

## Conceitos

[[Gemini free tier]] · [[Billing na Gemini API]] · [[LangGraph]]

## Relacionadas

- [[Decisao - LLM Gemini Flash free tier]]
- [[Decisao - Dois projetos Google separados]]
