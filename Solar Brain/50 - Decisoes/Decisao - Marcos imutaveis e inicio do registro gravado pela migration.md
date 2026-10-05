---
tipo: decisao
data: 2026-10-05
status: vigente
tags: [decisao, painel, metricas, api, migration, contrato, lia]
---
# Decisão — Marcos imutáveis por conversa e início do registro gravado pela migration

## Problema

O gráfico "Avanço das conversas no chat" conta o que cada conversa **já alcançou**. Até o S-45, o banco só guardava a situação atual, e a redistribuição reescreve `encaminhamentos.status` e `encaminhamentos.em`. O design aprovado em 03/10 pedia marcos por conversa, mas não dizia onde guardar a data a partir da qual o registro vale. O handoff aceitava duas formas: a configuração `Metricas:HistoricoDesde` ou um registro gravado pela migration.

## Decisão

- **Cinco marcos em `conversas`:** `intencao_em`, `essenciais_em`, `encaminhada_em`, `corretor_atribuido_em` e `primeiro_reengajamento_em`, todos `timestamptz` anuláveis. Cada um é gravado **uma vez**, só se estiver nulo, e nunca é reescrito nem apagado. A gravação acontece no mesmo `SaveChanges` do evento: turno, atribuição ou primeiro follow-up. Um turno que falha não deixa marco.
- **O início do registro mora no banco.** A migration `RegistrarEtapasDasConversas` cria a tabela `registro_metricas`, com uma única linha (`id = 1`), e grava `historico_desde` com `now()` do próprio banco no momento em que é aplicada. Não há valor fixo nem configuração, e nenhuma conversa antiga ganha marco.
- **Dados essenciais só pela Lia, sem copiar a regra.** O `/turn` ganhou `essenciaisCompletos` na resposta, calculado por `qualificacao.lacunas_essenciais` sobre o perfil fundido. O modelo não decide e o campo não entra no schema enviado ao Gemini. É a terceira emenda do contrato congelado, que passou a ter 7 tipos e 46 campos.
- **`encaminhada_em` segue a decisão da Lia:** é o primeiro turno com `agendar_reuniao` ou `direcionar_especialista`, mesmo sem dados essenciais e mesmo quando o encaminhamento já existia. Não depende de nascer uma linha em `encaminhamentos`.
- **`corretor_atribuido_em` nos dois únicos pontos que atribuem corretor:** `DecidirAsync` e `RedistribuirAsync`. Desatribuir e reatribuir preservam o primeiro instante.

## Por quê

Com a data no banco, cada ambiente guarda o seu próprio começo real: a máquina local, o stack de teste e o Cloud Run. Também não aparece segredo nem passo manual novo no deploy do S-26, porque a API já aplica as migrations no boot. Uma data em configuração precisaria ser escrita à mão em cada ambiente, e uma data errada esconderia conversas reais ou contaria conversas sem registro como "não atingiu".

## Custo aceito

- **O histórico começa vazio.** Logo depois do deploy, o gráfico só conta conversas novas, e o painel mostra o aviso "Histórico de avanço disponível desde DD/MM".
- **A intenção vale por lead.** `intencao_em` lê a intenção do lead fundido, então um lead que já tinha intenção em outra conversa marca a etapa no primeiro turno da conversa nova.
- **Agente e API sobem juntos.** Um agente antigo, sem o campo novo, faz a API entender "essenciais incompletos" sem erro.
- **Fica um bug antigo, fora deste card.** A redistribuição pode devolver a conversa ao corretor que exclui a própria conta. Isso virou o S-46 e não altera nenhum marco. *Atualização de 05/10: o S-46 foi integrado e corrigiu o bug. Ver [[Bug - redistribuicao reescolhia o corretor que saia]].*

## Relacionadas

- [[Decisao - Metricas do painel sem copiar regras da Lia]]: as regras de dados que este registro realiza.
- [[Decisao - Contrato do POST turn congelado]]: o contrato que recebeu a terceira emenda.
- [[Decisao - Score por regua deterministica]]: a régua de onde vêm as lacunas essenciais.
