---
tipo: decisao
data: 2026-09-10
status: vigente
tags: [decisao, testes, postgres, seguranca, s-29]
---
# Decisão — Banco de testes dedicado `solar_test` e execução em CI

## Problema

Anteriormente, testes de integração com banco de dados podiam acidentalmente executar contra o banco de desenvolvimento (`solar`), arriscando corrupção ou apagamento de dados de teste/demonstração. Além disso, a presença de connection strings hardcoded no código expunha credenciais e o skip silencioso quando o banco estava desligado mascarava falhas em esteiras de validação.

## Decisão

1. **Banco Dedicado e Descartável (`solar_test`):** Todos os testes de integração com banco real devem se conectar exclusivamente a uma base de dados descartável separada (`solar_test`), nunca à base de desenvolvimento (`solar`).
2. **Guarda Ativa de Conexão:** A suíte de testes (`ExclusaoLeadPostgresTeste`) valida ativamente o nome do banco antes de conectar. Se o banco apontado for `solar`, uma `InvalidOperationException` é disparada imediatamente, abortando a execução.
3. **Falha Explícita em Indisponibilidade:** Testes de integração não fazem retorno antecipado nem skip silencioso se o banco estiver indisponível; se a conexão ou execução falhar, dispara-se `Assert.Fail` com mensagem explicativa.
4. **Sem Segredos em Código:** Connection string é obtida prioritariamente via variável de ambiente `ConnectionStrings__PostgresTest` ou montada dinamicamente a partir do `.env` local (arquivo ignorado pelo git).
5. **Automação de Schema:** Os testes executam `await dbContext.Database.MigrateAsync()` programaticamente antes dos cenários, dispensando scripts manuais de DDL.

## Requisitos para CI (GitHub Actions)

Para execução contínua em CI:
- Um serviço de container `postgres:16-alpine` deve ser configurado com banco inicial `solar_test`.
- A variável `ConnectionStrings__PostgresTest` deve ser injetada no step de `dotnet test`:
  `Host=localhost;Port=5432;Database=solar_test;Username=...;Password=...`

## Conceitos

[[Direito de eliminacao]] · [[Integridade referencial]] · [[Segurança da Informação]]
