---
tipo: conceito
tags: [conceito, arquitetura]
---
# Agente stateless

## O que é

O serviço não guarda nada entre uma chamada e outra. Todo o estado necessário chega na requisição e sai na resposta. Quem persiste é outro.

Consequências que valem em qualquer sistema:

- escala horizontal é trivial — qualquer réplica atende qualquer turno;
- não existe "estado sujo" a debugar dentro do agente;
- em compensação, a requisição carrega mais dados, e o contrato fica maior.

## Como aparece no Solar

O agente Python **nunca** acessa o banco. A API .NET é a única dona do estado: histórico da conversa, lead, score, agendamento. A cada turno a .NET monta o payload, chama o agente e grava o resultado.

Isso é o que torna a [[Arquitetura poliglota]] pagável por uma pessoa só — sem estado compartilhado, a fronteira entre os dois repos é só o [[Contrato POST turn]].

Tem um efeito colateral bom na [[LGPD e GDPR]]: se o agente não persiste, não há dado pessoal parado nele. O que passa por ele é de passagem, e passa pelo [[Mascaramento de PII]].

Tem um efeito colateral ruim: o [[Indice vetorial em memoria]] precisa ser reconstruído no boot de cada réplica.

## Decisões que dependem disso

- [[Decisao - Agente Python stateless]]
- [[Decisao - Indice vetorial em memoria]]
