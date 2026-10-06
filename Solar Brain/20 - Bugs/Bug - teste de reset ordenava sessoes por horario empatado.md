---
tipo: bug
tags: [bug, testes, api, postgres, ci, autenticacao]
---
# Bug — o teste de redefinição de senha ordenava sessões por um horário empatado

## Sintoma

`AutenticacaoPainelPostgresTeste.Postgres_reset_consume_token_revoga_sessoes_anteriores_e_cria_nova_sessao` falhava às vezes na máquina local, e passava ao rodar isolado. No S-46 ele foi registrado como "instável" e deixado de lado. No primeiro CI do GitHub (S-27, 05/10), falhou nas **três** tentativas, sempre em `Assert.NotNull(sessoes[0].RevogadaEm)`. Com isso, o pipeline barraria toda publicação.

## Causa

O teste usa um `RelogioFixo`, que sempre devolve o mesmo instante. A sessão do login e a sessão criada pela redefinição nascem com o **mesmo `CriadaEm`**. O teste ordenava as duas por `CriadaEm` e esperava a antiga na posição 0. Com empate, o Postgres devolve as linhas **em qualquer ordem**: na máquina local a ordem costumava sair certa, e no runner do GitHub saía trocada.

O código da API estava certo. O erro estava na asserção.

## Solução

O teste guarda o `Id` da sessão logo depois do login, consulta as sessões sem `OrderBy` e exige três coisas: exatamente uma revogada, exatamente uma ativa, e a revogada com o `Id` original. A mudança foi de 5 linhas adicionadas e 3 removidas, só no teste, autorizada pelo usuário dentro do S-27. Depois dela, o CI passou 318/318 na primeira tentativa.

## A lição

> **"Instável" é um diagnóstico adiado. Um teste que passa sozinho e falha em outro ambiente quase sempre depende de uma ordem ou de um relógio que ninguém garantiu. Com relógio fixo, nunca ordene por horário.**

## Relacionadas

- [[Decisao - Login unico com tres papeis e sessao de 30 dias]]: onde nasceram as sessões e a redefinição de senha.
- [[Decisao - Publicacao da API pelo push na main]]: o pipeline cujo portão este teste travava.
- [[Bug - redistribuicao reescolhia o corretor que saia]]: o S-46, onde a falha foi chamada de instabilidade pela primeira vez.
