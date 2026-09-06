---
tipo: bug
tags: [bug, ia, armadilha, latencia]
---
# Bug — turno de 30 s que não era lentidão do modelo

## Sintoma

Primeira rodada completa do `scripts/conversas_exemplo.py` no S-06, 19 chamadas em sequência:

```
19 chamadas ao Gemini. Media 6285 ms, pior 30482 ms.
```

O número que assusta é o **30482 ms** — e não porque seja lento, mas porque o `Agente:TimeoutSegundos` da API valia exatamente **30**. Um turno a 30,5 s viraria `504` para o chamador, a meio segundo de ter dado certo.

## Hipóteses descartadas

1. **O modelo é lento.** Não é: a média era 6,3 s e o pior caso 5× a média. Distribuição com cauda assim não é custo de geração, é espera.
2. **O prompt ficou grande demais.** O histórico cresce dentro de cada roteiro, mas o pior caso não caiu no roteiro mais longo, e roteiros de 3 turnos também tiveram picos.
3. **Saída estruturada custa caro.** Foi a suspeita mais plausível — `with_structured_output` poderia estar fazendo uma segunda passada. Descartada porque `method="json_schema"` usa o schema nativo do Gemini, numa chamada só.

## Causa raiz

O free tier do Gemini limita **por minuto**, não só por dia. O `Gemini free tier` do vault registrava só a cota diária, e foi por isso que a hipótese certa demorou.

Dezenove chamadas emendadas estouram o limite por minuto. O SDK não devolve `429` ao chamador: ele faz **backoff e repete**, em silêncio. O que chega ao código é uma chamada bem-sucedida que demorou 30 s.

## Prova

Rodando **um** roteiro isolado, três chamadas: 1681, 7996, 1122 ms. Nenhuma cauda.

Depois, com `PAUSA_ENTRE_CHAMADAS = 4.0` no harness, as mesmas 19 chamadas:

```
19 chamadas ao Gemini. Media 1667 ms, pior 3831 ms.
```

Média caiu 3,8× e a pior caiu 8×. O custo real de um turno é **0,8 a 4 s**.

## Solução

- Pausa de 4 s entre chamadas no `scripts/conversas_exemplo.py`. É harness de desenvolvimento; medir throughput não é o objetivo dele, comparar qualidade de prompt é.
- `Agente:TimeoutSegundos` subiu de 30 para **45** no `appsettings.json`. Não porque o turno normal precise — precisa de 4 s —, mas porque o único caso lento observado tocou 30,5 s, e 504 na banca é pior que turno lento. Nada espera 45 s a menos que algo esteja de fato errado.

## O que isso não significa

Uma pessoa digitando entre turnos **nunca** dispara isso: o limite é por minuto e a conversa real tem pausas humanas. A cauda é artefato do harness, não do produto. Não confundir com a cota **diária**, que é o `429` de verdade e não tem contorno a não ser esperar o dia virar ou pagar.

## Armadilha vizinha, do mesmo dia

Durante a verificação do S-07, os containers da sessão anterior ainda estavam de pé nas mesmas portas. O `GET /health` em `:8080` respondeu **200** e o teste parecia válido — mas quem respondia era a imagem **antiga**, sem o `ConversasController`, e o `POST` devolvia 404. Container que sobrevive à sessão responde com a versão de ontem e não avisa. Antes de verificar aceite: `docker compose down` e `up --build`, e conferir no `docker ps` o `STATUS` de cada container.

## Conceitos

[[Gemini free tier]] · [[LangGraph]] · [[Contrato POST turn]]

## Relacionadas

- [[Decisao - Um no com saida estruturada]]
- [[Decisao - Modelo Gemini fixado sem alias]]
- [[Decisao - Conversa em memoria com turno serializado]]
- [[Bug - index.lock orfao trava o repositorio]]
