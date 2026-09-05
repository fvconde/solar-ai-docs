---
tipo: conceito
tags: [conceito, privacidade, fase5]
---
# Mascaramento de PII

## O que é

Substituir dado pessoal identificável por um marcador antes que ele saia do sistema — para o LLM, para o log, para qualquer lugar que você não controla.

`"meu CPF é 123.456.789-00"` vira `"meu CPF é <CPF>"`. O modelo entende a intenção sem receber o valor.

Vale para nome, telefone, e-mail, CPF, endereço. O valor real fica só onde precisa estar: no banco da API .NET.

## Como aparece no Solar

Card **S-34**, 2h. Duas superfícies:

1. **Antes do LLM** — o payload do [[Contrato POST turn]] passa pela camada de mascaramento antes de virar prompt.
2. **Nos logs** — nenhum dos três serviços grava dado pessoal em texto claro.

A regra de arquitetura é dura: se uma tarefa precisa do valor real, o porquê fica escrito no `ARQUITETURA.md`, não na cabeça de ninguém.

O [[Agente stateless]] ajuda aqui — o que não é persistido não vaza depois.

## Decisões que dependem disso

- [[Decisao - Camada minima de privacidade como Must]]
