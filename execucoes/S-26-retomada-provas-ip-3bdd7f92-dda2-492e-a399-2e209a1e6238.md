# S-26 — Retomada das provas de IP — 01/10/2026

Execução `3bdd7f92-dda2-492e-a399-2e209a1e6238`, líder Codex S-26, projeto `solar-ai-cloud`, região `southamerica-east1`. PowerShell **7.6.6**, caminhos absolutos e branches `feature/S-26`. Horários abaixo em UTC de **02/10**; execução local em **01/10**, America/Sao_Paulo.

## Estado: provas retomadas concluídas; aguarda revisão do Maestro

**Rodada inicial: 134 chamadas**, 133 asserções conformes e um caso informativo 401. **Complemento com forjas isoladas: 65/65 chamadas conformes**. Acumulado desta retomada: **199 chamadas registradas, 198 asserções conformes, um informativo e zero outras falhas**; **186 respostas 401 e 13 respostas 429**. A sequência a–d exata está documentada abaixo.

Não houve redeploy, mudança de configuração, leitura de logs ou aquisição do IP público do operador nesta retomada. Publicação `allUsers` e primeira chamada Gemini continuam aguardando seus gates; nenhum envio SMTP foi solicitado. Recursos pagos permanecem ativos e privados.

[Evidências completas, status de cada chamada e fonte do driver](S-26-retomada-provas-ip-3bdd7f92-dda2-492e-a399-2e209a1e6238-evidencias.json). [Etapa anterior: deploy, metadados e falha 138](S-26-deploy-privado-3bdd7f92-dda2-492e-a399-2e209a1e6238.md). A evidência anterior foi preservada.

## Ordem e preparação

O Maestro considerou a falha 138 não impeditiva para segurança: A esgotou o próprio bucket e B permaneceu separado. A partição usa a string de `RemoteIpAddress`; a hipótese é um peer IPv4 mapeado em IPv6, com outra string de chave, ou mudança de janela. Essa causa continua **hipótese**, sem leitura direta do socket.

A ordem autorizou espera de dois minutos, retomada a partir do caso 4 com status sempre registrado, caso 4 apenas informativo, e parada em qualquer outra falha. Proibiu redeploy e leitura de logs.

A espera mínima foi fixada até **00:55:39 UTC**; nenhuma prova foi feita antes desse instante. O driver começou às **01:00:13.132 UTC** e a primeira fase HTTP às **01:00:15.942 UTC**. Parser PowerShell conferido: **zero erros**.

O IP público obtido na etapa anterior existia só em memória e foi descartado. Pedi método de comparação sem logs ao Maestro. Sua resposta, consultada por `maestri check "Claude Code"`, indicou comparação **pelo comportamento do bucket**: esgotar pelo front, tentar as forjas e conferir liberação após a janela. Nenhum valor de IP público foi lido, recebido, impresso ou persistido nesta etapa.

## Respostas observadas

As janelas anteriores já tinham zerado. Reestabeleci o bucket de fallback para conferir os casos negativos; isso não foi repetição de deploy.

| Chamadas | Caso | Esperado | Observado |
|---|---|---|---|
| 1–60 | API, sem header próprio | 401 em cada | 60 × 401 |
| 61 | API, 61ª tentativa no fallback | 429 | 429 |
| 62 | Caso 4: próprio `169.254.169.126` | Informativo | **401** |
| 63 | Próprio inválido | 429, mesmo fallback | 429 |
| 64 | Próprio com espaço interno | 429, mesmo fallback | 429 |
| 65 | Próprio com vírgula | 429, mesmo fallback | 429 |
| 66 | Próprio com dois valores | 429, mesmo fallback | 429 |
| 67 | Só XFF forjado, sem próprio | 429, mesmo fallback | 429 |
| 68 | Próprio IPv6 válido, XFF sintético diferente | 401, outro bucket | 401 |
| 69–128 | Pelo front, sem cookie da aplicação | 401 em cada | 60 × 401 |
| 129 | Pelo front, 61ª tentativa | 429 | 429 |
| 130 | Front, forja simples de XFF e próprio | 429 | 429 |
| 131 | Front, XFF com vírgula e próprio inválido | 429 | 429 |
| 132 | Front, múltiplos valores em ambos | 429 | 429 |
| 133 | API direta, IP sintético de controle independente | 401 | 401 |
| 134 | Front depois de mais de dois minutos | 401 | **401** |

Fase API: **01:00:15.942–01:00:17.368 UTC**, 68 chamadas. Fase front: **01:01:26.591–01:01:34.564 UTC**, 65 chamadas. Fase final: **01:03:47.319–01:03:47.632 UTC**, uma chamada.

O front ficou sem chamadas de prova por mais de **132 segundos** entre a fase de forjas e a resposta final. As coortes de 60 tentativas e seus controles executaram em menos de 45 segundos; o driver para se exceder esse prazo.

## O que as provas sustentam

- Os valores próprios inválidos, com espaço, vírgula ou múltiplos valores usaram o bucket de fallback esgotado, sem erro 400. XFF sozinho também não selecionou outra partição.
- O caso com próprio IPv6 válido retornou 401 enquanto o fallback estava esgotado. A prova discriminante de XFF ignorado é o caso 67; o 401 isolado do caso 68, com XFF ainda livre, não distingue sozinho qual dos dois valores seria usado.
- Pelo front, as três forjas não escaparam do bucket esgotado. Após a janela, o front voltou a permitir tentativas. Esse é o método de comparação de IP indicado pelo Maestro, sem obter o endereço real.
- A resposta informativa 401 do caso 4 confirma que o IP literal não estava na partição esgotada do fallback naquele momento; não demonstra vulnerabilidade nem prova a causa da diferença.

A API aceita os IPs válidos com configuração de **um único KnownProxy `169.254.169.126`**, conferida na etapa anterior. Isso sustenta correspondência com o peer confiado pela regra de aceitação. **O endereço bruto do socket não foi lido** e a hipótese `::ffff:169.254.169.126` não foi medida.

A igualdade literal entre o IP público e o header encaminhado não foi medida nesta retomada. O resultado registrado é a comparação comportamental autorizada; não declaro observação direta do conteúdo do header no servidor.

Os testes de múltiplos valores usam `HttpClient` com um vetor de dois valores. Não houve captura das linhas HTTP no fio; o transporte pode combiná-las. Os casos locais aprovados da API já cobrem duas linhas, sem ampliar essa alegação para a nuvem.

## Driver, comandos e limites

Driver temporário:

`C:/Users/felip/Documents/FIAP/Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS/solar/worktrees/S-26/.maestri/roles/7eef81c0-93a7-4a6c-9639-cc23e6e924e0/s26-retomar-ip-20261002.ps1`

Comandos executados, código **0** em cada fase:

```powershell
$s26Driver='C:/Users/felip/Documents/FIAP/Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS/solar/worktrees/S-26/.maestri/roles/7eef81c0-93a7-4a6c-9639-cc23e6e924e0/s26-retomar-ip-20261002.ps1'
pwsh -NoProfile -File $s26Driver -Fase Api
pwsh -NoProfile -File $s26Driver -Fase Front
# Aguardar pelo menos 120 segundos desde a ultima coorte front.
pwsh -NoProfile -File $s26Driver -Fase Janela
```

São evidência da execução concluída, não autorização para nova rodada. A fonte integral está no JSON; os dois arquivos temporários de texto foram removidos por caminhos exatos após a consolidação.

Somente `GET /api/painel/leads` nas origens determinísticas da API/front, sem cookie da aplicação, corpo de resposta limitado a 8192 bytes, timeout 20 s, TLS padrão e sem redirects/proxy do ambiente. Token de identidade do operador via helper aprovado, limitado a 20 s, apenas em memória. Não houve impersonação, leitura de valor de segredo, alteração IAM, rota nova ou chamada ao agente nesta retomada.

## Estado dos serviços e próximos gates

Aplicações testadas:

| Repositório | SHA |
|---|---|
| API | `87c491bf88d7ba94be284cdf08ab1ae4efa17724` |
| Front | `af366c0672c625b9fbe01cfe1832d343f4a6f6d3` |
| Agente | `56ff8e09e616be2a6c2b5bf59cd08d7d1b0662b8` |
| Docs antes desta entrega | `ac9fb2c07de3e6a048fb9b36711c1b411e785f3a` |

A etapa anterior conferiu as sete versões **1 ENABLED**, usuário SQL `solar_app`, três revisões Ready privadas, gen2, imagens/digests, limites de instâncias/CPU, CORS e referências de segredos. Também concluiu os nove grupos HTTP anteriores ao caso 4. Esses metadados não foram novamente consultados nesta retomada; nenhuma revisão foi criada ou alterada.

As provas HTTP antes pendentes foram concluídas segundo o ajuste de aceite do Maestro. **A aprovação global da seção 9 fica com sua revisão**, considerando os limites de observação descritos.

A prova **API → agente no primeiro turno real** continua pendente do gate Gemini. Health do agente autenticado pelo líder, já observado na etapa anterior, não substitui essa prova. Publicação, seção 10 e conclusão do card permanecem pendentes.

Não foram solicitadas chamadas Gemini nem SMTP. Não houve SDK de provisionamento/deploy, acesso a valores de segredos, Git push, PR, merge, Notion, alteração de produção ou configuração de modelo. Nenhum teardown nesta ordem: SQL, API de CPU contínua/min1, imagens, segredos e demais recursos continuam sujeitos a custo; a fatura não foi apurada.

**Próximo passo: parar e devolver este relatório ao Maestro.**

## Complemento: comparação relativa com forjas isoladas — ordem do Maestro

A nova ordem proibiu arquivo com IP e consulta externa de IP e especificou uma chamada **só com XFF forjado** e outra **só com X-Solar-Client-IP forjado**. As forjas da rodada inicial combinavam ambos. Executei uma coorte complementar para cumprir os casos separados; as demais provas já concluídas foram preservadas.

**65/65 chamadas conformes**, da primeira chamada às **01:12:25.077 UTC** ao encerramento do driver às **01:14:53.528 UTC**; status observado registrado em todas. Nenhuma falha.

| Etapa | Chamadas globais | Observado |
|---|---|---|
| a: front normal, primeiras 60 | 135–194 | 60 × 401 |
| a: front normal, 61ª | 195 | 429 |
| b: front só XFF fictício | 196 | 429 |
| b: front só X-Solar-Client-IP fictício | 197 | 429 |
| c: API direta, próprio fictício novo | 198 | 401 |
| d: front normal após janela | 199 | 401 |

**(a)+(b) = 5,982 segundos**, menos de 45 s. O driver verifica esse limite durante a coorte e após cada forja. A última chamada ao front começou **mais de 142 segundos** depois da forja própria e retornou 401.

Isso cumpre a comparação relativa de buckets indicada pelo Maestro: as forjas isoladas via front não abriram outra partição; o próprio fictício novo na API direta ficou em partição separada; o front voltou a permitir após a janela. Substitui a comparação de IP, sem obter seu valor. Não houve arquivo de IP, consulta externa, leitura de logs, redeploy ou mudança de produção/IAM.

Comandos executados, ambos código **0**; parser: zero erros:

```powershell
$s26Driver='C:/Users/felip/Documents/FIAP/Fase_5_PRIVACIDADE_SEGURANCA_DE_DADOS/solar/worktrees/S-26/.maestri/roles/7eef81c0-93a7-4a6c-9639-cc23e6e924e0/s26-comparar-isolado-20261002.ps1'
pwsh -NoProfile -File $s26Driver -Fase Bucket
# Aguardar pelo menos 120 s desde a conclusao da coorte.
pwsh -NoProfile -File $s26Driver -Fase Janela
```

Fonte integral e 65 respostas no mesmo JSON, campos `FonteDriverComparacaoIsolada` e `ComparacaoRelativaIsolada`. A evidência da rodada inicial permanece separada e intacta. Os dois helpers adicionais de texto foram removidos por nomes exatos. Nenhuma publicação ou chamada Gemini/SMTP; permanece a parada para revisão do Maestro.

A conferência local da cópia da fonte detectou somente um LF final adicional criado por `apply_patch`. A cópia no JSON foi corrigida para preservar o arquivo completo; conferência final da fonte e dos 199 status passou. Nenhuma prova HTTP foi repetida por esse ajuste.
