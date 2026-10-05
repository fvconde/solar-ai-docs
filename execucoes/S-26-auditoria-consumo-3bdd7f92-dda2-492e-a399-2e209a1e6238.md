# S-26 — auditoria somente de leitura do consumo

Execução: 3bdd7f92-dda2-492e-a399-2e209a1e6238. Projeto solar-ai-cloud, região southamerica-east1, serviço solar-agente.

## Resultado

- Requisições: **41** entre 2026-10-02T01:34:00Z e 2026-10-02T03:22:19.4899245Z; coleta terminou em 2026-10-02T03:22:22.0387972Z.
- `/turn`: **40**, todas status **200**. `/health`: **1**, status **403**. `/resumo`: **0**. Caminho separado `/reengajar`: **0**.
- Depois de **2026-10-02T03:03:55Z**: **0 requisições** até o limite da consulta. Última requisição: `/turn`, 200, **02:34:31.430764 UTC**.
- Não há evidência de consumo contínuo nesse intervalo. A ausência de requisições nos registros consultados não identifica o iniciador nem prova que nenhuma tentativa sem registro ocorreu; a leitura é um retrato sujeito ao atraso de ingestão do Cloud Logging.
- Metadados Gemini previamente sanitizados: **51 respostas HTTP = 43 gerações + 8 embeddings**, todas **200**, entre 01:34:34.5964455 e 03:03:55.5191273 UTC. Última geração registrada: **02:34:32.571623 UTC**.
- O teto global de 20 foi excedido em **31 respostas HTTP**. Não foi enviada chamada Gemini nem turno pela liderança nesta auditoria.
- **0 respostas de erro do SDK observadas**; não é possível quantificar retries de transporte sem resposta HTTP com estes metadados. As 43 respostas de geração não são 43 turnos nem prova de 43 ações do usuário.

## Consulta e projeção

Consulta Admin/Logging somente de leitura; sem restrição a uma revisão, para abranger todo o serviço no período.

```text
resource.type="cloud_run_revision" AND resource.labels.service_name="solar-agente" AND resource.labels.location="southamerica-east1" AND logName:"run.googleapis.com%2Frequests" AND timestamp>="2026-10-02T01:34:00Z" AND timestamp<="2026-10-02T03:22:19.4899245Z"
```

Argumentos adicionais: `--limit=1000 --order=asc --project=solar-ai-cloud --quiet`. Foram recebidos 41 registros, abaixo do limite; não houve truncamento por esse limite.

Projeção final aplicada pelo formatter do SDK antes da saída:

```text
json[transforms](timestamp,httpRequest.requestUrl.sub('https://.*?[.]run[.]app','').sub('[?].*$',''),httpRequest.status)
```

Somente timestamp, caminho sem query e status foram emitidos e preservados. Nenhum IP, identidade, header ou corpo foi selecionado. A origem run.app é removida; a saída foi recusada se não começasse por `/` ou ainda contivesse `?` ou `://`.

As leituras de ajuste de projeção foram descartadas sem persistir URLs. A expressão final evita `^`, consumido na passagem pelo launcher .cmd; nenhuma alteração foi feita no transporte de produção. Não houve mutação de nuvem, código, configuração, Git ou IAM. Este novo arquivo é apenas o resultado solicitado.

## Agrupamento por caminho

| Caminho | Requisições | Status |
|---|---:|---|
| /turn | 40 | 200 × 40 |
| /resumo | 0 | — |
| /reengajar (caminho separado) | 0 | — |
| /health | 1 | 403 × 1 |
| Outros | 0 | — |

`reengajar` é um nó do grafo servido pela rota `/turn`; a API não oferece uma rota separada `/reengajar`. Separar turnos comuns de reengajamento exigiria informação que a ordem excluiu. Portanto, zero no caminho separado não significa zero reengajamentos dentro dos 40 `/turn`.

## Agrupamento por minuto UTC e correlação temporal

Minutos com pelo menos um registro em qualquer das duas fontes. Todos os demais minutos do intervalo têm zero requisições; os metadados Gemini cobrem apenas até o limite anterior, 03:03:55.5191273 UTC.

| Minuto UTC | /turn 200 | /health 403 | /resumo | /reengajar separado | Gerações 200 | Embeddings 200 |
|---|---:|---:|---:|---:|---:|---:|
| 2026-10-02T01:40:00Z | 0 | 1 | 0 | 0 | 0 | 0 |
| 2026-10-02T01:46:00Z | 2 | 0 | 0 | 0 | 0 | 0 |
| 2026-10-02T01:47:00Z | 1 | 0 | 0 | 0 | 3 | 0 |
| 2026-10-02T01:48:00Z | 6 | 0 | 0 | 0 | 7 | 1 |
| 2026-10-02T01:49:00Z | 2 | 0 | 0 | 0 | 2 | 1 |
| 2026-10-02T01:50:00Z | 2 | 0 | 0 | 0 | 2 | 0 |
| 2026-10-02T01:51:00Z | 3 | 0 | 0 | 0 | 3 | 1 |
| 2026-10-02T01:52:00Z | 2 | 0 | 0 | 0 | 2 | 0 |
| 2026-10-02T01:54:00Z | 3 | 0 | 0 | 0 | 3 | 0 |
| 2026-10-02T01:55:00Z | 1 | 0 | 0 | 0 | 1 | 0 |
| 2026-10-02T01:56:00Z | 2 | 0 | 0 | 0 | 2 | 0 |
| 2026-10-02T02:25:00Z | 3 | 0 | 0 | 0 | 3 | 0 |
| 2026-10-02T02:26:00Z | 1 | 0 | 0 | 0 | 2 | 1 |
| 2026-10-02T02:27:00Z | 3 | 0 | 0 | 0 | 3 | 3 |
| 2026-10-02T02:32:00Z | 3 | 0 | 0 | 0 | 3 | 0 |
| 2026-10-02T02:33:00Z | 2 | 0 | 0 | 0 | 3 | 1 |
| 2026-10-02T02:34:00Z | 4 | 0 | 0 | 0 | 4 | 0 |
| TOTAL | 40 | 1 | 0 | 0 | 43 | 8 |

## Correlação das 43 gerações e tentativas repetidas

1. As requisições de turno e as respostas de geração ocupam os mesmos dois blocos temporais: **01:46–01:56** e **02:25–02:34 UTC**. Não há chamada `/resumo` registrada que explique gerações adicionais.
2. As duas primeiras requisições `/turn` começaram em **01:46:54.520219** e **01:46:56.574272**; as duas primeiras gerações foram registradas em **01:47:03.284161** e **01:47:03.717689**. Sem identificador de correlação, não é possível atribuir cada resposta individualmente às duas requisições.
3. Há três intervalos entre uma requisição e a próxima com **duas gerações e um embedding**, listados abaixo. Nos demais intervalos, após o par inicial, há uma geração por intervalo. Isso reconcilia aritmeticamente **40 requisições /turn com 43 gerações**. É compatibilidade temporal, não atribuição causal comprovada.

| Intervalo definido pelo início de /turn e pelo próximo início UTC | Gerações registradas UTC | Embedding UTC |
|---|---|---|
| [01:48:07.200743, 01:48:23.156631) | 01:48:08.225111; 01:48:09.433662 | 01:48:08.609113 |
| [02:26:16.378335, 02:27:00.574379) | 02:26:17.431319; 02:26:23.664554 | 02:26:17.795421 |
| [02:33:38.719934, 02:34:01.654046) | 02:33:40.289956; 02:33:41.448718 | 02:33:40.644697 |

4. O código publicado do agente, SHA 56ff8e09e616be2a6c2b5bf59cd08d7d1b0662b8, documenta `_apresentar` em `app/lia/grafo.py:608` como segunda chamada ao LLM após `responder`. Esses três intervalos são compatíveis com esse fluxo; apenas timestamp e status não provam qual nó executou.
5. O coletor anterior conta cada linha de resposta HTTP do SDK separadamente, não somente respostas finais de turno. Assim, respostas de retries registradas também entrariam na contagem. **Todos os 51 registros são 200**, com **zero 429/5xx/outros erros HTTP registrados**. As três gerações excedentes não devem ser rotuladas como retries: há um caminho normal com duas gerações.
6. Retries causados por conexão/timeout antes de receber uma resposta podem não gerar a linha HTTPX usada pela contagem. Sem metadados dessas tentativas, não há número comprovado para eles nem prova de ausência. A leitura não inclui corpo, header, identidade, URL com query, ID de conversa ou logs de conteúdo.

## Requisições individuais — somente três campos

| Timestamp UTC | Caminho sem query | Status |
|---|---|---:|
| 2026-10-02T01:40:57.397562Z | /health | 403 |
| 2026-10-02T01:46:54.520219Z | /turn | 200 |
| 2026-10-02T01:46:56.574272Z | /turn | 200 |
| 2026-10-02T01:47:51.600796Z | /turn | 200 |
| 2026-10-02T01:48:00.015423Z | /turn | 200 |
| 2026-10-02T01:48:07.200743Z | /turn | 200 |
| 2026-10-02T01:48:23.156631Z | /turn | 200 |
| 2026-10-02T01:48:29.566996Z | /turn | 200 |
| 2026-10-02T01:48:36.188Z | /turn | 200 |
| 2026-10-02T01:48:41.187711Z | /turn | 200 |
| 2026-10-02T01:49:48.000666Z | /turn | 200 |
| 2026-10-02T01:49:58.444396Z | /turn | 200 |
| 2026-10-02T01:50:13.668102Z | /turn | 200 |
| 2026-10-02T01:50:22.227629Z | /turn | 200 |
| 2026-10-02T01:51:17.880190Z | /turn | 200 |
| 2026-10-02T01:51:27.531776Z | /turn | 200 |
| 2026-10-02T01:51:36.498982Z | /turn | 200 |
| 2026-10-02T01:52:05.926496Z | /turn | 200 |
| 2026-10-02T01:52:21.377439Z | /turn | 200 |
| 2026-10-02T01:54:19.133431Z | /turn | 200 |
| 2026-10-02T01:54:34.162120Z | /turn | 200 |
| 2026-10-02T01:54:49.832164Z | /turn | 200 |
| 2026-10-02T01:55:06.461137Z | /turn | 200 |
| 2026-10-02T01:56:01.389352Z | /turn | 200 |
| 2026-10-02T01:56:03.791621Z | /turn | 200 |
| 2026-10-02T02:25:13.913154Z | /turn | 200 |
| 2026-10-02T02:25:30.181418Z | /turn | 200 |
| 2026-10-02T02:25:50.354382Z | /turn | 200 |
| 2026-10-02T02:26:16.378335Z | /turn | 200 |
| 2026-10-02T02:27:00.574379Z | /turn | 200 |
| 2026-10-02T02:27:11.781172Z | /turn | 200 |
| 2026-10-02T02:27:24.016428Z | /turn | 200 |
| 2026-10-02T02:32:19.991367Z | /turn | 200 |
| 2026-10-02T02:32:27.241367Z | /turn | 200 |
| 2026-10-02T02:32:42.979368Z | /turn | 200 |
| 2026-10-02T02:33:15.791697Z | /turn | 200 |
| 2026-10-02T02:33:38.719934Z | /turn | 200 |
| 2026-10-02T02:34:01.654046Z | /turn | 200 |
| 2026-10-02T02:34:13.463100Z | /turn | 200 |
| 2026-10-02T02:34:24.275890Z | /turn | 200 |
| 2026-10-02T02:34:31.430764Z | /turn | 200 |

## Respostas Gemini sanitizadas reutilizadas

Fonte local: `s26-aceite-metadados-confirmados-20261002.json`, preservada sem alteração. Esta auditoria não executou nova chamada à aplicação nem ao Gemini; reutiliza os metadados HTTPX já coletados e não lê conteúdo de conversa.

| Timestamp UTC | Tipo | Status |
|---|---|---:|
| 2026-10-02T01:47:03.284161Z | Geracao | 200 |
| 2026-10-02T01:47:03.717689Z | Geracao | 200 |
| 2026-10-02T01:47:53.000861Z | Geracao | 200 |
| 2026-10-02T01:48:01.290527Z | Geracao | 200 |
| 2026-10-02T01:48:08.225111Z | Geracao | 200 |
| 2026-10-02T01:48:08.609113Z | Embedding | 200 |
| 2026-10-02T01:48:09.433662Z | Geracao | 200 |
| 2026-10-02T01:48:24.085732Z | Geracao | 200 |
| 2026-10-02T01:48:30.565243Z | Geracao | 200 |
| 2026-10-02T01:48:37.041830Z | Geracao | 200 |
| 2026-10-02T01:48:42.203519Z | Geracao | 200 |
| 2026-10-02T01:49:48.397845Z | Embedding | 200 |
| 2026-10-02T01:49:49.382392Z | Geracao | 200 |
| 2026-10-02T01:49:59.431414Z | Geracao | 200 |
| 2026-10-02T01:50:14.699590Z | Geracao | 200 |
| 2026-10-02T01:50:23.227121Z | Geracao | 200 |
| 2026-10-02T01:51:18.257514Z | Embedding | 200 |
| 2026-10-02T01:51:19.189154Z | Geracao | 200 |
| 2026-10-02T01:51:28.663266Z | Geracao | 200 |
| 2026-10-02T01:51:37.549349Z | Geracao | 200 |
| 2026-10-02T01:52:07.200805Z | Geracao | 200 |
| 2026-10-02T01:52:22.420826Z | Geracao | 200 |
| 2026-10-02T01:54:20.269417Z | Geracao | 200 |
| 2026-10-02T01:54:35.415923Z | Geracao | 200 |
| 2026-10-02T01:54:50.976151Z | Geracao | 200 |
| 2026-10-02T01:55:07.534550Z | Geracao | 200 |
| 2026-10-02T01:56:02.395256Z | Geracao | 200 |
| 2026-10-02T01:56:05.344144Z | Geracao | 200 |
| 2026-10-02T02:25:18.413353Z | Geracao | 200 |
| 2026-10-02T02:25:31.606Z | Geracao | 200 |
| 2026-10-02T02:25:51.658067Z | Geracao | 200 |
| 2026-10-02T02:26:17.431319Z | Geracao | 200 |
| 2026-10-02T02:26:17.795421Z | Embedding | 200 |
| 2026-10-02T02:26:23.664554Z | Geracao | 200 |
| 2026-10-02T02:27:00.929036Z | Embedding | 200 |
| 2026-10-02T02:27:01.947672Z | Geracao | 200 |
| 2026-10-02T02:27:12.118969Z | Embedding | 200 |
| 2026-10-02T02:27:15.344689Z | Geracao | 200 |
| 2026-10-02T02:27:24.366313Z | Embedding | 200 |
| 2026-10-02T02:27:31.911683Z | Geracao | 200 |
| 2026-10-02T02:32:21.289993Z | Geracao | 200 |
| 2026-10-02T02:32:28.750990Z | Geracao | 200 |
| 2026-10-02T02:32:43.881733Z | Geracao | 200 |
| 2026-10-02T02:33:17.062852Z | Geracao | 200 |
| 2026-10-02T02:33:40.289956Z | Geracao | 200 |
| 2026-10-02T02:33:40.644697Z | Embedding | 200 |
| 2026-10-02T02:33:41.448718Z | Geracao | 200 |
| 2026-10-02T02:34:02.675342Z | Geracao | 200 |
| 2026-10-02T02:34:14.951841Z | Geracao | 200 |
| 2026-10-02T02:34:25.521170Z | Geracao | 200 |
| 2026-10-02T02:34:32.571623Z | Geracao | 200 |

## Limites e decisão

Sem mutação para conter consumo. Não foi alterado o aceite final nem o registro do repositório. Publicação, revisão e decisão sobre o excedente permanecem com o Maestro. Não houve push, PR ou teardown.


## Atualização final — causa confirmada

O usuário confirmou ao Maestro ser autor das40 mensagens /turn ao testar Lia, sem uso externo ou consumo automático. Maestro determinou registrar51 de20, excedente31, como desvio de processo, sem custo financeiro do excedente/risco à cota diária. Atribuição é confirmação do usuário, não conclusão dos logs. Auditoria histórica preservada. [Aceite final](S-26-aceite-publico-3bdd7f92-dda2-492e-a399-2e209a1e6238.md).
