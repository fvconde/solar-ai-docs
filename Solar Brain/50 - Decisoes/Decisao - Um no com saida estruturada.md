---
tipo: decisao
data: 2026-09-05
status: vigente
tags: [decisao, ia]
---
# Decisão — Um nó com saída estruturada, não dois nós

## Problema

O contrato do `POST /turn` exige quatro coisas de cada turno: `resposta` (texto livre, que é a fala da Lia) e `intencao`, `camposExtraidos` e `proximaAcao` (estruturados, que são o julgamento sobre o lead).

Isso admite duas montagens no grafo:

1. **Dois nós** — um conversa, outro lê a conversa e extrai os campos. Separação limpa: o prompt de persona não se mistura com o prompt de extração.
2. **Um nó** — uma única chamada devolve tudo num objeto, com o schema imposto pelo próprio LLM.

## Decisão

Um nó, com `with_structured_output(SaidaLia, method="json_schema")`.

O modelo Pydantic `SaidaLia` reaproveita `CamposExtraidos` e os `Literal` do `app/contrato.py`, então o schema enviado ao Gemini e o contrato da fronteira não podem divergir sem o Python quebrar antes.

## Motivo

Dois nós **dobram o consumo de cota em cada turno de teste**, e cota é risco registrado — o free tier limita por dia e por minuto (ver [[Bug - latencia de 30s por limite por minuto]]). O S-06 é justamente o card em que se itera prompt em rajada, que é o pior momento possível para dobrar o custo por turno.

O ganho de separação que os dois nós dariam também não se perde: ele volta quando fizer diferença, no S-12 (nó qualificador) e no S-15 (nó de busca por [[RAG]]), onde os nós têm trabalho próprio de verdade e não só uma segunda leitura do mesmo texto.

O card pedia literalmente "um nó de LangGraph". A montagem mínima era a montagem certa.

## Custo aceito

O prompt de persona e as instruções de preenchimento dos campos convivem na mesma chamada. Mitigado separando em dois arquivos: `prompts/persona.md` vai como `SystemMessage` e é o que se itera; `prompts/turno.md` vai como `HumanMessage`, carrega o contexto do turno e a semântica dos campos, e muda pouco.

A camada de mascaramento do S-34 vai ter que interceptar **uma** chamada com tudo dentro, em vez de duas menores.

## Detalhes que custaram tentativa

- `gemini-3.5-flash-lite` **ignora `temperature`**: o modelo tem sampling fixo e a biblioteca emite `UserWarning` avisando que o parâmetro foi descartado. O `GEMINI_TEMPERATURE` só é enviado quando explicitamente preenchido, e vale apenas para o fallback `gemini-2.5-flash-lite`. Fixar um knob que o modelo escolhido não tem é pior que não ter knob.
- `method="json_schema"` já é o default da `langchain-google-genai` 4.4.0, mas está escrito explicitamente pela mesma razão que o modelo é fixo: default é ponteiro móvel.
- O `SaidaLia` **não vaza** para o OpenAPI publicado. Verificado: o agente continua publicando os mesmos seis schemas do contrato, e o espelho campo a campo com o .NET segue íntegro.

## Medido em 05/09

19 chamadas nos cinco roteiros de exemplo: média **1667 ms**, pior **3831 ms**, com pausa de 4 s entre chamadas.

## Conceitos

[[LangGraph]] · [[Gemini free tier]] · [[Contrato POST turn]] · [[Qualificacao de leads]]

## Relacionadas

- [[Decisao - Modelo Gemini fixado sem alias]]
- [[Decisao - Contrato do POST turn congelado]]
- [[Decisao - Nenhum ML classico no escopo]]
- [[Decisao - Conversa em memoria com turno serializado]]
