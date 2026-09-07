---
tipo: decisao
data: 2026-09-07
status: vigente
tags: [decisao, ia, testes, cota]
---
# Decisão — Testes do agente em duas superfícies, e negação vira nulo

## Problema

Até o S-11 a única prova de que a Lia extraía os campos certos eram cinco transcrições em `conversas/`, lidas a olho. Isso tem dois furos.

O primeiro é de cobertura: todos os cinco roteiros eram de leads que diziam o que **queriam**. Ninguém dizia o que não queria, ninguém se retratava, ninguém recusava informar. O caminho feliz estava provado e mais nada.

O segundo é de método: o critério de aceite do card é *"preenchendo só o que o lead realmente disse"* — uma afirmação **negativa**, sobre campos que não deveriam existir. Ler uma transcrição prova o que está lá; não prova o que não está.

E não dá para simplesmente comparar texto entre rodadas: a Lia é não determinística e o `gemini-3.5-flash-lite` ignora `temperature` ([[Decisao - Um no com saida estruturada]]), então nem existe knob para reduzir a variação.

## Decisão

Duas superfícies, com propósitos que não se misturam.

**`tests/`** é o gate, com `pytest`. Cada caso é **um turno isolado** — perfil e histórico montados prontos, uma mensagem, asserções sobre a saída estruturada. Um turno isolado custa **uma** chamada, contra as 4 ou 5 de um roteiro inteiro.

**`conversas/`** continua sendo o instrumento de leitura: tom, ritmo, uma pergunta por vez. Não é gate.

O gate afirma só o que é estável — os enums `intencao` e `proximaAcao`, inteiros, e nulo vs. preenchido. Não afirma texto livre nem valor de `score`.

A asserção central é a negativa: o caso declara **tudo** o que pode voltar preenchido, e qualquer outro campo não nulo reprova.

```python
inventados = {n: v for n, v in campos.items() if v is not None and n not in permitidos}
assert not inventados, f"campos que ninguem mencionou: {inventados}"
```

Marker `llm` separa os 24 casos que gastam cota dos 24 que não gastam. `pytest` é grátis e roda em 1 s; `pytest -m llm` custa 24 chamadas e uns 4 minutos.

**Junto, uma escolha de produto:** quando o lead só diz o que **não** quer, o campo fica **nulo**.

## Motivo

O marker existe porque cota é risco registrado desde o S-06. Sem ele, a suíte inteira estaria em dois estados ruins: ou ninguém a roda por medo de queimar cota, ou ela roda em todo commit e queima. Com ele, o teste barato é o default e o caro é uma escolha consciente.

A asserção invertida é o que justifica o card. Foi ela — não uma asserção sobre valor esperado — que pegou [[Bug - negacao extraida como preferencia]], onde `"qualquer lugar menos a zona leste"` virou `regiao: "exceto zona leste"`. Uma asserção positiva ("extraiu região?") teria passado.

Nulo em vez de campo de exclusão porque a alternativa é cara e o dano é grande. Criar `regiaoExcluida` significaria commit coordenado nos dois repos ([[Decisao - Contrato do POST turn congelado]]) por um campo que não credita requisito nenhum do enunciado. E manter a negação dentro de `regiao` é pior que perdê-la: esse valor vira consulta ao índice vetorial no S-15, e embedding não tem operador de negação — `"exceto zona leste"` recupera zona leste.

## Custo aceito

**A informação de exclusão se perde.** "Menos a zona leste" é dado de qualificação legítimo e hoje evapora. É escolha registrada, não esquecimento.

**Rodar as duas superfícies na mesma janela satura a cota por minuto.** Medido: depois de ~45 chamadas em dez minutos, a rodada de conversas seguinte deu média **23 s** e pior caso **99 s**, contra média 1667 ms e pior 3831 ms do S-06. Os 99 s passam longe do `Agente:TimeoutSegundos` de 45 s — sob essa pressão um turno real viraria `504`. É o mesmo mecanismo de [[Bug - latencia de 30s por limite por minuto]]: o SDK entra em backoff e devolve sucesso lento em vez de `429`. Nada no código muda; espaçar as duas coisas resolve.

**Uma chamada por caso pega erro sistemático, não intermitente.** O bug da negação reproduzia sempre e caiu no primeiro caso; já um `agendar_reuniao` indevido observado numa transcrição não reproduziu quando virou caso. Suíte verde significa "nenhum erro sistemático nos 25 casos", não "a Lia sempre acerta" — detalhado em [[Testar a Lia]]. Medir erro raro exigiria N repetições por caso e multiplicaria a cota por N.

**O `score` fica sem gate.** Ele se moveu até 20 pontos com entrada idêntica entre duas rodadas, então nenhum teste afirma valor de score — só que ele existe. Registrado em [[Qualificacao de leads]] como argumento para o S-12.

## O que a suíte pegou de imediato

- `regiao: "exceto zona leste"` numa negação → [[Bug - negacao extraida como preferencia]]
- `ROTULOS` em `app/lia/prompts.py` sem `expectativaRetorno`, sobra do realinhamento de vocabulário de 05/09 — o campo do Exemplo 2 do enunciado aparecia no perfil com a chave crua
- `agendar_reuniao` num lead de `score` 3 e `intencao` `indefinida`, contra a regra do próprio `turno.md` de que passar adiante cedo demais é pior que perguntar mais uma coisa

## Conceitos

[[Testar a Lia]] · [[Qualificacao de leads]] · [[Gemini free tier]] · [[Contrato POST turn]] · [[RAG]]

## Relacionadas

- [[Decisao - Um no com saida estruturada]]
- [[Decisao - Contrato do POST turn congelado]]
- [[Decisao - Vocabulario do contrato alinhado ao enunciado]]
- [[Bug - negacao extraida como preferencia]]
- [[Bug - latencia de 30s por limite por minuto]]
