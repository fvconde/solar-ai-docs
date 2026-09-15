# Contrato do executor — Solar

Este guia é para quem **executa um card**: Codex, Antigravity ou Claude Code recrutado como executor no Maestri. Quem seleciona, reserva, valida e integra é o Maestro, e as regras dele vivem na skill `orquestrate` — que você não lê e não precisa ler.

A precedência é: **o briefing do seu card**, depois este guia, depois o card no Notion. Onde o briefing for específico — contrato congelado, migration na fila, recurso reservado ao card vizinho — ele vence.

Em uso desde 11/09/2026. Dez cards já entregues por este fluxo (S-17, S-18, S-20, S-23, S-24, S-29, S-30, S-33, S-34, S-36), com os registros em `execucoes/`.

## 1. O que você é e o que não é

Você executa **um card**, no seu Andar, nos worktrees que o Maestro preparou.

Você **não** escolhe card, não reserva recurso, não altera campo no Notion, não faz merge em `develop`, não trabalha no checkout principal e não corrige o card de outro executor.

`ESTADO.md` e `ARQUITETURA.md` são leitura para você. Seu registro de entrega mora em `execucoes/`, em arquivo próprio, justamente para dois executores não disputarem o mesmo arquivo; a consolidação é do Maestro, depois da integração.

Se concluir que precisa de algo fora do escopo, **pare e pergunte ao Maestro**. Não decida sozinho e não amplie o card.

## 2. Onde você trabalha

Uma pasta por card, com os repositórios lado a lado — é esse layout que preserva os caminhos relativos do Compose:

```text
solar/
  solar-ai/                 # checkouts principais, não são seus
  solar-ai-api/
  solar-ai-front/
  solar-ai-docs/
  worktrees/
    S-XX/
      solar-ai/             # feature/S-XX se alterado; HEAD destacado se só apoio
      solar-ai-api/
      solar-ai-front/
      solar-ai-docs/        # seu registro de execução
```

Repositório que você altera fica em `feature/S-XX`. Repositório necessário só ao teste integrado fica em HEAD destacado sobre `origin/develop`, e **não se edita**. O mesmo nome de branch em repositórios distintos são branches independentes; registre a combinação de commits usada no teste.

**Caminho absoluto em todo comando e toda leitura.** Não é preciosismo: `git -C <repo>` resolve caminho relativo contra o diretório do `-C`, não contra o seu, e o erro só aparece depois, com o worktree já nascido no lugar errado.

**Você não nasce na raiz do worktree.** Recrutado com `--dir`, seu shell boota em `<worktree do card>/.maestri/roles/<uuid>/`. Confira onde está antes do primeiro comando.

```powershell
$card = "C:\...\solar\worktrees\S-XX"    # caminho absoluto real, vindo do briefing
git -C "$card\solar-ai-api" status --short --branch
git -C "$card\solar-ai-api" rev-parse HEAD
```

**O que não acompanha o worktree:** `.env`, `.venv`, `node_modules`, `dist` e tudo o mais que é gitignorado. Copie do checkout principal (`solar/<repo>/.env`) para o caminho equivalente dentro do seu worktree. **Ler o checkout principal é permitido; editar não.** Não copie um `.venv` de outro diretório — ele carrega caminhos absolutos; recrie.

Worktrees compartilham os metadados Git do repositório principal. Nada de manutenção concorrente, e não apague um `.git/index.lock` sem verificar se há processo Git ativo e a qual worktree ele atende — isso já travou o repositório em silêncio aqui.

## 3. Comandos proibidos e alternativas

| Proibido | Por quê | Alternativa |
|---|---|---|
| `docker compose config` | imprime **todos os segredos em texto claro**, incluindo senha do Postgres e chave da Gemini | `docker compose config --services`, ou `docker compose --dry-run up` |
| imprimir `.env` no terminal (`cat`, `Get-Content`, `type`) | mesmo motivo | `Test-Path` para existência; carregar a variável e imprimir só um booleano |
| `git stash` / `git stash pop` sem tag | a pilha é compartilhada entre worktrees; pode engolir o trabalho de outro executor | commit WIP, ou `git stash push -u -m "<tag única>"` e `apply` pelo SHA |
| `git checkout`/`switch` no checkout principal | tira a base de `develop` debaixo de todo mundo | trabalhar só dentro do próprio worktree |
| `-B`, `--force`, `reset --hard`, remoção de worktree | destrói entrega possivelmente não preservada | investigar a colisão; caminho existente pode ser retomada |
| merge em `develop` | nunca é implícito, em nenhuma hipótese | abrir PR e parar |

Ao lado destes valem os proibidos específicos do seu briefing. A regra geral é uma só: **se concluir que precisa tocar algo proibido, pare e pergunte.**

## 4. Ambiente e cota

O Compose declara `name: solar` e portas fixas 5432, 8080 e 8000; o front usa 4200. **Não suba um segundo ambiente completo com a configuração atual** — worktree isola arquivos, não portas, banco, rede nem cota de LLM. A janela de teste integrado é única e reservada no board; não pare containers de outro executor nem zere o banco dele.

Trocar só o nome do projeto não resolve colisão de porta. Ambientes simultâneos exigiriam portas de host distintas, volumes e rede próprios, proxy do front e CORS ajustados, e segredos locais — nada disso está feito.

Cota de LLM é compartilhada e não se recupera. Quando o card consumir chamadas reais: tire uma **linha de base antes de alterar o código**, estime o consumo e **pare para aprovação antes da primeira chamada** e antes de qualquer bateria grande, e **reporte o consumo real** — da rodada e acumulado — no relatório e no registro. Se a cota apertar, pare e avise em vez de queimar o resto.

`429` do Gemini é cota, não bug. Os números medidos e as três faces do problema estão em **Riscos abertos**, no `ESTADO.md`.

## 5. Commit, entrega e PR

**Commite a cada subtarefa concluída**, nunca acumule trabalho fora do git. Processo de agente cai, e o que não está commitado depende de sorte para ser recuperado — já aconteceu duas vezes aqui.

Execute as validações do aceite e registre a **saída real**. Falha de ambiente ou teste não executado aparece como pendência, **nunca** como aprovação. Mudança no `/turn` exige conferir os dois contratos e a combinação dos serviços.

Quando o briefing autorizar PR: um PR por repositório contra `develop`, com o título do card e o UUID da execução no corpo. Devolva URLs, branches, SHAs, testes e limitações.

Se o `gh` não estiver autenticado ou a rede falhar, **não finja que o PR existe** — já houve registro afirmando PR aberto com a branch nem publicada. Preserve os commits, informe o bloqueio exato e entregue o comando pronto para execução posterior.

Merge em `develop` nunca é seu, em nenhuma hipótese.

## 6. O board mudou no meio da execução

| Mudança encontrada | Conduta |
|---|---|
| Novo card independente | Não interrompe seu trabalho; é problema do Maestro |
| Título ou prioridade | Atualizar o registro pelo mesmo ID; não abandonar o trabalho |
| Aceite ou escopo relevante | Avaliar impacto e parar para alinhar antes de prosseguir |
| Nova dependência não integrada ou reaberta | Bloquear a parte afetada; preservar trabalho e revalidar a base |
| Card cancelado, arquivado ou removido | Parar implementação e publicação; preservar o trabalho e avisar |
| Responsável ou ID da execução mudou | Parar mutações compartilhadas e resolver a posse |
| Campo, status ou schema desconhecido | Não presumir equivalência; perguntar |

Dependência descoberta durante o código também precisa ser comunicada. Não continue no escopo antigo só porque ele constava no briefing inicial.

## 7. Modelo de registro por execução

Escreva `execucoes/S-XX-<id-execucao>.md` no seu worktree de `solar-ai-docs`. Cada executor escreve o seu.

```markdown
# Execução — <card> — <ID da execução>
- Página do Notion e ID:
- Agente / sessão:
- Estado / última atividade UTC:
- Escopo e critérios de aceite consultados:
- Dependências por ID e evidências de conclusão:
- Recursos reservados:
- Repositórios / caminhos / branches / SHAs base:
- O que foi alterado:
- Validações: comando, resultado e ambiente (sem segredos):
- Consumo de cota de LLM, quando houve:
- Pendências ou bloqueios:
- PRs e commits de entrega por repositório:
- Alterações propostas para ESTADO, arquitetura e vault:
- Próximo passo exato:
```

## 8. Relatório final ao Maestro

Termine respondendo ao Maestro com **ask back**, não com uma resposta comum:

```powershell
maestri ask "<nome do Maestro em maestri list>" "<relatório>"
```

A resposta normal volta cortada no tamanho de uma tela; o ask back chega inteiro. **Em linha única** — cada quebra de linha vira um Enter no terminal de quem recebe.

O relatório traz: critérios atendidos um a um com evidência, commits e branches, PRs com URL, saída real das validações, consumo de cota se houve, e as limitações que você conhece. Relato não é evidência: o Maestro vai reexecutar as suítes dentro do worktree e conferir os PRs por `gh pr list`.
