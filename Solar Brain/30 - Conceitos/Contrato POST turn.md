---
tipo: conceito
tags: [conceito, arquitetura, risco]
---
# Contrato POST /turn

## O que é

O único ponto de contato entre `solar-ai-api` (.NET) e `solar-ai` (Python). Um turno de conversa entra, um turno de resposta sai. Congelado no **S-05**, em 05/09.

Como é a **única** fronteira da [[Arquitetura poliglota]], ele concentra todo o risco de retrabalho do projeto: qualquer mudança nele exige commit coordenado em dois repositórios, e a [[Decisao - Quatro repositorios separados]] tornou esse commit mais caro de propósito.

Ele carrega o estado inteiro do turno porque o [[Agente stateless]] não tem de onde tirar contexto — é essa a troca aceita. Quem monta o payload e grava o resultado é sempre o .NET.

## O formato

**Requisição** — `POST /turn`, quatro campos:

```json
{
  "conversaId": "3f6d2b1a-8c4e-4f7a-9b21-5d0e7c8a1234",
  "mensagem": "Procuro apartamento de 2 quartos na zona sul até 600 mil",
  "historico": [
    { "papel": "agente", "texto": "Oi! Sou a Lia.", "em": "2026-09-05T20:00:00Z" },
    { "papel": "lead",   "texto": "Boa noite",      "em": "2026-09-05T20:00:20Z" }
  ],
  "perfilLead": {
    "nome": null, "intencao": "compra", "precoMin": null, "precoMax": 600000,
    "quartos": 2, "regiao": "zona sul", "urgencia": "alta", "score": 60
  }
}
```

| Campo | O quê |
|---|---|
| `conversaId` | UUID da conversa, gerado pelo .NET |
| `mensagem` | o que o lead acabou de dizer — 1 a 4000 caracteres |
| `historico` | até 50 turnos anteriores, do mais antigo ao mais recente. Quem corta em N é o .NET (S-07) |
| `perfilLead` | tudo o que o .NET já sabe do lead. É a memória de longo prazo do S-13 |

**Resposta** — cinco campos:

```json
{
  "resposta": "Achei três que combinam. Prefere perto do metrô?",
  "intencao": "compra",
  "camposExtraidos": {
    "nome": null, "precoMin": null, "precoMax": 600000,
    "quartos": 2, "regiao": "zona sul", "urgencia": null, "score": 60
  },
  "proximaAcao": "sugerir_imoveis",
  "imoveisSugeridos": [
    {
      "id": "IMV-001", "tipo": "apartamento", "bairro": "Moema",
      "quartos": 3, "metragem": 98, "precoVenda": 1480000, "precoAluguel": 7200,
      "motivo": "3 quartos na zona sul, dentro da faixa"
    }
  ]
}
```

| Campo | O quê |
|---|---|
| `resposta` | o texto que a Lia fala. Texto puro, sem markdown — quem formata é o canal |
| `intencao` | a intenção do lead **depois** deste turno |
| `camposExtraidos` | o que este turno acrescentou ao perfil. **Nulo = não mencionado**, nunca "não sei" |
| `proximaAcao` | o que o .NET faz a seguir |
| `imoveisSugeridos` | até 5 imóveis, vazio na maioria dos turnos |

## Vocabulários fechados

| campo | valores |
|---|---|
| `papel` | `lead` · `agente` |
| `intencao` | `compra` · `aluguel` · `investimento` · `indefinida` |
| `urgencia` | `alta` · `media` · `baixa` |
| `proximaAcao` | `continuar_conversa` · `sugerir_imoveis` · `agendar_reuniao` · `direcionar_especialista` · `encerrar` |

`score` é inteiro de 0 a 100. Preços são **reais inteiros** — o contrato não tem centavos.

`proximaAcao` tem cinco valores porque cada um muda o que o .NET faz, e nenhum outro mudaria: `sugerir_imoveis` diz que `imoveisSugeridos` veio preenchido, `agendar_reuniao` abre o fluxo de slots do S-17, `direcionar_especialista` entrega o investidor a quem trabalha com renda, `encerrar` dispara o resumo do S-18 e o follow-up. "Perguntar a próxima coisa" é `continuar_conversa` — o nó qualificador da [[Qualificacao de leads]] decide *o quê* perguntar, e isso não é assunto do .NET.

Os nomes são os do enunciado, não invenção: `agendar_reuniao` vem de "Encaminhar para reunião" (Exemplo 1) e `direcionar_especialista` de "Direcionar para especialista" (Exemplo 2). Um `escalar_humano` chegou a existir e foi removido em 05/09 — ver [[Decisao - Vocabulario do contrato alinhado ao enunciado]].

## A regra de merge

`perfilLead` **entra**, `camposExtraidos` **sai**. Os dois têm os mesmos campos — inclusive `expectativaRetorno`, texto livre exigido pelo Exemplo 2 do enunciado —, menos um: `intencao` só existe no perfil de entrada, porque na saída ela subiu para o topo — é o campo mais consumido (roteamento, filtro do painel no S-20, requisito "identificação de intenção" do enunciado) e repeti-lo dentro de `camposExtraidos` criaria duas fontes para o mesmo valor.

A cada turno o .NET faz: **campo não-nulo de `camposExtraidos` sobrescreve o do perfil; campo nulo não toca em nada.** É o que permite ao agente devolver só o delta sem apagar o que o lead disse três turnos atrás — e é por isso que a regra do S-11 ("campo não mencionado fica null, nunca inventado") é de segurança, não de estilo.

## Por que `imoveisSugeridos` carrega os campos de render

A base de imóveis mora em `solar-ai/data`, e é o agente do [[RAG]] que escolhe os três. Se a resposta trouxesse só `{id, motivo}`, o card visual do S-16 precisaria de preço e bairro vindos de outro lugar: ou uma segunda cópia do `imoveis.json` no front, ou um `GET /imoveis/{id}` no agente — **uma segunda fronteira entre os repos**, exatamente o que a [[Arquitetura poliglota]] existe para evitar.

Sete campos na resposta custam menos que qualquer um dos dois. E o .NET grava o que foi sugerido como snapshot, que é o que o detalhe do lead (S-21) precisa mostrar depois, mesmo que o imóvel tenha saído da base.

O catálogo em memória não fere o [[Agente stateless]]: é dado de referência somente-leitura, reconstruído no boot, não estado de lead.

## Quando o agente não responde

O .NET nunca deixa a falha do agente vazar como 500. O `AgenteClient` traduz:

| situação | HTTP na API |
|---|---|
| agente inalcançável, ou respondeu não-2xx | **502** |
| estourou o tempo limite (30s por padrão) | **504** |
| resposta fora do contrato | **502** |

**Sem retentativa.** Um turno é uma chamada ao LLM: repetir gasta cota do [[Gemini free tier]] e pode duplicar efeito no meio de um agendamento. Quem decide reenviar é o lead, apertando de novo.

O corpo é `ProblemDetails`, e o `detail` segue a mesma regra do `reason` do [[Contrato GET health]]: **só em `Development`**. Em produção o motivo fica no log — a mensagem cita host e porta do agente, e o endpoint é público até o rate limit do S-29.

## Onde ele está escrito

Espelhado, e é o espelho que é o contrato:

- **.NET** — `src/Solar.Api/Contracts/ContratoTurno.cs`, publicado em `/openapi/v1.json`
- **Python** — `app/contrato.py`, publicado em `/openapi.json`

Os dois recusam campo desconhecido: `JsonUnmappedMemberHandling.Disallow` de um lado, `extra="forbid"` do outro. Divergência de nome vira **400 ou 422 alto**, não `null` silencioso — que é a forma como um contrato espelhado apodrece sem ninguém ver.

## Duas armadilhas do espelho

**Atributo de validação em `record` posicional.** `[property: StringLength(...)]` num parâmetro do construtor primário é **ignorado** pelo MVC, e ele lança `InvalidOperationException` em tempo de requisição — não em compilação. O alvo tem que ser o parâmetro: `[StringLength(...)]`, sem prefixo. Custo: a restrição some do schema do OpenAPI. Vale para todo DTO novo (S-07, S-10, S-17).

**camelCase no Pydantic.** O JSON é camelCase porque é o que o .NET e o Angular falam; o Python escreve `snake_case`. Quem resolve é `alias_generator=to_camel` com `populate_by_name=True` no modelo base — sem isso, `perfilLead` entra como campo desconhecido e, antes do `extra="forbid"`, entrava como nada.

## O que ficou de fora, conscientemente

**Campo de versão do contrato.** Ele só se paga com negociação entre versões, e a regra do projeto é commit coordenado nos dois repos — a versão estaria sempre igual dos dois lados. Quem versiona é o git. O que substitui é a recusa de campo desconhecido: se os dois lados divergirem, a requisição falha alto no mesmo minuto.

**`canal` na requisição.** O Telegram do S-25 mudaria formatação, e formatação é do .NET e do front — o agente devolve texto puro.

**O agente como `check` do `/health` da API.** Seria acessório (`degraded` → 200), nunca essencial, mas o [[Contrato GET health]] foi congelado no S-04 e a fronteira já falha alto por conta própria.

## Risco registrado

O `ESTADO.md` listou este contrato como **a maior fonte potencial de retrabalho do projeto**. Congelado no S-05, antes de existir uma linha de LangGraph ou de EF Core que dependesse dele. Se mudar depois da Fase 2, o custo é dobrado por definição.

## Decisões que dependem disso

- [[Decisao - Contrato do POST turn congelado]]
- [[Decisao - Agente Python stateless]]
- [[Decisao - Quatro repositorios separados]]
