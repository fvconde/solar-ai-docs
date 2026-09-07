---
tipo: conceito
tags: [conceito, banco, dotnet, dominio]
---
# Migrations no Solar

## O que é, no recorte daqui

Cada mudança nas entidades do `solar-ai-api` vira um arquivo C# versionado que sabe **subir** (`Up`) e **descer** (`Down`) o schema. O banco não é criado à mão em lugar nenhum: nem no compose, nem no S-26.

O card S-10 escreveu isso no contexto de retomada — *"aprender migrations aqui de verdade: é o que salva o deploy da Fase 6"*. É literal: sem migration, publicar significa abrir o Postgres gerenciado e rodar DDL na mão, com o relógio da entrega correndo.

## Os três comandos

```powershell
# criar uma migration depois de mexer nas entidades
dotnet ef migrations add <Nome> --project src/Solar.Api/Solar.Api.csproj --output-dir Persistencia/Migrations

# ver o SQL que ela vai rodar, sem rodar
dotnet ef migrations script --project src/Solar.Api/Solar.Api.csproj

# aplicar (raramente necessario -- a API aplica no boot)
dotnet ef database update --project src/Solar.Api/Solar.Api.csproj
```

A ferramenta é global e precisa acompanhar a versão do EF Core: com pacotes 10.x, `dotnet ef` 9.x não serve. `dotnet tool update --global dotnet-ef`.

## Três armadilhas que já custaram tempo

### `migrations add` não abre conexão; `migrations remove` abre

Gerar uma migration é trabalho de metamodelo — o EF compara o snapshot com as entidades e escreve o arquivo, sem tocar o banco. Já o `remove` **conecta**, para saber se a migration foi aplicada. Com o Postgres fora, ele falha com `Failed to connect to 127.0.0.1:5432` e deixa os arquivos no lugar. Migration ainda não aplicada em banco nenhum: apagar a pasta `Persistencia/Migrations` e refazer é seguro e mais rápido.

### O `dotnet ef` roda fora da aplicação

Ele não tem as variáveis do compose, e o `Program.cs` do Solar **falha de propósito** quando a `ConnectionStrings__Postgres` não existe. Sem uma ponte, nenhum comando de migration funcionaria fora do container.

A ponte é o `SolarDbContextFactory : IDesignTimeDbContextFactory<SolarDbContext>`. Ele lê a variável de ambiente se ela existir e, se não, usa uma string de projeto sem senha — suficiente para o EF saber que o provider é o Postgres e gerar o SQL certo.

### Conferir o nome das constraints antes de commitar

O `OnModelCreating` do Solar renomeia tudo para snake_case percorrendo o metamodelo. Uma versão ingênua dessa função transforma `PK_Leads` em `p_k_leads` — e o erro só aparece **na migration gerada**, não no build. Ler o arquivo antes de commitar é barato; corrigir depois de aplicado em produção não é.

## Aplicação no boot

`MigracaoDoBanco.AplicarAsync` roda antes do `app.Run()` e aplica o que estiver pendente. Cinco tentativas de 2 s, porque em cloud não existe o `healthcheck` do compose entre o banco e a API. Falhou nas cinco, a aplicação não sobe.

Isso funciona porque o deploy roda com **instância única** (ver [[Decisao - Persistencia em EF Core com Postgres]]). Várias instâncias subindo juntas disputariam a mesma migration.

## Onde isso encosta

[[Decisao - Persistencia em EF Core com Postgres]] · [[Decisao - Ambiente local em Docker Compose]] · [[Direito de eliminacao]] (S-29 apaga linhas que só existem porque há schema) · [[Multi-repo e CI-CD]] (o pipeline do S-27 roda contra o mesmo `compose.yml`)
