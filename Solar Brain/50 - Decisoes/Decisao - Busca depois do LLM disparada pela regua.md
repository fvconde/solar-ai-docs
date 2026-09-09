---
tipo: decisao
data: 2026-09-09
status: vigente
tags: [decisao, ia]
---
# Decisão — A busca roda depois do LLM, e quem dispara é a régua

## Problema

O S-15 precisava decidir **onde** no grafo da Lia a busca de imóveis entra. O caminho intuitivo é buscar antes de gerar a resposta, como faz todo tutorial de [[RAG]]: recupera, injeta no prompt, responde numa chamada só.

Esse caminho quebra aqui por duas razões que se somam.

**A primeira é o filtro duro.** O card pede busca híbrida: preço, quartos e região são restrições que não podem ser violadas. Elas vêm do `PerfilLead` — e o perfil só incorpora a mensagem do turno **depois** que o LLM extrai os campos dela. Buscar antes significaria filtrar com o perfil de ontem. Na própria frase do critério de aceite — *"Quero apartamento de 2 quartos na zona sul até 600 mil"* — os três critérios chegam todos de uma vez, no primeiro turno, com o perfil ainda vazio.

**A segunda é o achado do S-12**, e é a mais traiçoeira: o nó qualificador monta as lacunas **antes** da mensagem do turno, então o turno que *fecha* o piso de qualificação sempre o vê aberto. Verificado ao vivo neste card: com o perfil fechando em `intencao`, `regiao` e `preco` na mesma frase, a Lia devolveu `continuar_conversa` e perguntou de novo pela intenção que ela acabara de extrair. Quatro variações de texto de prompt não resolveriam — é limitação estrutural, não redação.

## Decisão

O grafo ganhou dois nós **depois** de `pontuar`:

```
qualificar → responder → pontuar ─┬→ consultar → apresentar → END
                                  └→ END
```

`consultar` busca com o perfil **já fundido**. `apresentar` gasta uma **segunda chamada** ao LLM para escrever a fala com os imóveis na mão e o `motivo` de cada cartão.

E o gatilho tem duas portas:

1. o modelo devolve `proximaAcao: sugerir_imoveis` — o caminho normal, quando o lead pede opções;
2. **a régua percebe que este turno fechou os essenciais** — `_fechou_os_essenciais_agora`, que compara `lacunas_essenciais` do perfil de entrada com as do perfil fundido.

Desfecho explícito do modelo (`agendar_reuniao`, `direcionar_especialista`, `encerrar`) ganha das duas: encaminhar para gente de verdade é decisão da conversa, não do perfil.

## Motivo

A [[Regua de qualificacao]] já é a fonte determinística de "quanto vale este lead" e "o que perguntar agora" desde o S-12. Ela sabe, depois de fundir, exatamente o que o modelo não pode saber antes de ler a mensagem. Usar a mesma tabela como gatilho não acrescenta conceito novo ao projeto — acrescenta uma terceira pergunta à estrutura que já responde as outras duas, e de graça, sem chamada extra.

## Custo aceito

**Turno que sugere custa 2 chamadas de geração e 1 embedding.** Turno comum continua custando 1 chamada e nenhum embedding.

Por isso a régua só dispara no **instante da virada**, e não sempre que o perfil está completo: sem essa trava, toda conversa já qualificada passaria a custar o dobro por mensagem, e a cota diária de 500 do [[Gemini free tier]] não paga isso.

## Verificado

Ponta a ponta pela API, 09/09: `POST /conversas/{guid}/mensagens` com a frase do aceite devolveu **200 em 3,6 s** com dois apartamentos e o perfil em score 75.

## Conceitos

[[RAG]] · [[Regua de qualificacao]] · [[LangGraph]] · [[Indice vetorial em memoria]] · [[Gemini free tier]]

## Relacionadas

- [[Decisao - Score por regua deterministica]] — a mesma tabela, a terceira pergunta
- [[Decisao - Um no com saida estruturada]] — o desenho de uma chamada por turno, que esta decisão flexibiliza pela primeira vez
- [[Decisao - Motivo do LLM como portao do cartao]]
- [[Decisao - Tipo de imovel como filtro derivado do texto]]
- [[Decisao - Indice vetorial em memoria]]
