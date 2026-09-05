---
tipo: decisao
data: 2026-08-21
status: vigente
tags: [decisao, arquitetura]
---
# Decisão — Arquitetura poliglota: Python para IA, .NET para domínio

> **Vigente**, com um detalhe superado em 05/09: onde se lê ".NET 9 Web API", hoje é **.NET 10 com controllers**. A repartição Python/​.NET decidida aqui não mudou. Ver [[Decisao - NET 10 com controllers]].

## Problema

Um monolito Python entregaria a POC mais rápido. Mas o projeto tem dois objetivos ao mesmo tempo: passar no Tech Challenge e servir à carreira de quem o escreve.

## Decisão

**Python (LangGraph)** para a camada de IA. **C# .NET 9 Web API** para o domínio e o banco.

## Motivo

LangGraph é onde o ecossistema de agentes vive — reimplementar aquilo em .NET seria trabalho puro sem ganho. E .NET é a stack de carreira: o repositório fica como peça de portfólio na linguagem que importa profissionalmente.

## Custo aceito

Cerca de **8h a mais** que um monolito Python, e uma fronteira entre serviços a manter.

## Conceitos

[[Arquitetura poliglota]] · [[LangGraph]] · [[Contrato POST turn]]

## Relacionadas

- [[Decisao - Agente Python stateless]] — o que mantém o custo dessa fronteira pagável
- [[Decisao - Quatro repositorios separados]]
