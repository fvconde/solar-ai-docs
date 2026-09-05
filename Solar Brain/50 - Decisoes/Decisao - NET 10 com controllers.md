---
tipo: decisao
data: 2026-09-05
status: vigente
tags: [decisao, infra, dotnet]
---
# Decisão — `solar-ai-api` em .NET 10, com controllers em vez de minimal API

> Substitui o detalhe de versão da [[Decisao - Arquitetura poliglota Python e NET]], que continua **vigente** no essencial: Python para a camada de IA, .NET para o domínio e o banco. O que muda aqui é a versão do runtime e o estilo do pipeline HTTP, não a repartição de responsabilidades.

## Problema

O esqueleto do S-02 nasceu em .NET 9 e minimal API, herdado do template padrão do `dotnet new webapi`. Duas coisas erradas nisso.

A **versão**: a máquina tem os SDKs 7, 9 e 10 instalados e o .NET 10 é o runtime corrente. Ficar em 9 num projeto que começa hoje e congela em 24/09 é escolher uma versão que já nasce velha, sem nenhum ganho — não há dependência do projeto que exija o 9.

O **estilo**: minimal API concentra rota, validação e injeção de dependência em delegates dentro do `Program.cs`. Funciona para dois endpoints. O domínio do Solar tem leads, conversas, agendamentos e métricas — a essa altura o `Program.cs` viraria um arquivo de várias centenas de linhas sem eixo de organização.

## Decisão

- `TargetFramework` = `net10.0`, `global.json` fixando o SDK **10.0.400**, imagens `mcr.microsoft.com/dotnet/sdk:10.0` e `aspnet:10.0`.
- Pipeline MVC: `builder.Services.AddControllers()` + `app.MapControllers()`. O `Program.cs` fica com cinco linhas e não cresce mais.
- Um controller por área do domínio, com rotas por atributo. O primeiro é o `HealthController`, servindo `/` e `/health`.
- Injeção por construtor primário (`HealthController(IConfiguration, ILogger<HealthController>)`), que é o padrão que os controllers seguintes vão repetir.

## Motivo

Controllers dão um lugar óbvio para cada coisa nova entrar. Num projeto de uma pessoa só com prazo curto, "onde isso vai?" respondido pela estrutura vale mais que as poucas linhas que a minimal API economiza. É também o estilo que o desenvolvedor já conhece de .NET no trabalho — e a decisão de usar .NET era, desde o início, sobre stack de carreira.

## Custo aceito

Um pouco mais de cerimônia por endpoint: classe, atributos de rota, tipo de retorno `IActionResult`. Irrelevante frente ao ganho de organização.

O `Microsoft.AspNetCore.OpenApi` saiu do `csproj` junto: o template o incluía e nada o usava. Volta no **S-04**, cujo critério de aceite exige Swagger exposto — e o card manda não desabilitá-lo em ambiente nenhum, porque ele vira prova de arquitetura no pitch (S-32).

## Verificado em 05/09

Runtime dentro do container: `Microsoft.AspNetCore.App 10.0.11`. `GET /` e `GET /health` respondem 200, com `db: up`. Rota inexistente devolve 404 — o roteamento por controller está ativo, não é minimal API disfarçada.

## Conceitos

[[Arquitetura poliglota]] · [[Multi-repo e CI-CD]]

## Relacionadas

- [[Decisao - Arquitetura poliglota Python e NET]]
- [[Decisao - Ambiente local em Docker Compose]]
