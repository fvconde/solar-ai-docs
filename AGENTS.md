# Repository Guidelines

## Execução paralela de cards

Quando o usuário pedir execução de cards por agentes em paralelo, siga [WORKFLOW-AGENTES.md](WORKFLOW-AGENTES.md). O guia define consulta dinâmica do Notion, reserva, worktrees por card e integração em `develop`. Confira os pré-requisitos de adoção; não presuma que branches, campos do board ou um coordenador já foram configurados. Para esse fluxo explícito, cada executor registra sua entrega em arquivo próprio e o integrador consolida `ESTADO.md`.

## Estrutura do projeto

Este repositório contém documentação e orquestração do Solar, não código de aplicação. `ESTADO.md` é a fonte de verdade sobre progresso, próximos passos, riscos e decisões; `ARQUITETURA.md` registra o mapa atual dos serviços. O vault Obsidian fica em `Solar Brain/`: use `10 - Projeto/` para o hub, `20 - Bugs/` para investigações concluídas, `30 - Conceitos/` para conhecimento contextualizado e `50 - Decisoes/` para decisões arquiteturais. `scripts/checar_grafo.py` valida os links do vault. O `docker-compose.yml` integra os repositórios irmãos `solar-ai-api` e `solar-ai`, que devem estar clonados ao lado deste diretório.

## Comandos de desenvolvimento e validação

- `docker compose up --build`: sobe Postgres, API .NET e agente Python usando os arquivos Compose dos repositórios irmãos.
- `docker compose down`: encerra o ambiente local. Acrescente `-v` somente quando quiser apagar o volume do Postgres.
- `python scripts/checar_grafo.py`: verifica wikilinks; retorna código 1 para links quebrados e apenas avisa sobre notas órfãs ou sem backlink.

O frontend Angular não faz parte do Compose; execute-o no repositório `solar-ai-front`. Este repositório não possui build, linter ou suíte de cobertura próprios.

## Estilo e convenções

Escreva notas e commits em português, com Markdown curto e objetivo. Use UTF-8 e finais de linha LF, conforme `.gitattributes`. Nomes de notas não levam acentos: `Decisao - <titulo>.md` e `Bug - <titulo>.md`. Inclua frontmatter compatível com as notas vizinhas (`tipo`, `tags` e, para decisões, `data` e `status`). Toda nota nova deve ligar para outra nota e receber um backlink. Não reescreva decisões antigas: registre uma nova decisão e marque a anterior como `revogada`.

## Testes e revisão

Execute o verificador do grafo antes de commitar mudanças no vault. Ao alterar o Compose, valide a subida integrada sem registrar a saída de `docker compose config`, pois ela pode expor valores de `.env`. Nunca versione credenciais, dados pessoais, tokens ou capturas que os revelem.

## Commits e pull requests

Prefira mensagens focadas como `docs: fecha o S-14 e abre a Fase 3` ou `chore: normaliza fim de linha em LF`. Cite o card (`S-xx`) quando aplicável e mantenha cada commit em um único assunto. Pull requests devem resumir a mudança, apontar card/issue relacionado, listar validações executadas e destacar decisões ou riscos alterados. Inclua imagens apenas quando houver impacto visual no diagrama ou no vault.
