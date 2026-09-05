---
tipo: decisao
data: 2026-09-05
status: vigente
tags: [decisao, infra, docker]
---
# Decisão — Ambiente local em Docker Compose, com o front fora dele

> **Vigente**, com a estrutura do arquivo refinada horas depois: o compose do `solar-ai-docs` deixou de definir os serviços e passou a compô-los por `include`, com um fragmento por repositório dono. O ambiente, as portas e o raciocínio abaixo não mudaram. Ver [[Decisao - Compose composto por include]].

## Problema

Quatro repositórios separados ([[Decisao - Quatro repositorios separados]]) e nenhum lugar único para subir o ambiente. Sem isso, cada sessão começaria abrindo três terminais e lembrando de mão a ordem de partida — e o Postgres, que é a peça que o desenvolvedor menos domina, seria a primeira a ser adiada para "depois, no deploy".

## Decisão

O `docker-compose.yml` vive no `solar-ai-docs` e alcança os repos irmãos por caminho relativo (`../solar-ai-api`, `../solar-ai`). Sobe três serviços:

| serviço | imagem/origem | porta host |
|---|---|---|
| `postgres` | `postgres:16-alpine` | 5432 |
| `api` | build de `../solar-ai-api` | 8080 |
| `agente` | build de `../solar-ai` | 8000 |

Quatro escolhas dentro dessa:

- **O Angular fica fora.** Roda com `ng serve`, que tem hot reload. Dentro do compose, cada alteração de template custaria rebuild de imagem, e o front não ganharia nada em troca.
- **Postgres em container desde o primeiro dia**, com volume nomeado `postgres-data`. Evita a migração de SQLite para Postgres na véspera do deploy — que é a hora em que ela custa caro.
- **A API espera o banco por `healthcheck`, não por `depends_on` simples.** `pg_isready` é o que distingue "o container iniciou" de "o banco aceita conexão"; no primeiro boot há vários segundos entre os dois estados.
- **O agente não tem `depends_on` do Postgres**, e o `/health` dele não checa banco nenhum. Isso é [[Agente stateless]] escrito em YAML: se um dia o agente precisar do banco para responder, a arquitetura já quebrou antes de qualquer teste.

## Segredos

Nada de credencial em imagem. A senha do Postgres vem do `.env` do `solar-ai-docs` (gitignored, com `.env.example` ao lado) e a chave da Gemini entra no container do agente por `env_file` apontando para o `.env` do próprio `solar-ai` — que está no `.dockerignore` de lá, então nunca é copiado para dentro da imagem. Verificado em 05/09: `find / -name .env` dentro da imagem do agente não retorna nada.

## SDK fixado

A máquina tem os SDKs .NET 7, 9 e 10 instalados. Um `global.json` no `solar-ai-api` fixa **10.0.400**, a mesma banda da imagem `sdk:10.0` do container, para que o build local e o build do container sejam o mesmo build — é a origem clássica de "compila aqui, quebra no container". Versão e estilo da API em [[Decisao - NET 10 com controllers]].

## Custo aceito

O compose depende do layout de pastas: os quatro repositórios têm que estar clonados lado a lado dentro de uma pasta `solar/`. É a contrapartida direta do multi-repo, e vale a documentar no README.

## Medido em 05/09

`docker compose up --build` sobe os três. `GET :8080/health` responde `{"status":"up","db":"up"}` — a API abriu conexão real com o Postgres pelo DNS interno da rede do compose. `GET :8000/health` responde com `chave_carregada: true` e o modelo fixado. Imagem final da API sem nenhum `.cs`, imagem do agente sem nenhum `.env`.

## Conceitos

[[Multi-repo e CI-CD]] · [[Agente stateless]] · [[Arquitetura poliglota]]

## Relacionadas

- [[Decisao - Quatro repositorios separados]]
- [[Decisao - Arquitetura poliglota Python e NET]]
- [[Decisao - Agente Python stateless]]
