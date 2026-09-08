---
tipo: decisao
data: 2026-09-08
status: vigente
tags: [decisao, contrato, api]
---
# Decisão — DTO próprio para a releitura da conversa

## Problema

O S-13 precisava que o desfecho de cada turno sobrevivesse ao recarregamento da página. Sem ele, uma conversa encerrada voltava com o campo de digitação ativo, e o evento "Encaminhado" sumia da trilha.

O dado tinha que sair do banco e chegar ao front pelo `GET /conversas/{id}`. A rota óbvia era acrescentar `proximaAcao` ao `MensagemHistorico`, que já é o tipo das mensagens nessa resposta.

## Decisão

`MensagemHistorico` **não foi tocado**. O caminho de releitura ganhou tipo próprio, `MensagemDaConversa`, em `Contracts/ContratoConversa.cs`, e o `ConversaResponse` passou a usá-lo.

## Motivo

`MensagemHistorico` não é um DTO qualquer: é parte do [[Contrato POST turn]] congelado, espelhado campo a campo no Pydantic do agente ([[Decisao - Contrato do POST turn congelado]]). Mexer nele custaria três coisas de uma vez:

1. **Commit coordenado nos dois repositórios**, porque os dois lados recusam campo desconhecido — o `extra="forbid"` do Pydantic derrubaria o primeiro turno.
2. **Dado inútil trafegando a cada turno**: o histórico vai ao agente em toda chamada, e o agente não tem uso nenhum para o desfecho de turnos passados. Seriam até 50 campos a mais por requisição, e mais texto entrando no prompt do [[Gemini free tier]].
3. **A fronteira ficaria maior sem ganho.** O contrato pequeno é o que torna a [[Arquitetura poliglota]] pagável por uma pessoa só.

O `MensagemDaConversa` existe apenas no .NET. Verificado nos dois OpenAPI publicados: o espelho segue com **6 tipos e 37 campos**, os mesmos do S-10 e do S-12, e `MensagemDaConversa` aparece só no `:8080`.

## A regra que sai daqui

> **A resposta do `GET /conversas/{id}` é da UI; a do `POST /turn` é do agente. Elas não precisam compartilhar tipo, e não devem.**

Elas coincidiam por acidente de origem — no S-07 as duas nasceram do mesmo `MensagemHistorico` porque não havia diferença entre o que a UI e o agente precisavam. O S-13 criou a primeira diferença, e o certo foi separar em vez de inchar o tipo compartilhado.

Isso vale para o que vem: o S-16 vai querer `imoveisSugeridos` persistidos na trilha, e o S-19/S-20 vão querer campos de painel. Todos entram no DTO da UI, nenhum no contrato do agente.

## Custo aceito

Dois tipos com quatro campos em comum, e o `HistoricoCompletoAsync` projetando para um enquanto o `HistoricoRecenteAsync` projeta para o outro. É duplicação real, e é barata: a alternativa era acoplar a UI ao contrato do agente, e aí toda evolução de tela viraria commit coordenado.

## Conceitos

[[Contrato POST turn]] · [[Arquitetura poliglota]] · [[Agente stateless]] · [[Migrations no Solar]]

## Relacionadas

- [[Decisao - Contrato do POST turn congelado]] — o contrato que esta decisão protege
- [[Decisao - Persistencia em EF Core com Postgres]] — onde a coluna `proxima_acao` foi parar
- [[Decisao - Front do chat em Angular]] — quem consome o DTO novo
