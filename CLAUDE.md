# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> O projeto inteiro é escrito em português. Mantenha português em notas, commits, `ESTADO.md` e conversa.

## Execução paralela de cards

Quando o usuário invocar o fluxo de agentes em paralelo, leia [WORKFLOW-AGENTES.md](WORKFLOW-AGENTES.md) antes de selecionar ou reservar um card. Esse fluxo adapta o rito de sessão única abaixo e de `retomar-solar`: cada executor registra a própria entrega, o integrador consolida `ESTADO.md`, e a assinatura/atualização operacional do Notion segue a autorização de execução. Confira a preparação; o guia não configura branches, campos ou coordenação automaticamente. Fora desse fluxo explícito, mantenha o rito existente.

## O que é este repositório

`solar-ai-docs` é o repositório de **documentação e orquestração** do Solar — plataforma de atendimento e qualificação de leads imobiliários com IA generativa, agente conversacional "Lia" (Tech Challenge Fase 5, FIAP; entrega **29/09/2026**, congelamento de código **24/09/2026**).

Não tem código de aplicação. Tem quatro coisas: o `ESTADO.md`, o `ARQUITETURA.md`, o `docker-compose.yml` que compõe o ambiente local dos outros repos, e o vault `Solar Brain/`.

O projeto vive em **quatro repositórios clonados lado a lado** numa pasta `solar/` — o compose depende desse layout (`include: ../solar-ai-api/compose.yml`):

```
solar/
  solar-ai-front/   Angular 20 standalone — chat do lead e painel do corretor (:4200, roda fora do compose)
  solar-ai-api/     .NET 10 Web API com controllers — dona do domínio e do banco (:8080) + Postgres 16 (:5432)
  solar-ai/         Python, FastAPI, LangGraph — a agente Lia, stateless (:8000)
  solar-ai-docs/    este repo
```

## Fluxo obrigatório de sessão

1. **Toda sessão começa pela skill `retomar-solar`** (`.claude/skills/retomar-solar/SKILL.md`) — mesmo quando o usuário não a pede pelo nome. Ela define o rito completo: carregar estado, consultar o vault, resumir em 10 linhas, perguntar o tempo disponível, propor o próximo card.
2. **`ESTADO.md` é a fonte única da verdade** sobre *por que* o projeto está como está. O board no Notion ("Solar — Backlog") diz *onde* ele está. Se o `ESTADO.md` divergir do código, diga isso — não deduza nem preencha lacunas.
3. **Atualizar o `ESTADO.md` é o último ato de toda sessão**, antes de qualquer outra coisa: linha em **Feito**, ponto exato de retomada em **Próximo**, linha datada em **Decisões** se houve decisão, e **Riscos abertos** se surgiu risco.
4. A seção **Decisões é append-only**. Nunca reescreva nem apague linha antiga; decisão revista vira linha nova.

O `ESTADO.md` (~90 KB) concentra, na seção **Próximo**, os runbooks operacionais dos outros três repos — como rodar o front, subir o ambiente, mexer no banco e nas migrations, iterar o prompt da Lia, testar o agente, regravar embeddings. **Consulte-o em vez de reinventar comandos**; este arquivo não os duplica.

## Comandos

```bash
# Ambiente local completo (Postgres + API .NET + agente Python), rodado desta pasta
docker compose up --build
docker compose down -v          # o -v é o que de fato zera o volume postgres-data

# Integridade do grafo do vault — roda antes de commitar notas
python scripts/checar_grafo.py  # exit 1 se houver wikilink quebrado; avisa sobre órfãs e sem-backlink
```

O `docker-compose.yml` daqui **não define serviço nenhum**: ele compõe por `include` os fragmentos `compose.yml` que cada repo dono publica, para que API e agente caiam na mesma rede (a API chama o agente por HttpClient desde o S-05). Cada fragmento lê o `.env` do próprio repositório. O Angular fica fora de propósito — `ng serve` tem hot reload.

## O vault `Solar Brain/`

Vault do Obsidian com a memória técnica: `10 - Projeto/Solar.md` é a nota-hub, `20 - Bugs/`, `30 - Conceitos/`, `50 - Decisoes/`.

**Consultar antes de trabalhar:** `20 - Bugs/` antes de investigar bug (`grep -ril` por 429, timeout, cota, race); `50 - Decisoes/` antes de propor arquitetura — se já há decisão, a conversa é *revê-la*, não *tomá-la*; `30 - Conceitos/` antes de explicar conceito, porque a nota diz o que ele significa **aqui**.

**Alimentar ao fim, e a regra é uma só:** se a IA errou porque faltava contexto, esse contexto vira nota. Bug que custou mais de uma hipótese, decisão tomada ou revertida (nota **e** linha no `ESTADO.md`, sempre as duas), conceito explicado do zero que vai voltar. Conhecimento genérico não entra — documenta-se a race condition *deste* projeto, não o que é uma race condition.

**Ao criar nota:** nome de arquivo **sem acento** (texto interno acentuado normalmente); frontmatter com `tipo` e `tags`, mais `data` e `status` em decisões; **toda nota nasce ligada** a pelo menos uma existente e ganha link de volta no hub — órfã não aparece no grafo e se perde. Decisão nunca é reescrita: nota nova com link para a antiga e `status: revogada` na velha.

**Este repositório é público** (escolha consciente de 05/09): nada de credencial, dado pessoal de terceiro, print com token ou saída de `docker compose config` — ela imprime todos os `.env` em texto claro.

## Regras de arquitetura que não mudam

- O agente Python é **stateless** e **nunca** acessa o banco. Dona do estado é a API .NET.
- O contrato do `POST /turn` está **congelado** (S-05) e espelhado em DTO nos dois repos — `app/contrato.py` e `Contracts/ContratoTurno.cs`. Os dois lados recusam campo desconhecido, então divergência falha alto no primeiro turno. **Mudança exige commit coordenado nos dois repositórios.**
- Prompts da Lia vivem em `solar-ai/prompts/`, nunca embutidos no código.
- Modelo do LLM e do embedding são **fixos, nunca alias**: `-latest` é ponteiro móvel e muda o comportamento sozinho.
- Nenhum segredo em repositório. Nenhum log, em nenhum dos três serviços, grava dado pessoal em texto claro; o que vai ao LLM passa pelo mascaramento do S-34. **Toda exceção é registrada no `ARQUITETURA.md`**, nunca na cabeça de ninguém.
- Schema é **migration versionada**, nunca DDL na mão; a API aplica as pendentes no boot.
- A trava por conversa (`TravaDeConversas`, `SemaphoreSlim`) **só vale dentro de um processo** — o deploy do S-26 tem que subir com instância única enquanto for assim.

## Armadilhas conhecidas

- **`429` do Gemini é cota, não bug.** Três faces: diária (500/dia por modelo por projeto, falha alto), por minuto (falha **devagar** — o SDK entra em backoff e devolve sucesso lento, até virar `504` num turno real), e embedding (100/min contando **por conteúdo**, então um boot do índice sem cache gasta 80). Detalhes e números medidos na seção **Riscos abertos** do `ESTADO.md`.
- **Testes de graça vs. testes que custam.** No `solar-ai`, `pytest` roda em 1 s sem rede; `-m llm` custa 25 chamadas reais. Não rode a suíte junto do `conversas_exemplo.py`, e não rode teste na hora anterior à gravação do vídeo.
- **Container responde com a imagem velha e não avisa.** O `Dockerfile` copia `prompts/` e `data/`: editar o arquivo local não muda o container. Antes de verificar aceite, `docker compose down && up --build`.
- **`.git/index.lock` órfão trava o repo em silêncio** — já aconteceu (nota em `20 - Bugs/`). Varra os quatro repos antes de sessão que vá commitar.
- Ambiente é **Windows/PowerShell**; o venv do agente é `./.venv/Scripts/python.exe`. O `.gitattributes` força `eol=lf` nos quatro repos porque CRLF quebra `.sh` dentro de container Linux.
- A rede corporativa do usuário faz inspeção de SSL e atrapalha Docker e npm — este projeto se desenvolve em casa.
