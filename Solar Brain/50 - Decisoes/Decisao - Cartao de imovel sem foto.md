---
tipo: decisao
data: 2026-09-09
status: vigente
tags: [decisao, produto, front]
---
# Decisão — O cartão de imóvel não tem foto

## Problema

O S-16 nasceu, em 22/08, pedindo cards visuais "com foto placeholder, preço, bairro e principais atributos", e o próprio card já registrava o cuidado: placeholders de banco de imagem livre, **nunca** foto de imóvel real de portal.

Quando o S-15 fez os cartões desenharem com dado real, a pergunta ficou concreta: o que essa foto acrescenta?

## Decisão

**Imóvel não tem foto.** O cartão mostra informação em texto: tipo, bairro, preço da intenção do lead, quartos, metragem e o motivo escrito pela Lia.

## Motivo

A foto seria placeholder — uma imagem genérica ilustrando um imóvel que ela não é. Num produto de verdade isso é foto do anúncio; aqui seria decoração que **afirma algo falso na tela**, do lado de um preço e de uma metragem que são verificáveis contra a base.

E ela não sustenta nenhum dos 11 requisitos obrigatórios do enunciado. A base de imóveis é simulada e assumida como tal ([[Decisao - Nenhum ML classico no escopo]] tem a mesma lógica: o que não prova nada não entra).

## Custo aceito

A demo tem menos apelo visual do que teria com imagem. Em troca, nada no cartão finge ser o imóvel real — e a tela inteira passa a ser conteúdo que a Lia ou a base podem justificar.

## Consequência

O S-16 fica **satisfeito pelo que já existe**: o `card-imovel` do S-09 mais o `imoveisSugeridos` do S-15. Cerca de 4h voltam para a margem do projeto, que é o recurso mais escasso da Fase 3 em diante.

O texto do critério de aceite no board ainda nomeia a foto e precisa ser corrigido lá — o board é do Felipe, esta nota é o registro do porquê.

## Conceitos

[[RAG]] · [[Qualificacao de leads]]

## Relacionadas

- [[Decisao - Front do chat em Angular]] — onde o cartão nasceu
- [[Decisao - Motivo do LLM como portao do cartao]] — a única frase do cartão que alguém escreveu, e por que ela tem dono
- [[Decisao - Busca depois do LLM disparada pela regua]]
