# S-26 — passo A: causa do bloqueio de d1

01/10/2026, execução `3bdd7f92-dda2-492e-a399-2e209a1e6238`. Ordem `S-26-decisao-bloqueio-d1.md` lida. Somente leitura; nenhum recurso criado ou API habilitada nesta investigação. Sem IP do operador, e-mail ou token nas evidências.

## Consulta que havia ficado indisponível

Reprodução em PowerShell 7.6.6/launcher `gcloud.cmd`: exit 1, `INVALID_ARGUMENT: Unparseable filter: syntax error at line 1, column 122, token ':'`. O filtro de timestamps perdeu as aspas na passagem pelo launcher Windows. A mesma consulta com aspas internas escapadas para esse launcher passou e retornou seis registros; não era API desativada nem falta de permissão. Nenhuma alteração em `Operacoes.ps1` foi feita.

Consulta final: Admin Activity de `run.googleapis.com`, janela `2026-10-01T17:39:00Z`–`17:42:30Z`, projeto `solar-ai-cloud`. Projeção do SDK apenas `timestamp`, `protoPayload.methodName`, `resourceName` e `status.code/message`; sem `callerIp`, `principalEmail` ou `requestMetadata`. Uma tentativa intermediária de máscara REST aninhada em `protoPayload` retornou HTTP400; não gerou recurso nem devolveu registros. A consulta final usa a projeção do SDK autorizada.

| UTC | Método | Recurso | Status |
|---|---|---|---|
| 17:40:32.113171 | CreateService | namespaces/solar-ai-cloud/services/s26-diag-interno | sem erro (`status` vazio) |
| 17:40:44.695901 | CreateService | namespaces/solar-ai-cloud/services/s26-diag-borda | sem erro (`status` vazio) |
| 17:40:52.177695 | SetIamPolicy | projects/solar-ai-cloud/locations/southamerica-east1/services/s26-diag-borda | sem erro (`status` vazio) |
| 17:40:54.758480 | SetIamPolicy | projects/solar-ai-cloud/locations/southamerica-east1/services/s26-diag-interno | sem erro (`status` vazio) |
| 17:41:05.599416 | DeleteService | namespaces/solar-ai-cloud/services/s26-diag-borda | sem erro (`status` vazio) |
| 17:41:15.515303 | DeleteService | namespaces/solar-ai-cloud/services/s26-diag-interno | sem erro (`status` vazio) |

Os `describe` não aparecem nesta projeção de Admin Activity. Consulta somente leitura da API v2 com `showDeleted=true` não devolveu metadados retidos dos dois serviços. Para completar a investigação sem recriar recursos, foram extraídos **apenas campos públicos** do JSON já registrado pelo SDK nos dois `describe`, nos arquivos locais `14.40.54.337535.log` e `14.40.55.991444.log` de 01/10/2026 (horário local UTC−3). Nenhum arquivo bruto foi copiado ou publicado.

## Causa identificada: guard de URL

| Serviço | `status.url` | URLs anunciadas em `run.googleapis.com/urls` | Revisão pronta/criada |
|---|---|---|---|
| s26-diag-borda | https://s26-diag-borda-4or3sjeksq-rj.a.run.app | https://s26-diag-borda-935010665676.southamerica-east1.run.app ; a própria URL com hash | s26-diag-borda-d1 / s26-diag-borda-d1 |
| s26-diag-interno | https://s26-diag-interno-4or3sjeksq-rj.a.run.app | https://s26-diag-interno-935010665676.southamerica-east1.run.app ; a própria URL com hash | s26-diag-interno-d1 / s26-diag-interno-d1 |

As quatro mutações passaram na auditoria e os dois `describe` registraram os objetos de serviços com revisões prontas. O guard local `status.url -cne $urlDeterministica` rejeita ambos os objetos recuperados, embora a origem determinística esteja anunciada pelo próprio serviço. **A rejeição ocorreu no guard, após as seis chamadas**, não nas sondagens P1–P5. A presença de duas URLs concorda com a [documentação de URLs do Cloud Run](https://docs.cloud.google.com/run/docs/triggering/https-request); a evidência acima é específica desta execução.

## Passo B e proposta para produção

Correção diagnóstica restrita ao relatório: Id distinto para cada deploy/binding/describe; guard com Id próprio por serviço; exigir marca/nome esperados, lista anunciada válida, origem determinística exatamente nessa lista e `status.url` também anunciado. Sem normalização, sem aceitar URL arbitrária e sem alterar a audiência determinística. Mesmos nomes/escopo, inventário de ausência antes da nova criação e teardown no mesmo dia. A condição de parada P3 permanece.

O defeito equivalente do deploy final fica em `Operacoes.ps1:275–280`, tipo `UrlPublicada`, acionado por `Planos.ps1:149` e pelo wrapper `Deploy.ps1`. **Proposta para revisão do Maestro, não implementada:** aplicar a mesma validação de origem anunciada no verificador compartilhado e acrescentar cobertura para `status.url` com hash/lista válida, lista ausente/malformada, origem ausente, origem de outro serviço, URL com path/credencial e divergência de ownership. Não é necessário modificar esses scripts para a tentativa diagnóstica B; permanecem byte a byte intactos.

P1–P5 continuam pendentes até o passo B. Nenhum SQL, segredo, imagem da aplicação, Deploy, Gemini, SMTP, IAM de projeto, publicação ou PR nesta investigação.
