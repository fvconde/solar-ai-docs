---
tipo: conceito
tags: [conceito, ia]
---
# LangGraph

## O que é

Biblioteca para orquestrar agentes de LLM como **grafo de estados**, não como cadeia linear. Cada nó é um passo (classificar intenção, buscar imóvel, qualificar, agendar); as arestas decidem para onde ir com base no estado.

Ganho sobre uma cadeia simples: fluxo condicional e ciclos ficam explícitos e inspecionáveis, em vez de virarem `if` espalhado no código.

## Como aparece no Solar

É a camada de IA inteira do `solar-ai`. O grafo da Lia tem que dar conta de identificação de intenção, [[Qualificacao de leads]], busca via [[RAG]] e agendamento — todos requisitos obrigatórios do enunciado.

O estado do grafo é do turno, não da sessão — ver [[Agente stateless]].

## O grafo hoje

```
START → qualificar → responder → pontuar → END
        (puro)       (Gemini)    (puro)
```

Três nós desde o S-12, e **uma** chamada ao LLM. Os nós das pontas são funções puras sobre a [[Regua de qualificacao]]: `qualificar` decide sobre o que perguntar, `pontuar` calcula o score.

Essa é a forma que a [[Decisao - Um no com saida estruturada]] deixou marcada: separar nós só quando eles tiverem **trabalho próprio**, porque nó que só relê o mesmo texto dobra a cota do [[Gemini free tier]] sem entregar nada. Um nó puro não custa chamada, então a conta não mudou.

O nó de busca por [[RAG]] entra no S-15 — e esse **vai** custar, porque tem trabalho próprio de verdade.

## Decisões que dependem disso

- [[Decisao - Arquitetura poliglota Python e NET]]
- [[Decisao - Nenhum ML classico no escopo]]
- [[Decisao - Um no com saida estruturada]]
- [[Decisao - Score por regua deterministica]]
