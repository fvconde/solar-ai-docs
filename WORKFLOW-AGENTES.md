# Workflow de agentes de código — Solar

Roteiro compartilhado para Codex, Antigravity e Claude Code. Versão inicial de 09/09/2026.

**Objetivo:** executar cards independentes em paralelo, com um responsável por card, worktrees próprios e integração controlada em `develop`.

**Estado de adoção:** preparação do piloto realizada em 09/09/2026. O usuário criou `develop` nos quatro repos; foram encontradas as referências `origin/develop`. Os oito campos de coordenação abaixo foram criados e relidos no Notion, preservando o schema anterior. A documentação está versionada neste repositório. O primeiro teste operacional ainda será feito; cada ferramenta deve confirmar seu próprio acesso ao Notion antes de reservar. O board é dinâmico: nenhum exemplo deste documento constitui uma fila fixa.

**Convenção ativa do piloto:** assinatura nas propriedades do Notion, reservas sequenciais e até dois cards em execução paralela. O usuário coordena a ordem de início e a integração. A seção no corpo do card é apenas alternativa futura, não uma segunda fonte de reserva. Não há coordenador transacional implementado.

## 1. Fontes de verdade

| Informação | Fonte |
|---|---|
| Cards existentes, escopo, aceite, prioridade, dependências e reserva | [Solar — Backlog](https://app.notion.com/p/05fdc91851f847318d9f81239e9b0f5e), consultado ao vivo |
| Motivos e decisões do projeto | [ESTADO.md](ESTADO.md) e notas relacionadas no Solar Brain |
| Fronteiras dos serviços | [ARQUITETURA.md](ARQUITETURA.md) e contratos no código |
| O que está integrado | Histórico de `origin/develop`, PRs e validações, em cada repositório envolvido |
| Como coordenar a execução | Este documento |

O identificador estável de um card é o **ID da página do Notion**. `S-XX` e título são rótulos: renomear um card não cria uma tarefa nova. Guardar ambos. Não reutilizar código de card excluído; códigos duplicados precisam ser esclarecidos antes da seleção.

Consultar o schema do banco e todas as páginas ativas, seguindo a paginação até o fim. Uma busca por palavras ou uma view filtrada não prova que um card está livre. Consultar também o corpo completo, subtarefas e propriedades do candidato e das dependências. Se o banco mudar de endereço ou um campo mudar de significado, resolver o novo mapeamento antes de executar; ausência de campo não significa ausência de impedimento.

`ESTADO.md` não funciona como trava nem como lista estática de próximos cards. Se ele divergir do board ou do código, registrar a divergência. Não reabrir decisões já registradas com base apenas em um parágrafo antigo de retomada; uma contradição de escopo ainda sem resolução bloqueia a parte afetada.

## 2. Preparação, uma vez

1. Publicar este guia no repositório de documentação e disponibilizar a mesma versão para os três agentes. Iniciar a sessão por `solar-ai-docs` ou fornecer o caminho absoluto do guia no prompt. Arquivos locais não versionados não aparecem automaticamente em novos worktrees.
2. Conferir os quatro repositórios, alterações locais, remotos, PRs e worktrees existentes. Preservar qualquer trabalho em andamento. A pasta `solar/` contém quatro repositórios; não é um único repositório Git.
3. Em cada repositório, criar `develop` a partir da `origin/main` atualizada **somente se ainda não existir**. Publicar a branch e registrar o commit inicial. Se já existir, usá-la; nunca recriar ou zerar uma `develop` existente. A inspeção inicial deste guia viu apenas `main` e `origin/main` nas referências locais, sem atualizar os remotos.
4. Adotar PRs `feature/S-XX` → `develop`. Promover `develop` → `main` em uma entrega revisada. Escolher um único responsável pela integração, inicialmente o usuário ou um agente designado por ele.
5. Preparar os campos de coordenação no Notion e confirmar leitura e escrita em cada ferramenta. Cada agente precisa do seu próprio acesso; o acesso de um não configura os demais.
6. Escolher o modo de reserva da seção 4. Começar com no máximo dois cards em execução; subir para três quando revisão e integração acompanharem o ritmo.

O guia descreve a adoção; não concede autorização automática para publicar, fazer merge, mudar o schema do board ou iniciar outro card. Um pedido explícito de execução autoriza o trabalho daquele card e sua reserva operacional conforme este fluxo. Respeitar autorizações já dadas, sem pedir novamente.

### Campos de coordenação no Notion

Os campos abaixo foram criados no board em 09/09/2026. Reler o schema em cada sessão; se forem renomeados ou alterados, resolver o mapeamento explicitamente.

| Campo | Tipo sugerido | Uso |
|---|---|---|
| Agente responsável | Select | Codex, Antigravity ou Claude Code; vazio quando livre |
| ID da execução | Texto | UUID novo por execução; distingue duas sessões do mesmo agente |
| Estado da execução | Select | Reservado, Executando, Pausado, Bloqueado, Em revisão, Integrando, Integrado, Cancelado |
| Início | Data com hora | Início da execução em UTC |
| Última atividade | Data com hora | Último marco ou retomada em UTC |
| Recursos reservados | Texto estruturado | Contratos, migrations, módulos e ambientes compartilhados |
| Repositórios envolvidos | Multi-select | Todos os repos afetados, além do repositório principal já existente |
| Entrega da execução | Texto | Branch, caminhos, commits base e de entrega, PRs por repositório |

Manter o `Status` de negócio existente: `Backlog`, `Nesta semana`, `Fazendo`, `Revisão`, `Feito`. `Superfície` indica uma ferramenta prevista e **não comprova posse**. Não substituir o responsável humano por uma identidade fictícia de pessoa; usar campo próprio de agente.

Recomenda-se migrar `Dependências` de texto para uma **relação com os próprios cards**, preservando o texto original durante a conferência. Até lá, resolver os códigos textuais para IDs de páginas a cada leitura. Código inexistente, dependência ambígua, autorreferência ou ciclo significa bloqueio; nunca ignorar silenciosamente. Cards novos precisam de aceite e dependências explícitas, inclusive “nenhuma” quando conferido.

Como alternativa em um board sem esses campos, pode-se manter os dados em uma seção única **Execução do agente** no corpo de cada card. Essa alternativa não está ativa neste piloto. Uma troca de convenção exige reconciliar as reservas existentes e orientar todos os agentes antes de continuar; não usar duas fontes de reserva concorrentes.

## 3. Como escolher o próximo card

Executar esta avaliação a cada pedido de início, retomada e após cada integração:

1. Ler o board atual completo, as reservas ativas e a base integrada. Incluir cards recém-criados; excluir arquivados e cancelados, verificando o estado real da página.
2. Filtrar cards em `Backlog` ou `Nesta semana`, sem responsável/execução ativa, com escopo e aceite compreendidos. `Fazendo` ou `Revisão` sem assinatura é inconsistência a reconciliar, não convite para assumir.
3. Resolver o grafo de dependências diretas e transitivas. Todas precisam estar satisfeitas. Para código, isso significa **entrega integrada e validada em todos os repositórios necessários**, não apenas checkbox marcado ou PR aberto. Para design/documento/decisão, exigir o artefato aceito correspondente.
4. Ler o código e delimitar os recursos afetados. Comparar com todos os cards reservados, pausados, em revisão e em integração. Não basta que os cards sejam de repositórios diferentes.
5. Entre os elegíveis, priorizar `Must`, depois `Should`, depois `Could`; em empate, `Nesta semana`, impacto em desbloquear outros cards, menor sobreposição e menor esforço. Usar código do card como último desempate. Uma dependência `Should` que libera um `Must` pode subir na ordem, com justificativa registrada.
6. Resumir a escolha: card e ID, dependências verificadas, repos, recursos, aceite e motivo para poder rodar em paralelo. Se nenhum card for elegível, relatar impedimentos concretos; não inventar trabalho nem remover dependências para ocupar o agente.

Se o usuário pedir um card específico bloqueado, explicar o impedimento e indicar um candidato elegível. Não executar outro card sem autorização para escolher o próximo.

### Dependência funcional e disputa técnica são diferentes

| Recurso | Regra inicial |
|---|---|
| Contrato `/turn` e DTOs espelhados | Um card dono da alteração, abrangendo .NET e Python |
| Schema, migrations e snapshot do EF | Um card por vez; o seguinte parte da migration já integrada |
| Grafo da Lia e prompts compartilhados | Serializar mudanças no mesmo fluxo; leitura é livre |
| Rotas, store e DTOs do frontend | Verificar os arquivos reais e o comportamento compartilhado |
| Compose, banco local e cota do LLM | Reservar ambiente e janela de testes integrados |
| `ESTADO.md`, `ARQUITETURA.md` e hub do vault | Consolidar pela integração; workers produzem registros separados |

Dois cards podem alterar o mesmo repositório se seus recursos forem independentes. Mudanças na mesma tabela, contrato ou fluxo podem conflitar mesmo sem tocar a mesma linha. Se a inspeção revelar nova dependência ou sobreposição, bloquear a parte afetada e comunicar ao coordenador; não alterar o escopo de outro card por conta própria.

## 4. Reservar sem dois agentes assumirem o mesmo card

**Assinatura visível no Notion é coordenação; sozinha não garante exclusão mútua.** Dois agentes podem ler “livre”, escrever seus nomes e ambos acreditar que venceram. Relê-la é obrigatório para verificar a gravação, mas não transforma a sequência em uma operação atômica.

### Piloto recomendado: reservas sequenciais, execução paralela

O usuário inicia um agente e aguarda a mensagem **“Reserva confirmada”** antes de pedir ao próximo que selecione um card. Só a seleção e a reserva são sequenciais; programação e testes isolados correm em paralelo. Um único coordenador pode assumir essa distribuição depois. Se houver outro processo selecionando/reservando, o agente aguarda a vez.

Dentro dessa janela exclusiva:

1. Gerar o ID da execução e reler candidato, dependências e reservas. Conferir que nada mudou desde a seleção.
2. Reservar juntos card e recursos, registrando agente, execução, horário e `Reservado`; mudar o `Status` para `Fazendo`. Reservas de recursos são consultadas em todos os cards ativos.
3. Reler a página, conferir ID da execução, responsável, escopo e recursos. Só então confirmar a reserva e liberar a próxima seleção.
4. Criar worktrees, registrar branches, caminhos e commits base por repo. Passar a `Executando` apenas quando o ambiente estiver preparado.

Se a criação do worktree falhar, a reserva continua visível como bloqueada até recuperação ou cancelamento documentado. Se uma gravação do Notion tiver resposta incerta, reler e reconciliar pelo mesmo ID; não criar outra execução às cegas. Sem acesso ao board, não iniciar card novo; uma execução já reservada pode preservar trabalho local, mas aguarda acesso antes de mudar escopo, publicar a entrega ou se declarar concluída.

### Evolução: reservas simultâneas de verdade

Para disparar os três agentes ao mesmo tempo, implementar um coordenador comum com armazenamento transacional e operação `reservar(card, execução, recursos)` que aceite **um único vencedor**. A reserva de todos os recursos deve ocorrer na mesma transação, ou falhar inteira. Todos os agentes e máquinas devem passar por ele; nesse modo, o Notion é o espelho visível da reserva, e indisponibilidade de sincronização bloqueia novas execuções até reconciliação.

Esse coordenador **não foi implementado por este guia**. Branch, comentário no card, arquivo versionado de locks ou `git worktree lock` não substituem esse mecanismo. Um lock local só coordena processos que compartilham o mesmo armazenamento e protocolo; não protege outros clones ou máquinas.

### Pausa e transferência

Atualizar atividade em marcos reais: reserva, início, validação, pausa, entrega e retomada. Não presumir que um agente pausado executa heartbeat em segundo plano.

Uma execução sem atividade pode estar aguardando o usuário ou sem conexão. **Nunca roubar reserva automaticamente por tempo.** O coordenador confirma a parada, registra último commit, alterações locais, pendências e recursos; só então cancela/libera ou transfere a execução. O sucessor recebe novo ID e referência ao anterior. Revalidar a posse antes de retomar e antes de qualquer publicação. Se dois donos forem detectados, ambos interrompem mutações compartilhadas até a reconciliação.

## 5. Branches e worktrees em quatro repositórios

```text
main → develop → feature/S-XX → PR para develop → entrega para main
```

Uma pasta por card contendo os repositórios lado a lado preserva os caminhos relativos do Compose:

```text
solar/
  solar-ai/                 # checkouts de referência existentes
  solar-ai-api/
  solar-ai-front/
  solar-ai-docs/
  worktrees/
    S-XX/
      solar-ai/             # feature/S-XX se alterado; detached se só apoio
      solar-ai-api/
      solar-ai-front/
      solar-ai-docs/        # guia e registro da entrega deste card
```

Criar worktree em `feature/S-XX` em cada repo alterado. Para um repo de apoio necessário ao teste integrado, usar worktree em commit fixo de `origin/develop`, com HEAD destacado, e não editá-lo. O mesmo nome de branch em repositórios distintos representa branches independentes. Registrar a combinação de commits usada no teste.

Exemplo PowerShell, depois de concluir a preparação e a reserva, rodado da pasta `solar/`. Substituir `S-XX` pelo código real; executar cada comando conferindo seu resultado, sem continuar após erro:

```powershell
# Exemplo de repo que sera alterado:
git -C ./solar-ai-api fetch origin
git -C ./solar-ai-api worktree list
git -C ./solar-ai-api branch --all
New-Item -ItemType Directory -Path ./worktrees/S-XX
git -C ./solar-ai-api worktree add --no-track -b feature/S-XX ./../worktrees/S-XX/solar-ai-api origin/develop
git -C ./worktrees/S-XX/solar-ai-api rev-parse HEAD
git -C ./worktrees/S-XX/solar-ai-api status --short --branch

# Exemplo de apoio que NAO sera alterado:
git -C ./solar-ai fetch origin
git -C ./solar-ai worktree add --detach ./../worktrees/S-XX/solar-ai origin/develop
```

Repetir a inspeção por repo; criar a pasta do card uma única vez. Se o caminho ou a branch já existir, inspecionar reserva, worktree e PR: pode ser uma retomada. Nunca usar `-B`, `--force`, reset ou remoção para vencer a colisão. Se `origin/develop` não existir, concluir a preparação; não cair silenciosamente para `main`.

Trabalhar e testar **dentro do worktree**, conferindo caminho e branch antes de editar. Não alternar a branch do checkout compartilhado. Worktrees compartilham metadados Git: evitar operações de manutenção concorrentes. Um `.git/index.lock` não deve ser apagado sem verificar se há processo Git ativo e qual worktree ele atende.

Cada worktree prepara suas dependências e configuração local a partir das instruções do repo. `.venv`, `node_modules`, `.env` e arquivos não versionados não acompanham o checkout; não compartilhar diretórios de build entre agentes nem imprimir segredos. Não copiar um venv com caminhos absolutos de outro diretório.

### Isolar o ambiente de execução

O Compose atual declara `name: solar` e portas fixas 5432, 8080 e 8000. O front usa 4200. **Não subir dois ambientes completos com a configuração atual.** Worktree não isola portas, banco ou cota do Gemini.

No piloto, manter testes unitários/builds em paralelo e uma única janela de teste integrado, reservada no board pelo coordenador. Essa janela deve identificar card, dono, caminhos reais dos builds e commits. Não parar containers de outro agente nem zerar seu banco.

Para ambientes simultâneos, primeiro adaptar e validar o Compose: projeto distinto por execução, portas do host diferentes, volumes e rede próprios, proxy do front e CORS ajustados e segredos locais. Só mudar o nome do projeto não resolve colisão de porta. Cota de LLM continua compartilhada quando a chave/projeto é o mesmo; agendar as chamadas reais.

## 6. Execução e mudanças no board

Na reserva, registrar uma fotografia do **escopo relevante**: aceite, dependências por ID, repos, recursos e decisões aplicáveis, além da data de leitura. Comparar esse conteúdo a cada retomada, antes de mudanças de contrato/migration e antes da entrega. A data de última edição é um sinal para reler; não é uma trava nem uma versão exclusiva do escopo, pois a própria assinatura altera a página.

| Mudança encontrada | Conduta |
|---|---|
| Novo card independente | Entra na próxima seleção; não interrompe trabalho atual |
| Título ou prioridade | Atualizar o registro pelo mesmo ID; não abandonar trabalho automaticamente |
| Aceite ou escopo relevante | Avaliar impacto, ajustar plano e recursos antes de prosseguir; esclarecer ambiguidade material |
| Nova dependência não integrada ou dependência reaberta | Bloquear a parte afetada; preservar trabalho e revalidar a base |
| Card cancelado, arquivado ou removido | Parar implementação/publicação; preservar o trabalho e reconciliar a reserva |
| Responsável/ID da execução mudou | Parar mutações compartilhadas e resolver a posse |
| Campo, status ou schema desconhecido | Atualizar o mapeamento explicitamente; não presumir equivalência |

Uma dependência descoberta durante o código também precisa ser registrada e comunicada. Não continuar no escopo antigo apenas porque ele constava no prompt inicial. Não sobrescrever o corpo inteiro do card para registrar progresso: alterar somente os campos/blocos da execução após leitura atual, preservando especificação e histórico.

Executar as validações previstas no aceite e nos repositórios. Primeiro testes determinísticos e builds; chamadas reais ao LLM na janela reservada. Falha de ambiente ou teste não executado deve aparecer como pendência, nunca como aprovação. Mudança no `/turn` exige conferir ambos os contratos e a combinação dos serviços.

## 7. Entrega, integração e liberação de dependentes

1. O executor relê escopo e posse, revisa o diff e registra testes, resultados e limitações. Abre os PRs autorizados para `develop`, ligados ao mesmo card. `Status = Revisão`, `Estado da execução = Em revisão`. O responsável permanece até a integração ou cancelamento.
2. No worktree de documentação do card, produzir `execucoes/S-XX-<id-execucao>.md` com o modelo abaixo. Cada executor escreve seu próprio arquivo. Preparar também alterações de arquitetura/notas necessárias em seu worktree, sem substituir versões compartilhadas.
3. O integrador processa uma entrega por vez. Atualiza a branch do card com `origin/develop`, resolve conflitos preservando ambas as intenções e executa novamente os testes afetados. No piloto, preferir merge da base para evitar reescrever uma branch publicada.
4. Em migrations, a reserva só é liberada depois da integração. Se surgirem migrations concorrentes anteriores ao fluxo, reconciliar modelo e snapshot, conferir o SQL e testar banco novo e atualização de banco existente. Não editar migration já aplicada em ambiente compartilhado para esconder conflito.
5. Em entrega com vários repos, marcar `Integrando`, registrar todos os PRs/SHAs e manter dependentes bloqueados durante a janela. Testar a combinação exata e integrar todos; se uma parte falhar, preservar a barreira até corrigir ou reverter de forma coordenada. Não existe merge atômico entre os quatro repos.
6. Consolidar `ESTADO.md` e, quando aplicável, `ARQUITETURA.md` e vault no worktree de integração de documentação. Acrescentar decisões sem apagar histórico; conferir links do vault quando alterado. A conclusão integrada no `ESTADO.md` substitui a disputa por um único item “Próximo”.
7. Só depois de aceite e integração completa: `Status = Feito`, execução `Integrado`, SHAs e evidências gravados; liberar recursos e limpar a reserva ativa, preservando o histórico. Reconsultar o board e recalcular elegibilidade dos dependentes, inclusive cards recém-criados. Não marcar todos os dependentes como liberados em bloco sem checar as outras dependências.

O registro individual encerra a sessão do executor; a consolidação do estado global encerra a sessão do integrador. Ao invocar explicitamente este fluxo, essa divisão adapta o rito de sessão única de `CLAUDE.md`/`retomar-solar`: workers não disputam `ESTADO.md`, e o agente atualiza o board quando a execução autoriza isso. As demais regras do projeto permanecem aplicáveis. Uma sessão comum fora deste fluxo segue o rito existente.

Depois de verificar commits publicados, integração, worktree limpo e ausência de processo ativo, remover o worktree pelo Git e encerrar a execução. Não remover worktree sujo, usar remoção forçada ou apagar branch com entrega não preservada.

### Modelo de registro por execução

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
- Pendências ou bloqueios:
- PRs e commits de entrega por repositório:
- Alterações propostas para ESTADO, arquitetura e vault:
- Próximo passo exato:
- Integração: responsável, SHAs em develop e validação conjunta:
```

## 8. Prompts para usar em qualquer agente

Fornecer o **caminho absoluto real** do guia e abrir o agente no projeto correto. Os prompts são portáveis; carregamento automático de arquivos e acesso ao Notion dependem da configuração de cada ferramenta. Não pressupor que Antigravity lê `AGENTS.md` ou que uma conexão do Codex também exista no Claude Code.

### Selecionar e iniciar o próximo

> Leia `<caminho absoluto>/solar-ai-docs/WORKFLOW-AGENTES.md` e siga esse fluxo. Consulte o board Solar — Backlog ao vivo, incluindo cards novos e alterações, e selecione o próximo card elegível sem reserva ou conflito com as execuções atuais. Esta é a única seleção/reserva em andamento neste momento. Assine o card com seu agente e um ID de execução, confirme a reserva no Notion e então implemente em worktrees próprios, em feature/S-XX a partir de origin/develop. Valide o aceite e entregue para revisão. Registre impedimentos; não assuma dependências concluídas nem faça merge sem autorização. Pare após esse card.

### Iniciar um card escolhido

> Leia `<caminho absoluto>/solar-ai-docs/WORKFLOW-AGENTES.md`. Inicie o card `<URL ou ID do Notion>` seguindo seleção, reserva e worktrees do guia. Esta é a única reserva em andamento neste momento. Releia o escopo atual e as dependências. Se estiver ocupado ou bloqueado, explique o impedimento antes de implementar. Sua assinatura e atualizações operacionais deste card estão autorizadas. Entregue para revisão, sem merge.

### Retomar ou integrar

> Retome a execução `<ID>` pelo card `<URL>`, seguindo `<caminho absoluto>/solar-ai-docs/WORKFLOW-AGENTES.md`. Confira posse, mudanças no board, branches e arquivos locais antes de continuar. Preserve trabalho anterior e atualize o registro de retomada.

> Atue como integrador da execução `<ID>`, seguindo `<caminho absoluto>/solar-ai-docs/WORKFLOW-AGENTES.md`. Confira todos os PRs, dependências e testes; prepare a combinação atualizada com develop e consolide a documentação. Apresente a entrega e pendências para revisão. Faça merge somente se essa autorização já tiver sido dada.

## 9. Exemplo observado, não uma fila permanente

Na leitura de 09/09/2026, o S-37 estava `Feito`. O S-17 estava `Nesta semana`, mas envolve contrato, migration, .NET e Python; o S-20 aparece com repositório principal frontend, porém seu aceite também exige controle de acesso na API. Portanto, a sugestão de executá-los juntos depende da delimitação real desses recursos.

O S-18 ainda tinha S-36 em aberto. Logo, “S-37 concluído” não basta para iniciar S-18. Esse exemplo mostra por que a seleção deve resolver todas as dependências atuais. Não copiar os números ou a ordem deste parágrafo para um algoritmo de seleção.

## 10. Conferência do piloto

- O segundo agente ignora um card já reservado e identifica os recursos do primeiro.
- Um card recém-criado entra na próxima leitura; renomear um card preserva sua identidade.
- Acrescentar uma dependência aberta bloqueia a entrega afetada na próxima revalidação.
- Pausa ou falha de conexão não permite apropriação automática da reserva.
- Um PR aberto não libera dependentes; uma entrega parcial em vários repos também não.
- Cada processo edita/testa no seu worktree e nenhum encerra o ambiente de outro.
- Um único integrador consolida estado e documentação sem apagar alterações anteriores.

Estas são verificações operacionais a executar na adoção; não representam testes já realizados.

Referências técnicas: [Git worktree](https://git-scm.com/docs/git-worktree) para isolamento dos checkouts e metadados compartilhados; [atualização de páginas no Notion](https://developers.notion.com/reference/patch-page) para a operação de escrita. O fluxo não pressupõe garantia transacional de reserva entre uma leitura e uma atualização de página.
