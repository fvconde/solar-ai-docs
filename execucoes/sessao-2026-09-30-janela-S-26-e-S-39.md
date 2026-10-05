# Sessão do Maestro — janela S-26 e S-39

- **Pausa:** 30/09/2026, com o limite de 5h do Codex esgotado pela segunda vez. O usuário retoma no dia seguinte.
- **Maestro:** Claude Code, no Térreo. Entrega 12/10/2026 e congelamento 09/10/2026.

## Como retomar

1. `maestri list`. Os quatro terminais abaixo devem estar no ar, cada um no seu Andar.
2. **Se os terminais continuam abertos**, o Codex guarda a conversa. Basta mandar ao líder uma linha de retomada ("o limite foi restabelecido, continue de onde parou") e conferir com `maestri check` se ela não ficou colada no campo. Se ficou, envie com `--raw "\r"`.
3. **Se algum terminal morreu** (`not running`, ou o Maestri foi fechado), a conversa se perdeu, mas o trabalho em disco não. Religue-o com `maestri recruit "<nome>" --preset "Codex" --replace "<nome>"`, responda ao trust prompt e confira o modelo na barra de status. Depois mande: "Leia o briefing em `<caminho>` e o registro de execução em `<caminho>`; o estado conferido no disco é `<resumo abaixo>`; continue pelo próximo passo." O briefing é gitignorado e só existe no disco do worktree.
4. Se a tela mostrar "Switch to gpt-6-luna for lower credit usage?", responda **2** (manter o modelo). O modelo do implementador do S-26 é escolha do usuário; não reverta sem perguntar.

## S-39 · Expurgo automático pelo prazo de retenção — EM REVISÃO

- **Execução:** `beb5d97c-3d5b-4b33-9171-0dfe0e333d1a` · Andar `S-39 — Expurgo por retenção` · worktrees em `solar/worktrees/S-39` (api, docs).
- **Terminais:** `Codex S-39` (líder, GPT-6.1-Sol high) e `Codex S-39 Luna` (GPT-6-Luna max), ociosos por ordem do Maestro.
- **PRs:** [solar-ai-api #15](https://github.com/fvconde/solar-ai-api/pull/15) em `a6a6d70` e [solar-ai-docs #17](https://github.com/fvconde/solar-ai-docs/pull/17) em `f51c7c7`, ambos MERGEABLE CLEAN.
- **Validação do Maestro:** 165/165 em duas rodadas com Postgres próprio, 20/20 focados. Uma devolução do Maestro (1 de 3), já corrigida: atraso inicial da primeira varredura.
- **Próximo passo:** merge do usuário. Depois dele, o Maestro fecha o card, consolida `ESTADO.md` (fecha o risco da retenção sem automação) e `ARQUITETURA.md`, e limpa worktrees, branches e terminais.

## S-26 · Deploy dos três serviços e Postgres gerenciado — EXECUTANDO

- **Execução:** `3bdd7f92-dda2-492e-a399-2e209a1e6238` · Andar `S-26 — Deploy` · worktrees em `solar/worktrees/S-26` (api, front, agente, docs).
- **Briefing:** `solar/worktrees/S-26/solar-ai-docs/execucoes/briefing-S-26-3bdd7f92-dda2-492e-a399-2e209a1e6238.md`.
- **Terminais:** `Codex S-26` (líder, GPT-6.1-Sol high) e `Codex S-26 Luna` (**GPT-6-Astra medium**, trocado pelo usuário em 30/09). Os dois pararam no limite de uso.
- **Checklist do líder:** nota `S-26 — Checklist de execução` no canvas.

**Estado conferido no disco em 30/09, na pausa:**

- `solar-ai-api`, commitados e não publicados: `d606226` OpenAPI só em Development, `97f4ca1` e `c54f5a1` proxies confiáveis, `5248d5b` e `5e56f39` identidade do agente com público canônico, `d02c709` SMTP, `5525a76` semente do supervisor. Critérios 1 a 5 aprovados pelo líder.
- **Trabalho sem commit, do critério 6 (imagens), em andamento:** `.dockerignore` modificado na API e no agente; `tests/operacionais/` novo no agente; `Dockerfile`, `.dockerignore` e `deploy/` novos no front. Nada disso está no git; o líder deve conferir e commitar ao retomar.
- `solar-ai-docs`: 10 commits de registro, o último `7dc1249`.
- **Ainda faltam:** critérios 6 a 9 (imagens, configuração de produção, scripts e runbook, as quatro configurações do card), `docker build` das três imagens, e o **primeiro relatório ao Maestro** com os comandos de nuvem e o custo.

**Decisões já passadas ao líder, fora do briefing original:**

- Região `southamerica-east1` em todos os recursos. `gcloud` autenticado pelo usuário e fora do PATH dos terminais antigos: `C:/Users/felip/AppData/Local/Google/Cloud SDK/google-cloud-sdk/bin/gcloud.cmd`. Leitura liberada; criação de recurso só com aprovação do Maestro.
- `solar-api` com `--no-cpu-throttling` e `--min-instances=1`, além de `--max-instances=1`. O follow-up do S-24 e o expurgo do S-39 rodam em segundo plano e parariam com CPU só durante requisições. O custo mensal disso vem no primeiro relatório.

**Pendências do usuário:** conta Gmail dedicada com senha de app, gravada pelo script de segredos que o líder vai preparar.

## Incidentes e contornos desta janela

- **Limite de 5h do Codex esgotado duas vezes.** Os quatro terminais dividem a mesma cota. Nenhum trabalho se perdeu porque o briefing exige commit a cada subtarefa.
- **Mensagem longa ficou colada no campo** como `[Pasted Content N chars]`, sem envio, embora o `ask` tenha retornado com sucesso. Contorno: `maestri ask "<nome>" --raw "\r"`.
- **O Codex guarda o último modelo como padrão.** O segundo líder subiu em Luna e foi trocado para GPT-6.1-Sol high pelo `/model`.
- **O `maestri ask` bloqueia até o agente ficar ocioso** e é morto pelo limite de tempo do comando em segundo plano. Isso não afeta o agente: confira a entrega com `maestri check`, sem reenviar.
- **Terminal órfão do S-44:** `Codex S-44 Front` ficou fora da árvore do Maestro e trava `worktrees/S-44/.maestri`. O Andar `S-44 — Porta de entrada` também continua listado. Os dois só saem pela interface, pelo usuário.

## Consumo de Gemini

Zero nos dois cards até a pausa. O S-26 tem teto de 20 chamadas no critério 10, com aprovação antes da primeira.
