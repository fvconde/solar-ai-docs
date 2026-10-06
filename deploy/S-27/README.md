# S-27 / S-28 — Preparo de Workload Identity Federation (WIF) e CI/CD para os Três Repositórios

Execução S-27 `df312134-114c-4742-80c3-01ac29034216`, extensão S-28 `91454301-5111-4a21-82f9-7d47a4ea0cce`, base operacional S-26 (`3bdd7f92-dda2-492e-a399-2e209a1e6238`), projeto `solar-ai-cloud`, região **southamerica-east1 (São Paulo)**.

Este documento detalha o script de infraestrutura como código para a federação de identidade sem chaves (Workload Identity Federation) e o pipeline de CI/CD dos três repositórios do ecossistema Solar:
- `solar-ai-api` (API de retaguarda NestJS)
- `solar-ai` (Agente cognitivo Python)
- `solar-ai-front` (Painel do corretor Angular)

---

## 1. Decisão de Arquitetura: Pool Único vs Segundo Pool

Conforme determinado no card S-28 e no briefing operacional:
- **O usuário ainda não executou o preparo de nuvem do S-27**.
- Em vez de criar um segundo pool isolado para o front e o agente, **o script [Preparo-Wif.ps1](Preparo-Wif.ps1) estende o pool, o provedor OIDC e a conta de serviço de pipeline do S-27**.
- **Justificativa**: Evita duplicidade e custos operacionais desnecessários no Google Cloud IAM, centraliza a identidade do pipeline de entrega contínua do projeto Solar em uma conta com menor privilégio estrito (`s27-pipeline-df312134`) e isola os repositórios autorizados por meio da `attribute-condition` no próprio provedor OIDC e dos bindings de `workloadIdentityUser` por repositório específico.

---

## 2. Modo Plano Puro vs -Executar (Exclusivo do Usuário)

O script [Preparo-Wif.ps1](Preparo-Wif.ps1) segue estritamente a filosofia operacional do S-26:

1. **Plano Puro por Padrão (Dry-Run)**:
   Sem o switch `-Executar`, o script apenas constrói e exibe na tela o plano legível com todas as 13 ações planejadas e os 15 comandos de variáveis do GitHub Actions. **Nenhuma chamada externa ao Google Cloud ou ao GitHub é realizada**.
2. **Execução Exclusiva do Usuário**:
   Conforme as regras do projeto, **os agentes automatizados não realizam mutações no ambiente Google Cloud**. Apenas o operador humano (usuário) está autorizado a executar o script com `-Executar`.
3. **Parâmetro Obrigatório `NumeroProjeto`**:
   O Google Cloud WIF exige o identificador numérico imutável do projeto (`projectNumber`) para compor os caminhos de recursos federados e `principalSet`. Esse valor deve ser fornecido explicitamente.

### Como inspecionar o plano (plano puro, sem mutações):

Abra o terminal PowerShell e execute com o caminho absoluto:

```powershell
& "C:\Users\felip\Documents\FIAP\Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS\solar\worktrees\S-28\solar-ai-docs\deploy\S-27\Preparo-Wif.ps1" -NumeroProjeto 123456789012
```

### Como aplicar as alterações na nuvem (somente usuário):

```powershell
& "C:\Users\felip\Documents\FIAP\Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS\solar\worktrees\S-28\solar-ai-docs\deploy\S-27\Preparo-Wif.ps1" -NumeroProjeto <NUMERO_REAL_DO_PROJETO> -Executar
```

---

## 3. Pré-requisitos e APIs do Google Cloud

Antes de executar com `-Executar`, certifique-se de que:

1. As seguintes APIs estão ativas no projeto `solar-ai-cloud`:
   - `iam.googleapis.com` (Identity and Access Management)
   - `iamcredentials.googleapis.com` (IAM Service Account Credentials API)
   - `cloudresourcemanager.googleapis.com` (Cloud Resource Manager)
   - `artifactregistry.googleapis.com` (Artifact Registry)
   - `run.googleapis.com` (Cloud Run Admin API)
   - `sts.googleapis.com` (Security Token Service — indispensável para a troca de tokens do WIF)
2. A infraestrutura base do **S-26** já foi provisionada:
   - Repositório Artifact Registry: `solar-s26-3bdd7f92` na região `southamerica-east1`.
   - Serviços Cloud Run: `solar-api`, `solar-agente` e `solar-front` na região `southamerica-east1`.
   - Contas de serviço de runtime:
     - API: `s26-api-3bdd7f92@solar-ai-cloud.iam.gserviceaccount.com`
     - Agente: `s26-agente-3bdd7f92@solar-ai-cloud.iam.gserviceaccount.com`
     - Front: `s26-front-3bdd7f92@solar-ai-cloud.iam.gserviceaccount.com`

O script possui preflight automatizado em modelo **fail-closed**: qualquer falha em consultas de inventário (`list`), respostas nulas/inválidas, contas desabilitadas, serviços inexistentes, marcas ausentes ou divergência de ownership (exigindo correspondência exata e case-sensitive de `s26-execucao=3bdd7f92-dda2-492e-a399-2e209a1e6238` na description das contas e no label `s26-execucao` dos serviços em `metadata.labels` ou `root`) bloqueia imediatamente a execução com **zero mutações**. Recursos válidos da própria execução já existentes são identificados com segurança, permitindo reexecução idempotente sem recriação desnecessária.

---

## 4. Arquitetura WIF e Princípio do Menor Privilégio

Os pipelines de CD do `solar-ai-api`, `solar-ai` e `solar-ai-front` não utilizam chaves de conta de serviço em arquivo JSON (`service account keys`). A autenticação ocorre por OIDC via Workload Identity Federation:

### Recursos Criados:
- **Pool WIF**: `solar-s27-df312134` (escopo global).
- **Provedor OIDC**: `github-df312134` apontando para o emissor `https://token.actions.githubusercontent.com`.
- **Condição Restritiva no Provedor (Attribute Condition)**:
  ```cel
  (assertion.repository == 'fvconde/solar-ai-api' || assertion.repository == 'fvconde/solar-ai' || assertion.repository == 'fvconde/solar-ai-front') && assertion.ref == 'refs/heads/main'
  ```
  Essa regra restringe estritamente a autenticação para execuções originadas da branch `main` de **apenas** os três repositórios autorizados. Qualquer tentativa de autenticação de outro repositório ou de branches como `develop`, `feature/*` ou pull requests é sumariamente rejeitada pelo gateway de STS do Google Cloud.
- **Conta de Serviço do Pipeline**: `s27-pipeline-df312134@solar-ai-cloud.iam.gserviceaccount.com` (distinta das três contas de runtime).

### Permissões IAM Atribuídas (Menor Privilégio Estrito — 10 Bindings):
1. `roles/iam.workloadIdentityUser` sobre a conta de serviço do pipeline:
   - Vinculado individualmente por repositório aos `principalSet`:
     - `principalSet://iam.googleapis.com/projects/<NUMERO>/locations/global/workloadIdentityPools/solar-s27-df312134/attribute.repository/fvconde/solar-ai-api`
     - `principalSet://iam.googleapis.com/projects/<NUMERO>/locations/global/workloadIdentityPools/solar-s27-df312134/attribute.repository/fvconde/solar-ai`
     - `principalSet://iam.googleapis.com/projects/<NUMERO>/locations/global/workloadIdentityPools/solar-s27-df312134/attribute.repository/fvconde/solar-ai-front`
2. `roles/artifactregistry.writer` **apenas** sobre o repositório `solar-s26-3bdd7f92` em `southamerica-east1`:
   - Permite que o pipeline envie (`docker push`) novas imagens com as tags imutáveis dos SHAs dos commits.
3. `roles/run.developer` **apenas** sobre os serviços Cloud Run específicos:
   - `solar-api` em `southamerica-east1`
   - `solar-agente` em `southamerica-east1`
   - `solar-front` em `southamerica-east1`
4. `roles/iam.serviceAccountUser` **apenas** sobre as contas de runtime específicas:
   - `s26-api-3bdd7f92` (API)
   - `s26-agente-3bdd7f92` (Agente)
   - `s26-front-3bdd7f92` (Front)

Nenhum papel administrativo, amplo ou global em nível de projeto (como `Owner`, `Editor` ou `Service Account Admin`) é concedido ao pipeline.

---

## 5. Configuração das GitHub Variables (15 Comandos)

Após a execução do script pelo usuário, o script imprimirá os comandos abaixo para configuração no GitHub CLI (`gh`). Cada comando inclui explicitamente `--repo <repositorio>` para garantir que as variáveis sejam aplicadas no repositório correto, independentemente do diretório onde o terminal esteja:

### Repositório API (`fvconde/solar-ai-api`):
```bash
gh variable set GCP_PROJECT_ID --repo fvconde/solar-ai-api --body "solar-ai-cloud"
gh variable set GCP_REGION --repo fvconde/solar-ai-api --body "southamerica-east1"
gh variable set GCP_ARTIFACT_REGISTRY --repo fvconde/solar-ai-api --body "solar-s26-3bdd7f92"
gh variable set GCP_WORKLOAD_IDENTITY_PROVIDER --repo fvconde/solar-ai-api --body "projects/<NUMERO_REAL>/locations/global/workloadIdentityPools/solar-s27-df312134/providers/github-df312134"
gh variable set GCP_DEPLOY_SERVICE_ACCOUNT --repo fvconde/solar-ai-api --body "s27-pipeline-df312134@solar-ai-cloud.iam.gserviceaccount.com"
```

### Repositório Agente (`fvconde/solar-ai`):
```bash
gh variable set GCP_PROJECT_ID --repo fvconde/solar-ai --body "solar-ai-cloud"
gh variable set GCP_REGION --repo fvconde/solar-ai --body "southamerica-east1"
gh variable set GCP_ARTIFACT_REGISTRY --repo fvconde/solar-ai --body "solar-s26-3bdd7f92"
gh variable set GCP_WORKLOAD_IDENTITY_PROVIDER --repo fvconde/solar-ai --body "projects/<NUMERO_REAL>/locations/global/workloadIdentityPools/solar-s27-df312134/providers/github-df312134"
gh variable set GCP_DEPLOY_SERVICE_ACCOUNT --repo fvconde/solar-ai --body "s27-pipeline-df312134@solar-ai-cloud.iam.gserviceaccount.com"
```

### Repositório Front (`fvconde/solar-ai-front`):
```bash
gh variable set GCP_PROJECT_ID --repo fvconde/solar-ai-front --body "solar-ai-cloud"
gh variable set GCP_REGION --repo fvconde/solar-ai-front --body "southamerica-east1"
gh variable set GCP_ARTIFACT_REGISTRY --repo fvconde/solar-ai-front --body "solar-s26-3bdd7f92"
gh variable set GCP_WORKLOAD_IDENTITY_PROVIDER --repo fvconde/solar-ai-front --body "projects/<NUMERO_REAL>/locations/global/workloadIdentityPools/solar-s27-df312134/providers/github-df312134"
gh variable set GCP_DEPLOY_SERVICE_ACCOUNT --repo fvconde/solar-ai-front --body "s27-pipeline-df312134@solar-ai-cloud.iam.gserviceaccount.com"
```

---

## 6. Próxima Release e Primeira Publicação Coordenada

Os workflows `.github/workflows/cd.yml` nos três repositórios disparam exclusivamente em push na branch `main`. No entanto, **a primeira publicação real no Cloud Run não deve ocorrer isoladamente agora**:

- As branches `develop` e `main` dos repositórios não estão no mesmo commit (`git ls-remote`: agente `develop` `f99adcb` vs `main` `32796fd`; front `develop` `7c03526` vs `main` `00a24f2`; API `develop` `e7dbadf` vs `main` `422635b`).
- O Cloud Run em produção ainda executa uma versão do agente cognitivo (`solar-ai`) anterior às evoluções do S-38.
- A versão de desenvolvimento da API requer o campo `essenciaisCompletos` nos diálogos do agente. Se a API for publicada isoladamente antes da atualização do agente Python, o painel do corretor apresentará instabilidade em produção.
- **Ordem de publicação obrigatória**: O agente (`solar-ai`) deve ser publicado antes ou junto da API (`solar-ai-api`), seguido pelo front (`solar-ai-front`). A primeira publicação real na nuvem é uma ação posterior exclusiva do usuário após a execução do preparo WIF.

---

## 7. Testes Automatizados da Infraestrutura

A integridade do plano, dos comandos gerados, da conformidade fail-closed e da idempotência é validada localmente por [Testar-Preparo-Wif.ps1](Testar-Preparo-Wif.ps1) com uma suíte de **30 testes automatizados** sob executor falso (mock).

O teste comprova:
- Zero chamadas externas gcloud durante o planejamento.
- Conformidade exata e literal da `attribute-condition` do provedor WIF transmitida ao transporte nativo.
- **Avaliação dinâmica da condição (Nota b Maestro)**: comprovação de que a condição efetivamente emitida aceita exatamente os 3 repositórios na `main` e rejeita qualquer 4º repositório ou branches divergentes (`develop`, `feature/*`, `refs/pull/*`, etc.), preservando semântica CEL estrita e case-sensitive (`-ceq`) ao recusar `refs/heads/Main` e variantes de caixa dos repositórios.
- Escopo restrito de IAM em cada recurso correspondente para os 3 serviços e 3 contas runtime (10 bindings, zero papéis amplos ou administrativos).
- Inclusão e validação de `sts.googleapis.com` no preflight.
- **Preflight fail-closed exato (Zero mutações)**: recusa imediata antes de qualquer mutação quando as contas de runtime ou serviços Cloud Run estiverem ausentes, desabilitados, com marcas ausentes ou com ownership divergente (inclusive quando prefixos como `s26-execucao=` ou `3bdd7f92-` forem sucedidos por UUID de outro dono).
- Suporte a formatos de inventário com labels em `metadata.labels` e no nível raiz (`root`).
- Reexecução limpa e idempotente pulando as 3 criações caso os recursos válidos já existam e aplicando os 10 bindings.
- Geração dos 15 comandos `gh variable set` contendo explicitamente `--repo` e sem nenhuma chave JSON.
- Nenhuma chamada real ao Google Cloud.

Para executar os testes via PowerShell:
```powershell
& "C:\Users\felip\Documents\FIAP\Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS\solar\worktrees\S-28\solar-ai-docs\deploy\S-27\Testar-Preparo-Wif.ps1"
```
