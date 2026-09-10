---
tipo: decisao
data: 2026-09-10
status: vigente
tags: [decisao, seguranca, lgpd, painel, s-20, s-29]
---
# Decisão — Uma chave única governa a exclusão LGPD e o painel do corretor

## Problema

O S-29 criou `AutorizacaoPrivacidade`, que lê `Seguranca:ChavePrivacidade` do ambiente, recusa a operação com 503 quando a chave não está configurada e protege os endpoints de exclusão.

O S-20 nasceu com um gate próprio e mais fraco: `GET /painel/corretores` era aberto e distribuía os ids que `GET /painel/leads` aceitava como credencial única. Duas requisições anônimas liam a base inteira de leads, com telefone e e-mail. Na revisão, a recomendação foi reaproveitar o mecanismo do S-29 em vez de inventar um segundo.

## Decisão

**Os endpoints do painel passam a exigir a mesma chave de privacidade da exclusão.** O `X-Corretor-Id` continua existindo, mas deixou de ser credencial: serve para saber *qual* corretor está logado e aplicar o filtro "meus leads".

Junto vieram duas medidas que o mesmo card endereçou: a fila deixou de trafegar telefone e e-mail — contato fica para o detalhe do lead, no S-21 —, e os endpoints ganharam política própria de rate limit.

## Consequência assumida, e ela não é pequena

**Quem recebe a chave para ver a fila também pode eliminar qualquer lead.** É a mesma chave, validada pelo mesmo código, e não há níveis. Na prática, dar acesso ao painel para um corretor concede a ele um poder destrutivo que o painel não expõe em tela nenhuma.

Aceito para a POC por três motivos: a alternativa exigiria papéis e um segundo segredo, o que é desproporcional ao prazo; a superfície é interna, sem cadastro público de corretores; e o mecanismo unificado é claramente melhor que os dois anteriores, um deles sem proteção alguma.

**O que fazer se sobrar tempo:** separar em duas chaves — uma de leitura para o painel, outra de eliminação —, ou introduzir um nível no próprio `AutorizacaoPrivacidade`. Não exige mudar o formato dos cabeçalhos.

Registrado aqui porque, sem este texto, a consequência ficaria como efeito colateral de uma recomendação de revisão em vez de escolha consciente. Ver [[Decisao - Aceitar residuo de commit orfao apos rotacao]].

## Conceitos

[[LGPD e GDPR]] · [[Direito de eliminacao]]
