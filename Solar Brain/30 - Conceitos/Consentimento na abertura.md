---
tipo: conceito
tags: [conceito, privacidade, fase5]
---
# Consentimento na abertura

## O que é

Base legal do tratamento. Antes de coletar qualquer dado do lead, a Lia diz o que vai coletar, para quê, e pede o aceite. O aceite fica registrado com carimbo de tempo.

É o requisito mais barato da [[LGPD e GDPR]] de implementar e o mais visível de demonstrar — aparece na primeira tela da demo.

## Como aparece no Solar

Card **S-33**, 2h. Primeira tela do fluxo conversacional.

Tem um atrito real com o requisito de *conversa natural* e *fluxo humanizado* do enunciado: aviso legal na abertura é o oposto de humanizado. A saída é escrever o consentimento na voz da Lia, não em juridiquês — o que também é conteúdo para a seção de privacidade do README.

**A metade da UI já está feita (07/09, com o S-09):** aceite **ativo** — checkbox desmarcada por padrão, sem pré-marcação nem aceite implícito —, recusa **reversível** com evento "Conversa não iniciada", e nenhuma mensagem enviada ao provedor antes da marcação e da ação principal. O aviso fala em "provedor de inteligência artificial", nunca no nome do provedor, e declara que as mensagens não treinam modelos.

**Falta a outra metade:** registrar o aceite com **carimbo de tempo** no backend. Hoje ele só existe no `localStorage` do navegador — some ao trocar de máquina ou limpar o site.

## Decisões que dependem disso

- [[Decisao - Camada minima de privacidade como Must]]
- [[Decisao - Front do chat em Angular]]
- [[Decisao - Consentimento persistido antes do kickoff]]
