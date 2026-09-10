---
tipo: decisao
data: 2026-09-09
status: vigente
tags: [decisao, produto, privacidade, dominio]
---
# Decisão — O encaminhamento tem corretor de verdade, e o contato não passa pelo LLM

## Problema

Até o S-37, `agendar_reuniao` e `direcionar_especialista` eram, para o backend, idênticos a `continuar_conversa`: não havia um único `if` sobre `ProximaAcao` em todo o C#. Cinco cards obrigatórios já dependiam de dados que nenhum card criava — o S-17 pedia "slots por corretor", o S-18 é "resumo **para o corretor**", o S-20 lista leads "com status", o S-33 manda gravar o aceite "no Lead" e o S-34 argumenta com "o telefone real vindo do banco". **Zero ocorrências de `corretor` no código**, e `Conversa.Nova()` fabricava um `Lead` novo a cada conversa — a tabela `leads` era, na prática, uma coluna a mais da conversa.

## Decisão

Três escolhas, e nenhuma delas toca o [[Contrato POST turn]]:

1. **O contato é pedido por formulário na trilha**, no momento do handoff, e não pela Lia. `POST /conversas/{id}/contato` grava nome, telefone e e-mail direto no Postgres.
2. **A atribuição é determinística**: especialidade compatível com a trilha → região do lead entre as regiões do corretor → menor carga aberta → desempate por quem está há mais tempo sem receber lead. Mesma família da [[Decisao - Score por regua deterministica]], e explicável em uma frase no pitch.
3. **O nome do corretor vai no evento estruturado da trilha**, nunca no texto do LLM — mesmo princípio de [[Decisao - Motivo do LLM como portao do cartao]].

A base de 5 corretores é semeada por migration, como os 80 imóveis são semeados por JSON. As duas especialidades cobrem as cinco zonas da base: senão um lead de investimento na zona leste cairia em "sem corretor" **na demo**, e o caminho de exceção viraria o caminho comum.

## Motivo

O ponto 1 é **o argumento mais forte da Fase 5, e ele é estrutural, não textual**. O telefone não chega ao modelo porque *o contrato do turno não tem campo para ele* — não porque um prompt pediu para não usar. Restrição que não pode ser violada é código. Está sob teste: `ContratoDoTurnoTeste` afirma por reflexão que nenhum dos 6 tipos do espelho carrega campo de contato, e que o espelho continua com 37 campos.

O ponto 3 evita a Lia afirmar um fato do banco que pode ter falhado. O nome vem do `MensagemResponse` e do `MensagemDaConversa` — DTOs só do .NET, que crescem sem commit coordenado, como já valia em [[Decisao - DTO proprio para a releitura da conversa]].

Região ausente **não exclui ninguém**: não saber onde o lead quer morar não é o mesmo que saber que ninguém atende ali. Região que não casa com nenhum corretor, essa sim, grava `corretor_id` nulo com status `aguardando` — e a conversa não quebra.

## Custo aceito

A regra de região é uma **segunda implementação** do casamento que o `indice.py` já faz (`_regiao_bate`): termo de uma palavra casa como palavra inteira, termo com espaço casa como trecho. Duas cópias podem divergir. Aceito porque a alternativa — a API perguntar ao agente onde o lead quer morar — reintroduziria uma fronteira que [[Decisao - Agente Python stateless]] fechou.

A dedupe por contato **apaga o lead provisório** da conversa deduplicada, reapontando conversas e encaminhamentos para o canônico antes. É o que transforma base de conversas em base de clientes, e é irreversível dentro do turno.

`ContatoResponse` devolve **só o `leadId`**. Devolver o nome gravado contaria a quem digitasse um telefone alheio de quem ele é.

## Consequência

Destrava `S-17` (o slot passa a pertencer a alguém), `S-18` (o resumo ganha destinatário), `S-20` e `S-21` (a fila tem status e dá para filtrar "meus leads"), `S-33` (o aviso passa a declarar o compartilhamento com um terceiro humano) e `S-34` (a exceção do telefone deixa de ser hipótese). O `ON DELETE CASCADE` de `encaminhamentos` a partir de `leads` é o que o S-29 vai usar.

O `solar-ai-api` ganhou seu **primeiro projeto de testes** — 43 casos xUnit, sem rede e sem cota.

## Conceitos

[[Agente stateless]] · [[Contrato POST turn]] · [[Migrations no Solar]] · [[Mascaramento de PII]] · [[Regua de qualificacao]] · [[LGPD e GDPR]]

## Relacionadas

- [[Decisao - Agente Python stateless]] — a restrição que mantém a atribuição inteira no .NET
- [[Decisao - Motivo do LLM como portao do cartao]] — mesmo princípio: fato do banco vira dado estruturado, não texto do modelo
- [[Decisao - Score por regua deterministica]] — a mesma bifurcação moradia/investimento, e a mesma preferência por regra explicável
- [[Decisao - DTO proprio para a releitura da conversa]] — por que o corretor cabe no DTO do .NET sem commit coordenado
- [[Decisao - Agenda simulada por slots]] — o S-17 depende deste card: o slot pertence ao corretor atribuído aqui
- [[Decisao - Persistencia em EF Core com Postgres]] — onde `corretores` e `encaminhamentos` entram
- [[Bug - HasData com colecao primitiva derruba o boot]] — o custo de descobrir onde o seed podia morar
