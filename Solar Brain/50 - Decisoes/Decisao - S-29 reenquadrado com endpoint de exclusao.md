---
tipo: decisao
data: 2026-08-31
status: vigente
tags: [decisao, privacidade, fase5, backlog]
---
# Decisão — S-29 reenquadrado: `Could`/Fase 6 → `Should`/Fase 4

## Problema

O S-29 estava em `Could`, na Fase 6, dependendo do deploy (S-26). Com isso, ele só aconteceria se tudo desse certo — e [[Direito de eliminacao]] é a peça de LGPD mais demonstrável que o projeto tem.

Além disso, a dependência estava errada: **o endpoint existe em local**, não precisa de deploy.

## Decisão

S-29 vira `Should`, na **Fase 4**, dependendo só do **S-10**. E passa a incluir explicitamente o **endpoint de exclusão dos dados do lead**.

## Motivo

O direito de eliminação é a parte da [[LGPD e GDPR]] que se demonstra ao vivo no vídeo em **vinte segundos**: pede exclusão, mostra a base vazia, acabou.

E a dependência de S-26 não tinha razão técnica nenhuma — era acoplamento acidental no board.

## Custo aceito

Nenhum incremental: o card já existia. O que mudou foi quando ele acontece e do que ele depende.

## Nota sobre a ordem de corte

Continua sendo o **último** da ordem de corte do [[Orcamento de esforco]] — o que significa que, na prática, ele agora acontece.

## Conceitos

[[Direito de eliminacao]] · [[LGPD e GDPR]] · [[Orcamento de esforco]]

## Relacionadas

- [[Decisao - Camada minima de privacidade como Must]]
