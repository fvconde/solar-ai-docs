---
tipo: decisao
data: 2026-09-05
status: vigente
tags: [decisao, arquitetura, risco]
---
# Decisão — o `POST /turn` congelado em DTO espelhado, com recusa de campo desconhecido

## Problema

O `POST /turn` é a única fronteira entre `solar-ai-api` e `solar-ai`, e o `ESTADO.md` o listava desde 21/08 como **a maior fonte potencial de retrabalho do projeto**. Até o S-05 ele não existia em lugar nenhum: nem código, nem escrito.

O prazo é o que torna isso caro. Da Fase 2 em diante, cada card novo passa a depender do formato — o grafo do S-06, a extração estruturada do S-11, o EF Core do S-10, os cards de imóvel do S-16. Mudar o contrato depois disso custa commit coordenado em dois repositórios **mais** o retrabalho de tudo que já assumiu o formato antigo. Com congelamento de código em 24/09, não há orçamento para descobrir isso na Fase 3.

E existe um modo de falha pior que mudar o contrato: **ele apodrecer em silêncio**. Um campo renomeado de um lado só chega ao outro como `null` — o turno responde 200, a Lia responde alguma coisa, e o `precoMax` simplesmente nunca mais é preenchido. Sem nada no log.

## Decisão

Contrato congelado em **DTO espelhado nos dois repositórios**, com os campos que o card S-05 já fixava:

- **entra** — `conversaId`, `mensagem`, `historico[]`, `perfilLead`
- **sai** — `resposta`, `intencao`, `camposExtraidos`, `proximaAcao`, `imoveisSugeridos[]`

O formato completo, os vocabulários fechados e a regra de merge estão em [[Contrato POST turn]]. Três escolhas de dentro dele valem registro:

1. **Campo desconhecido é recusado dos dois lados** — `JsonUnmappedMemberHandling.Disallow` no .NET, `extra="forbid"` no Pydantic.
2. **`imoveisSugeridos` carrega os campos de render** (tipo, bairro, quartos, metragem, preços), não só `{id, motivo}`.
3. **Sem campo de versão do contrato.** Quem versiona é o git, nos dois repos.

A API expõe o mesmo `POST /turn` como repasse, através de um `HttpClient` tipado (`AgenteClient`), com `502` / `504` no lugar de qualquer 500.

## Motivo

**Recusar campo desconhecido** é o que troca o modo de falha. Sem isso, um espelho quebrado vira `null` silencioso e só aparece semanas depois, quando alguém nota que o score nunca sobe. Com isso, a mesma divergência vira **400 ou 422 no primeiro request**, na sessão em que foi introduzida. Num projeto de uma pessoa só, com quatro repos e pipelines independentes ([[Multi-repo e CI-CD]]), errar alto vale mais que tolerar.

**Os campos de render no imóvel** evitam uma segunda fronteira. A base mora em `solar-ai/data` e quem escolhe os três é o [[RAG]]; se a resposta trouxesse só o id, o S-16 precisaria de uma segunda cópia do `imoveis.json` ou de um `GET /imoveis/{id}` no agente. Sete campos custam menos que qualquer um dos dois, e o que o .NET grava vira o snapshot que o S-21 mostra depois.

**Nenhum campo de versão** porque ele só se paga com negociação entre versões, e a regra aqui é commit coordenado — a versão estaria sempre igual dos dois lados, sendo mantida à toa. A recusa de campo desconhecido faz o trabalho que o número prometia.

**Vocabulário como `string` com constantes, não `enum`**, do mesmo jeito que o `HealthStatus` do [[Contrato GET health]]. O contrato fica descrito na única fonte que os dois lados publicam — o OpenAPI — e o `Literal` do Pydantic é quem valida, porque é o agente que produz esses valores. O .NET aceita a string e deixa o agente recusar: foi o que aconteceu com `urgencia: "urgentissima"`, que virou 422 no agente e `502` na API.

**Sem retentativa no `AgenteClient`.** Um turno é uma chamada ao LLM: repetir gasta cota do [[Gemini free tier]] e pode duplicar efeito no meio de um agendamento.

## Custo aceito

**A requisição é grande, e vai crescer.** Todo turno carrega até 50 mensagens de histórico mais o perfil inteiro, porque o [[Agente stateless]] não tem de onde tirar contexto. É a conta do stateless, e ela já estava aceita — o S-05 só a tornou visível em número.

**`intencao` fora do `camposExtraidos`** obriga o .NET a fazer o merge em dois pedaços: o campo do topo e os sete de dentro. O ganho é não ter duas fontes para o mesmo valor.

**Preços sem centavos.** O contrato usa inteiro em reais dos dois lados. Serve para imóvel; se um dia entrar valor com centavo — condomínio proporcional, taxa — o contrato muda.

**O `POST /turn` da API é público e sem limite.** No S-07 ele deixa de ser a porta principal, e o rate limit chega no S-29. Até lá, qualquer um que alcance a porta 8080 gasta cota do Gemini.

**A validação sumiu do schema do OpenAPI.** `[StringLength]` teve que sair de `[property:]` para o parâmetro do construtor primário — ver a armadilha registrada em [[Contrato POST turn]]. O MVC valida; o Swagger não mostra o limite.

## Verificado em 05/09

Com os três containers de pé e o agente devolvendo eco:

- **Caminho feliz** — `POST /turn` na API (`:8080`) atravessa até o agente (`:8000`) e volta 200 com os cinco campos.
- **Espelho** — os dois OpenAPI comparados campo a campo: **6 tipos, 35 campos**, mesmos nomes e mesmos tipos dos dois lados.
- **Validação** — `mensagem` vazia devolve **400** com o erro por campo; campo desconhecido (`canal`) devolve **400** antes de sair da API.
- **Vocabulário** — `urgencia: "urgentissima"` passa pelo .NET, é recusada pelo agente com **422**, e a API devolve **502 · "o agente respondeu 422"**.
- **Agente fora** — `docker stop` no agente: **502**, com `detail` citando `http://agente:8000` em `Development`.
- **Tempo limite** — API apontada para um endereço que não responde, com `Agente__TimeoutSegundos=3`: **504** em 3,1s.
- **Produção** — a mesma falha com `ASPNETCORE_ENVIRONMENT=Production` devolve **502 sem `detail`**; o motivo fica só no log.

## Emendas

- **05/09** — [[Decisao - Vocabulario do contrato alinhado ao enunciado]] trocou dois vocabulários: `proximaAcao` perdeu `escalar_humano` e ganhou `direcionar_especialista`, `agendar_visita` virou `agendar_reuniao`, e `expectativaRetorno` entrou em `PerfilLead` e `CamposExtraidos`. O mecanismo desta decisão — DTO espelhado, recusa de campo desconhecido dos dois lados, commit coordenado — continua valendo inteiro; foi ele que tornou a emenda segura.

## Conceitos

[[Contrato POST turn]] · [[Agente stateless]] · [[Arquitetura poliglota]] · [[Qualificacao de leads]] · [[RAG]]

## Relacionadas

- [[Decisao - Agente Python stateless]]
- [[Decisao - Quatro repositorios separados]]
- [[Decisao - Formato do payload do health check]]
- [[Decisao - NET 10 com controllers]]
- [[Decisao - Compose composto por include]]
- [[Decisao - Vocabulario do contrato alinhado ao enunciado]]
