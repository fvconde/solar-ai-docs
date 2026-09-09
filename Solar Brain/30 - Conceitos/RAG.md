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

## Risco fechado em 08/09, no S-14

A variedade das descrições era o risco que podia inutilizar o RAG inteiro, e ele estava aberto desde 22/08. Medido antes de escrever uma linha do índice, sobre os 80 imóveis, sem gastar cota:

| medida | valor |
|---|---|
| vocabulário / palavras totais | 867 / 2723 |
| similaridade média entre pares (cosseno tf) | **0,185** (mediana 0,178) |
| pares acima de 0,6 | **0** — o pior par dá 0,553 |
| descrições idênticas | 0 |
| aberturas distintas (3 primeiras palavras) | 75 de 80 |
| bairros distintos | 57 |

Prosa de verdade, média de 34 palavras, sem template repetido. A base serve.

**O método vale mais que o número.** Similaridade léxica média entre pares é o teste barato para "a base tem variedade?", e roda offline, antes de existir embedding. Se a média tivesse dado alta, o conserto seria reescrever descrições — trabalho que ficaria muito mais caro depois do índice pronto e do S-15 em cima dele.

Confirmado na prática logo depois: busca por *"cobertura com terraço e vista aberta"* traz três coberturas no topo; *"perto da Avenida Paulista"* traz Consolação e Planalto Paulista; *"casa com quintal para os cachorros"* traz casas térreas com quintal.

## Decisões que dependem disso

- [[Decisao - Indice vetorial em memoria]]
- [[Decisao - Cache de embeddings por hash da base]]
