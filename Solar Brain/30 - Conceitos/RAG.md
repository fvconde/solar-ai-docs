---
tipo: conceito
tags: [conceito, ia]
---
# RAG

## O que é

*Retrieval-Augmented Generation*: antes de gerar a resposta, buscar trechos relevantes numa base e injetá-los no prompt. O modelo responde sobre dados que ele não viu no treino, e as respostas ficam ancoradas em algo verificável.

A qualidade do RAG é dominada pela qualidade da base, não pelo modelo. Se os documentos são parecidos entre si, a busca devolve resultados indistinguíveis por melhor que seja o embedding.

## Como aparece no Solar

A Lia usa RAG sobre a base simulada de imóveis (`solar-ai/data`) para responder o que o lead pergunta sem inventar imóvel. É diferencial listado no enunciado.

A busca roda sobre o [[Indice vetorial em memoria]].

## Risco aberto

A variedade das descrições da base **não foi verificada**. O ESTADO.md registra: se as descrições forem repetitivas, o RAG do S-15 devolve resultados indistinguíveis. Checar antes de investir no S-14.

## Decisões que dependem disso

- [[Decisao - Indice vetorial em memoria]]
