# ARQUITETURA — Solar

> Como as peças se encaixam e onde ficam as fronteiras.
> O **porquê** de cada decisão mora no `ESTADO.md` (linha datada) e no vault `Solar Brain/`.
> Este arquivo é o mapa; ele não repete o raciocínio, aponta para ele.

**Criado em:** 08/09/2026 (S-14) · **Última atualização:** 08/09/2026

---

## Os três serviços

| Serviço | Stack | Papel | Porta |
|---|---|---|---|
| `solar-ai-front` | Angular 20 standalone | Chat do lead e painel do corretor | 4200 |
| `solar-ai-api` | .NET 10 Web API, controllers | Dona do domínio e do estado | 8080 |
| `solar-ai` | Python, FastAPI, LangGraph | Agente conversacional Lia | 8000 |
| `postgres` | Postgres 16 em container | Banco da API | 5432 |

O ambiente local sobe pelo `docker-compose.yml` deste repositório. O Angular roda fora, com `ng serve`.

## As fronteiras, e o que atravessa cada uma

```
navegador ──HTTP──> solar-ai-front ──/conversas/{id}/mensagens──> solar-ai-api ──/turn──> solar-ai
                                                                       │
                                                                   EF Core
                                                                       ↓
                                                                   postgres
```

**Front → API.** O front conhece `POST /conversas/{guid}/mensagens` e `GET /conversas/{guid}`. O `{guid}` é escolhido pelo cliente e guardado no `localStorage`; a conversa nasce no primeiro POST. O front nunca fala com o agente.

**API → agente.** `POST /turn`, contrato congelado no S-05 e espelhado em DTO nos dois repositórios — `app/contrato.py` no Python e `Contracts/ContratoTurno.cs` no .NET. Os dois lados recusam campo desconhecido: se um repo mudar sem o outro, o primeiro turno falha alto em vez de virar `null` silencioso. **Mudança no contrato exige commit coordenado nos dois repositórios.**

**Agente → banco: não existe.** O agente é stateless por decisão de arquitetura. Ele recebe histórico e perfil na requisição e devolve a resposta; não abre conexão com o Postgres, não guarda nada entre turnos. Quem funde o perfil, serializa o turno e decide o que persiste é a API.

## Onde mora o estado

Três tabelas em snake_case, criadas por migration versionada (`leads`, `conversas`, `mensagens`), com `ON DELETE CASCADE` de `conversas` e `mensagens` a partir de `leads`. Schema nunca é DDL na mão; a API aplica as migrations pendentes no boot.

A trava por conversa (`TravaDeConversas`, um `SemaphoreSlim`) impede que duas mensagens simultâneas leiam o mesmo histórico e uma atualização de perfil se perca. **Ela só vale dentro de um processo** — com mais de uma instância da API a proteção some sem erro e sem log. O deploy do S-26 tem que subir com instância única enquanto for assim.

## O índice vetorial dos imóveis (S-14)

A base simulada é `solar-ai/data/imoveis.json`: 80 imóveis com campos estruturados e uma descrição em prosa.

**Como funciona hoje.** No boot, o agente monta um índice em memória: cabeçalho estruturado + descrição de cada imóvel viram um vetor de 768 dimensões pelo `gemini-embedding-001`, normalizado na construção. A busca é cosseno — produto escalar, já que os dois lados têm norma 1 — em Python puro, sobre 80 vetores. Nenhuma dependência nova entrou no `requirements.txt`.

**Cache por hash da base.** Os vetores ficam versionados em `solar-ai/data/embeddings.json`, gerados por `scripts/gerar_embeddings.py`. O boot só chama a API de embedding se o cache não confere — modelo diferente, dimensão diferente, ou sha256 do corpus mudou. Como o `Dockerfile` copia `data/`, o container sobe **sem rede e sem cota**. Motivo medido: a cota de embedding do free tier é de 100 por minuto e conta **por conteúdo, não por requisição HTTP**, então cada boot sem cache gasta 80 dessas 100 — dois boots no mesmo minuto davam `429`.

**Degradação.** Índice que não sobe não derruba o agente: o `/health` acrescenta o check `indice_imoveis` e o serviço responde `degraded` com HTTP 200. A Lia continua conversando e qualificando; ela só não consulta imóveis. `gemini_config` continua sendo o único check essencial.

**Filtro estruturado.** A busca aceita um recorte vindo do `PerfilLead` — intenção, faixa de preço, quartos, região. `quartos` é piso e não igualdade; `regiao` casa com bairro ou zona, sem acento e sem caixa; preço só filtra com a intenção conhecida, porque é ela que diz se o número se compara a `precoVenda` ou a `precoAluguel`. Filtro que não deixa nada de pé devolve lista vazia de propósito: é fato para a Lia dizer, nunca para ela trocar por um imóvel qualquer.

**Caminho de produção: pgvector.** Índice em memória vale porque a base é pequena, estática e carrega em segundos, e porque mantém o agente stateless sem uma curva de banco no meio do prazo. Deixa de valer quando a base cresce, quando ela muda em runtime, ou quando reconstruir por réplica passa a incomodar. A resposta seguinte é pgvector no Postgres que já existe: os vetores passam a ser coluna, o índice vira IVFFlat ou HNSW e a busca vira SQL. **É escolha de POC, declarada como tal** — decisão registrada em `Solar Brain/50 - Decisoes/Decisao - Indice vetorial em memoria.md`.

## Privacidade

Nenhum log, em nenhum dos três serviços, grava dado pessoal em texto claro. O que vai para o LLM passa pela camada de mascaramento do S-34.

**Exceções — o que vai ao modelo em texto claro, e por quê.** Toda exceção mora aqui, nunca na cabeça de ninguém:

- _(nenhuma registrada até 08/09/2026; o S-34 ainda não foi implementado)_

O free tier da Gemini usa o conteúdo enviado para treino. Enquanto não houver tier pago confirmado, o mascaramento do S-34 é o único controle real, e o texto de consentimento do S-33 tem que declarar o fato.

## Regras que não mudam

- O agente Python é stateless e **nunca** acessa o banco.
- O contrato do `POST /turn` é versionado nos dois repos; mudança exige commit coordenado.
- Prompts da Lia vivem em `solar-ai/prompts/`, nunca embutidos no código.
- Nenhum segredo em repositório, em nenhuma hipótese.
- Modelo do LLM e do embedding são **fixos**, nunca alias: `-latest` é ponteiro móvel e muda o comportamento sozinho.
