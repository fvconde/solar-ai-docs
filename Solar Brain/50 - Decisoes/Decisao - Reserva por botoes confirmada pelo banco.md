---
tipo: decisao
data: 2026-10-08
status: vigente
tags: [decisao, agendamento, slots, front, api, sem-llm]
---
# Decisão — Reserva por botões, confirmada pelo banco e fora do LLM

## Problema

Desde o S-17 a Lia agenda pela conversa: a API manda até três horários no `/turn`, o modelo escolhe um e a API reserva com `UPDATE` condicional (ver [[Decisao - Agenda simulada por slots]] e [[Decisao - Agenda na requisicao e agendador como no do grafo]]). Funcionava, mas na tela aparecia só como uma linha de evento. Quem avalia pelo vídeo podia não perceber que o requisito de agendamento existe, e cada escolha de horário custava uma chamada ao Gemini.

## Decisão

Depois do encaminhamento com corretor atribuído e do envio do contato (ver [[Decisao - Encaminhamento ao corretor com contato fora do LLM]]), o chat mostra um cartão com os próximos três horários livres do corretor. O clique vai direto à API, sem passar pelo agente:

- **Oferta é fato do banco.** `POST /conversas/{id}/contato` e `GET /conversas/{id}` devolvem `oferta`, sempre lista, recalculada a cada leitura. Ela só vem preenchida com corretor atribuído, contato registrado e nenhum agendamento confirmado.
- **A reserva é a mesma do S-17.** `POST /conversas/{id}/agendamentos { slotId }` usa a trava da conversa e o `UPDATE` condicional. Na mesma transação, grava a fala do lead com o horário e a fala fixa da Lia, sem chamada ao modelo.
- **Perda de corrida é resposta, não erro.** `409 horario_indisponivel` traz uma oferta nova, que pode vir vazia. Os outros `409` (já agendada, sem contato, sem corretor) têm código próprio. Slot de outro corretor responde `404`.
- **O front só confirma depois do `200`** e reconstrói oferta, cartão e recibo pelo `GET`. Uma falha de leitura nunca repete o `POST`.
- **Horários fixos 9h, 14h e 19h**, sobre a tabela `slots` existente. A `AgendaInicial` garante 9 livres por corretor e apaga no boot só os slots **futuros e livres** fora desses horários.

Com reunião marcada, a Lia não responde perguntas novas: ela devolve a frase fixa e o corretor segue o atendimento. Decisão do usuário no tour de 07/10.

## Por que não pelo LLM

O horário escolhido é um id do banco, e o modelo só acrescentaria risco e custo. A Lia continua aceitando "pode ser às 14h" pelo texto, como no S-17, e os dois caminhos acabam no mesmo `UPDATE` condicional.

## Custo aceito

- Duas rotas chegam à mesma reserva, a do turno e a do botão. Qualquer regra nova de elegibilidade precisa valer nas duas.
- O aviso visual de horário perdido não foi observado no E2E real. A concorrência está provada contra Postgres e pelos testes do front, e essa limitação foi aceita pelo usuário.
- O recolhimento ("Agora não") fica no `sessionStorage` da conversa. Ele sobrevive ao F5, mas não a outro navegador.

## Fora

Calendário semanal do corretor, remarcar e cancelar, gestão de disponibilidade e Google Calendar.

Registro da execução: `execucoes/S-47-d7f38617-86fa-4f87-8eb1-64d37079d636.md`.
