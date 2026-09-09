---
tipo: conceito
tags: [conceito, ia, armadilha]
---
# Gemini free tier

## O que é

A família Gemini Flash / Flash-Lite tem camada gratuita de uso via API, com cota **por dia e por projeto**.

## Por que foi escolhido no Solar

É o único free tier relevante que **não exige cartão de crédito** — o que importa porque o plano de deploy do projeto está preso exatamente nessa pergunta (ver riscos do ESTADO.md).

## As armadilhas

1. **Ativar billing num projeto do Google apaga o free tier daquele projeto inteiro**, na hora e sem desfazer. Por isso o Solar usa um projeto isolado — e, desde 05/09, dois projetos com papéis fixos. A mecânica completa, incluindo o estado intermediário em que se paga *e* os dados ainda vão para treino, está em [[Billing na Gemini API]].
2. **A cota é diária, e o número é 500.** Medido no S-12, quando ela estourou pela primeira vez no projeto: `GenerateRequestsPerDayPerProjectPerModel-FreeTier`, `quotaValue: 500`, por modelo e por projeto, para o `gemini-3.5-flash-lite`. Erro `429` durante o desenvolvimento é cota, não bug no código.
3. **Existe também limite por minuto**, e ele não se parece com um erro. Em rajada de chamadas, o SDK entra em backoff e repete sozinho: o que chega ao código é uma chamada bem-sucedida que demorou 30 s, não um `429`. Descoberto no S-06 — ver [[Bug - latencia de 30s por limite por minuto]]. As duas cotas se confundem fácil: a diária falha alto, a por minuto falha devagar.

4. **Embedding tem cota própria, e ela conta por conteúdo, não por requisição.** Medida no S-14: `EmbedContentRequestsPerMinutePerUserPerProjectPerModel-FreeTier`, `quotaValue: 100`, no `gemini-embedding-001` (a métrica reporta o modelo como `gemini-embedding-1.0`). O `batchEmbedContents` manda os 80 imóveis numa única chamada HTTP e mesmo assim gasta **80 das 100** — então **dois boots do índice no mesmo minuto dão `429`**. É a face número três da cota, e a única em que a unidade não é a requisição. Não se soma à cota diária de geração: são métricas separadas. Ver [[Indice vetorial em memoria]] e [[Decisao - Cache de embeddings por hash da base]].

## Quanto custa uma sessão de iteração

Números do S-12, o dia em que os 500 acabaram:

| operação | chamadas |
|---|---|
| `pytest -m llm` (suíte de extração) | 27 |
| `pytest -m llm -k handoff` (subconjunto) | 4 |
| `conversas_exemplo.py` (7 roteiros) | 29 |
| um turno real na demo | 1 |
| boot do índice sem cache (S-14) | 80 *na cota de embedding* |
| uma busca no índice (S-14) | 1 *na cota de embedding* |

Uma iteração honesta — mudar o prompt, rodar o gate, regravar os roteiros — custa **56 chamadas**. Cabem cerca de **oito** dessas num dia, e o S-12 precisou de mais.

**Consequência prática, aprendida caro:** iterar prompt contra o subconjunto (`-k`) e guardar a suíte completa para o fim. Rodar a suíte inteira depois de cada ajuste de texto gasta o orçamento do dia em três tentativas.

**As duas cotas atingem a demo, cada uma do seu jeito.** A diária derruba tudo até virar o dia. A por minuto é pior de diagnosticar: logo depois de uma bateria de testes, uma conversa real estoura o timeout de 45 s da API e vira `504` — visto no S-12, ver [[Bug - turno real vira 504 sob cota por minuto]]. Nos dois casos a regra é a mesma: **não rodar testes na hora anterior à gravação do vídeo.**

## Contrapartida registrada

No free tier, o conteúdo enviado pode ser usado para treinar produtos do Google. É isso que torna o [[Mascaramento de PII]] um controle necessário e não uma boa prática.

## Decisões que dependem disso

- [[Decisao - LLM Gemini Flash free tier]]
- [[Decisao - Dois projetos Google separados]]
- [[Decisao - Modelo Gemini fixado sem alias]]
- [[Decisao - Um no com saida estruturada]]
