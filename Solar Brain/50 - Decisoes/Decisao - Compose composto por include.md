---
tipo: decisao
data: 2026-09-05
status: vigente
tags: [decisao, infra, docker]
---
# Decisão — Compose composto por `include`, com um fragmento por repositório dono

> Refina a [[Decisao - Ambiente local em Docker Compose]], tomada horas antes no mesmo dia. O ambiente local continua sendo levantado do `solar-ai-docs`; o que muda é **quem define cada serviço**.

## Problema

A primeira versão pôs os três serviços num `docker-compose.yml` único no `solar-ai-docs`. Funciona, e atende o critério de aceite do S-02 — mas cobra em dois lugares:

- **CI/CD por repositório** é objetivo declarado do projeto (S-27 e S-28). O pipeline do `solar-ai-api` que quisesse subir Postgres + API para um teste de integração teria que clonar um segundo repositório só para buscar um YAML.
- **Acoplamento invertido.** Um arquivo no `solar-ai-docs` descrevendo como a API .NET é construída significa que o repo de documentação sabe detalhes de build de um repo de código. O `Dockerfile` já mora no lugar certo; a definição do serviço não morava.

A alternativa óbvia — um compose independente por repo — é **pior**, e o motivo é o S-05.

## Por que não dois composes independentes

Cada `docker compose up` cria uma rede própria. Dois composes = duas redes isoladas. Hoje não dói, porque nenhum serviço chama o outro. No S-05 a API passa a chamar o agente por `HttpClient` tipado, e aí seria preciso uma rede `external` declarada nos dois arquivos e criada à mão com `docker network create` antes de qualquer subida.

É um pré-requisito manual que não está escrito em nenhum dos dois repositórios e que **falha em silêncio**: o container sobe, e só a chamada HTTP quebra, com DNS que não resolve. Some a isso duas fontes para o mapa de portas (nada impede os dois pedirem 8080) e um `down` que deixa de ser simétrico ao `up`.

## Decisão

Cada repositório dono publica um `compose.yml` com **apenas os seus serviços**:

| arquivo | define | roda sozinho? |
|---|---|---|
| `solar-ai-api/compose.yml` | `postgres` + `api` | sim — é o alvo do S-27 |
| `solar-ai/compose.yml` | `agente` | sim — é o alvo do S-28 |
| `solar-ai-docs/docker-compose.yml` | **nada** — só `include` dos dois | é o ambiente completo |

Quatro detalhes que fazem isso funcionar:

- **O orquestrador não define serviço nenhum.** Ele declara `name: solar` e inclui. É a única fonte do mapa de portas e da rede.
- **Os fragmentos não declaram `name:`.** Assim o projeto Compose é o de quem inclui, e os três serviços caem na mesma rede — `solar_default`. Rodando sozinho, cada fragmento ganha o nome do próprio diretório e um volume separado, que é o isolamento que o CI quer.
- **Caminhos relativos resolvem em relação ao fragmento**, não a quem inclui. Por isso `context: .` e `env_file: .env` funcionam nos dois modos.
- **Sem `container_name` fixo.** Nome fixo impediria rodar o ambiente completo e um fragmento isolado ao mesmo tempo. Os containers passaram a se chamar `solar-api-1`, `solar-postgres-1`, `solar-agente-1`.

## Onde os segredos passaram a morar

Cada fragmento lê o `.env` do próprio repositório. A senha do Postgres saiu do `solar-ai-docs` e foi para o `solar-ai-api` — junto de quem é dono do banco, o que é a regra do [[Agente stateless]] aplicada também à credencial. A chave da Gemini já morava no `solar-ai`. O `solar-ai-docs` deixou de ter `.env`.

**Armadilha:** `docker compose config` imprime todos os segredos resolvidos em texto claro, chave da Gemini incluída. Nunca colar a saída desse comando em issue, print ou chat.

## Custo aceito

O Postgres agora é definido no `solar-ai-api`. Se um dia outro serviço precisar do mesmo banco em local, o fragmento deixa de ser "só do repo dono" — improvável neste projeto, já que o agente é stateless por decisão.

A dependência do layout de pastas continua: `include: ../solar-ai-api/compose.yml` exige os quatro repositórios clonados lado a lado numa pasta `solar/`.

## Verificado em 05/09

Os três modos sobem e respondem: ambiente completo pelo `solar-ai-docs`, `solar-ai-api` sozinho (`/health` com `db: up`) e `solar-ai` sozinho. De dentro da rede do ambiente completo, `getent hosts postgres agente` resolve os dois — que é a prova antecipada de que o S-05 vai funcionar. O volume `solar_postgres-data` sobreviveu ao refactor.

## Conceitos

[[Multi-repo e CI-CD]] · [[Agente stateless]] · [[Contrato POST turn]]

## Relacionadas

- [[Decisao - Ambiente local em Docker Compose]]
- [[Decisao - Quatro repositorios separados]]
- [[Decisao - NET 10 com controllers]]
