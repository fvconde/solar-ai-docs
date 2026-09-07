---
tipo: decisao
data: 2026-09-07
status: vigente
tags: [decisao, dominio, dotnet, banco]
---
# Decisão — Persistência em EF Core: Lead, Conversa, Mensagem

Emenda a [[Decisao - Conversa em memoria com turno serializado]], que previa esta troca no S-10. O que aquela nota decidiu sobre **semântica** — quem funde o perfil, como o histórico é montado, turnos serializados — continua valendo inteiro. O que muda é onde o estado mora.

## Problema

O `ConversaStore` era um `ConcurrentDictionary`. A conversa morria com o processo, e três cards dependiam disso mudar: S-12 (qualificador), S-19 (dashboard) e S-29 (exclusão do lead) não têm o que ler nem o que apagar sem banco.

## Decisão

### Três tabelas, e uma delas não é a conversa

`PerfilLead` era um record dentro da `Conversa`. Vira tabela **própria**: o `Lead` é o que o S-19 conta no dashboard e o que o S-29 apaga, e nenhum dos dois quer ir buscar isso dentro de uma conversa. A `Conversa` liga o lead a um **canal** (`web` por padrão, `telegram` no S-25) e a `Mensagem` guarda papel, texto e carimbo.

O `PerfilLead` do contrato continua existindo, agora como projeção: `Lead.ParaContrato()`. A entidade não vaza para o OpenAPI — conferido, a API publica os mesmos 12 schemas de antes.

### A mensagem tem `bigint` identity, e não `Guid`

As duas mensagens de um turno são gravadas com o **mesmo** `DateTimeOffset`. Ordenar por carimbo de tempo empata, e empate em ordem de conversa significa a fala da Lia aparecer antes da pergunta do lead. O sequencial do banco desempata e dá ordem estável. Confirmado no banco: `em` idêntico nas linhas 1 e 2, e nas 3 e 4.

O `Lead`, esse sim, é `Guid` — mas **UUIDv7**, ordenado no tempo, para as chaves novas caírem juntas no índice em vez de espalhar escrita por todas as páginas.

### snake_case escrito à mão, sem pacote de convenção

O EF nomearia `Conversas.PrecoMax`, e o Postgres exige aspas para ler identificador com maiúscula: `select * from "Conversas"` funciona, `select * from Conversas` não. Quinze linhas percorrendo o metamodelo no `OnModelCreating` resolvem isso sem uma dependência a mais. O corte respeita sigla: `PK_Leads` vira `pk_leads`, não `p_k_leads`.

### A trava **não** virou transação — e isso corrige a nota anterior

A [[Decisao - Conversa em memoria com turno serializado]] escreveu que no S-10 "a trava por conversa vira transação". Está errado, e o motivo aparece quando se olha o relógio: entre ler o histórico e gravar o turno há uma chamada ao agente que leva de 0,8 s a **45 s**. Transação aberta esse tempo todo segura uma conexão do pool por turno — o banco esgota muito antes do Gemini.

Então: o `SemaphoreSlim` por conversa **fica**, serializando os três passos; a transação é só o `SaveChangesAsync` final, que o EF já envolve sozinho. O que a trava protege não é a escrita — é a janela entre a leitura e a escrita.

Custo real e registrado: a trava vale **dentro de um processo**. Com mais de uma instância da API ela deixa de proteger, e o substituto é `pg_advisory_xact_lock` no Postgres. Até o S-26 o deploy roda com instância única.

### Turno que falha não deixa rastro — agora de verdade

Em memória, `ObterOuCriar` já criava a conversa antes de o agente responder: turno falho deixava uma conversa vazia para trás. Com o EF, `ObterOuCriarAsync` só chama `Add` — a conversa fica **rastreada e não gravada**, e quem a leva ao banco é o mesmo `SaveChangesAsync` das mensagens.

Verificado com o agente parado: `POST` numa conversa nova devolve 502 e o banco continua com as mesmas 2 conversas, 2 leads e 10 mensagens de antes. Zero linhas.

### Migrations aplicadas no boot

`MigracaoDoBanco.AplicarAsync` roda antes do `app.Run()`, com cinco tentativas espaçadas de 2 s. Sem isso, `docker compose up` subiria a API contra um banco sem schema, e o S-26 exigiria um passo manual no deploy.

Falhou nas cinco, a aplicação **não sobe**. API de pé com schema velho é pior que API fora: ela responde 200 no `/health` e 500 no primeiro turno.

O log de migração nunca imprime a exceção inteira — a mensagem do Npgsql carrega a connection string, e a connection string carrega a senha.

## Custo aceito

- **`dotnet run` local agora exige `ConnectionStrings__Postgres` no ambiente.** Antes a API subia sem banco e o `/health` acusava. Agora falha no boot, de propósito: sem banco ela não tem o que fazer, e 500 no primeiro turno esconderia erro de ambiente.
- O `dotnet ef` precisa de um `IDesignTimeDbContextFactory`, porque ele roda fora da aplicação e não tem as variáveis do compose. Ver [[Migrations no Solar]].
- Uma conversa = um lead. Reconhecer o mesmo lead em duas conversas fica fora do escopo.
- O `canal` não vem da requisição — é `web` fixo até o S-25. Acrescentar campo no `NovaMensagemRequest` agora só criaria superfície sem uso.

## Verificado em 07/09

Ambiente completo de pé, banco zerado. Migration aplicada no primeiro boot (`Aplicando 1 migration(s)`), `Banco em dia.` nos seguintes. Conversa de 3 turnos acumulou o perfil com os **mesmos números do S-07** — score 30 → 50 → 65, nada re-perguntado —, agora lendo o histórico do Postgres. `docker restart` na API: a conversa voltou inteira, com perfil e 4 mensagens. O turno que tinha falhado por cota, reenviado depois do restart, fechou em 6 mensagens.

Dois `POST` simultâneos na mesma conversa: 1,3 s e 2,1 s, histórico alternando certo, o segundo enxergando o perfil do primeiro. 404 para conversa inexistente, 400 para mensagem vazia e para campo desconhecido — e nenhum deles cria linha. Postgres parado: `/health` devolve `down` + **503** com o motivo. Espelho do contrato conferido de novo: **6 tipos, 37 campos, íntegro**.

O SQL da janela de histórico foi lido no log: `SELECT m.papel, m.texto, m.em FROM mensagens ... ORDER BY m.id DESC LIMIT @p`. Três colunas e o `LIMIT` no banco — em memória isso era uma fatia de lista, e sem o `Take` uma conversa longa carregaria o histórico inteiro a cada turno só para descartar quase tudo.

## Conceitos

[[Migrations no Solar]] · [[Qualificacao de leads]] · [[Agente stateless]] · [[Direito de eliminacao]]

## Relacionadas

- [[Decisao - Conversa em memoria com turno serializado]] — a nota que esta emenda
- [[Decisao - NET 10 com controllers]]
- [[Decisao - Ambiente local em Docker Compose]]
- [[Decisao - S-29 reenquadrado com endpoint de exclusao]]
- [[Bug - libgssapi no log da API]]
