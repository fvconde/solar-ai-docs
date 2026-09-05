---
name: retomar-solar
description: Retoma o trabalho no projeto Solar — plataforma de atendimento e qualificação de leads imobiliários com IA generativa, agente conversacional "Lia", entrega em 29/09/2026. Use SEMPRE no início de qualquer conversa ou sessão que mencione Solar, Lia, solar-ai, solar-ai-api, solar-ai-front ou solar-ai-docs, e sempre que o usuário disser "retomar", "onde parei", "vamos continuar", "o que faço hoje", "próximo card" ou algo equivalente — mesmo que ele não peça a skill pelo nome. Lê o ESTADO.md, reconstrói o contexto e propõe o próximo card que cabe no tempo disponível hoje.
---

# Retomar o Solar

## Quem é o usuário

Analista Desenvolvedor Jr., trabalha sozinho neste projeto. Cerca de 2h por noite em dias úteis, 4h nos fins de semana. Forte em Angular, confortável em C# .NET, iniciante em backend profundo, banco de dados e cloud.

Trate essas três áreas como aprendizado real: explique o porquê da decisão, não só o comando a digitar. Nas outras, vá direto ao ponto — ele não precisa de aula de Angular.

## Como o projeto está organizado

Quatro repositórios lado a lado numa pasta `solar/`:

- `solar-ai-front` — Angular 20, chat do lead e painel do corretor
- `solar-ai-api` — C# .NET 10 Web API baseada em controllers, dona do domínio e do banco
- `solar-ai` — agente Python com LangGraph, stateless. A base simulada de imóveis vive em `solar-ai/data`
- `solar-ai-docs` — este repositório: `ESTADO.md`, `ARQUITETURA.md`, `docker-compose.yml`, as skills e o vault `Solar Brain/`

Toda sessão começa aqui, no `solar-ai-docs`.

## Passo 1 — Carregar o estado

Leia o `ESTADO.md` na raiz deste repositório. Ele é a fonte única da verdade sobre **por que** as coisas estão como estão. O board no Notion ("Solar — Backlog") mostra **onde** o projeto está.

Se o `ESTADO.md` não existir ou estiver visivelmente desatualizado em relação ao que você encontrar no código, diga isso primeiro. Não invente estado nem preencha lacunas por dedução.

Leia também o `ARQUITETURA.md` se a tarefa de hoje tocar a fronteira entre serviços.

## Passo 1.5 — Consultar o Solar Brain quando a tarefa exigir

`Solar Brain/` é o vault do Obsidian com a memória técnica do projeto. Notas markdown ligadas por `[[wikilinks]]`.

```
Solar Brain/
  10 - Projeto/     Solar.md — nota-hub, o mapa do grafo
  20 - Bugs/        Bug - <titulo>.md
  30 - Conceitos/   conceito técnico no recorte do Solar
  50 - Decisoes/    Decisao - <titulo>.md — uma por linha da seção Decisões do ESTADO.md
```

**Quando CONSULTAR, antes de trabalhar:**

1. **Antes de investigar qualquer bug** — buscar em `20 - Bugs/` por sintomas parecidos (`grep -ril` por termos como 429, timeout, cota, fallback, race). Um bug já investigado economiza a fase inteira de hipóteses.
2. **Antes de propor qualquer decisão de arquitetura** — ler `50 - Decisoes/`. Se já existe decisão sobre o assunto, a conversa é *rever a decisão*, não *tomar uma*. As decisões trazem o custo aceito; propor algo que já foi descartado por preço é retrabalho puro.
3. **Antes de explicar um conceito técnico do projeto** — ler `30 - Conceitos/`. A nota diz o que aquele conceito significa **aqui**, com as armadilhas registradas. Ex.: `Gemini free tier.md` explica por que `429` é cota e não bug.

**Quando ALIMENTAR, ao fim da tarefa:**

A regra que decide, e é a única:

> **Se a IA errou porque faltava contexto, esse contexto precisa virar nota.**

Casos concretos:

- **Bug que custou mais de uma hipótese para achar** → nota em `20 - Bugs/`, com linha do tempo, sintoma, hipóteses descartadas, causa raiz e solução. Hipótese descartada vale tanto quanto a solução — é o que impede reinventar a roda.
- **Decisão de arquitetura tomada ou revertida** → linha no `ESTADO.md` (append-only, obrigatória) **e** nota em `50 - Decisoes/`. As duas, sempre.
- **Conceito que precisou ser explicado do zero** e vai voltar → nota em `30 - Conceitos/`.

**O que NÃO vira nota:** conhecimento genérico. Não se documenta o que é uma race condition — documenta-se a race condition *deste* projeto. Se a informação está num tutorial qualquer da internet, ela não pertence ao vault.

**Ao criar nota:**

- Nome de arquivo **sem acento** (Windows/Linux/git). Texto interno com acentuação normal.
- Frontmatter com `tipo`, `tags` e, em decisões, `data` e `status`.
- **Toda nota nasce ligada** a pelo menos uma existente, e o hub `10 - Projeto/Solar.md` ganha o link de volta. Nota órfã não aparece no grafo, e o que não aparece no grafo se perde.
- Decisão nunca é reescrita. Mudou? Nota nova com link para a antiga, e `status: revogada` no frontmatter da velha.

## Passo 2 — Resumir em até 10 linhas

- Fase atual e quantos dias faltam para 29/09/2026
- O que foi concluído na última sessão
- Qual card estava em andamento e onde exatamente parou
- Riscos abertos ainda não resolvidos

Compacto. Ele quer voltar ao trabalho, não ler relatório.

## Passo 3 — Perguntar o tempo disponível

Uma pergunta, direta: quanto tempo você tem hoje?

## Passo 4 — Propor o próximo card

Nesta ordem de prioridade:

1. `Must` antes de `Should`, `Should` antes de `Could`
2. Nunca um card com dependência aberta
3. O card tem que caber no tempo informado. Se sobrarem 2h e o card for de 4h, proponha a primeira metade **com um ponto de parada limpo definido antes de começar** — nunca um card pela metade sem critério de parada
4. Se o projeto estiver atrasado em relação à janela da fase, diga isso na primeira linha e sugira qual card cortável sacrificar agora, em vez de esperar o prazo forçar a decisão

Traga junto o critério de aceite e o contexto de retomada gravados no card.

## Passo 5 — Ao fim da sessão

Quando ele sinalizar que vai parar, ou quando um card for concluído, atualize o `ESTADO.md` antes de qualquer outra coisa:

- Acrescente em **Feito** uma linha do que ficou pronto
- Atualize **Próximo** com o card e o ponto exato de retomada
- Se uma decisão de arquitetura foi tomada ou revertida, acrescente uma linha datada em **Decisões**. Esta seção é append-only: nunca reescreva nem apague linhas antigas
- Se surgiu um risco novo, registre em **Riscos abertos**
- Aplique a regra de alimentação do Passo 1.5: o que aprendeu hoje que faltava de contexto vira nota no `Solar Brain/`

Depois lembre ele de mover o card no Notion. Você cuida do arquivo, ele cuida do board.

## Regras de arquitetura que não mudam

- O agente Python é stateless e **nunca** acessa o banco. Quem é dono do estado é a API .NET
- O contrato do `POST /turn` é versionado nos dois repos; mudanças nele exigem commit coordenado
- Prompts da Lia vivem em arquivos dentro de `solar-ai/prompts/`, nunca embutidos no código
- Nenhum segredo em repositório, em nenhuma hipótese
- Nenhum log, em nenhum dos três serviços, grava dado pessoal em texto claro. O que vai para o LLM passa pela camada de mascaramento do S-34, exceto quando a tarefa precisa do valor real — e aí o porquê fica escrito no `ARQUITETURA.md`, não na cabeça de ninguém
- Congelamento de código em **24/09**. Depois disso, só entregáveis: README, arquitetura, vídeo e pitch

## Duas armadilhas conhecidas

- **Cota do Gemini free tier.** É limitada por dia e por projeto. Em sessão de iteração de prompt dá para queimar rápido. Se aparecer erro 429, é isso — não é bug no código.
- **Rede corporativa.** O ambiente de trabalho dele faz inspeção de SSL e atrapalha Docker e npm. Este projeto se desenvolve em casa.