---
tipo: bug
tags: [bug, ia, prompt, extracao, rag]
---
# Bug — a negação entrou no campo de preferência

## Sintoma

Caso adversarial do S-11, primeira rodada da suíte de extração:

```
lead: "qualquer lugar menos a zona leste"
camposExtraidos: {"regiao": "exceto zona leste", "score": 25}
```

Nenhum teste anterior pegava isso, porque os 5 roteiros do S-06 só tinham leads que diziam o que **queriam**.

## Por que é pior do que parece

O erro ingênuo esperado era extrair `"zona leste"` — a região que a pessoa acabou de descartar. Não foi esse. O modelo foi mais esperto e mais perigoso: preservou a negação **dentro de um campo que só sabe representar preferência**.

O `regiao` tem três consumidores, e nenhum deles entende "exceto":

1. Volta como texto para o `prompts/turno.md` do turno seguinte, no bloco de perfil.
2. Vai para o resumo que o corretor humano lê.
3. No S-15 vira **consulta ao índice vetorial**.

O terceiro é o que dói. Embedding não tem operador de negação: `"exceto zona leste"` e `"zona leste"` caem quase no mesmo ponto do espaço. A busca devolveria com prioridade exatamente os imóveis que a pessoa excluiu, e a Lia os apresentaria com convicção. Um campo malpreenchido teria virado uma recomendação errada com cara de acerto, três cards depois do lugar onde nasceu.

## Hipóteses descartadas

1. **Falta de instrução sobre `regiao`.** Havia instrução: `regiao — bairro, zona ou cidade, como ela falou`. O problema era ela: **"como ela falou"** é exatamente a licença que o modelo usou. Instrução fiel à fala colide com campo que só representa desejo.
2. **Temperatura.** O `gemini-3.5-flash-lite` ignora `temperature` ([[Decisao - Um no com saida estruturada]]), então não havia o que baixar. Não era variação de amostragem: reproduziu.
3. **Schema frouxo.** `regiao: str | None` aceita qualquer string, mas apertar o schema não resolveria — não existe tipo que exprima "lugar desejado e não excluído". Isto é semântica de prompt, não de contrato.

## Causa raiz

O `turno.md` descrevia **como transcrever**, não **o que o campo significa**. Enquanto todo lead do conjunto de teste dizia o que queria, transcrever e significar coincidiam, e o defeito ficou invisível por dois cards.

## Solução

Duas linhas no `prompts/turno.md`: uma regra geral na abertura de `camposExtraidos` e o exemplo concreto em `regiao`.

```
**Estes campos guardam o que ela quer, não o que ela descartou.** Se a pessoa só
disse o que não serve, o campo fica nulo — nunca escreva a exclusão dentro dele.
Estes valores viram busca de imóvel depois, e uma busca por "exceto zona leste"
devolve zona leste.
```

A razão foi escrita **dentro do prompt** de propósito: dar o motivo ao modelo é o que faz a regra generalizar para "não quero térreo" e "nada acima de 2 mil de condomínio", casos que a suíte não cobre.

Depois da mudança: o caso passou, e a rodada completa dos 21 casos ficou verde — a regra geral não zerou campo legítimo em nenhum outro.

## O que isso deixa em aberto

O produto ainda **perde** a informação: "menos a zona leste" é um dado de qualificação de verdade, e hoje ele evapora. O contrato não tem campo de exclusão, e criar um custaria commit coordenado nos dois repos ([[Decisao - Contrato do POST turn congelado]]) por um ganho que não credita requisito nenhum do enunciado. Fica registrado como escolha, não como esquecimento: nulo é caro, mas é muito mais barato que um valor que inverte de sentido no RAG.

## Conceitos

[[Qualificacao de leads]] · [[RAG]] · [[Indice vetorial em memoria]] · [[LangGraph]]

## Relacionadas

- [[Decisao - Um no com saida estruturada]]
- [[Decisao - Contrato do POST turn congelado]]
- [[Decisao - Vocabulario do contrato alinhado ao enunciado]]
- [[Bug - latencia de 30s por limite por minuto]]
