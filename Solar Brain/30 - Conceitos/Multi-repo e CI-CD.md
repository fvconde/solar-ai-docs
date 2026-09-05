---
tipo: conceito
tags: [conceito, infra]
---
# Multi-repo e CI/CD

## O que é

Um repositório por serviço, cada um com seu pipeline. O oposto do monorepo, onde um pipeline só serve tudo.

**A favor:** pipeline independente, deploy independente, histórico limpo por serviço.
**Contra:** qualquer mudança que atravessa dois serviços vira commit coordenado em dois lugares, sem atomicidade.

Num time, o trade-off é sobre autonomia. Numa pessoa só, é puro custo — que se paga se o CI/CD por repositório for um objetivo em si.

## Como aparece no Solar

Quatro repositórios lado a lado numa pasta `solar/`:

- `solar-ai-front` — Angular 20
- `solar-ai-api` — C# .NET 10 Web API, controllers
- `solar-ai` — agente Python LangGraph
- `solar-ai-docs` — este repo: ESTADO.md, ARQUITETURA.md, docker-compose.yml, skills e o vault

O custo aceito recai inteiro sobre o [[Contrato POST turn]].

## Decisões que dependem disso

- [[Decisao - Quatro repositorios separados]]
