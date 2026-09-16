---
tipo: decisao
data: 2026-09-13
status: vigente
tags: [decisao, ia, arquitetura, custo]
---
# Decisão — O supervisor é determinístico e não chama o LLM

## Problema

O critério do S-23 pede duas coisas na mesma frase, e elas puxam para lados opostos.

A primeira: *"o grafo tem um nó supervisor que roteia cada turno para qualificador, consultor, agendador ou reengajador"*. A segunda: *"o custo em chamadas por turno NÃO sobe em relação ao que existe hoje — 1 no turno comum, 2 no turno que sugere"*.

A leitura ingênua de "supervisor multiagente" é um nó que pergunta ao modelo para onde ir. Esse nó custaria **uma chamada por turno**, em todo turno, e violaria a segunda metade do critério antes de entregar a primeira. Com a [[Gemini free tier]] dividida com a demo, isso não é detalhe de performance: é o orçamento inteiro.

Havia ainda a armadilha de honestidade registrada no próprio card, depois de a primeira leitura do estado ter sido contestada: contar função determinística como agente é exagero, e é o tipo de coisa que a banca pega na arguição.

## Decisão

**O nó `_supervisor` é uma função pura em Python, sem chamada ao modelo.** Ele lê o `EstadoTurno` e decide a rota por regra:

- `reengajador` quando `reengajamento` está ativo — o gatilho estrutural que o S-24 trouxe, ativado só pelo header `X-Solar-Trigger: follow-up`;
- `agendador` quando a requisição carrega slots em `agenda`;
- `consultor` quando o perfil já fechou os essenciais e a mensagem indica busca no catálogo;
- `qualificador` como rota padrão, para conversa e descoberta.

A topologia passou a ser `START → supervisor → {qualificador, agendador, consultor, reengajador}`, e cada turno emite uma linha de log INFO com o GUID da conversa e o nó escolhido.

## Motivo

Um supervisor movido a LLM não é mais capaz aqui — ele é **menos** verificável e mais caro. As quatro condições de roteamento são fatos estruturais do estado, não julgamentos de linguagem: saber se há slots na requisição não exige interpretar texto. Pagar uma chamada para decidir o que um `if` decide é gastar cota e trocar determinismo por variação.

A consequência boa é que o roteamento virou testável de graça: 13 testes offline provam as quatro rotas e afirmam que o supervisor não gasta chamada.

## Custo aceito

O roteamento por regra não captura intenção que só aparece na paráfrase — é a mesma limitação de [[Decisao - Tipo de imovel como filtro derivado do texto]], e pelo mesmo motivo: regra sobre estado não lê subtexto. Quando a rota `consultor` depender de nuance que a regra não vê, o turno cai no `qualificador`, que é o padrão seguro.

## Consequência

**Quem mexer no roteamento tem de preservar a propriedade.** O teto de 1 chamada no turno comum e 2 no turno que sugere é item de aceite, não recomendação, e existe teste que o afirma. Um supervisor que passe a consultar o modelo quebra o orçamento em todo turno, não só no seu.

**Quem descrever o sistema não deve chamá-lo de agentes autônomos.** É supervisor com nós especializados, cada um com prompt e ferramentas próprias. Três nós chamam o LLM — `_responder`, `_reengajar` e `_apresentar`; os demais são funções puras.

## Conceitos

[[LangGraph]] · [[Agente stateless]] · [[Gemini free tier]] · [[Contrato POST turn]] · [[Regua de qualificacao]]

## Relacionadas

- [[Decisao - Um no com saida estruturada]] — mesmo princípio: não pagar chamada por algo que a estrutura já resolve
- [[Decisao - Score por regua deterministica]] — o precedente direto, com a régua fora do modelo
- [[Decisao - Agenda na requisicao e agendador como no do grafo]] — previu que o S-23 obrigaria o agendador a existir como nó, e obrigou
- [[Decisao - Tipo de imovel como filtro derivado do texto]] — mesma limitação aceita: regra sobre estado não lê paráfrase
