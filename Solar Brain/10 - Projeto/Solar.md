---
tipo: hub
tags: [hub, projeto]
---
# Solar

Plataforma de atendimento e qualificação de leads imobiliários com IA generativa. A agente conversacional se chama **Lia**.

Tech Challenge Fase 5 · pós FIAP · entrega **29/09/2026** · congelamento de código **24/09/2026**.

> Esta nota é o hub do grafo. O **estado** do projeto vive no `ESTADO.md` na raiz do repo; aqui vive o **porquê** expandido.

---

## Arquitetura

Três serviços, uma fronteira.

- [[Arquitetura poliglota]] — Python para IA, .NET para domínio, Angular no front
- [[Agente stateless]] — regra dura: o Python nunca toca o banco
- [[Contrato POST turn]] — a única fronteira, e o maior risco de retrabalho
- [[Contrato GET health]] — o mesmo envelope nos dois serviços, e as duas plateias que o leem
- [[Multi-repo e CI-CD]] — quatro repositórios, um pipeline cada
- [[Decisao - Front do chat em Angular]] — o front nasce (S-08 e S-09), e as três escolhas que o mantêm barato
- [[Decisao - Cartao de imovel sem foto]] — o que o cartão mostra, e por que placeholder de imagem ficou de fora
- [[Migrations no Solar]] — o schema é código versionado, e é o que salva o deploy da Fase 6

Decisões: [[Decisao - Arquitetura poliglota Python e NET]] · [[Decisao - Agente Python stateless]] · [[Decisao - Quatro repositorios separados]] · [[Decisao - Ambiente local em Docker Compose]] · [[Decisao - Compose composto por include]] · [[Decisao - NET 10 com controllers]] · [[Decisao - Formato do payload do health check]] · [[Decisao - Contrato do POST turn congelado]] · [[Decisao - Conversa em memoria com turno serializado]] · [[Decisao - Vocabulario do contrato alinhado ao enunciado]] · [[Decisao - Front do chat em Angular]] · [[Decisao - Persistencia em EF Core com Postgres]] · [[Decisao - DTO proprio para a releitura da conversa]]

## Camada de IA

- [[LangGraph]] — o grafo da Lia
- [[RAG]] — busca híbrida sobre a base simulada de imóveis: filtro duro primeiro, cosseno depois
- [[Indice vetorial em memoria]] — em RAM, não pgvector; 80 imóveis em 768 dimensões
- [[Gemini free tier]] — o LLM, e suas armadilhas de cota
- [[Billing na Gemini API]] — os três estados de tier, e por que o do meio é o pior
- [[Testar a Lia]] — o que dá para afirmar sobre uma função não determinística, e o que só dá para ler

Decisões: [[Decisao - Busca depois do LLM disparada pela regua]] · [[Decisao - Motivo do LLM como portao do cartao]] · [[Decisao - Tipo de imovel como filtro derivado do texto]] · [[Decisao - Indice vetorial em memoria]] · [[Decisao - Cache de embeddings por hash da base]] · [[Decisao - LLM Gemini Flash free tier]] · [[Decisao - Nenhum ML classico no escopo]] · [[Decisao - Dois projetos Google separados]] · [[Decisao - Modelo Gemini fixado sem alias]] · [[Decisao - Um no com saida estruturada]] · [[Decisao - Testes do agente em duas superficies]] · [[Decisao - Score por regua deterministica]]

## Produto

- [[Qualificacao de leads]] — o coração do que a Lia faz
- [[Regua de qualificacao]] — a tabela que dá o score e escolhe a próxima pergunta
- [[Follow-up proativo]] — o requisito que escolheu o canal

Decisões: [[Decisao - Identidade de produto Solar e agente Lia]] · [[Decisao - Canal da demo e chat web com Telegram cortavel]] · [[Decisao - Agenda simulada por slots]] · [[Decisao - Score por regua deterministica]]

## Privacidade — disciplinas da Fase 5

- [[LGPD e GDPR]] — o que a lei pede
- [[Consentimento na abertura]] — S-33
- [[Mascaramento de PII]] — S-34
- [[Direito de eliminacao]] — S-29

Decisões: [[Decisao - Camada minima de privacidade como Must]] · [[Decisao - Versao minima de privacidade e nao a completa]] · [[Decisao - S-29 reenquadrado com endpoint de exclusao]] · [[Decisao - Front do chat em Angular]] (metade do S-33 na UI)

## Operação

- [[Bug - index.lock orfao trava o repositorio]] — recorrente, e silencioso: um repo travado não avisa que o trabalho não está sendo versionado
- [[Bug - latencia de 30s por limite por minuto]] — o free tier também limita por minuto, e essa cota falha devagar em vez de falhar alto
- [[Bug - libgssapi no log da API]] — duas linhas de erro no boot que não eram erro nenhum; corrigido, mas o diagnóstico vale
- [[Bug - negacao extraida como preferencia]] — a Lia guardou "exceto zona leste" num campo que vira busca vetorial, onde a negação inverte de sentido
- [[Bug - turno real vira 504 sob cota por minuto]] — a suíte satura o minuto e a conversa seguinte estoura o timeout; risco direto para a gravação do vídeo
- [[Bug - falha ao retomar apagava a conversa]] — um `catch` vazio no front transformava falha de rede em perda permanente de conversa, sem sintoma

## Gestão

- [[Orcamento de esforco]] — 67h de `Must` contra teto de 65–75h, e a ordem de corte

Decisões: [[Decisao - Entrega individual confirmada]]

---

## Datas que importam

| data | o quê |
|---|---|
| **15/09/2026** | gatilho duplo: cortar se a Fase 3 não fechou ([[Orcamento de esforco]]) e reavaliar privacidade ([[Decisao - Versao minima de privacidade e nao a completa]]) |
| **24/09/2026** | congelamento de código |
| **29/09/2026** | entrega |
