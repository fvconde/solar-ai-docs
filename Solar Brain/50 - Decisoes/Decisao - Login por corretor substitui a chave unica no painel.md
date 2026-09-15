---
tipo: decisao
data: 2026-09-15
status: vigente
tags: [decisao, seguranca, lgpd, painel, autenticacao, s-42]
---
# Decisão — Login por corretor substitui a chave única no painel

Revoga [[Decisao - Uma chave unica para privacidade e painel]], de 10/09, que registrava a consequência que este card veio desfazer.

## Problema

A decisão de 10/09 unificou o gate do painel com o da exclusão LGPD, e assumiu por escrito a consequência: **quem recebia a chave para ver a fila também podia eliminar qualquer lead.** Mesma chave, mesmo código, sem níveis. Aquela nota já previa o conserto — "separar em duas chaves, ou introduzir um nível no próprio `AutorizacaoPrivacidade`".

O S-42 escolheu um caminho diferente dos dois previstos, porque o problema tinha uma segunda metade que a nota de 10/09 não endereçava: **o `X-Corretor-Id` era identidade declarada, não provada.** Qualquer cliente que tivesse a chave podia afirmar ser qualquer corretor e receber o filtro "meus leads" dele. E o Angular listava todos os corretores e autenticava qualquer perfil por clique.

## Decisão

**Os endpoints do painel passam a exigir autenticação individual por corretor, com senha e sessão própria. A chave de privacidade deixa de abrir o painel.**

- `Seguranca:ChavePrivacidade` sobrevive **exclusivamente** para o que é destrutivo: `DELETE /leads` e `DELETE /conversas`. Ela nunca chega ao navegador do corretor.
- O `corretorId` sai do claim da sessão, não de cabeçalho. `X-Corretor-Id` deixou de existir no contrato.
- `GET /painel/corretores` foi removido: ele só servia à grade de seleção insegura.
- Senha por `PasswordHasher<Corretor>` em `IdentityV3`, 220.000 iterações, nunca em texto claro. Sessão por cookie opaco `HttpOnly`/`SameSite=Strict`, com apenas o SHA-256 do token no banco.

O caminho "duas chaves" que a nota antiga previa resolveria o privilégio destrutivo, mas não a personificação — continuaria sendo um segredo compartilhado sem identidade. Login resolve os dois de uma vez.

## O que veio do handoff de design, e não da engenharia

A forma do fluxo foi decidida no board de design `Solar corretor Login - Handoff v1.0`, e o usuário determinou que **onde o handoff divergisse do critério de aceite do card, valeria o handoff**. Isso cortou coisas que o plano técnico tinha: o convite administrativo de primeiro acesso e a sessão de 8 horas.

O que ficou no lugar: e-mail primeiro e senha depois; e-mail desconhecido leva a "um especialista entra em contato", sem autocadastro; corretor semeado define a própria senha pelo fluxo de redefinição, sem senha padrão em lugar nenhum; bloqueio de cinco tentativas por trinta segundos.

## Consequências assumidas, e elas são explícitas

Registradas aqui porque foram **escolhas conscientes do usuário**, feitas depois de aviso por escrito, e não descuido:

- **A sessão não expira.** Cookie com `max-age` de dez anos, por dispositivo. O handoff trata isso como característica, não lacuna.
- **Não há logout.** Também decisão do handoff. `DELETE /painel/sessao` não existe nesta rodada, então uma sessão só morre por revogação no servidor — que acontece ao redefinir a senha.
- **`POST /painel/identificacao` revela se um e-mail existe no cadastro**, por desenho: as telas 2 e 3 são visivelmente diferentes. Mitigado só por rate limit. Em compensação, a tela de "link enviado" usa a mesma frase exista ou não o e-mail, então a recuperação não vaza.
- **Sem MFA**, e **o corretor autenticado continua vendo todos os leads** — RBAC por dono segue sendo decisão de produto separada, como já era antes deste card.

## O que este card não resolveu

A API e a rota do SPA disputam o namespace `/painel`. Foi contornado no proxy do servidor de desenvolvimento, mapeando só os cinco endpoints reais, mas **quem configurar o reverse proxy em produção esbarra no mesmo conflito**. A correção de fundo é prefixar a API com `/api`, que é mudança de contrato e não cabia aqui.

## Conceitos

[[LGPD e GDPR]] · [[Direito de eliminacao]]
