---
tipo: decisao
data: 2026-09-05
status: vigente
tags: [decisao, arquitetura, produto]
---
# Decisão — Vocabulário do contrato alinhado ao enunciado, não inventado

Emenda a [[Decisao - Contrato do POST turn congelado]]. O mecanismo de congelamento não muda; muda o conteúdo de dois vocabulários.

## Problema

O `proximaAcao` do S-05 foi desenhado a partir do que *parecia* fazer sentido para um SDR, não do que o enunciado pede. O resultado, achado ao reler o PDF inteiro:

**Um valor a mais que ninguém pediu.** `escalar_humano` — válvula de escape para "situação estranha" — não aparece em nenhuma das 7 páginas do enunciado. Todo SDR real tem, e é defensável no pitch, mas requisito não é. E requisito que não existe só pode custar: disparar errado tira ponto em "Qualidade das respostas" e "Contexto conversacional" (critérios literais, sob *Inteligência Artificial*) sem creditar nada em lugar nenhum.

**Duas lacunas a menos, e essas obrigatórias.** O Exemplo 2 do enunciado é escrito por extenso:

> **Exemplo 2 – Investimento.** Cliente: "Quero investir em imóveis para renda." O agente deverá: Entender perfil investidor; Identificar ticket; **Identificar expectativa de retorno**; **Direcionar para especialista.**

Nem `expectativaRetorno` existia em `CamposExtraidos`, nem `direcionar_especialista` existia em `proximaAcao`. Um dos três cenários que o PDF descreve não tinha como ser cumprido.

## Decisão

| era | virou | por quê |
|---|---|---|
| `agendar_visita` | `agendar_reuniao` | o enunciado diz "Encaminhar para reunião" (Exemplo 1) e "Agendamento de reuniões" (requisito funcional) |
| — | `direcionar_especialista` | "Direcionar para especialista" (Exemplo 2) |
| `escalar_humano` | *removido* | não existe no enunciado |
| — | `expectativaRetorno` em `PerfilLead` e `CamposExtraidos` | "Identificar expectativa de retorno" (Exemplo 2) |

`expectativaRetorno` é **texto livre**, com teto de 200 caracteres, guardado nas palavras do lead: "0,8% ao mês", "que se pague em 12 anos", "valorização no longo prazo". Normalizar para número perderia as duas últimas formas, que é como metade das pessoas fala de retorno.

## Motivo

Vocabulário de contrato é onde o enunciado deveria ser copiado, não interpretado. Um avaliador que procura "direcionar para especialista" encontra a palavra dele; um que procura "escalar para humano" não procura nada, porque não escreveu isso.

## Remover não abriu buraco

A pergunta óbvia: e quando o lead diz "quero falar com uma pessoa de verdade"?

Cai em `agendar_reuniao`, que é a resposta certa. Num SDR real, o lead pedindo humano **é** o encaminhamento para o corretor — o desfecho desejado, não a exceção. Verificado: a Lia responde *"vou te passar para um corretor agora mesmo"* com `proximaAcao: agendar_reuniao`. O caso ficou melhor tratado depois da remoção, não pior.

## Custo aceito

Commit coordenado nos dois repos, que é exatamente o preço que [[Decisao - Quatro repositorios separados]] aceitou. Foi feito **agora** por ser o momento mais barato que vai existir: só o código do S-06 e do S-07 dependia do contrato, o `solar-ai-front` ainda não existe e o S-10 ainda não gravou schema de banco. Depois do S-09 e do S-10 a mesma mudança custaria migração e retrabalho de UI.

## Não fica como extensão de roadmap

Decidido em 05/09, depois de a remoção já estar feita: o `escalar_humano` **não** vai para o pitch nem para a seção de roadmap do README como "o que eu faria a seguir". Sai por inteiro.

O roadmap do Solar é para o que foi cortado por **preço** — Voice AI, CRM, WhatsApp, observabilidade —, e listar ali algo que foi cortado por **não ser requisito** confunde as duas coisas. Uma lista de "o que eu faria a seguir" com um item que o enunciado não pede enfraquece os itens que ele pede.

Esta nota é o registro de que existiu e por que saiu — o suficiente para não ser reinventado, sem mantê-lo vivo como intenção.

## Verificado em 05/09

Espelho conferido campo a campo com o ambiente de pé: **6 tipos, 37 campos** (eram 35), mesmos nomes e tipos nos dois OpenAPI, `ProximaAcao` idêntica nos dois lados.

Exemplo 1 ponta a ponta fecha em `agendar_reuniao`. Exemplo 2 ponta a ponta pela API: a Lia pivota já no primeiro turno ("para quem investe, o foco é a rentabilidade"), captura ticket 600000, captura `expectativaRetorno: "0,8% ao mes"` verbatim, e fecha em `direcionar_especialista` dizendo que vai direcionar a um especialista. O `expectativaRetorno` foi fundido no perfil acumulado pelo .NET, como manda [[Decisao - Conversa em memoria com turno serializado]].

## Conceitos

[[Contrato POST turn]] · [[Qualificacao de leads]] · [[Agente stateless]]

## Relacionadas

- [[Decisao - Contrato do POST turn congelado]] — emendada por esta
- [[Decisao - Conversa em memoria com turno serializado]]
- [[Decisao - Um no com saida estruturada]]
- [[Decisao - Quatro repositorios separados]]
