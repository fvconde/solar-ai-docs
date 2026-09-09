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

## Como ele roda, desde o S-15

A busca é **híbrida**, e nessa ordem: filtro estruturado primeiro, similaridade depois.

1. **Filtro duro** — tipo, quartos (piso, não igualdade), região (bairro ou zona) e preço. Preço só filtra com a `intencao` conhecida, porque é ela que diz se o número se compara com venda ou com aluguel. Nada aqui é negociável: o que não passa, não concorre.
2. **Cosseno** sobre o que sobrou, com a consulta embutida na hora — 1 unidade de cota por busca.

O texto da consulta é a mensagem do lead mais um complemento montado do perfil, para o caso de a mensagem sozinha não descrever imóvel nenhum ("pode ser", "manda o que você achar"). **Preço fica de fora do texto embutido de propósito:** ele já é restrição dura no filtro, e número em texto de embedding aproxima por semelhança de dígito, não de imóvel.

**Lista vazia é resposta, não falha.** Quando o filtro não deixa nada passar, a Lia diz que a base não tem aquilo e negocia o critério que mais aperta, nomeando qual. Ela nunca troca por um imóvel qualquer — e `proximaAcao` desce para `continuar_conversa`, porque sugerir sem imóvel não é sugerir.

O que o RAG **não** faz aqui: reordenação por modelo, *query expansion*, chunking. A base são 80 registros curtos, um documento por imóvel; nada disso teria o que consertar.

## O gargalo real não era o modelo

O funil aperta cedo. Na consulta do critério de aceite — *2 quartos, zona sul, até R$ 600.000* — **3 dos 80 imóveis passam no filtro duro**. Com três candidatos, a parte semântica não tem o que ordenar: quem decide a qualidade da resposta é o filtro, não o embedding.

Isso inverte a intuição de quem chega ao RAG pela vitrine da similaridade. Numa base pequena com restrições fortes, **o trabalho está em acertar o filtro** — e foi por isso que o tipo do imóvel virou filtro duro em [[Decisao - Tipo de imovel como filtro derivado do texto]] em vez de ficar por conta do ranking.

## Decisões que dependem disso

- [[Decisao - Indice vetorial em memoria]]
- [[Decisao - Cache de embeddings por hash da base]]
- [[Decisao - Busca depois do LLM disparada pela regua]]
- [[Decisao - Motivo do LLM como portao do cartao]]
- [[Decisao - Tipo de imovel como filtro derivado do texto]]
