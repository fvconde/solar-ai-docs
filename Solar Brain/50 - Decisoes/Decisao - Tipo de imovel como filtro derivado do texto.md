---
tipo: decisao
data: 2026-09-09
status: vigente
tags: [decisao, ia, produto]
---
# Decisão — Tipo de imóvel é filtro duro derivado do texto, não campo do contrato

## Problema

O `Filtro` da busca recorta por preço, quartos e região — os campos que existem no `PerfilLead`. **`tipo` não existe lá.**

Na frase do próprio critério de aceite do S-15, isso aparece na tela. Dos 80 imóveis da base, exatamente **três** passam no filtro de *2 quartos, zona sul, até R$ 600.000 na venda* — e um deles é uma **casa**, para alguém que escreveu "quero apartamento". Verificado ao vivo: o cartão da casa apareceu no chat.

"Quero apartamento" é restrição dura tanto quanto "2 quartos". Devolver casa para quem pediu apartamento não é um resultado ruim de ranking — é a busca desobedecendo, e derruba a confiança no resto da lista.

## As três saídas, e por que esta

**Colocar `tipo` no `PerfilLead`** é a resposta certa e cara: o [[Contrato POST turn]] está congelado desde o S-05, mexer nele exige commit coordenado em dois repositórios, mais a entidade `Lead` e uma migration, mais o contrato do front. Uma a duas horas, num card `Should` de quatro, com a margem de tempo do projeto já fina.

**Deixar por conta do LLM**, pelo portão de [[Decisao - Motivo do LLM como portao do cartao]], é grátis e probabilístico — e falhou numa das rodadas de verificação.

**Derivar do texto** é o meio-termo: determinístico, testável de graça, sem tocar o contrato.

## Decisão

`indice.tipo_pedido(mensagem, historico)` lê o tipo que o lead nomeou, da fala mais recente para a mais antiga, e entra como campo do `Filtro`. Sinônimos mapeados: apto/apê → apartamento, sobrado → casa, kitnet/quitinete/estúdio → studio.

Palavra precedida de negação numa janela de três palavras **não conta** — é a mesma pedra do [[Bug - negacao extraida como preferencia]], que ali virava campo e aqui viraria filtro. "Qualquer coisa menos casa" não filtra casa.

Um teste afirma que os sinônimos cobrem **todo tipo presente na base real**: tipo novo em `imoveis.json` sem sinônimo aqui seria um imóvel que a busca nunca encontra.

## Custo aceito

É heurística de palavra, não campo de perfil. Ela não sobrevive a paráfrase — "um lugar para morar com a família" não diz tipo nenhum, e aí o filtro simplesmente não se aplica, que é o comportamento seguro.

**O campo de verdade fica para o S-35** (catálogo em pgvector), que já mexe no contrato por outros motivos. Quando ele chegar, `tipo_pedido` sai.

## Conceitos

[[RAG]] · [[Indice vetorial em memoria]] · [[Contrato POST turn]] · [[Qualificacao de leads]]

## Relacionadas

- [[Decisao - Busca depois do LLM disparada pela regua]]
- [[Decisao - Motivo do LLM como portao do cartao]]
- [[Decisao - Contrato do POST turn congelado]] — a decisão que torna esta necessária
- [[Bug - negacao extraida como preferencia]]
