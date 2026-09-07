---
tipo: bug
tags: [bug, banco, docker, armadilha]
---
# Bug — `libgssapi_krb5.so.2` no log da API

> **Corrigido em 07/09**, no mesmo dia em que foi diagnosticado. A nota fica porque o diagnóstico é o que importa: o sintoma parece falha de banco e não é, e quem reencontrar isso em outra imagem .NET vai precisar deste raciocínio.

## Sintoma

Toda vez que a API abria a **primeira** conexão com o Postgres, o log do container cuspia duas linhas, sem prefixo de nível e sem categoria:

```
Cannot load library libgssapi_krb5.so.2
Error: libgssapi_krb5.so.2: cannot open shared object file: No such file or directory
```

No primeiro boot de um banco vazio elas apareciam coladas num `fail:` do EF, o que piorava a leitura:

```
fail: Microsoft.EntityFrameworkCore.Database.Command[20102]
      Failed executing DbCommand ... SELECT "MigrationId" FROM "__EFMigrationsHistory"
```

## Por que não era falha

São **dois** eventos independentes que o Docker interleava, e nenhum dos dois era erro:

1. O `fail:` do EF é a sondagem normal da tabela `__EFMigrationsHistory` num banco que ainda não a tem. Some no segundo boot — no banco já migrado o log mostra `Executed DbCommand` seguido de `Banco em dia.` Este continua acontecendo, e **está certo que aconteça**.
2. As linhas do `libgssapi` eram do **Npgsql**, escritas direto em stderr e não pelo logger, ao sondar a biblioteca de Kerberos na imagem `mcr.microsoft.com/dotnet/aspnet:10.0`. Ela não existe lá. O Solar autentica no Postgres por senha, então a biblioteca nunca seria usada; o Npgsql seguia e conectava.

Foi isso que tornou o diagnóstico chato: uma linha em stderr, sem timestamp e sem nível, aparecendo no meio de um stack trace de `System.Net.Http` que era de outro teste — o do agente parado. Log interleavado faz dois problemas parecerem um.

A prova de que não afetava nada: o `/health` respondia `up` na mesma requisição, a migration aplicava, e os turnos gravavam.

## Correção

Instalar a biblioteca na etapa de runtime do `Dockerfile` do `solar-ai-api`, **antes** do `USER $APP_UID` — `apt` precisa de root:

```dockerfile
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgssapi-krb5-2 \
    && rm -rf /var/lib/apt/lists/*
```

O `--no-install-recommends` e o `rm` do cache do apt são o que mantêm o custo em cerca de 1 MB. Imagem final: **356 MB**.

Verificado com `docker compose down -v` e `up --build`: zero ocorrências de `gssapi` no log, `/health` em `up`, turno completo gravando, e o segundo boot com log inteiramente limpo — nenhum `fail:`, nenhuma linha órfã em stderr.

## Como confirmar em dez segundos, se voltar

```powershell
(Invoke-WebRequest http://localhost:8080/health -UseBasicParsing).Content
```

`"status":"up"` com `"postgres":{"status":"up"}` encerra o assunto. Se o banco estivesse de fato inalcançável, viria `down` + **503** com o motivo no corpo.

## Anterior ao S-10

Já aparecia desde o S-02, quando o `/health` abria uma `NpgsqlConnection` crua. O S-10 trocou isso pelo `DbContext`, mas a origem era a mesma — não foi o EF Core que trouxe.

## Relacionadas

- [[Decisao - Persistencia em EF Core com Postgres]]
- [[Decisao - Formato do payload do health check]]
- [[Decisao - Ambiente local em Docker Compose]]
- [[Bug - latencia de 30s por limite por minuto]] — a outra armadilha de log deste projeto: lá o sucesso mentia, aqui era o erro que mentia
