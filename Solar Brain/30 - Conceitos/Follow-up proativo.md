---
tipo: conceito
tags: [conceito, produto]
---
# Follow-up proativo

## O que é

O sistema inicia a conversa, sem que o lead tenha falado primeiro. É o que transforma um chatbot em ferramenta de vendas: o lead esfriou, o sistema volta nele.

O detalhe que decide a arquitetura é **quem pode iniciar mensagem** em cada canal.

## Como aparece no Solar

Requisito obrigatório do enunciado. E foi ele que escolheu o canal da demo:

- **WhatsApp** proíbe mensagem proativa fora da janela de 24h desde a última mensagem do usuário, e exige template aprovado. Isso **mataria a demonstração** do follow-up no vídeo.
- **Telegram** deixa o bot iniciar conversa livremente. Custo ~4h contra ~18h do WhatsApp.
- **Chat web** em Angular é o canal da demo — controle total.

Este é o exemplo mais limpo do projeto de restrição de plataforma virando decisão de arquitetura.

**Estado na UI (07/09):** o handoff do chat reserva o estado "retomada" e trata o encerramento como terminal (composer removido, follow-up desativado), mas o **controle de ativar/desativar a retomada** ainda não existe — é pendência registrada no board, junto com a janela de tempo, a frequência máxima e o texto da primeira retomada.

## Decisões que dependem disso

- [[Decisao - Canal da demo e chat web com Telegram cortavel]]
- [[Decisao - Front do chat em Angular]]
