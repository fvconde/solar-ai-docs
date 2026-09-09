---
tipo: conceito
tags: [conceito, ia, produto]
---
# Régua de qualificação

## O que é

Uma tabela de sinais, em `solar-ai/app/lia/qualificacao.py`, que responde às duas perguntas do nó qualificador: **quanto vale este lead** e **sobre o que perguntar agora**. Determinística, sem LLM. Entrou no S-12; o porquê está em [[Decisao - Score por regua deterministica]].

## A tabela

Duas trilhas, escolhidas por `intencao`. Cada uma soma 100.

| moradia (compra/aluguel) | peso | | investimento | peso |
|---|---|---|---|---|
| intenção definida ✱ | 25 | | intenção definida ✱ | 25 |
| região ✱ | 20 | | ticket (faixa de preço) ✱ | 20 |
| faixa de preço ✱ | 20 | | expectativa de retorno ✱ | 20 |
| prazo (urgência) | 15 / 9 / 5 | | região | 15 |
| quartos | 10 | | prazo (urgência) | 10 / 6 / 3 |
| nome | 10 | | nome | 10 |

✱ = **essencial**: o que um humano precisa antes de assumir o lead.

Detalhes que não são acidente:

- **`intencao: "indefinida"` não pontua.** Existir o campo não é saber a resposta.
- **`precoMin` e `precoMax` são um sinal só.** Quem deu as duas pontas não pontua em dobro.
- **Urgência é graduada**, e os pontos estão escritos um a um. Saber que a pessoa não tem pressa é informação, mas não é prontidão. Não use multiplicador aqui: `round(15 * 0.3)` é **4** em Python, não 5.
- **A ordem da tabela é a ordem dos pesos**, e está sob teste. É ela que vira a fila de perguntas.

## As três funções

```python
pontuar(perfil)             # -> 0..100, soma dos sinais preenchidos
lacunas(perfil)             # -> sinais em falta, do que mais vale para o que menos vale
lacunas_essenciais(perfil)  # -> só os essenciais em falta: o piso do handoff
desfecho_da_trilha(perfil)  # -> a proximaAcao que os essenciais desta trilha disparam
fundir(perfil, intencao, extraidos)  # espelha Lead.Fundir do .NET
```

**Essencial é piso, não gatilho.** Só a trilha de investimento tem gatilho (`DESFECHO_DA_TRILHA` → `direcionar_especialista`), porque só ela tem regra positiva no contrato. Em moradia o piso apenas libera o handoff quando a pessoa pedir; tratá-lo como suficiente fez a Lia parar de qualificar no meio da conversa.

Desde o S-15, `lacunas_essenciais` tem um segundo uso: comparada antes e depois de `fundir`, ela identifica o turno que fecha o piso — o gatilho da busca de imóveis.

**Invariante sob teste:** `pontuar(p) + soma dos pesos de lacunas(p) == 100`. Score e próxima pergunta são a mesma regra lida de dois lados — se esse teste quebrar, as duas se separaram.

## No grafo

```
START → qualificar → responder → pontuar → END
        (puro)       (Gemini)    (puro)
```

`qualificar` calcula as lacunas do perfil que chegou e as injeta no `turno.md`. `pontuar` funde `camposExtraidos` no perfil **em memória** e aplica a régua. Custo: segue **uma** chamada ao [[Gemini free tier]] por turno — ver [[Decisao - Um no com saida estruturada]].

O `fundir` é espelho do `Lead.Fundir` do `solar-ai-api`. Duas regras, as duas sob teste dos dois lados: **campo nulo não apaga** o que já se sabia, e **`indefinida` não apaga** intenção conhecida. Mexeu num, confira o outro — divergência aqui não dá erro, dá score calculado sobre um perfil que o banco não tem.

## O bloco é informação, não comando

O que o `turno.md` recebe é curto e declarativo:

| estado | o que o prompt mostra |
|---|---|
| lacunas abertas | as perguntas em prosa, na ordem dos pesos, + "a regra de `proximaAcao` decide se há próxima pergunta; esta lista só decide qual seria" |
| + essencial aberto | uma linha: o que faltava **antes desta mensagem**, e que a lista foi montada sem ela |
| + essencial fechado numa trilha com gatilho | uma linha: "este perfil já satisfaz a regra de `direcionar_especialista`" |
| nada aberto | "nada — o perfil está completo" |

A primeira versão era uma **lista numerada com imperativos** ("pergunte o primeiro item", "siga para o próximo") mais parágrafos de exceção. Custou quatro iterações contra o LLM, e cada correção só movia a falha: a Lia parava de qualificar cedo, ou nunca direcionava o investidor, ou — numa rodada — errava um preço na resposta.

**A lição:** lista numerada num prompt lê como checklist a cumprir e ganha de regra em prosa escrita quarenta linhas abaixo. Prosa compete com prosa. Não escreva a exceção; não emita o comando.

## A lista é montada antes da mensagem do turno

`qualificar` roda sobre o perfil que chegou, então **o turno que fecha um limiar sempre o vê aberto**. Não dá para inverter: o desfecho precisa estar no mesmo prompt que gera a resposta.

A saída é o bloco declarar o próprio limite — *"esta lista foi montada sem a mensagem de agora"* — e o `turno.md` mandar contar a mensagem antes de aplicar o piso. Quem mexer nesses textos precisa preservar essa ressalva: sem ela, o turno em que o investidor informa a expectativa de retorno volta a devolver `continuar_conversa`.

**No S-15 essa mesma limitação voltou, e desta vez o conserto foi de código.** Com o perfil fechando em `intencao`, `regiao` e `preco` na mesma frase — *"quero apartamento de 2 quartos na zona sul até 600 mil"* —, a Lia devolveu `continuar_conversa` e perguntou de novo pela intenção que ela acabara de extrair. Nenhuma redação de prompt resolve: o modelo está lendo uma lista que é verdadeira no instante em que foi montada.

Quem desempata é a régua, **depois** de `fundir`: se o perfil de entrada tinha essencial em aberto e o fundido não tem mais, este é o turno da virada, e ele dispara a busca de imóveis sozinho. Ver [[Decisao - Busca depois do LLM disparada pela regua]]. É a quarta pergunta que a mesma tabela passou a responder — *já dá para mostrar imóvel?* — sem custar chamada nenhuma.

## Como mexer nos pesos

São julgamento de produto, não medida — não há base rotulada para calibrar, e não haverá ([[Decisao - Nenhum ML classico no escopo]]). Para mexer:

1. Edite a tupla da trilha em `app/lia/qualificacao.py`.
2. `pytest` (grátis, 1 s). A suíte afirma que cada trilha soma 100, que os pesos estão em ordem decrescente, que os essenciais são os de maior peso e que a graduação da urgência topa no peso do sinal. Errar a conta falha na hora.
3. Só depois `pytest -m llm`, e só se o **prompt** mudou: peso não muda extração.

Marcar um sinal como essencial é mudança de comportamento, não de calibragem: mexe em quando a Lia para de qualificar. Os essenciais de hoje foram escolhidos por já estarem escritos em prosa no `turno.md` — "quem não disse nem o que quer, nem onde, nem quanto não está pronto para um corretor" e a regra congelada do `direcionar_especialista`. Mudar um deles exige mudar as duas superfícies juntas.

## O que a régua não faz

Ela lê **presença**, não **qualidade**. "Uns 500 mil, sei lá" pontua igual a "meu teto é 500 mil". Era o que o LLM prometia e não cumpria de forma reprodutível ([[Testar a Lia]]) — trocou-se sensibilidade fingida por grosseria honesta.

E ela **não desce**. Preencher campo nunca baixa o score. Para ordenar uma fila isso é o que se quer: "por que caiu?" deixa de existir como pergunta.

## Conceitos

[[Qualificacao de leads]] · [[LangGraph]] · [[Contrato POST turn]] · [[Testar a Lia]] · [[Agente stateless]]

## Relacionadas

- [[Decisao - Score por regua deterministica]]
- [[Decisao - Busca depois do LLM disparada pela regua]]
- [[Decisao - Um no com saida estruturada]]
- [[Decisao - Testes do agente em duas superficies]]
