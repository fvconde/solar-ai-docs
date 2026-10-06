---
tipo: bug
tags: [bug, api, encaminhamento, corretor]
---
# Bug — a redistribuição reescolhia o corretor que estava excluindo a própria conta

## Sintoma

Um corretor aprovado excluía a própria conta e a API respondia `204`. A conta sumia. No painel do supervisor, a conversa que era dele aparecia **sem corretor**, mas ainda com status `atribuido`, em vez de ir para outro corretor elegível ou ficar `aguardando`.

Veio à tona no teste de ponta a ponta do S-45, em 05/10, e virou o S-46.

## Causa

`EncaminhamentoRepositorio.RedistribuirAsync` desatribui as conversas do corretor e escolhe de novo entre os candidatos de `CandidatosAsync`. A consulta de candidatos **não excluía o próprio corretor de origem**. Ele continuava aprovado e, depois da desatribuição, com carga zero, então a regra de menor carga tendia a escolhê-lo de volta. Logo em seguida, `ContasController` removia a conta na mesma transação, e o encaminhamento ficava apontando para ninguém, com o status de atribuído.

O teste do S-46 observou o `corretor_id` nulo depois do `DELETE`, mesmo com a FK configurada como `Restrict`. **O mecanismo que zera a coluna não foi investigado**, porque o card corrigiu a causa (a reescolha) e não a FK.

## A hipótese que errou

Ao propor o card, o Maestro leu `DeleteBehavior.Restrict` em `SolarDbContext` e previu que a remoção da conta falharia por violação de FK, com erro `500` e rollback. O teste vermelho mostrou o contrário: `204` e estado incoerente, como o card original descrevia. A previsão foi feita lendo a configuração; o teste rodou contra o Postgres real.

## Solução

`CandidatosAsync` ganhou o parâmetro opcional `corretorOrigemId`, que `RedistribuirAsync` passa para a consulta excluir a origem antes da escolha. A ordem da regra não mudou, e `DecidirAsync`, que não passa o parâmetro, segue igual. Sem outro elegível, a conversa fica `aguardando`. Quatro testes contra Postgres cobrem a reescolha, a exclusão com dois corretores, a exclusão com um só e a recusa pelo supervisor.

## A lição

> **A configuração do EF não diz o que o banco faz numa transação inteira. Teste vermelho contra o Postgres antes de prever o sintoma.**

## Relacionadas

- [[Decisao - Encaminhamento ao corretor com contato fora do LLM]]: onde nasceram a escolha de corretor e a FK `Restrict`.
- [[Decisao - Login unico com tres papeis e sessao de 30 dias]]: o S-44, que criou a exclusão da própria conta.
- [[Decisao - Marcos imutaveis e inicio do registro gravado pela migration]]: o S-45, cujo teste revelou o bug e cujo marco a correção preserva.
- [[Bug - teste de reset ordenava sessoes por horario empatado]]: o teste de autenticação que a validação do S-46 chamou de instável; a causa veio no S-27.
