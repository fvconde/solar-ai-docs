# S-27 — Preparo de Workload Identity Federation (WIF) e CI/CD para solar-ai-api

Execução `df312134-114c-4742-80c3-01ac29034216`, base operacional S-26 (`3bdd7f92-dda2-492e-a399-2e209a1e6238`), projeto `solar-ai-cloud`, região **southamerica-east1 (São Paulo)**.

Este documento detalha o script de preparo de nuvem para a federação de identidade sem chaves (Workload Identity Federation) e o pipeline de CI/CD do repositório `solar-ai-api`.

---

## 1. Modo Plano Puro vs -Executar (Exclusivo do Usuário)

O script [Preparo-Wif.ps1](file:///C:/Users/felip/Documents/FIAP/Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS/solar/worktrees/S-27/solar-ai-docs/deploy/S-27/Preparo-Wif.ps1) segue estritamente a filosofia do S-26:

1. **Plano Puro por Padrão (Dry-Run)**:
   Sem o switch `-Executar`, o script apenas constrói e exibe a estrutura do plano, as ações planejadas e os comandos das variáveis do GitHub. **Nenhuma chamada ao Google Cloud ou ao GitHub é realizada**.
2. **Execução Exclusiva do Usuário**:
   Conforme as regras do projeto, **os agentes automatizados não realizam mutações no ambiente Google Cloud**. Apenas o operador humano (usuário) está autorizado a executar o script com `-Executar`.
3. **Parâmetro Obrigatório `NumeroProjeto`**:
   O Google Cloud WIF exige o identificador numérico imutável do projeto (`projectNumber`) para compor os caminhos de recursos federados e `principalSet`. Esse valor deve ser fornecido explicitamente.

### Como inspecionar o plano:

```powershell
# Exibir o plano puro (sem mutações)
& .\Preparo-Wif.ps1 -NumeroProjeto 123456789012
```

### Como aplicar as alterações na nuvem (somente usuário):

```powershell
# Executar as mutações reais no Google Cloud
& .\Preparo-Wif.ps1 -NumeroProjeto <NUMERO_REAL_DO_PROJETO> -Executar
```

---

## 2. Pré-requisitos e APIs do Google Cloud

Antes de executar com `-Executar`, certifique-se de que:

1. As seguintes APIs estão ativas no projeto `solar-ai-cloud`:
   - `iam.googleapis.com` (Identity and Access Management)
   - `iamcredentials.googleapis.com` (IAM Service Account Credentials API)
   - `cloudresourcemanager.googleapis.com` (Cloud Resource Manager)
   - `artifactregistry.googleapis.com` (Artifact Registry)
   - `run.googleapis.com` (Cloud Run Admin API)
2. A infraestrutura base do **S-26** já foi provisionada:
   - Repositório Artifact Registry: `solar-s26-3bdd7f92` na região `southamerica-east1`.
   - Serviço Cloud Run: `solar-api` na região `southamerica-east1`.
   - Conta de serviço de runtime da API: `s26-api-3bdd7f92@solar-ai-cloud.iam.gserviceaccount.com`.

O script possui preflight automatizado (fail-closed) que valida a presença de todos esses itens antes de qualquer mutação.

---

## 3. Arquitetura WIF e Princípio do Menor Privilégio

O pipeline de CD do `solar-ai-api` não utiliza chaves de conta de serviço em arquivo JSON (`service account keys`). A autenticação ocorre por OIDC via Workload Identity Federation:

### Recursos Criados:
- **Pool WIF**: `solar-s27-df312134` (escopo global).
- **Provedor OIDC**: `github-df312134` apontando para o emissor `https://token.actions.githubusercontent.com`.
- **Condição Restritiva (Attribute Condition)**:
  ```cel
  assertion.repository == 'fvconde/solar-ai-api' && assertion.ref == 'refs/heads/main'
  ```
  Isso garante matematicamente que apenas workflows disparados pela branch `main` do repositório `fvconde/solar-ai-api` consigam autenticar no pool.
- **Conta de Serviço do Pipeline**: `s27-pipeline-df312134@solar-ai-cloud.iam.gserviceaccount.com` (distinta da conta de runtime da API).

### Permissões IAM Atribuídas (Menor Privilégio Estrito):
1. `roles/iam.workloadIdentityUser` sobre a conta de serviço do pipeline:
   - Atribuído ao `principalSet://iam.googleapis.com/projects/<NUMERO>/locations/global/workloadIdentityPools/solar-s27-df312134/attribute.repository/fvconde/solar-ai-api`.
2. `roles/artifactregistry.writer` **apenas** sobre o repositório `solar-s26-3bdd7f92` em `southamerica-east1`:
   - Permite que o pipeline envie (`docker push`) novas imagens da API com a tag do SHA do commit.
3. `roles/run.developer` **apenas** sobre o serviço Cloud Run `solar-api`:
   - Permite atualizar a imagem e variáveis de ambiente do serviço de retaguarda.
4. `roles/iam.serviceAccountUser` **apenas** sobre a conta de runtime da API (`s26-api-3bdd7f92`):
   - Permite que o Cloud Run utilize a conta de runtime já existente ao implantar novas revisões.

Nenhum papel administrativo ou global em nível de projeto é concedido ao pipeline.

---

## 4. Configuração das GitHub Variables

Após a execução do script pelo usuário, o script imprimirá os comandos abaixo para configuração no GitHub CLI (`gh`). **O script não executa comandos contra a API do GitHub automaticamente**:

```bash
gh variable set GCP_PROJECT_ID --body "solar-ai-cloud"
gh variable set GCP_REGION --body "southamerica-east1"
gh variable set GCP_ARTIFACT_REGISTRY --body "solar-s26-3bdd7f92"
gh variable set GCP_WORKLOAD_IDENTITY_PROVIDER --body "projects/<NUMERO_REAL>/locations/global/workloadIdentityPools/solar-s27-df312134/providers/github-df312134"
gh variable set GCP_DEPLOY_SERVICE_ACCOUNT --body "s27-pipeline-df312134@solar-ai-cloud.iam.gserviceaccount.com"
```

---

## 5. Próxima Release e Primeira Publicação Coordenada

O workflow `.github/workflows/cd.yml` foi configurado para disparar na branch `main`. No entanto, **a primeira publicação real no Cloud Run não deve ocorrer isoladamente agora**:

- Atualmente, as branches `main` e `develop` encontram-se alinhadas após o fechamento da `release/v1.2`.
- O Cloud Run em produção ainda executa uma versão do agente cognitivo (`solar-ai`) anterior às evoluções do S-38.
- A versão de desenvolvimento da API requer o campo `essenciaisCompletos` nos diálogos do agente. Se a API for publicada isoladamente antes da atualização do agente Python, o painel do corretor apresentará instabilidade em produção.
- Conforme planejado no card S-27, a publicação contínua entrará em ação na próxima release conjunta com a atualização do agente (S-26 / S-38).

---

## 6. Testes Automatizados da Infraestrutura

A integridade do plano, dos comandos gerados e das regras de fail-closed é validada localmente por [Testar-Preparo-Wif.ps1](file:///C:/Users/felip/Documents/FIAP/Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS/solar/worktrees/S-27/solar-ai-docs/deploy/S-27/Testar-Preparo-Wif.ps1).

O teste utiliza um executor falso (mock) e comprova:
- Zero chamadas externas gcloud durante o planejamento.
- Conformidade exata da `attribute-condition` do provedor WIF.
- Escopo restrito de IAM em cada recurso correspondente.
- Interrupção imediata (fail-closed) em caso de divergência de projeto, APIs faltantes, pré-requisitos ausentes ou falha em comandos.
- Nenhuma chamada real ao Google Cloud.

Para executar os testes:
```powershell
& .\Testar-Preparo-Wif.ps1
```
