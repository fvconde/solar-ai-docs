---
tipo: decisao
data: 2026-09-09
status: vigente
tags: [decisao, ia, produto, privacidade]
---
# Decisão — O resumo do corretor é escrito pelo LLM, em endpoint próprio

## Problema

O S-18 pede um resumo de 5 a 8 linhas para o corretor ler em trinta segundos, cobrindo perfil, orçamento, imóveis de interesse, **objeções levantadas** e próximo passo.

A rota barata seria montar esse texto no .NET a partir do `Lead`: os campos já estão todos lá, o custo é zero e o teste é determinístico. A pergunta era se isso bastava.

## Decisão

**Não basta, e a razão é estrutural.** O resumo é gerado por chamada ao agente — `POST /resumo`, endpoint novo, com saída estruturada em cinco seções — e persistido no encaminhamento do S-37.

Três escolhas saíram junto:

- **Saída estruturada em cinco seções**, não texto corrido. É o que torna "seção vazia não é inventada" asserível por nulo vs. preenchido, sem julgar texto — a filosofia de [[Testar a Lia]] desde o S-11.
- **Fronteira nova, mas barata.** O `ResumoRequest` reaproveita `PerfilLead`, `MensagemHistorico` e `ImovelSugerido`, já espelhados e congelados. Nasce **um tipo novo por lado**, e o [[Contrato POST turn]] **não é tocado**.
- **Geração preguiçosa, uma vez**, na primeira leitura do encaminhamento — nunca dentro do turno do lead.

## Motivo

**O `PerfilLead` descarta a negação de propósito.** [[Decisao - Testes do agente em duas superficies]] registra que, quando o lead diz só o que *não* quer, o campo fica nulo: manter `regiao: "exceto zona leste"` seria pior que perder, porque esse valor vira consulta ao índice vetorial no [[RAG]] e embedding não tem operador de negação.

Daí o silogismo que decide o card: um template lê o perfil; o perfil jogou a objeção fora; logo o template não satisfaz o critério. Só a transcrição tem essa informação, e lê-la para extrair objeção é trabalho de LLM.

O efeito colateral é a melhor frase do card para o pitch: **o campo estruturado joga a negação fora porque embedding não entende "exceto"; o resumo do corretor a recupera do texto, porque um humano entende.**

A geração fora do turno também não é preferência. Pôr a segunda chamada dentro do `POST /conversas/{id}/mensagens` faria a pessoa esperar por um texto que ela nunca vê, dentro do orçamento de 45 s e com a trava da conversa segurada — e transformaria um turno bom em `504` sob pressão de cota, que é falha já observada duas vezes neste projeto.

## Custo aceito

Uma chamada a mais por encaminhamento, no [[Gemini free tier]] — a mais rara do sistema, contra 1 por turno comum e 56 por iteração de prompt. A segunda fronteira entre os repositórios passa a existir, com o mesmo mecanismo da primeira: campo desconhecido recusado dos dois lados e commit coordenado. E a primeira leitura do painel espera pela geração, em vez de encontrá-la pronta — migrar para geração antecipada fica barato quando o S-24 trouxer o `BackgroundService`, mas não se planeja isso agora.

Risco assumido: **alucinação de objeção**. A defesa é a de [[Decisao - Motivo do LLM como portao do cartao]] — campo nulável, proibição explícita no prompt, e teste afirmando nulo quando não houve objeção.

## Alternativas descartadas

- **Template determinístico no .NET.** Grátis e testável, mas impossível pelo motivo acima.
- **Sumarização local com `transformers` + `torch`.** Otimizaria a chamada mais barata do sistema; o ganho de privacidade seria **zero**, porque a transcrição já vai ao Gemini turno a turno desde o S-06; e o peso de gigabytes mais pesos briga com o S-26 (Cloud Run) e com o S-28, cujo critério exige CI gratuito e sem chave. [[Decisao - Nenhum ML classico no escopo]] já cobria o caso.
- **`python-docx`.** Não há entregável em `.docx`: o resumo é lido no painel, o README é markdown e o pitch é deck.

## Conceitos

[[Qualificacao de leads]] · [[Agente stateless]] · [[Gemini free tier]] · [[Testar a Lia]] · [[Mascaramento de PII]]

## Relacionadas

- [[Decisao - Testes do agente em duas superficies]] — onde a negação foi deliberadamente descartada do perfil, e que é a premissa desta decisão
- [[Decisao - Motivo do LLM como portao do cartao]] — mesma defesa contra alucinação, no cartão de imóvel
- [[Decisao - Contrato do POST turn congelado]] — a primeira fronteira; esta é a segunda, e herda o mecanismo
- [[Decisao - Agente Python stateless]] — por que o `/resumo` recebe transcrição na requisição em vez de ler o banco
