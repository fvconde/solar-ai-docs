---
tipo: decisao
data: 2026-08-31
status: vigente
tags: [decisao, ia, escopo]
---
# Decisão — Nenhum componente de ML clássico entra no escopo

## Problema

Mesma revisão de 31/08 que descobriu a lacuna da Fase 5 levantou a pergunta simétrica: as Fases 1, 2 e 4 do currículo também não aparecem no projeto. Caberia um modelo treinado — um classificador de score de lead, digamos.

## Decisão

Nenhum ML clássico. As Fases 1, 2 e 4 ficam de fora.

## Motivo

O score do lead **já sai** do nó qualificador do S-12, via LLM (ver [[Qualificacao de leads]] e [[LangGraph]]). Um modelo treinado em base sintética custaria **3–6h para provar pouco** — e provaria sobre dados que o próprio projeto inventou.

## Custo aceito

Três fases do currículo sem representação no entregável.

**Mitigação:** vale uma linha no README dizendo isso explicitamente. **Escolha declarada é diferente de esquecimento** — e é essa diferença que a revisão de 31/08 ensinou, ao encontrar um esquecimento de verdade na Fase 5.

## Conceitos

[[Qualificacao de leads]] · [[LangGraph]] · [[Orcamento de esforco]]

## Relacionadas

- [[Decisao - Camada minima de privacidade como Must]] — a outra metade da mesma revisão, e o contraste: lá havia lacuna real, aqui há escolha
