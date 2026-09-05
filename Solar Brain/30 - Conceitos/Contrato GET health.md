---
tipo: conceito
tags: [conceito, arquitetura, operacao]
---
# Contrato GET /health

## O que é

O formato de resposta do `/health`, **idêntico** em `solar-ai-api` (.NET) e `solar-ai` (Python). Congelado no **S-04**.

É o segundo contrato do projeto, e o oposto do [[Contrato POST turn]] em risco: aquele carrega o estado inteiro de um turno e mudar dói; este é uma casca de quatro campos que só cresce por dentro do `checks`.

## O formato

```json
{
  "service": "solar-ai-api",
  "status": "up",
  "version": "9b570ce",
  "checks": { "postgres": { "status": "up" } }
}
```

| Campo | Valor |
|---|---|
| `service` | nome do repositório: `solar-ai-api` ou `solar-ai` |
| `status` | `up` · `degraded` · `down` — nada além disso |
| `version` | SHA curto do commit; `dev` quando a variável `SOLAR_VERSION` não vem do ambiente |
| `checks` | dicionário `nome → { status, reason? }` |

## As duas plateias

É a razão de o contrato existir, e a razão de ele ter **duas metades que precisam concordar**:

- **Cloud Run (S-26) e healthcheck do Compose** leem **só o código HTTP**. Nunca abrem o corpo.
- **O painel do S-19** lê **só o corpo**. Nunca vê o código.

Fixar um sem o outro deixa metade dos consumidores sem contrato.

| `status` | HTTP |
|---|---|
| `up` | **200** |
| `degraded` | **200** |
| `down` | **503** |

## Regra de agregação

Cada check é **essencial** ou **acessório** — a classificação vive no código, não no payload.

- Qualquer essencial fora → envelope `down` → **503**
- Só acessório fora → envelope `degraded` → **200**
- Todos de pé → `up` → **200**

Hoje: `postgres` é essencial na API — sem banco ela não entrega nada, porque todo o estado mora lá por causa do [[Agente stateless]]. `gemini_config` é essencial no agente: sem chave não há turno para responder.

No S-15 o [[RAG]] entra como `"indice_imoveis"`, **acessório** — a Lia ainda conversa sem [[Indice vetorial em memoria]], só não recomenda imóvel. É `degraded`, e continua 200.

## `reason`, e o detalhe reduzido em produção

`reason` só aparece quando o check **não** está `up`, e só no corpo em ambiente de desenvolvimento. Em produção o motivo existe **apenas no log**.

O `/health` é público e sem autenticação. A mensagem do Npgsql cita host, porta, base e usuário — reconhecimento de graça para quem varre a internet. Encosta na mesma preocupação de [[Mascaramento de PII]]: o que sai do processo é decidido pelo ambiente, não pelo acaso da exceção.

Quem controla: `ASPNETCORE_ENVIRONMENT` na API, `SOLAR_ENV` no agente. Os dois tratam **ausência da variável como produção** — se o deploy esquecer, o erro é esconder demais.

## Um endpoint só

Sem separar liveness de readiness. Três serviços e um deploy não pagam a segunda rota, e o detalhe da falha não vira endpoint verboso — vira log.

O `/` de cada serviço devolve só `{"service": ...}`, sem campo `status`, de propósito: um `/` que responde sempre `up` com os mesmos nomes de campo do envelope seria armadilha para quem ligar o monitoramento.

## Onde ele está escrito

Como record tipado nos dois lados, e não como dicionário solto — é isso que dá schema no Swagger, critério de aceite do S-04:

- `.NET` — `Contracts/HealthResponse.cs`, publicado em `/openapi/v1.json` e na UI em `/swagger`
- `Python` — modelos Pydantic em `app/main.py`, publicados em `/openapi.json` e na UI em `/docs`

## Decisões que dependem disso

- [[Decisao - Formato do payload do health check]]
- [[Decisao - Ambiente local em Docker Compose]]
- [[Decisao - NET 10 com controllers]]
