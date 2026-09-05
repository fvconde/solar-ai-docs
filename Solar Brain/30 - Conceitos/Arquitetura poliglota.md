---
tipo: conceito
tags: [conceito, arquitetura]
---
# Arquitetura poliglota

## O que é

Usar mais de uma linguagem/runtime num mesmo sistema, cada uma na camada onde o ecossistema dela é mais forte, em vez de forçar tudo numa stack só.

O custo não é a linguagem — é a **fronteira**. Cada serviço novo é um contrato a versionar, um deploy a configurar e um lugar a mais onde o erro pode estar. Por isso o número de fronteiras importa mais que o número de linguagens.

## Como aparece no Solar

Duas linguagens, uma fronteira:

- **Python (FastAPI + LangGraph)** — camada de IA. É onde o ecossistema de agentes vive.
- **C# .NET 10 Web API**, baseada em controllers — domínio, banco e toda a persistência. Versão e estilo em [[Decisao - NET 10 com controllers]].
- **Angular 20** — front.

A fronteira inteira é o [[Contrato POST turn]]. Ela é pequena de propósito, e o que a mantém pequena é o [[Agente stateless]].

## Decisões que dependem disso

- [[Decisao - Arquitetura poliglota Python e NET]]
- [[Decisao - Agente Python stateless]]
- [[Decisao - Quatro repositorios separados]]
