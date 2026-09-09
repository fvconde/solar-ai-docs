---
tipo: decisao
data: 2026-09-09
status: vigente
tags: [decisao, ia, produto]
---
# Decisão — O motivo do LLM é o portão do cartão

## Problema

Cada `ImovelSugerido` carrega um campo `motivo`, que aparece dentro do cartão na tela do lead. Duas perguntas: quem escreve, e o que acontece quando a busca traz um imóvel que não deveria estar ali.

Escrever o motivo pela [[Regua de qualificacao]] seria determinístico e grátis — e diria a mesma frase em todos os cartões, trocando o bairro. Um motivo montado por template não é motivo: é rótulo.

## Decisão

O `motivo` é **texto do LLM**, escrito na segunda chamada do turno (ver [[Decisao - Busca depois do LLM disparada pela regua]]), e ele funciona como **portão**: o código só monta o cartão de um imóvel que a busca achou **e** o LLM justificou.

```
imóvel na busca + motivo do LLM  → vira cartão
imóvel na busca sem motivo       → não aparece
motivo de id que não veio da busca → ignorado
```

A ordem dos cartões é sempre a da busca, nunca a do LLM.

## Motivo

Um portão que já existia por outro caminho. Como o `motivo` é obrigatório e vem do modelo, a ausência dele é informação de graça: é o modelo dizendo que não conseguiu ligar aquele imóvel ao que a pessoa pediu. Aproveitar isso dá à Lia uma saída honesta — mostrar dois imóveis certos em vez de três com um errado — sem precisar de campo novo no contrato nem de mais uma chamada.

O inverso também importa: **inventar a justificativa no código seria fabricar exatamente a parte que o lead lê**. O cartão tem preço, metragem e bairro vindos da base, verificáveis; a frase é a única coisa ali que alguém escreveu. Ela precisa ter dono.

## Custo aceito

O portão é **probabilístico**. Verificado ao vivo: numa rodada o modelo omitiu o motivo de uma casa que a busca trouxe para quem pediu apartamento, e ela sumiu como projetado; noutra rodada ele escreveu motivo para a mesma casa, e ela apareceu na tela.

Foi por isso que o tipo virou filtro duro em [[Decisao - Tipo de imovel como filtro derivado do texto]]. **O portão é rede de segurança, não é o filtro.** Restrição que não pode ser violada é código; o portão pega o resto.

## Conceitos

[[RAG]] · [[Testar a Lia]] · [[Contrato POST turn]]

## Relacionadas

- [[Decisao - Busca depois do LLM disparada pela regua]]
- [[Decisao - Tipo de imovel como filtro derivado do texto]]
- [[Decisao - Score por regua deterministica]] — o que é da régua é da régua; o que é de fala é do modelo
