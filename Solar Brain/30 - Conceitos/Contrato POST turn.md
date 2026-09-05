---
tipo: conceito
tags: [conceito, arquitetura, risco]
---
# Contrato POST /turn

## O que é

O único ponto de contato entre `solar-ai-api` (.NET) e `solar-ai` (Python). Um turno de conversa entra, um turno de resposta sai.

Como é a **única** fronteira da [[Arquitetura poliglota]], ele concentra todo o risco de retrabalho do projeto: qualquer mudança nele exige commit coordenado em dois repositórios, e a [[Decisao - Quatro repositorios separados]] tornou esse commit mais caro de propósito.

## Como aparece no Solar

Congelado cedo, no card **S-05**, justamente porque descongelar sai caro. Versionado nos dois repos.

Ele carrega o estado inteiro do turno porque o [[Agente stateless]] não tem de onde tirar contexto — é essa a troca aceita.

## Risco registrado

O ESTADO.md lista este contrato como **a maior fonte potencial de retrabalho do projeto**. Se ele mudar depois da Fase 2, o custo é dobrado por definição.

## Decisões que dependem disso

- [[Decisao - Agente Python stateless]]
- [[Decisao - Quatro repositorios separados]]
