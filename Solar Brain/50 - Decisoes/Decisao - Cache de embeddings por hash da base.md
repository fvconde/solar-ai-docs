---
tipo: decisao
data: 2026-09-08
status: vigente
tags: [decisao, ia, infra, armadilha]
---
# Decisão — Cache de embeddings versionado, com hash da base

## Problema

O [[Indice vetorial em memoria]] é reconstruído no boot. Parecia barato: 80 imóveis numa única chamada `batchEmbedContents`, 2,7 s.

No S-14 o boot bateu `429` e trouxe o número que faltava: a cota de embedding do [[Gemini free tier]] é **100 por minuto** e conta **por conteúdo, não por requisição HTTP**. Um boot gasta 80 das 100. Dois boots no mesmo minuto — que é o padrão de `docker compose up --build`, ver o erro, subir de novo — dão `429`.

Isso encosta em três coisas de uma vez: o dia a dia de desenvolvimento, a iteração de prompt do S-15, e o deploy do S-26, onde cada réplica que sobe paga o pedágio e depende de rede para ficar de pé.

## Decisão

Os vetores ficam **versionados no repositório**, em `solar-ai/data/embeddings.json`, gerados por `scripts/gerar_embeddings.py`.

O boot lê o arquivo e só chama a API se ele **não confere**. Quatro checagens, cada uma com motivo próprio no log: modelo diferente do que o ambiente pede, dimensão diferente de 768, sha256 do corpus diferente, ou algum imóvel sem vetor.

O hash é do **texto que vai para o embedding** — cabeçalho estruturado mais a descrição —, não do arquivo JSON cru. Mudar `Imovel.texto` invalida o cache tão corretamente quanto mudar um imóvel, e é exatamente o que se quer: os vetores velhos deixariam de corresponder ao que a busca compara.

O boot **nunca escreve** o cache. Quem escreve é o script, à mão. Um boot que grava depende de sistema de arquivos gravável, que o container não tem por padrão — e falharia de um jeito que ninguém veria.

## Motivo

- O `Dockerfile` já copia `data/`, então o container sobe **sem rede e sem cota** de graça, sem mudar nada no build.
- 624 KB de JSON num repositório, para uma base estática de 80 imóveis, é preço baixo.
- Cache que se recusa sozinho quando a base muda não tem como envelhecer errado em silêncio — o modo de falha é "gastou cota à toa", nunca "respondeu com vetor velho".

## Custo aceito

- **Arquivo gerado dentro do git.** É artefato derivado, o que normalmente não se versiona. Aqui vale porque a origem é estática e o ganho é o boot offline.
- **Um passo manual a mais.** Mexeu em `data/imoveis.json` ou em `Imovel.texto`, rode `scripts/gerar_embeddings.py`. Esquecer não quebra nada: o boot volta a gastar cota e o log diz o motivo da recusa.
- Arredondamento em 6 casas decimais. Medido no S-14: o cosseno entre o vetor do cache e o vetor recém-gerado dá 1,0 dentro de 1e-4, e a ordenação não muda. Há teste ao vivo afirmando isso.

## Conceitos

[[Indice vetorial em memoria]] · [[Gemini free tier]] · [[RAG]] · [[Agente stateless]]

## Relacionadas

- [[Decisao - Indice vetorial em memoria]] — esta decisão não a revoga: o índice continua em memória e continua reconstruído no boot; muda só de onde vêm os vetores.
- [[Decisao - Modelo Gemini fixado sem alias]] — o nome do modelo entra no cache justamente porque trocá-lo troca os vetores.
