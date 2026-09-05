---
tipo: decisao
data: 2026-08-21
status: vigente
tags: [decisao, arquitetura, regra-dura]
---
# Decisão — O agente Python é stateless e nunca acessa o banco

## Problema

Com dois serviços, a pergunta imediata é quem é dono do estado. Se os dois forem, existem duas verdades sobre a mesma conversa, e um dia elas discordam.

## Decisão

Toda persistência é da API .NET. O agente Python **nunca** toca o banco. Esta é regra de arquitetura, não preferência — não muda sem decisão nova registrada aqui.

## Motivo

Mantém o contrato entre os dois repos pequeno, que é exatamente o que torna a [[Arquitetura poliglota]] pagável por uma pessoa só.

## Custo aceito

O payload do turno fica maior — o agente não tem de onde buscar contexto, então tudo tem que chegar na requisição. E o [[Indice vetorial em memoria]] tem que ser reconstruído no boot.

## Efeito colateral bom

Dado pessoal não fica parado no agente. Isso simplifica a resposta a [[LGPD e GDPR]] e reduz a superfície do [[Mascaramento de PII]].

## Conceitos

[[Agente stateless]] · [[Contrato POST turn]] · [[Arquitetura poliglota]]

## Relacionadas

- [[Decisao - Arquitetura poliglota Python e NET]]
- [[Decisao - Indice vetorial em memoria]]
