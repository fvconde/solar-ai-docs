---
tipo: decisao
data: 2026-09-05
status: vigente
tags: [decisao, dominio, dotnet]
---
# Decisão — Conversa em memória, turno serializado, perfil fundido pela API

## Problema

O S-07 abriu o `POST /conversas/{id}/mensagens`, que é o primeiro endpoint do Solar que **guarda estado**. Três perguntas apareceram juntas, e nenhuma tinha resposta óbvia no contrato já congelado.

## Decisão

### Quem funde o perfil

A API. O agente devolve `camposExtraidos` — só o que *aquele turno* acrescentou, com campo nulo significando "não mencionado agora" — e a API funde isso no `PerfilLead` acumulado. Campo não-nulo sobrescreve; `intencao: "indefinida"` **não** apaga uma intenção já conhecida.

É a regra do [[Agente stateless]] aplicada ao estado do lead: se o agente fundisse, ele precisaria carregar o perfil anterior como estado próprio, e a fronteira deixaria de ser um turno isolado.

### Como o histórico é montado

Últimas `Conversas:JanelaHistorico` mensagens, padrão **20**, com `Math.Clamp` entre 2 e `ContratoTurno.LimiteHistorico` (50). O clamp não é decorativo: o contrato recusa `historico` acima de 50 do lado do agente, e uma janela mal configurada viraria 422 no Python e **502** para o chamador, num erro que parece de rede e é de configuração.

A mensagem do turno atual **não** entra no histórico enviado — ela vai em `mensagem`. Quem entra é o que já foi trocado.

### Turnos da mesma conversa não correm em paralelo

Um `SemaphoreSlim` por conversa, segurado **através** da chamada ao agente. Duas mensagens simultâneas na mesma conversa, sem isso, leem o mesmo histórico vazio e uma das duas atualizações de perfil se perde.

## Motivo

O card mandava usar dicionário em memória de propósito: fechar o circuito antes de introduzir persistência, para não depurar duas coisas ao mesmo tempo. O S-10 troca o `ConversaStore` por EF Core e Postgres — e aí a trava por conversa vira transação, não desaparece.

## Invariante que vale documentar

**Turno que falha não deixa rastro.** O `RegistrarTurno` só roda depois de o agente responder. Com o agente parado, o `POST` devolve 502, o histórico fica no tamanho anterior, o perfil não muda, e reenviar a mesma mensagem depois funciona como se a primeira tentativa não tivesse existido.

Sem isso, a mensagem do lead entraria no histórico sem resposta da Lia, e o próximo turno mandaria ao agente um histórico terminando em `lead` — estado que o contrato aceita e que a Lia interpretaria errado.

## Custo aceito

- Estado morre quando o processo reinicia. É o que se quer nesta fase.
- Conversa é criada implicitamente no primeiro `POST`, com `Guid` escolhido pelo cliente. Qualquer id cria conversa: o `POST /conversas` fica público e sem limite até o S-29, exatamente como o `POST /turn`.
- Duas mensagens simultâneas na mesma conversa serializam, então a segunda espera a primeira. Para um chat é a semântica correta.

## Verificado em 05/09

Ambiente completo de pé. Conversa de três turnos: perfil acumulou `intencao` no turno 1, `precoMax` + `regiao` no 2, `quartos` + `nome` no 3, com score 30 → 50 → 65 e nada re-perguntado. `docker stop` no agente: **502**, histórico parado em 6, perfil intacto, e o mesmo turno reenviado depois fechou em 8. Dois `POST` simultâneos: 200 nos dois, 3,6 s e 7,6 s, histórico alternando `lead`/`agente` e perfil com as duas atualizações.

## Conceitos

[[Agente stateless]] · [[Contrato POST turn]] · [[Qualificacao de leads]]

## Relacionadas

- [[Decisao - Contrato do POST turn congelado]]
- [[Decisao - NET 10 com controllers]]
- [[Decisao - Um no com saida estruturada]]
- [[Decisao - S-29 reenquadrado com endpoint de exclusao]]
