---
tipo: decisao
data: 2026-10-08
status: vigente
tags: [decisao, front, chat, trilha, agendamento, contato, painel]
---

# Decisão — A trilha do chat é uma projeção do que a API grava

## Problema

No tour de 08/10, depois do S-47, o usuário apontou ajustes na tela que são de apresentação:
- Depois do clique num horário ficavam três coisas: o cartão, a fala do lead e o "Combinado!" da Lia.
- Os avisos não mostravam a hora.
- Quem estava logado precisava digitar de novo o contato que a conta já tem.
- As métricas ocupavam metade da Visão geral.

O jeito fácil seria apagar falas no banco ou gravar a apresentação na API. Só que painel, métricas e expurgo leem essas falas (ver [[Decisao - Reserva por botoes confirmada pelo banco]]).

## Decisão (S-48)

- **A API continua gravando tudo, e o front decide o que mostrar.** A escolha do horário continua gravada como fala do lead mais a confirmação da Lia, com `StatusAgendamento` e `SlotId`. Ao vivo e no reload, o front troca esse par por um único aviso "Reunião agendada". Ele só retira a fala do lead quando o par é inequívoco: mesma hora `em` e mesmo horário reservado. Na dúvida, a fala fica na tela.
- **A hora dos avisos sempre vem de um dado persistido.**
  - Encaminhado: hora da fala da Lia que fechou em handoff.
  - Reunião agendada: `em` da confirmação.
  - Contato enviado: a coluna nova `leads.contato_em`, anulável e sem backfill. Conversa anterior ao S-48 mostra o aviso sem hora, sem inventar valor.
- **Logado recebe o formulário preenchido, e o chat nunca escreve na conta.** Os valores vêm de `GET /api/conta` e valem só para aquela conversa. O envio segue pelo mesmo `POST /conversas/{id}/contato`. Campo que a conta não tem fica vazio. Foram descartados: pular o formulário, pedir só o que falta e "Usar outro contato".
- **Métricas viraram aba própria.** A Visão geral fica só com a lista e o detalhe, em altura total. "Ver mais"/"Ver menos" e a preferência no `localStorage` saíram.

## Por que

Uma mudança de apresentação não pode apagar o que outra tela lê. Mantendo o banco completo, o painel, as métricas do S-45 e o expurgo continuam iguais, e o front pode mudar de ideia sem migration.

## Custo aceito

- A regra que identifica o par lead + confirmação vive no front. Se a API mudar a forma como grava a reserva, essa regra precisa mudar junto.
- Depois do handoff, a Lia vai para o agendador e não busca mais imóveis. Esse comportamento é do agente e ficou fora do card. Para o vídeo, peça imóveis antes do encaminhamento.
- No desktop de 1440 px, o rótulo "Encaminhamento solicitado" passa 4,4 px de cada lado da coluna do gráfico, sem colidir com as vizinhas. Já era assim antes do S-48.

Registro da execução: `execucoes/S-48-6f8174aa-b118-4324-a6ae-c584d178b442.md`.
