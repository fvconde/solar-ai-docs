---
tipo: decisao
data: 2026-10-06
status: vigente
tags: [decisao, deploy, ci-cd, github-actions, agente, front, wif]
---
# Decisão — Agente e front também são publicados pelo push na `main`

## Problema

O S-27 deu pipeline só à API. O agente e o front continuavam publicados pelo script do S-26, à mão. Desde o S-45, a API espera o campo `essenciaisCompletos` no `/turn`, e um agente antigo na nuvem faz o painel errar sem dar erro. Com a API publicando sozinha e o agente dependendo de alguém lembrar do script, a primeira release depois do S-27 deixaria os dois desencontrados.

## Decisão

Decidido pelo usuário ao aprovar o S-28, em 05/10:

- **Mesmo molde da API, em cada repositório.** Há um `ci.yml` em PR e push na `develop`, e um `cd.yml` em push na `main`, com os testes como portão (`needs`). Cada deploy roda `gcloud run deploy solar-agente` ou `solar-front` trocando **só** `--image` e `SOLAR_VERSION`. A fila e a guarda do topo da `main` são as mesmas.
- **O CI do agente não conhece a chave do Gemini.** Ele roda a suíte grátis, com o `-m "not llm"` que já está no `pytest.ini`, e nenhum workflow cita `GEMINI_API_KEY`. Assim o CI não gasta a cota diária que a demo usa.
- **O CI do front encerra sozinho.** Ele roda `npm test -- --no-watch --browsers=ChromeHeadless`, o build e os testes stdlib de `deploy/tests/`. A forma `--watch=false`, que o Angular 20 ignora, ficaria presa até o timeout.
- **Um pool WIF só.** O `Preparo-Wif.ps1` do S-27 foi estendido em vez de duplicado. A condição do provedor aceita os três repositórios, sempre só em `refs/heads/main`, e a conta do pipeline ganhou papéis apenas sobre os dois serviços novos e as contas de execução deles.

## Por quê

Uma release para a `main` passa a publicar os três serviços, sem passo manual que alguém esqueça. O pitch mostra três pipelines com teste como portão, e não um.

## Custo aceito

- **Os três CDs disparam independentes, sem ordem garantida.** Numa release que mude o `/turn`, API e agente podem ficar desencontrados por alguns minutos. A regra prática é promover a release longe da gravação e conferir o `/health` dos três antes de usar o painel.
- **O preparo continua sendo do usuário**, e agora são 15 Variables (5 por repositório).

## Relacionadas

- [[Decisao - Publicacao da API pelo push na main]]: o molde que esta decisão estende.
- [[Decisao - Front publico e API privada por IAM no Cloud Run]]: a configuração do S-26 que nenhum dos três pipelines redefine.
- [[Decisao - Marcos imutaveis e inicio do registro gravado pela migration]]: a emenda do `/turn` que obriga agente e API a subirem juntos.
- [[Testar a Lia]]: por que a suíte grátis e a que custa cota são separadas.
