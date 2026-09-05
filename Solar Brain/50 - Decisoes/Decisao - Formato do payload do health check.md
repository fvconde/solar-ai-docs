---
tipo: decisao
data: 2026-09-05
status: vigente
tags: [decisao, arquitetura, operacao]
---
# Decisão — envelope com `checks` no `/health`, e `degraded` respondendo 200

## Problema

Os dois esqueletos já respondiam `/health` desde o S-02, mas cada um com uma casca própria e improvisada: a API devolvia `{service, status, db}`, o agente `{service, status, modelo, chave_carregada}`. Nada errado — e nada contratado.

Três coisas quebravam nesse formato:

1. **Não absorve dependência nova.** O S-15 acrescenta o índice do [[RAG]] ao agente. Como campo solto (`indice: "up"`), toda dependência futura muda a forma do objeto, e o painel do S-19 precisa de uma alteração por dependência.
2. **`db` só existe na API.** As duas cascas divergiam, então o front precisaria de dois tipos para duas respostas que dizem a mesma coisa.
3. **Ninguém tinha decidido o código HTTP.** A API devolvia `503` com `status: "degraded"` no corpo — o código dizia "não me mande tráfego" e o corpo dizia "ainda atendo". Duas respostas contraditórias para as duas plateias.

## Decisão

Envelope `{service, status, version, checks}` nos dois serviços, vocabulário `up` / `degraded` / `down`, `checks` como **dicionário**. O detalhe está em [[Contrato GET health]].

**A tabela de status code, que é a metade que faltava:**

| `status` | HTTP |
|---|---|
| `up` | 200 |
| `degraded` | **200** |
| `down` | 503 |

## Motivo

**`checks` como dicionário** porque é a única forma que cresce sem quebrar: `"indice_imoveis": {...}` entra ao lado de `"gemini_config"` sem que nenhuma chave existente mude de forma. O front do S-19 itera o dicionário e nunca mais precisa ser editado por dependência nova.

**Mesma casca nos dois serviços**, mesmo com o agente tendo um check só. Um `checks` com uma entrada é o mesmo tipo de um `checks` com quatro — se o agente tivesse formato próprio "porque é mais simples", o [[Agente stateless]] apareceria como exceção no front em vez de aparecer como o que é: um serviço com poucas dependências.

**Record tipado nos dois lados**, e não dicionário montado à mão, porque é o que produz schema no Swagger — e Swagger exposto é o critério de aceite do S-04, além de virar prova de arquitetura no pitch do S-32.

**`degraded` → 200** é a escolha que precisava ser feita e não fazia diferença nenhuma até existir um orquestrador. Com o Cloud Run (S-26), faz toda: `degraded` significa "ainda atende o que dá", e devolver 503 mandaria o Cloud Run reciclar uma instância que está servindo — e o healthcheck do Compose marcar `unhealthy` um container útil. Quem precisa distinguir `up` de `degraded` é o painel do S-19, e ele lê o corpo.

O corolário disso é que `down` fica reservado para falha **essencial**, e por isso o Postgres fora agora derruba a API para `down` — não `degraded`, como o código do S-02 dizia. Com o banco fora ela não entrega nada.

## Custo aceito

**O agente perdeu `modelo` e `chave_carregada` do corpo.** Eram úteis: era assim que se confirmava, sem entrar no container, que `gemini-3.5-flash-lite` estava mesmo carregado — o que importa por causa de [[Decisao - Modelo Gemini fixado sem alias]]. O envelope só carrega `status` e `reason`, e abrir exceção para um campo do agente desfaria a simetria que é o ponto da decisão. O nome do modelo passou a sair na linha de log do boot.

**`version` depende de uma variável de ambiente** (`SOLAR_VERSION`), não do git — `.git/` está no `.dockerignore` dos dois repos de propósito, então o build não tem como descobrir o SHA sozinho. Sem a variável, o campo vale `dev`. Quem injeta o SHA de verdade são os pipelines do S-27 e S-28 e o deploy do S-26. Ver [[Multi-repo e CI-CD]].

**Uma variável nova no agente** (`SOLAR_ENV`), só para decidir se o `reason` aparece no corpo. A API já tinha `ASPNETCORE_ENVIRONMENT`.

## Deixado de fora, conscientemente

O `healthcheck:` do Compose para `api` e `agente` — hoje só o Postgres tem um. O contrato existe para ser lido por ele, mas ligá-lo pede `curl` dentro da imagem `aspnet:10.0`, que não vem com nenhum cliente HTTP. Fica para o S-26, junto com o probe do Cloud Run, que é onde a decisão de instalar ou não o binário se paga.

## Verificado em 05/09

Com o ambiente completo de pé, `SOLAR_VERSION` injetado:

- **Caminho feliz** — API e agente devolvem `status: "up"` com `version` e `checks`, **HTTP 200** nos dois.
- **`down` na API** — com `docker stop` no Postgres: `status: "down"`, **HTTP 503**, e em `Development` o `reason` traz `57P01: terminating connection due to administrator command`.
- **`down` no agente** — container sem `GEMINI_API_KEY`: `status: "down"`, **HTTP 503**.
- **Detalhe reduzido** — os mesmos dois containers em produção (`ASPNETCORE_ENVIRONMENT=Production`, `SOLAR_ENV` ausente) devolvem `{"status":"down"}` **sem `reason`**, e o motivo aparece só no `docker logs`.
- **Swagger** — `/swagger` e `/openapi/v1.json` respondem 200 na API; `/docs` e `/openapi.json` no agente.

## Conceitos

[[Contrato GET health]] · [[Agente stateless]] · [[Arquitetura poliglota]] · [[Multi-repo e CI-CD]]

## Relacionadas

- [[Decisao - Ambiente local em Docker Compose]]
- [[Decisao - Compose composto por include]]
- [[Decisao - NET 10 com controllers]]
- [[Decisao - Modelo Gemini fixado sem alias]]
