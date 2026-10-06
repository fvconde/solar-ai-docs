---
tipo: decisao
data: 2026-10-05
status: vigente
tags: [decisao, deploy, ci-cd, github-actions, api, wif]
---
# Decisão — A API é publicada pelo push na `main`, e a `develop` só testa

## Problema

O card S-27 pedia: "push na branch main dispara build e deploy". Só que o fluxo do projeto integra tudo em `develop`, e a `main` só recebe releases (`release/v1.0`, `v1.1`, `v1.2`). Se o pipeline publicasse a cada merge na `develop`, qualquer card integrado mudaria sozinho a demo que está no ar, perto da gravação do vídeo.

## Decisão

- **A `develop` e os PRs só testam.** O `ci.yml` restaura, compila e roda a suíte inteira contra um Postgres 16 de serviço do GitHub, no banco `solar_test`.
- **Só o push na `main` publica.** O `cd.yml` repete os testes, e o job de deploy depende deles (`needs`). Teste vermelho barra a publicação.
- **O deploy troca só a imagem e a versão.** Ele roda `gcloud run deploy solar-api --image <sha> --update-env-vars SOLAR_VERSION=<sha>` e nunca usa `--set-env-vars`, `--set-secrets` ou `--clear-secrets`, que reescreveriam a produção do S-26 inteira.
- **O GitHub entra no Google sem chave**, por Workload Identity Federation. A condição fica **no provedor**, e não só no binding: `assertion.repository == 'fvconde/solar-ai-api' && assertion.ref == 'refs/heads/main'`. A conta do pipeline tem o mínimo de papéis.
- **A publicação acontece em fila e só no topo.** O `concurrency` não cancela publicações em andamento, e um commit que já não é o topo da `main` termina sem publicar.
- **O preparo na nuvem é do usuário.** `deploy/S-27/Preparo-Wif.ps1` mostra o plano por padrão e só altera a nuvem com `-Executar`.

## Por quê

A demo que está no ar é a que vai para o vídeo e para a banca. Publicar por release deixa o momento da mudança na mão do usuário, e o card continua mostrando no pitch um pipeline de verdade, com teste como portão.

## Custo aceito

- **A publicação só acontece quando o usuário promove uma release.**
- **A próxima release publica só a API, e precisa do agente atualizado.** Desde o S-45, a API espera o campo `essenciaisCompletos`, e um agente antigo na nuvem faz o painel errar sem dar erro. O agente e o front continuam no script do S-26 até o S-28.
- **As tags são imutáveis.** Refazer o CD do mesmo SHA não sobrescreve a imagem.

## Relacionadas

- [[Decisao - Quatro repositorios separados]]: o S-27 é a razão de ter repositórios separados.
- [[Decisao - Front publico e API privada por IAM no Cloud Run]]: o deploy do S-26, cuja configuração este pipeline preserva.
- [[Decisao - Marcos imutaveis e inicio do registro gravado pela migration]]: a emenda do `/turn` que obriga agente e API a subirem juntos.
- [[Bug - teste de reset ordenava sessoes por horario empatado]]: o teste que travou o primeiro CI verde.
