---
tipo: decisao
data: 2026-09-13
status: vigente
tags: [decisao, ia, arquitetura, privacidade, custo]
---
# Decisão — O resumo do corretor é uma fronteira stateless separada, gerada uma vez e persistida

## Problema

"Resumo inteligente" é requisito obrigatório do enunciado, e o leitor é um corretor com trinta segundos entre atendimentos. Três perguntas precisavam de resposta antes de escrever uma linha: **quem** escreve o resumo, **onde** ele roda e **quando**.

A tentação barata era um template determinístico no .NET — grátis, testável, sem cota. Ela não sobrevive ao critério de aceite.

## Por que o LLM, e por que a alternativa é impossível

O critério pede "objeções e restrições levantadas". **Essa informação não existe no `PerfilLead`.**

A [[Decisao - Tipo de imovel como filtro derivado do texto]] e o registro de 07/09 explicam o motivo: quando o lead diz só o que *não* quer, o campo estruturado fica nulo **de propósito**, porque `regiao: "exceto zona leste"` viraria consulta ao índice vetorial e embedding não tem operador de negação.

O encadeamento é fechado. Um template lê o perfil. O perfil descartou a negação. Logo o template não satisfaz o critério. Só a transcrição carrega a objeção, e ler transcrição para extrair objeção é trabalho de modelo de linguagem.

Isso vira frase de pitch: **o campo estruturado joga a negação fora porque embedding não entende "exceto"; o resumo do corretor a recupera do texto, porque um humano entende.**

## Onde roda: endpoint novo, não dentro do turno

`POST /resumo` é a **segunda fronteira** entre `solar-ai-api` e `solar-ai`, e a primeira nova desde que o `/turn` foi congelado — ver [[Decisao - Contrato do POST turn congelado]].

Ela nasceu barata de propósito: reaproveita `PerfilLead`, `MensagemHistorico` e `ImovelSugerido`, já espelhados, e cria **um tipo novo por lado**, o `ResumoResponse`. O contrato do `/turn` **não foi tocado**, conferido por diff na integração.

Pôr a segunda chamada dentro de `POST /conversas/{id}/mensagens` foi avaliado e recusado: a pessoa esperaria por um texto que ela nunca vê, dentro do orçamento de 45 s e com a trava da conversa segurada, e um turno bom viraria `504` sob pressão de cota.

## Quando roda: uma vez, na primeira leitura

Geração preguiçosa. `POST /encaminhamentos/{id}/resumo` devolve o `jsonb` gravado em `encaminhamentos.resumo`; se for nulo, gera e persiste. `?forcar=true` é a única regeneração explícita.

Medido na integração, com conversa real de 18 mensagens: primeira leitura **200 em 2,38 s com exatamente 1 chamada** ao agente; segunda leitura **200 em 0,013 s com zero chamadas**, resposta idêntica.

## Cinco seções nuláveis, e a nulidade é o teste

`perfil`, `orcamento`, `imoveis`, `objecoes` e `proximoPasso` voltam `null` quando não há fato que as sustente. Saída estruturada em seções, e não texto corrido, é o que torna "seção vazia não é inventada" asserível por **nulo contra preenchido**, sem julgar texto — a mesma filosofia de teste que o projeto adota desde o [[Decisao - Um no com saida estruturada]].

Na validação com dado real, `imoveis` e `objecoes` vieram nulos sozinhos, sem ninguém montar o caso.

## Privacidade

A transcrição que sobe passa pela mesma camada de mascaramento das outras saídas para o Google — ver [[Decisao - Mascaramento nas duas fronteiras com o Google]], cujo título envelheceu: **as fronteiras agora são três**, e esta é a terceira.

Uma diferença deliberada em relação ao turno: os tokens de contato **não** são restaurados na saída do resumo. O corretor lê o telefone real no painel, vindo do banco pela via estruturada do [[Decisao - Encaminhamento ao corretor com contato fora do LLM]], nunca do texto que o modelo escreveu.

## Consequências

- O agente continua stateless e sem acesso ao Postgres — [[Agente stateless]] segue intacto.
- Falha de resumo deixa o encaminhamento de pé com `resumo` nulo e ação de tentar de novo, e **nunca derruba o turno do lead**.
- Custo: 1 chamada por encaminhamento; leituras seguintes custam zero.
- **Alucinação de objeção é o risco real**, defendido como o `motivo` do S-15: campo nulável, prompt proibindo inventar, teste afirmando nulo quando não houve objeção.

**Quem consumir isto na tela** — o S-21 é o próximo — não deve reimplementar geração nem chamar com `forcar=true` em render, ou cada abertura de painel queima cota. E precisa tratar seção nula como estado normal, nunca como erro ou "carregando".

## Conceitos

[[Agente stateless]] · [[Contrato POST turn]] · [[Gemini free tier]] · [[Regua de qualificacao]]

## Relacionadas

- [[Decisao - Contrato do POST turn congelado]] — o congelamento que obrigou a fronteira nova a ser separada em vez de uma emenda
- [[Decisao - Encaminhamento ao corretor com contato fora do LLM]] — criou o destinatário do resumo, e a via estruturada pela qual o contato chega ao painel
- [[Decisao - Mascaramento nas duas fronteiras com o Google]] — o título ficou velho aqui: esta decisão acrescenta a terceira fronteira
- [[Decisao - Um no com saida estruturada]] — mesma aposta: estrutura no lugar de julgamento de texto
- [[Decisao - Tipo de imovel como filtro derivado do texto]] — a mesma limitação de embedding que faz o perfil descartar a negação
