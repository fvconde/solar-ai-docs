---
tipo: decisao
data: 2026-09-11
status: proposta
tags: [decisao, privacidade, api, angular]
---
# Decisão — Consentimento persistido antes do kickoff

## Problema

O aceite do aviso existia somente no `localStorage`. O primeiro `POST` de mensagem criava a conversa e o lead ao enviar o kickoff silencioso `Olá`, sem existir um carimbo de consentimento no servidor.

## Proposta

Criar `POST /conversas/{id}/consentimento` para registrar `ConsentimentoEm` e `VersaoAvisoPrivacidade` no lead antes de qualquer mensagem. O endpoint cria conversa e lead sem mensagens, valida a versão vigente e é idempotente para a mesma versão.

`POST /conversas/{id}/mensagens` deixa de criar conversa e responde conflito quando não encontra um lead consentido. O front guarda apenas o identificador da conversa no navegador, consulta o carimbo no servidor e só então envia o kickoff.

Por decisão do usuário, a declaração de uso para treino foi revertida, e o motivo é o que faltava nesta nota: **o texto descreve o regime alvo do projeto, o tier pago, e não o de desenvolvimento.** O desenvolvimento roda em free tier — conferido em 07/09, sem conta de faturamento —, mas a proposta é aderir ao tier pago, e as telas passam a refletir isso desde já. A consequência fica escrita: adotar o tier pago é pré-condição para a declaração ser verdadeira em uso real, e a demo gravada conta como uso. Concretamente: o aviso curto e a página completa agora afirmam, de forma alinhada, que as mensagens não são usadas pelo provedor para treinar ou melhorar modelos. Essa decisão diverge conscientemente do critério escrito do card, que permanece inalterado. O aviso ainda declara a finalidade do processamento e o encaminhamento para atendimento humano; o link abre uma página completa, e a retenção apenas referencia a política da Solar, cuja regra continua pertencendo ao S-30.

Quando a deduplicação por telefone ou e-mail funde dois leads, o registro sobrevivente conserva o aceite explícito mais recente, sempre transferindo carimbo e versão juntos. O modelo atual comporta um único evento de consentimento; escolher o mais recente preserva a evidência do aviso mais novo que a pessoa aceitou, enquanto manter o primeiro poderia deixar como vigente uma versão já superada. Essa regra evita que o aceite morra junto com o lead removido e não substitui um histórico imutável de eventos, caso ele seja exigido no futuro.

## Consequências

- Recusar na primeira tela não cria lead, conversa ou mensagem.
- Uma chamada direta ao endpoint de mensagens não contorna o consentimento.
- Conversas antigas sem carimbo pedem novo aceite antes de continuar.
- Uma nova conversa pede novo aceite porque, no modelo atual, ela nasce com outro lead.
- A deduplicação nunca apaga um aceite e mantém a versão correspondente ao carimbo mais recente.

## Conceitos

[[Consentimento na abertura]] · [[Contrato POST turn]] · [[LGPD e GDPR]]

## Relacionadas

- [[Decisao - Front do chat em Angular]]
- [[Decisao - Camada minima de privacidade como Must]]
