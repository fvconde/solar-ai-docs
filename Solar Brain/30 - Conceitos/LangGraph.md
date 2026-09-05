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

O nó qualificador é onde o score do lead sai, via LLM. É por isso que [[Decisao - Nenhum ML classico no escopo]] pôde ser tomada: o score já existe sem treinar modelo nenhum.

O estado do grafo é do turno, não da sessão — ver [[Agente stateless]].

## Decisões que dependem disso

- [[Decisao - Arquitetura poliglota Python e NET]]
- [[Decisao - Nenhum ML classico no escopo]]
