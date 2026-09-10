# ARQUITETURA — Solar

> Como as peças se encaixam e onde ficam as fronteiras.
> O **porquê** de cada decisão mora no `ESTADO.md` (linha datada) e no vault `Solar Brain/`.
> Este arquivo é o mapa; ele não repete o raciocínio, aponta para ele.

**Criado em:** 08/09/2026 (S-14) · **Última atualização:** 10/09/2026 (S-17)

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

**API → agente.** `POST /turn`, contrato congelado no S-05 e espelhado em DTO nos dois repositórios — `app/contrato.py` no Python e `Contracts/ContratoTurno.cs` no .NET. Os dois lados recusam campo desconhecido: se um repo mudar sem o outro, o primeiro turno falha alto em vez de virar `null` silencioso. O S-17 acrescentou `agenda[]` à requisição, `slotEscolhido` à resposta e o tipo `SlotOferecido`; o espelho tem 7 tipos e 42 campos. **Mudança no contrato exige commit coordenado nos dois repositórios.**

**Agente → banco: não existe.** O agente é stateless por decisão de arquitetura. Ele recebe histórico e perfil na requisição e devolve a resposta; não abre conexão com o Postgres, não guarda nada entre turnos. Quem funde o perfil, serializa o turno e decide o que persiste é a API.

## Onde mora o estado

Seis tabelas em snake_case, criadas por migration versionada — `leads`, `conversas`, `mensagens`, `corretores`, `encaminhamentos` e `slots` —, com `ON DELETE CASCADE` de `conversas`, `mensagens` e `encaminhamentos` a partir de `leads`. `slots.lead_id` é nulo enquanto livre e volta a nulo se o lead for eliminado; `mensagens.slot_id` preserva o vínculo do evento enquanto o slot existir. Schema nunca é DDL na mão; a API aplica as migrations pendentes no boot.

`corretores` é a única tabela **semeada**: 5 linhas literais dentro da própria migration, como os 80 imóveis são semeados por JSON. Seed não mora em `HasData` — coleção primitiva ali faz o EF ver o modelo mudando a cada build e o boot cai, com o log culpando o banco (`Solar Brain/20 - Bugs/Bug - HasData com colecao primitiva derruba o boot.md`).

Os slots não ficam presos a datas de migration. Depois de aplicar o schema, a rotina de boot `AgendaInicial` garante ao menos 6 horários futuros livres por corretor ativo, em dias úteis e relativos ao relógio corrente; horários persistidos usam UTC, e a conversão para São Paulo acontece nas bordas.

A trava por conversa (`TravaDeConversas`, um `SemaphoreSlim`) impede que duas mensagens simultâneas leiam o mesmo histórico e uma atualização de perfil se perca. **Ela só vale dentro de um processo** — com mais de uma instância da API a proteção some sem erro e sem log. O deploy do S-26 tem que subir com instância única enquanto for assim.

## O índice vetorial dos imóveis (S-14)

A base simulada é `solar-ai/data/imoveis.json`: 80 imóveis com campos estruturados e uma descrição em prosa.

**Como funciona hoje.** No boot, o agente monta um índice em memória: cabeçalho estruturado + descrição de cada imóvel viram um vetor de 768 dimensões pelo `gemini-embedding-001`, normalizado na construção. A busca é cosseno — produto escalar, já que os dois lados têm norma 1 — em Python puro, sobre 80 vetores. Nenhuma dependência nova entrou no `requirements.txt`.

**Cache por hash da base.** Os vetores ficam versionados em `solar-ai/data/embeddings.json`, gerados por `scripts/gerar_embeddings.py`. O boot só chama a API de embedding se o cache não confere — modelo diferente, dimensão diferente, ou sha256 do corpus mudou. Como o `Dockerfile` copia `data/`, o container sobe **sem rede e sem cota**. Motivo medido: a cota de embedding do free tier é de 100 por minuto e conta **por conteúdo, não por requisição HTTP**, então cada boot sem cache gasta 80 dessas 100 — dois boots no mesmo minuto davam `429`.

**Degradação.** Índice que não sobe não derruba o agente: o `/health` acrescenta o check `indice_imoveis` e o serviço responde `degraded` com HTTP 200. A Lia continua conversando e qualificando; ela só não consulta imóveis. `gemini_config` continua sendo o único check essencial.

**Filtro estruturado.** A busca aceita um recorte vindo do `PerfilLead` — intenção, faixa de preço, quartos, região. `quartos` é piso e não igualdade; `regiao` casa com bairro ou zona, sem acento e sem caixa; preço só filtra com a intenção conhecida, porque é ela que diz se o número se compara a `precoVenda` ou a `precoAluguel`. Filtro que não deixa nada de pé devolve lista vazia de propósito: é fato para a Lia dizer, nunca para ela trocar por um imóvel qualquer.

**Caminho de produção: pgvector.** Índice em memória vale porque a base é pequena, estática e carrega em segundos, e porque mantém o agente stateless sem uma curva de banco no meio do prazo. Deixa de valer quando a base cresce, quando ela muda em runtime, ou quando reconstruir por réplica passa a incomodar. A resposta seguinte é pgvector no Postgres que já existe: os vetores passam a ser coluna, o índice vira IVFFlat ou HNSW e a busca vira SQL. **É escolha de POC, declarada como tal** — decisão registrada em `Solar Brain/50 - Decisoes/Decisao - Indice vetorial em memoria.md`.

## O encaminhamento ao corretor (S-37)

O desfecho passa a desfechar. Quando o turno volta com `agendar_reuniao` ou `direcionar_especialista`, a API escolhe um corretor, grava **uma** linha em `encaminhamentos` — índice único em `conversa_id`, então encaminhar duas vezes não duplica — e devolve o nome ao front.

**A escolha é pura e determinística**, em `Encaminhamentos/EscolhaDeCorretor.cs`: sem banco, sem relógio, mesma entrada e mesma saída. Ordem da regra: especialidade compatível com a trilha (`investimento` → investimento; `compra` e `aluguel` → moradia) → região do lead entre as regiões do corretor → menor carga aberta → desempate por quem está há mais tempo sem receber lead. Sem elegível, a linha sai com `corretor_id` nulo e status `aguardando`, e a conversa segue.

**Região ausente não exclui ninguém.** Não saber onde o lead quer morar não é o mesmo que saber que ninguém atende ali. Já uma região que não casa com corretor nenhum cai em `aguardando`.

O casamento de região **espelha o `_regiao_bate` do `indice.py`**: termo de uma palavra casa como palavra inteira, termo com espaço casa como trecho, sem acento e sem caixa. São duas implementações da mesma regra, em linguagens diferentes — divergência aqui é o risco conhecido desta seção, aceito porque a alternativa devolveria ao agente uma pergunta que `Agente stateless` fechou.

**A escrita é atômica com o turno.** A decisão acontece fora da gravação, e o encaminhamento entra no mesmo `SaveChangesAsync` das duas mensagens e do perfil fundido — turno que falha no agente não deixa encaminhamento, mesma invariante do S-10.

**O nome do corretor não passa pelo LLM.** Ele viaja em `MensagemResponse` e `MensagemDaConversa` — DTOs só do .NET, fora do espelho congelado —, e o front o desenha como evento estruturado da trilha. Sobrevive ao reload porque o `GET /conversas/{id}` o reconstrói do banco.

**Dedupe por contato.** `POST /conversas/{id}/contato` grava nome, telefone e e-mail. Telefone vira dígitos e e-mail vira minúsculas antes de comparar, sob índice único parcial; o mesmo contato visto noutra conversa traz aquela conversa para o lead que já existe, funde o perfil e **apaga o lead provisório**. É o que transforma base de conversas em base de clientes.

## O agendamento (S-17)

Os horários só entram na conversa depois do handoff. Antes de chamar o agente, a API consulta no máximo três `slots` futuros e livres do corretor atribuído e os envia em `TurnoRequest.agenda`. O nó puro `agendar` leva essa lista ao prompt; a mesma chamada estruturada do nó `responder` pode devolver `slotEscolhido`. Um gate no Python e outro na API descartam qualquer id que não tenha sido oferecido naquele turno.

**A fala não confirma o banco.** A Lia só declara a intenção de reservar. A API executa um `UPDATE` condicional — corretor correto, slot futuro e `lead_id IS NULL` — na mesma transação que grava as duas mensagens e o encaminhamento. Exatamente uma disputa pode alterar a linha. A vencedora produz o evento estruturado `confirmado`; a perdedora produz `indisponivel` com até três alternativas atuais. O front prefere esse evento ao evento genérico de handoff e o `GET /conversas/{id}` o reconstrói depois do reload.

Agenda vazia não derruba o turno e não autoriza invenção: o prompt orienta a Lia a dizer que a confirmação seguirá pelo contato informado. Se o agente falhar, a transação nem começa; não ficam conversa, encaminhamento ou reserva parciais.

## Privacidade

Nenhum log, em nenhum dos três serviços, grava dado pessoal em texto claro. O que vai para o LLM passa pela camada de mascaramento do S-34.

**Exceções — o que vai ao modelo em texto claro, e por quê.** Toda exceção mora aqui, nunca na cabeça de ninguém:

- **`nome` do lead, desde o S-06.** Vai em todo `TurnoRequest` dentro do `PerfilLead`, e volta em `CamposExtraidos` porque é o modelo que o extrai da conversa. Mascarar quebraria a função: a Lia chama a pessoa pelo nome, e é isso que sustenta o requisito de "conversa natural". Fica **fora** do mascaramento do S-34, e o consentimento do S-33 tem que cobrir o fato.

**O que deliberadamente não vai, e por construção (S-37):** `telefone` e `email` do lead. Eles entram por formulário próprio (`POST /conversas/{id}/contato`), vão do formulário ao Postgres e do Postgres ao painel — **nunca ao turno**. A garantia não é textual e sim estrutural: o contrato congelado do `/turn` não tem campo para eles, e os dois lados recusam campo desconhecido. `Solar.Api.Tests` afirma por reflexão que nenhum dos 7 tipos do espelho carrega campo de contato, e que o espelho continua com 42 campos — o teste falha antes de qualquer vazamento entrar em produção.

O free tier da Gemini usa o conteúdo enviado para treino. Enquanto não houver tier pago confirmado, o mascaramento do S-34 é o único controle real, e o texto de consentimento do S-33 tem que declarar o fato.

## Regras que não mudam

- O agente Python é stateless e **nunca** acessa o banco.
- O contrato do `POST /turn` é versionado nos dois repos; mudança exige commit coordenado.
- Prompts da Lia vivem em `solar-ai/prompts/`, nunca embutidos no código.
- Nenhum segredo em repositório, em nenhuma hipótese.
- Modelo do LLM e do embedding são **fixos**, nunca alias: `-latest` é ponteiro móvel e muda o comportamento sozinho.
