---
tipo: decisao
data: 2026-09-10
status: vigente
tags: [decisao, seguranca, git, credenciais, s-29]
---
# Decisão — Aceitar resíduo de commit órfão no GitHub após rotação da credencial

## Problema

Durante o S-29, uma credencial real do PostgreSQL de desenvolvimento — mantida fora do versionamento pelo `.gitignore` — foi gravada em código num arquivo de teste e publicada num repositório **público**. A remediação reescreveu o histórico de `feature/S-29` e republicou a branch consolidada em um único commit limpo.

Reescrever o histórico, porém, **não apaga o objeto do lado do GitHub**. Verificou-se em 10/09/2026 que o commit desvinculado continua sendo servido: uma consulta à API pelo SHA completo devolve o arquivo com a credencial legível. E o SHA não é obscuro — está citado no registro de execução do card e em comentários do PR, ambos públicos.

Restavam duas saídas: solicitar purga formal ao suporte do GitHub, ou aceitar o resíduo.

## Decisão

**Aceitar o resíduo, sem abrir chamado ao suporte do GitHub.**

O fundamento é que o material exposto é uma **credencial morta**. A senha foi rotacionada via `ALTER USER` no container `solar-postgres-1`, preservando o volume de dados, e a rotação foi comprovada: a senha antiga é recusada com `password authentication failed` e a nova autentica.

Essa verificação precisa ser feita **de fora do container**, pela porta publicada. Um teste executado de dentro do container não vale: o `pg_hba.conf` gerado pela imagem oficial confia em conexões vindas de `127.0.0.1` e aceita qualquer senha, produzindo um falso positivo — engano cometido e corrigido durante a própria revisão.

## Consequências

- Vale para **este caso**, em que a exposição é de credencial já invalidada. Não estabelece que reescrever histórico seja remediação suficiente em geral.
- Afirmações do tipo "zero credenciais em commits" ficam **proibidas** para esta entrega. A formulação correta é: *a credencial exposta foi rotacionada e está inválida; o objeto órfão permanece acessível no GitHub*.
- Se a política mudar e a purga passar a ser exigida, o caminho é solicitação formal ao suporte. Reescrever o histórico de novo não remove um objeto já desvinculado.
- Reforça a regra que já valia: connection string vem de variável de ambiente ou do `.env` ignorado pelo git, nunca de literal em código. Ver [[Decisao - Banco de testes dedicado solar_test e CI]].

## Conceitos

[[LGPD e GDPR]] · [[Direito de eliminacao]]
