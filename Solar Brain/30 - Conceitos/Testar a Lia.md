---
tipo: conceito
tags: [conceito, ia, testes, prompt, cota]
---
# Testar a Lia

## O problema

A Lia é uma função não determinística. Rodar o mesmo roteiro duas vezes com o mesmo prompt dá textos diferentes — o `gemini-3.5-flash-lite` ignora `temperature` ([[Decisao - Um no com saida estruturada]]), então nem existe botão para reduzir isso. Um teste que compare a resposta em texto falha por motivo nenhum, e um teste que não compare nada não protege nada.

O S-11 resolveu isso separando o que é **asserível** do que só é **legível**.

## Duas superfícies, propósitos diferentes

**`conversas/`** — seis roteiros gravados por `scripts/conversas_exemplo.py`. Servem para **ler**: tom, ritmo, se a Lia faz uma pergunta por vez, se a conversa soa humana. `git diff conversas/` mostra o efeito de uma mudança de prompt, mas com uma ressalva medida no S-11: **a deriva de amostragem domina o diff**. Numa regravação sem nenhuma mudança relevante de prompt, todas as seis conversas mudaram de redação. Não é gate de regressão; é instrumento de leitura.

**`tests/test_extracao.py`** — casos de um turno com asserção sobre a saída estruturada. É o gate. Cada caso monta perfil e histórico prontos e gasta **uma** chamada, contra as 4 ou 5 de um roteiro inteiro.

## O que dá para afirmar

| Estável o bastante para asserção | Instável demais |
|---|---|
| `intencao` (enum de 4) | `resposta` (texto livre) |
| `proximaAcao` (enum de 5) | redação de qualquer campo textual |
| campo nulo vs. preenchido | |
| `precoMin` / `precoMax` / `quartos` (inteiros) | |
| `score` — **desde o S-12** | |

O `score` mudou de lado. Enquanto saía do LLM, ele se movia **até 20 pontos** com entrada idêntica (40→60, 30→20, 10→5) e nenhum teste podia afirmar o valor dele, só que ele existia. Desde que virou [[Regua de qualificacao]] determinística ([[Decisao - Score por regua deterministica]]), ele é asserível — e melhor: asserível **de graça**, em `tests/test_qualificacao.py`, sem uma chamada ao Gemini. A suíte `-m llm` verifica só a ligação: que o score que volta do `/turn` é o mesmo que a régua calcula sobre o perfil fundido.

## A asserção que pega alucinação é a negativa

O instinto é afirmar "extraiu o que devia". Isso não pega o erro caro. O caso declara **tudo** o que pode voltar preenchido, e o teste falha em qualquer campo fora dessa lista que não seja nulo:

```python
inventados = {n: v for n, v in campos.items() if v is not None and n not in permitidos}
assert not inventados, f"campos que ninguem mencionou: {inventados}"
```

Foi essa asserção — não uma sobre valor esperado — que pegou [[Bug - negacao extraida como preferencia]].

## Um caso de uma chamada é amostragem, não prova

O limite honesto do método. Cada caso faz **uma** chamada, então ele pega erro **sistemático** e não pega erro **intermitente**.

Medido no próprio S-11: numa regravação, um lead de `score` 0 com `intencao` ainda `indefinida` recebeu `proximaAcao: agendar_reuniao`, contra a regra explícita do `turno.md`. O mesmo turno virou caso de teste — `handoff-lead-sem-nenhum-dado-nao-vai-para-corretor` — e **passou**. O defeito é real e é raro.

O contraste é o que importa: o bug da negação reproduziu em toda tentativa, porque a instrução estava genuinamente errada. Este não reproduz, porque a instrução está certa e o modelo a desobedece de vez em quando.

Consequência prática: a suíte verde significa "nenhum erro sistemático nos 25 casos", nunca "a Lia sempre acerta". Quem quiser medir frequência de erro raro precisa de N repetições por caso, e isso multiplica a cota por N — não cabe no orçamento deste projeto. As transcrições em `conversas/`, lidas de vez em quando, continuam sendo a rede que pega o intermitente, e foi assim que este apareceu.

## Custo e a armadilha da cota

`pytest` roda a suíte grátis — contrato, prompts e [[Regua de qualificacao]] — e não gasta nada. `pytest -m llm` roda os casos de extração e gasta uma chamada por caso, com pausa de 5 s entre elas.

A proporção mudou no S-12, e na direção certa: a suíte grátis foi de 24 para 86 testes, a paga de 25 para 27 casos. Toda regra que dá para escrever como função pura sai da superfície que custa cota.

**Não rode a suíte e o `conversas_exemplo.py` na mesma janela.** Medido no S-11: com ~45 chamadas em dez minutos, a rodada seguinte de conversas deu média de **23 s** e pior caso de **99 s**, contra média de 1667 ms e pior de 3831 ms do S-06. É o limite por minuto do [[Gemini free tier]] em backoff silencioso, o mesmo mecanismo de [[Bug - latencia de 30s por limite por minuto]] — e 99 s passa longe do `Agente:TimeoutSegundos` de 45 s, ou seja, sob essa pressão um turno real viraria `504`. Espaçar as duas coisas resolve; nada no código precisa mudar.

## Conceitos

[[Qualificacao de leads]] · [[Gemini free tier]] · [[LangGraph]] · [[Contrato POST turn]]

## Relacionadas

- [[Bug - negacao extraida como preferencia]]
- [[Bug - latencia de 30s por limite por minuto]]
- [[Decisao - Um no com saida estruturada]]
- [[Decisao - Vocabulario do contrato alinhado ao enunciado]]
