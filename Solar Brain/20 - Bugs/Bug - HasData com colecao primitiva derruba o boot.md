---
tipo: bug
tags: [bug, dominio, migrations, dotnet]
---
# Bug — `HasData` com coleção primitiva derruba o boot, e o log culpa o banco

## Sintoma

No S-37, a API subia, logava `Aplicando 1 migration(s): ...CorretorEncaminhamentoContatoDoLead` e morria. O banco ficava com as **duas** migrations antigas, sem `corretores` nem `encaminhamentos`, e o `psql` respondia `relation "corretores" does not exist`.

O log dizia, quatro vezes: **`Banco indisponivel na tentativa N/5: InvalidOperationException`**. O Postgres estava `healthy` o tempo todo.

## Causa raiz

O seed dos 5 corretores foi escrito com `HasData` no `OnModelCreating`, e `Corretor.Regioes` é `List<string>` (mapeado para `text[]`). Cada build do modelo criava uma **instância nova** da lista, e o EF concluiu que o modelo muda a cada construção:

> `PendingModelChangesWarning`: The model for context 'SolarDbContext' changes each time it is built. This is usually caused by dynamic values used in a 'HasData' call.

Esse aviso é promovido a exceção, e ela estourava **dentro** do `MigrateAsync`.

## O que custou tempo, e é o achado que vale

O `MigracaoDoBanco` captura `Exception` genérica e loga só `erro.GetType().Name` — de propósito, porque a mensagem do Npgsql pode carregar a connection string com a senha. O efeito colateral: **qualquer** falha de migration se disfarça de indisponibilidade do banco, com a palavra errada no log e 4 tentativas × 2s de espera antes de o erro real aparecer, lá no fim, como `Unhandled exception`. A primeira hipótese foi banco fora, e ela era falsa.

## Solução

O seed saiu do modelo e virou `migrationBuilder.InsertData` literal **dentro da migration**, com `DeleteData` no `Down`. É o que o card do S-37 já pedia ("seed de 5 por migration"), e tem uma razão própria: seed que lê código da aplicação muda de resultado quando o código muda; migration é histórico e precisa ser imutável.

Sem `HasData`, o modelo não tem dado nenhum e o aviso não existe.

## Como não cair de novo

- **Coleção primitiva (`List<string>`, `string[]`) não vai em `HasData`.** Se o seed é literal, ele mora na migration.
- **`Aplicando N migration(s)` não significa que aplicou.** A confirmação é `Banco em dia.` na linha seguinte, e o `select "MigrationId" from "__EFMigrationsHistory"`.
- **`Banco indisponivel` no log do boot já não mente** — corrigido em 09/09, na mesma sessão. `MigracaoDoBanco.EhIndisponibilidade` separa o transitório (`NpgsqlException.IsTransient`, `SocketException`, `TimeoutException`, inclusive embrulhados em outra exceção) do resto: indisponibilidade mantém as 5 tentativas e o log só do tipo, para a senha não vazar; **qualquer outra falha aborta na primeira tentativa**, com `LogCritical` dizendo tipo e mensagem. Cinco casos no xUnit guardam a separação.

## Relacionadas

- [[Migrations no Solar]] — o schema é migration versionada, aplicada no boot
- [[Decisao - Encaminhamento ao corretor com contato fora do LLM]] — o card em que isso apareceu
- [[Decisao - Persistencia em EF Core com Postgres]] — o EF Core e o boot que aplica o pendente
- [[Bug - libgssapi no log da API]] — o outro caso de linha de log que aponta para o lugar errado no boot
