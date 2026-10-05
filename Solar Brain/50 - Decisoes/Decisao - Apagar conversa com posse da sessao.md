---
tipo: decisao
data: 2026-10-04
status: vigente
tags: [decisao, privacidade, lgpd, api, front]
---
# Decisão — O titular apaga a conversa com a posse da sessão, e só a conversa escolhida

## Problema

A página `/privacidade` prometia, desde o S-33, que o titular podia pedir a eliminação dos dados. O único caminho, porém, era humano: o corretor ou o atendimento acionava o endpoint administrativo, como decidido em 12/09. O S-38 precisava dar ao titular um caminho próprio. O obstáculo é que o chat não exige login, então não há identidade para verificar.

## Decisão

- **A prova é a posse da sessão (02/10).** No consentimento, a API emite uma chave aleatória de 32 bytes para a conversa anônima. A chave vai num cookie `HttpOnly`, com `SameSite=Strict` e `Path=/conversas/{id}`, e o banco guarda só o hash dela, em `conversas.chave_exclusao_hash`. Conversa com conta exige o login do dono, e o cookie não substitui esse login. O usuário não vê, não digita e não guarda chave nenhuma.
- **Uma ação, um limite (04/10).** "Apagar conversa" apaga a conversa provada, as mensagens e os encaminhamentos dela. O lead só sai junto quando aquela era a única conversa dele. A ação nunca apaga outra conversa, nem quando todas pertencem à mesma conta. Isso substituiu a regra anterior do S-38, que apagava o lead inteiro quando todas as conversas eram da conta dona.
- **Fluxo simples.** Botão no rodapé do composer e um modal curto com Cancelar e Apagar conversa. Não há caixa de seleção, e-mail, código nem link de recuperação.
- **Conversa antiga sem chave** continua pelo canal humano. A chave não é emitida para trás, porque quem tivesse só o UUID poderia pegá-la. O destino do legado fica para uma decisão de migração separada.
- **A versão do aviso de privacidade fica em 2026-09-11.** O texto novo só descreve um direito a mais. Trocar a versão obrigaria todos a aceitar de novo e recusaria navegadores antigos.

## Por quê

Quem tem a sessão já lê a conversa inteira na tela, então poder apagá-la não amplia o acesso dessa pessoa a nada. Apagar mais do que a conversa provada esbarrava na deduplicação por contato: conversas diferentes caem no mesmo lead quando o telefone ou o e-mail coincidem. Com a cascata, quem digitasse o telefone de outra pessoa poderia apagar a conversa dela.

## Custo aceito

- **Navegador compartilhado:** quem usa a mesma sessão do navegador também consegue apagar.
- **Dados que ficam:** cadastro e reserva compartilhados não são eliminados por esta ação. O restante segue pelo canal humano ou pela exclusão de conta.
- **Conversas antigas:** as que existiam antes do S-38 não têm o botão funcional.

## Relacionadas

- [[Decisao - S-29 reenquadrado com endpoint de exclusao]]: a cascata administrativa que esta ação reaproveita.
- [[Decisao - Login unico com tres papeis e sessao de 30 dias]]: a conversa com dono e a deduplicação por conta.
- [[Direito de eliminacao]]
