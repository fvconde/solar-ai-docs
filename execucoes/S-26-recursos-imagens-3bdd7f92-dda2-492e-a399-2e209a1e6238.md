# S-26 — Recursos e imagens — 01/10/2026

Execução `3bdd7f92-dda2-492e-a399-2e209a1e6238`. Líder: Codex S-26. Projeto `solar-ai-cloud`, região `southamerica-east1`. Branches `feature/S-26`; comandos em PowerShell **7.6.6**, com caminhos absolutos. Docker **29.6.2**, daemon Linux/x86_64.

## Resultado e autorização

O Maestro comunicou a aprovação do custo pelo usuário e autorizou somente `Provisionar.ps1 -Etapa Recursos`, seguido de `Imagens.ps1`, com os SHAs aprovados e builds completos com rede. As duas etapas terminaram com código **0**, em uma execução cada. Os recursos foram conferidos antes dos builds; os digests remotos foram conferidos depois dos pushes.

**Parado antes de `Segredos.ps1`.** Os sete segredos estão vazios. A próxima etapa depende do usuário presente com o Gmail e de ordem do Maestro. Nenhum Deploy, serviço Cloud Run da aplicação, turno Gemini, envio SMTP, push Git, publicação ou PR foi executado nesta etapa.

As [evidências estruturadas](S-26-recursos-imagens-evidencias-3bdd7f92-dda2-492e-a399-2e209a1e6238.json) contêm horários, plano SQL, operações, SHAs e digests. Não contêm valores de segredos, tokens, identidade do operador nem endereços IP do SQL.

## Preflight e SHAs

- Projeto configurado e conta ativa conferidos em memória, sem exibir a identidade. APIs Run, Artifact Registry, SQL Admin, Secret Manager e IAM habilitadas: **5/5**.
- Cinco inventários completos e parseáveis. Ausência dos **15/15** nomes do plano antes de qualquer criação: registro, SQL, três SAs, sete segredos e três serviços Cloud Run. O script repetiu seus próprios guards antes das mutações.
- Quatro worktrees limpos, na branch correta. Os três contextos de build tiveram branch/status/HEAD conferidos pelo próprio `Imagens.ps1`, e novamente após os pushes.
- Dockerfiles completos e `.dockerignore` lidos. `.env`, `.env.*`, credenciais e chaves estão excluídos dos contextos; nenhum conteúdo desses arquivos foi lido. Os builds usaram os Dockerfiles dos worktrees, sem os overlays locais da revisão anterior.

| Repositório | HEAD de entrada |
|---|---|
| solar-ai-api | `87c491bf88d7ba94be284cdf08ab1ae4efa17724` |
| solar-ai-front | `af366c0672c625b9fbe01cfe1832d343f4a6f6d3` |
| solar-ai | `56ff8e09e616be2a6c2b5bf59cd08d7d1b0662b8` |
| solar-ai-docs | `0db11a8d66e8e7260a40dbe4de90e79689737ab8` |

## Recursos provisionados e conferidos

`Provisionar -Etapa Recursos`: **23:34:58.485–23:46:44.355 UTC**, 01/10. Plano: 21 ações e espera da operação SQL; nenhuma repetição. Conferência concluída às **23:50:56.998 UTC**.

| Recurso | Resultado observado |
|---|---|
| Artifact Registry `solar-s26-3bdd7f92` | Docker, regional, tags imutáveis, ownership desta execução |
| Cloud SQL `solar-s26-3bdd7f92` | `RUNNABLE`, Postgres 16, Enterprise, `db-f1-micro`, zonal, região aprovada |
| Disco SQL | SSD 10 GiB; crescimento automático desabilitado |
| Acesso SQL | Conector obrigatório `REQUIRED`; IPv4 habilitado; nenhuma rede autorizada |
| Backup/proteção SQL | Backup habilitado às 03:00 UTC na região aprovada; proteção contra exclusão habilitada |
| Banco | `solar`, presente uma vez |
| SAs | `s26-front-3bdd7f92`, `s26-api-3bdd7f92`, `s26-agente-3bdd7f92`; descriptions com ownership exata |
| Cloud Run | `solar-front`, `solar-api`, `solar-agente` continuam ausentes |

Ownership **12/12** conferidas pelos guards por tipo/nome. O mapa retornado tem 11 chaves porque registro e SQL compartilham o nome; cada recurso foi validado separadamente.

| Segredo | Versões | Grant direto conferido |
|---|---:|---|
| solar-postgres-connection-string | 0 | API — secretAccessor |
| solar-smtp-usuario | 0 | API — secretAccessor |
| solar-smtp-senha-app | 0 | API — secretAccessor |
| solar-smtp-remetente | 0 | API — secretAccessor |
| solar-semente-senha-supervisor | 0 | API — secretAccessor |
| solar-chave-privacidade | 0 | API — secretAccessor |
| solar-gemini-api-key | 0 | Agente — secretAccessor |

Grants previstos conferidos: **8/8** — `roles/cloudsql.client` para a SA API no projeto e sete bindings `roles/secretmanager.secretAccessor`, sem condição. Cada segredo novo tem exatamente o binding direto previsto. Nenhuma versão foi criada ou acessada; o usuário SQL `solar_app` não foi criado por esta etapa.

Operações SQL, sem erros:

| Operação | ID | Início UTC | Fim UTC |
|---|---|---|---|
| CREATE | `8311111a-8c1a-48d1-875b-2e1f00000030` | 23:35:30.513 | 23:45:44.407 |
| CREATE_DATABASE | `fb94e32f-54ce-4bcd-87c6-05f700000030` | 23:45:55.291 | 23:45:59.739 |

O conferidor temporário do líder teve duas suposições ajustadas: contagem das chaves do mapa e ausência do campo `authorizedNetworks` na resposta quando a lista está vazia. As verificações iniciais foram somente leituras. A conferência final passou; não houve alteração de script de produção, repetição de provisionamento, adoção ou mudança de ownership.

## Builds completos, pushes e digests

`Imagens.ps1`: **23:51:28.405–23:53:03.703 UTC**, 01/10. Credencial helper gcloud disponível; configuração Docker prevista aplicada. **3/3 builds completos**, **3/3 pushes**; etapa com código 0. Houve acesso de rede aos registries/dependências pelos builds. Nenhum container da aplicação foi iniciado.

Verificação às **23:53:37.871 UTC**: as tags remotas resolveram para os mesmos digests dos `RepoDigests` locais. Todas as imagens são `linux/amd64`, com usuários não root. A tag de cada serviço é seu SHA completo da tabela anterior.

Prefixo: `southamerica-east1-docker.pkg.dev/solar-ai-cloud/solar-s26-3bdd7f92`.

| Imagem | Digest remoto e local | USER |
|---|---|---|
| solar-api | `sha256:04e395ad894c3732a0c1abecacd3f462b20f6ca1022843e8726db35d60ecf05a` | `1654` |
| solar-agente | `sha256:9b4192d0b3a4068f639898f8d2b5bf17c288abfc8202020ddc700c006ce14c96` | `solar` |
| solar-front | `sha256:16347dc45c22f638df38c3920c2ba45eb4dc3f320fb71b0fd9bc8343ba032ffe` | `nginx` |

As referências completas por tag e por digest estão no JSON de evidências. Não foi necessário repetir push nem sobrescrever tag imutável.

## Comandos concretos executados

Este bloco registra as chamadas já concluídas. **Não repetir `Recursos`**: os nomes agora existem. O líder usou um wrapper temporário para preservar somente início/fim/estado e identificadores de falha sanitizados; ele chamou os scripts abaixo sem alterar seu código.

```powershell
# PowerShell 7, -NoProfile; chamadas historicas, nao retomada automatica.
$scripts = 'C:/Users/felip/Documents/FIAP/Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS/solar/worktrees/S-26/solar-ai-docs/deploy/S-26'
$execucao = '3bdd7f92-dda2-492e-a399-2e209a1e6238'
& ($scripts + '/Provisionar.ps1') -Etapa Recursos -Executar -PeloLider -AprovacaoMaestro $execucao
$shas = @{
    Api = '87c491bf88d7ba94be284cdf08ab1ae4efa17724'
    Front = 'af366c0672c625b9fbe01cfe1832d343f4a6f6d3'
    Agente = '56ff8e09e616be2a6c2b5bf59cd08d7d1b0662b8'
}
& ($scripts + '/Imagens.ps1') -Shas $shas -Executar -PeloLider -AprovacaoMaestro $execucao
```

Os builds usaram `docker build --platform=linux/amd64 -t <registro/solar-servico:SHA> <worktree-absoluto>` e `docker push <registro/solar-servico:SHA>`. Digest remoto: `gcloud artifacts docker images describe <tag> --project=solar-ai-cloud --quiet --format=json`, comparado em memória com `docker image inspect <tag>`. Metadados externos completos e saídas de tokens não foram impressos nem persistidos.

## Custos, limites e próximo gate

- **SQL permanece ativo e pago**, conforme aprovação do usuário. Registro, imagens, backups e armazenamento dos segredos também permanecem. Nenhum teardown foi autorizado nesta ordem; a desmontagem futura segue o gate do runbook. Não há serviços Cloud Run da aplicação nesta etapa.
- Estimativa que sustentou a aprovação permanece registrada no runbook, com data de referência. Esta execução não apurou uma fatura real; não afirma custo zero nem saldo suficiente do trial.
- Nenhuma falha parcial nos scripts aprovados. Não foi necessária recuperação da seção 11. Ela continua obrigatória para uma falha futura, sem repetir/adotar os recursos existentes.
- Os testes locais já aceitos pelo Maestro não foram repetidos nesta etapa de nuvem. Os resultados novos são provisionamento, leituras de metadados, builds, pushes e digests. Eles não comprovam IAM entre serviços, saúde de revisões, SMTP ou Gemini em produção.
- Código da aplicação e scripts de produção intactos; somente relatório, evidências e registro de execução versionados pelo líder. Sem Notion, merge, S-39 ou alteração de modelo.
- Nove helpers/registros temporários de texto desta etapa removidos por caminhos exatos depois da consolidação no JSON versionado. A pasta `api-runtime-publicado` da etapa anterior permaneceu intacta, conforme ordem do Maestro.
- Critério 8 global continua pendente: `Segredos.ps1` exige o usuário presente e o Gmail. Deploy privado, espera IAM, publicação e critério 10 dependem de novas ordens/gates. **Gemini 0 chamadas; SMTP 0 envios.**
