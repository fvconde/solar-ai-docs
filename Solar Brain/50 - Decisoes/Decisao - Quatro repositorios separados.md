---
tipo: decisao
data: 2026-08-21
status: vigente
tags: [decisao, infra]
---
# Decisão — Quatro repositórios separados

## Problema

Monorepo ou multi-repo. Para uma pessoa só, monorepo é quase sempre a resposta certa — menos cerimônia, commit atômico atravessando serviços.

## Decisão

Quatro repositórios: `solar-ai-front`, `solar-ai-api`, `solar-ai` e `solar-ai-docs`.

## Motivo

**CI/CD por repositório é diferencial listado no enunciado.** Pipeline independente por serviço é o argumento inteiro — sem ele, esta decisão não se sustentaria.

## Custo aceito

Mudanças no contrato exigem **commit coordenado em dois repos**, sem atomicidade. Isso encarece exatamente a coisa mais arriscada do projeto.

## Conceitos

[[Multi-repo e CI-CD]] · [[Contrato POST turn]]

## Relacionadas

- [[Decisao - Arquitetura poliglota Python e NET]]
- [[Decisao - Agente Python stateless]] — reduz a frequência com que o custo acima é pago
