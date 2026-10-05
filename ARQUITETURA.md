# ARQUITETURA — Solar

> Como as peças se encaixam e onde ficam as fronteiras.
> O **porquê** de cada decisão mora no `ESTADO.md` (linha datada) e no vault `Solar Brain/`.
> Este arquivo é o mapa; ele não repete o raciocínio, aponta para ele.

**Criado em:** 08/09/2026 (S-14) · **Última atualização:** 05/10/2026 (S-45)

---

## Os três serviços

| Serviço | Stack | Papel | Porta |
|---|---|---|---|
| `solar-ai-front` | Angular 20 standalone | Chat do lead e painel do corretor | 4200 |
| `solar-ai-api` | .NET 10 Web API, controllers | Dona do domínio e do estado | 8080 |
| `solar-ai` | Python, FastAPI, LangGraph | Agente conversacional Lia | 8000 |
| `postgres` | Postgres 16 em container | Banco da API | 5432 |

O ambiente local sobe pelo `docker-compose.yml` deste repositório. O Angular roda fora, com `ng serve`.

## As fronteiras, e o que atravessa cada uma

```
navegador ──HTTP──> solar-ai-front ──/conversas/{id}/mensagens, /api/painel──> solar-ai-api ──/turn────> solar-ai
                                                                       │              └─/resumo──> solar-ai
                                                                   EF Core
                                                                       ↓
                                                                   postgres
```

**Front → API.** O front conhece `POST /conversas/{guid}/mensagens` e `GET /conversas/{guid}` para o chat, e `/api/painel/...` para o painel do corretor. O `{guid}` é escolhido pelo cliente e guardado no `localStorage`; a conversa nasce no primeiro POST. O front nunca fala com o agente.

**Painel e página do SPA.** A rota de página `/painel` pertence ao Angular e continua sendo servida pelo front. As operações do painel usam `/api/painel/...`; no desenvolvimento, uma única entrada `/api` do proxy encaminha essas chamadas para a API. Em produção, o reverse proxy precisa conservar a mesma separação.

**Métricas do painel (S-22).** `GET /api/painel/metricas?dias=30` usa a mesma sessão e o mesmo recorte da fila (`GET /api/painel/leads`). O cálculo é feito só com dados do banco, em `ConsultaDeMetricasDoPainel`, e a resposta não traz nome, telefone, e-mail nem texto de mensagem de lead. O recorte da fila mora em `RegrasDaFilaDeLeads`, e o último contato em `ConsultaDeUltimoContato`. A fila, o expurgo do S-39 e as métricas consomem essas duas regras, então quem mudar uma delas muda as três telas. As métricas não copiam regra da Lia, e o porquê está na linha de 03/10 do `ESTADO.md`.

**Avanço das conversas (S-45).** A mesma rota devolve as seguintes métricas:
- `avanco`: seis barras para o supervisor (iniciadas, intenção, essenciais, encaminhamento, corretor e horário) e duas para o corretor (atribuídas e horário);
- `dadosEssenciaisPreenchidos`;
- `periodo.historicoDesde`;
- o tempo mediano até o primeiro encaminhamento, com a série dos últimos 7 dias em UTC;
- o follow-up por janela de resposta (`Metricas:JanelaRespostaFollowUpDias`, padrão 7).

As barras leem **só os marcos gravados em `conversas`**, nunca o estado atual dos encaminhamentos. Por isso, redistribuir um corretor não muda o gráfico. Avanço, essenciais e horários contam apenas conversas cuja primeira mensagem real é igual ou posterior a `historicoDesde`. Intenção, score, atribuição e privacidade continuam contando o recorte inteiro. O porquê está na linha de 05/10 do `ESTADO.md`.

**Conta e sessão (S-44).** Cliente, corretor e supervisor entram pela mesma porta: `POST /api/sessoes`, `GET` e `DELETE /api/sessao`, cadastro em `POST /api/contas` (cliente) e `POST /api/corretores` (corretor, que nasce em análise), conta em `/api/conta`, redefinição de senha em `/api/senha/...` e aprovação de corretor em `/api/painel/corretores/...`. A sessão é um cookie de 30 dias renovado com o uso e revogável no servidor. **Conversa com dono** (`conversas.conta_id` preenchido) só é lida e escrita com a sessão dessa conta; sem ela, a API responde `404`. Conversa sem dono continua funcionando só pelo UUID. Contrato completo em `execucoes/contrato-S-44-0a7099b3-7fe0-4e3b-90e7-81245441c62a.md`; o porquê está na linha de 29/09 do `ESTADO.md`.

**API → agente, primeira fronteira: `POST /turn`.** Contrato congelado no S-05 e espelhado em DTO nos dois repositórios — `app/contrato.py` no Python e `Contracts/ContratoTurno.cs` no .NET. Os dois lados recusam campo desconhecido: se um repo mudar sem o outro, o primeiro turno falha alto em vez de virar `null` silencioso. O S-17 acrescentou `agenda[]` à requisição, `slotEscolhido` à resposta e o tipo `SlotOferecido`. O S-45 acrescentou `essenciaisCompletos` à resposta. Esse valor é calculado no agente por `qualificacao.lacunas_essenciais` e nunca vem do modelo. O espelho tem hoje 7 tipos e 46 campos. **Mudança no contrato exige commit coordenado nos dois repositórios.**

**API → agente, segunda fronteira: `POST /resumo` (S-18).** A primeira fronteira nova desde o congelamento do `/turn`, e ela nasceu barata de propósito: reaproveita `PerfilLead`, `MensagemHistorico` e `ImovelSugerido`, já espelhados, e cria **um tipo novo por lado** — `ResumoResponse`, com `perfil`, `orcamento`, `imoveis`, `objecoes` e `proximoPasso`. Valem as mesmas regras do `/turn`: `extra="forbid"` no Python e `JsonUnmappedMemberHandling.Disallow` no .NET, commit coordenado, e falha do agente virando 502 ou 504, nunca 500. **O `/turn` não foi tocado** — são endpoints separados, e é isso que permitiu a segunda fronteira sem reabrir o contrato congelado.

**Agente → banco: não existe.** O agente é stateless por decisão de arquitetura. Ele recebe histórico e perfil na requisição e devolve a resposta; não abre conexão com o Postgres, não guarda nada entre turnos. Quem funde o perfil, serializa o turno e decide o que persiste é a API.

## Onde mora o estado

Seis tabelas em snake_case, criadas por migration versionada — `leads`, `conversas`, `mensagens`, `corretores`, `encaminhamentos` e `slots` —, com `ON DELETE CASCADE` de `conversas`, `mensagens` e `encaminhamentos` a partir de `leads`. `slots.lead_id` é nulo enquanto livre e volta a nulo se o lead for eliminado; `mensagens.slot_id` preserva o vínculo do evento enquanto o slot existir. Schema nunca é DDL na mão; a API aplica as migrations pendentes no boot. Além das seis, `sessoes` e `recuperacoes_senha` vêm do S-42. O S-38 acrescentou `conversas.chave_exclusao_hash` (bytea, nullable). A última migration é `20261005132141_RegistrarEtapasDasConversas`, do S-45. Ela acrescenta a `conversas` cinco marcos `timestamptz` anuláveis: `intencao_em`, `essenciais_em`, `encaminhada_em`, `corretor_atribuido_em` e `primeiro_reengajamento_em`. Cada marco é gravado uma vez e nunca é reescrito; quem atribuir corretor por um caminho novo precisa chamar `Conversa.RegistrarCorretorAtribuido`. A mesma migration cria `registro_metricas`, com uma linha só (`id = 1`), cujo `historico_desde` é o `now()` do banco no momento da aplicação. **`corretores` guarda todas as contas**, inclusive clientes (`perfil = cliente`, `status_corretor` nulo), e `conversas.conta_id` aponta para ela com `ON DELETE CASCADE`. A deduplicação de lead por telefone e e-mail vale dentro do mesmo dono, não mais no banco inteiro.

`corretores` é a única tabela **semeada**: 5 linhas literais dentro da própria migration, como os 80 imóveis são semeados por JSON. Seed não mora em `HasData` — coleção primitiva ali faz o EF ver o modelo mudando a cada build e o boot cai, com o log culpando o banco (`Solar Brain/20 - Bugs/Bug - HasData com colecao primitiva derruba o boot.md`).

Os slots não ficam presos a datas de migration. Depois de aplicar o schema, a rotina de boot `AgendaInicial` garante ao menos 6 horários futuros livres por corretor ativo, em dias úteis e relativos ao relógio corrente; horários persistidos usam UTC, e a conversão para São Paulo acontece nas bordas.

`encaminhamentos.resumo` é `jsonb` nulável e guarda o resumo já gerado para o corretor (S-18). Nulo ali significa **ainda não gerado**, não "sem conteúdo" — a ausência de conteúdo é expressa pelas cinco seções internas, cada uma nulável por si. É a distinção que evita regerar à toa e queimar cota.

`mensagens.imoveis_sugeridos` é `jsonb` e guarda o **snapshot** do que a Lia mostrou naquele turno, não o id para reconsultar — o motivo é texto escrito sobre aquele lead e a base pode mudar (S-36). A coluna carrega três estados distinguíveis, e a distinção é semântica: **nulo** em fala do lead, lista **vazia** em fala da Lia sem sugestão, lista preenchida quando houve. Quem ler a coluna não pode colapsar nulo e vazio.

A trava por conversa (`TravaDeConversas`, um `SemaphoreSlim`) impede que duas mensagens simultâneas leiam o mesmo histórico e uma atualização de perfil se perca. **Ela só vale dentro de um processo** — com mais de uma instância da API a proteção some sem erro e sem log. Por isso a API publicada pelo S-26 roda com `max-instances=1`, e escalar exige trocar a trava antes.

## O índice vetorial dos imóveis (S-14)

A base simulada é `solar-ai/data/imoveis.json`: 80 imóveis com campos estruturados e uma descrição em prosa.

**Como funciona hoje.** No boot, o agente monta um índice em memória: cabeçalho estruturado + descrição de cada imóvel viram um vetor de 768 dimensões pelo `gemini-embedding-001`, normalizado na construção. A busca é cosseno — produto escalar, já que os dois lados têm norma 1 — em Python puro, sobre 80 vetores. Nenhuma dependência nova entrou no `requirements.txt`.

**Cache por hash da base.** Os vetores ficam versionados em `solar-ai/data/embeddings.json`, gerados por `scripts/gerar_embeddings.py`. O boot só chama a API de embedding se o cache não confere — modelo diferente, dimensão diferente, ou sha256 do corpus mudou. Como o `Dockerfile` copia `data/`, o container sobe **sem rede e sem cota**. Motivo medido: a cota de embedding do free tier é de 100 por minuto e conta **por conteúdo, não por requisição HTTP**, então cada boot sem cache gasta 80 dessas 100 — dois boots no mesmo minuto davam `429`.

**Degradação.** Índice que não sobe não derruba o agente: o `/health` acrescenta o check `indice_imoveis` e o serviço responde `degraded` com HTTP 200. A Lia continua conversando e qualificando; ela só não consulta imóveis. `gemini_config` continua sendo o único check essencial.

**Filtro estruturado.** A busca aceita um recorte vindo do `PerfilLead` — intenção, faixa de preço, quartos, região. `quartos` é piso e não igualdade; `regiao` casa com bairro ou zona, sem acento e sem caixa; preço só filtra com a intenção conhecida, porque é ela que diz se o número se compara a `precoVenda` ou a `precoAluguel`. Filtro que não deixa nada de pé devolve lista vazia de propósito: é fato para a Lia dizer, nunca para ela trocar por um imóvel qualquer.

**Caminho de produção: pgvector.** Índice em memória vale porque a base é pequena, estática e carrega em segundos, e porque mantém o agente stateless sem uma curva de banco no meio do prazo. Deixa de valer quando a base cresce, quando ela muda em runtime, ou quando reconstruir por réplica passa a incomodar. A resposta seguinte é pgvector no Postgres que já existe: os vetores passam a ser coluna, o índice vira IVFFlat ou HNSW e a busca vira SQL. **É escolha de POC, declarada como tal** — decisão registrada em `Solar Brain/50 - Decisoes/Decisao - Indice vetorial em memoria.md`.

## O encaminhamento ao corretor (S-37)

O desfecho passa a desfechar. Quando o turno volta com `agendar_reuniao` ou `direcionar_especialista`, a API escolhe um corretor, grava **uma** linha em `encaminhamentos` — índice único em `conversa_id`, então encaminhar duas vezes não duplica — e devolve o nome ao front.

**A escolha é pura e determinística**, em `Encaminhamentos/EscolhaDeCorretor.cs`: sem banco, sem relógio, mesma entrada e mesma saída. Ordem da regra: especialidade compatível com a trilha (`investimento` → investimento; `compra` e `aluguel` → moradia) → região do lead entre as regiões do corretor → menor carga aberta → desempate por quem está há mais tempo sem receber lead. Sem elegível, a linha sai com `corretor_id` nulo e status `aguardando`, e a conversa segue.

**Região ausente não exclui ninguém.** Não saber onde o lead quer morar não é o mesmo que saber que ninguém atende ali. Já uma região que não casa com corretor nenhum cai em `aguardando`.

O casamento de região **espelha o `_regiao_bate` do `indice.py`**: termo de uma palavra casa como palavra inteira, termo com espaço casa como trecho, sem acento e sem caixa. São duas implementações da mesma regra, em linguagens diferentes — divergência aqui é o risco conhecido desta seção, aceito porque a alternativa devolveria ao agente uma pergunta que `Agente stateless` fechou.

**A escrita é atômica com o turno.** A decisão acontece fora da gravação, e o encaminhamento entra no mesmo `SaveChangesAsync` das duas mensagens e do perfil fundido — turno que falha no agente não deixa encaminhamento, mesma invariante do S-10.

**O nome do corretor não passa pelo LLM.** Ele viaja em `MensagemResponse` e `MensagemDaConversa` — DTOs só do .NET, fora do espelho congelado —, e o front o desenha como evento estruturado da trilha. Sobrevive ao reload porque o `GET /conversas/{id}` o reconstrói do banco.

**Dedupe por contato.** `POST /conversas/{id}/contato` grava nome, telefone e e-mail. Telefone vira dígitos e e-mail vira minúsculas antes de comparar, sob índice único parcial; o mesmo contato visto noutra conversa traz aquela conversa para o lead que já existe, funde o perfil e **apaga o lead provisório**. É o que transforma base de conversas em base de clientes.

## O resumo para o corretor (S-18)

O encaminhamento passa a carregar o que o corretor lê em trinta segundos. `POST /encaminhamentos/{id}/resumo` devolve o `jsonb` já gravado em `encaminhamentos.resumo`; quando ele é nulo, a API reúne perfil, histórico recente e a união deduplicada dos imóveis mostrados, chama o agente, persiste e devolve. `?forcar=true` é a única forma de regerar.

**A geração é preguiçosa e acontece uma vez, fora do turno do lead.** Pôr a segunda chamada dentro de `POST /conversas/{id}/mensagens` faria a pessoa esperar por um texto que ela nunca vê, dentro do orçamento de 45 s e com a trava da conversa segurada — um turno bom viraria `504` sob pressão de cota. Custo real medido: **1 chamada na primeira leitura, zero em todas as seguintes.**

**As cinco seções são nuláveis, e a nulidade é informação.** `perfil`, `orcamento`, `imoveis`, `objecoes` e `proximoPasso` voltam `null` quando não há fato na transcrição que as sustente — seção vazia não é inventada. Isso é asserível por nulo contra preenchido, sem julgar texto, que é a filosofia de teste do projeto desde o S-11. Em conversa real validada na integração, `imoveis` e `objecoes` vieram nulos. **Quem consome não pode tratar nulo como erro nem como "carregando".**

**`objecoes` existe porque o `PerfilLead` descarta a negação de propósito.** Quando o lead diz só o que *não* quer, o campo estruturado fica nulo — `regiao: "exceto zona leste"` viraria consulta ao índice vetorial, e embedding não tem operador de negação (decisão de 07/09). Só a transcrição carrega isso, e ler transcrição para extrair objeção é trabalho de LLM. É a frase que explica o card inteiro: o campo estruturado joga a negação fora porque embedding não entende "exceto"; o resumo a recupera do texto, porque um humano entende.

**Falha de resumo não derruba nada.** O encaminhamento fica de pé com `resumo` nulo e ação de tentar de novo; o turno do lead nunca é afetado.

## O agendamento (S-17)

Os horários só entram na conversa depois do handoff. Antes de chamar o agente, a API consulta no máximo três `slots` futuros e livres do corretor atribuído e os envia em `TurnoRequest.agenda`. O nó puro `agendar` leva essa lista ao prompt; a mesma chamada estruturada do nó `responder` pode devolver `slotEscolhido`. Um gate no Python e outro na API descartam qualquer id que não tenha sido oferecido naquele turno.

**A fala não confirma o banco.** A Lia só declara a intenção de reservar. A API executa um `UPDATE` condicional — corretor correto, slot futuro e `lead_id IS NULL` — na mesma transação que grava as duas mensagens e o encaminhamento. Exatamente uma disputa pode alterar a linha. A vencedora produz o evento estruturado `confirmado`; a perdedora produz `indisponivel` com até três alternativas atuais. O front prefere esse evento ao evento genérico de handoff e o `GET /conversas/{id}` o reconstrói depois do reload.

Agenda vazia não derruba o turno e não autoriza invenção: o prompt orienta a Lia a dizer que a confirmação seguirá pelo contato informado. Se o agente falhar, a transação nem começa; não ficam conversa, encaminhamento ou reserva parciais.

## O follow-up (S-24)

Um `BackgroundService` na API — o primeiro `IHostedService` do projeto — varre conversas inativas e manda a Lia retomar o contato. A varredura e o limiar de inatividade são configuráveis em `FollowUp`: o `appsettings.json` carrega o padrão de produção (inatividade de 2h, varredura a cada 15min) e o `appsettings.Development.json` os valores de demonstração (2min e 30s). **O padrão do arquivo base nunca é o valor da demo** — agente que persegue lead é antipadrão, e o limite de 2 tentativas por conversa é o outro lado dessa mesma regra.

Só é elegível a conversa que está inativa além do limiar, tem menos de 2 tentativas, **tem consentimento válido**, não tem desfecho de encerramento e não foi encaminhada. O estado mora em duas colunas de `conversas`: `tentativas_reengajamento` e `desfecho`.

**O gatilho é um header, e a guarda é estrutural.** `AgenteClient` expõe dois métodos: `TurnoAsync`, que os controllers públicos usam, e `ReengajarAsync`, que acrescenta `X-Solar-Trigger: follow-up`. O agente só ativa o nó reengajador quando esse header chega. Como apenas o serviço de varredura chama `ReengajarAsync`, o caminho de reengajamento é inalcançável a partir do endpoint público — por construção, não por checagem que alguém possa esquecer. O contrato congelado do `/turn` não foi tocado.

**A fala não precede o sucesso.** A transação que grava a mensagem e incrementa o contador só abre depois de o agente responder. Agente fora do ar não deixa mensagem pela metade nem consome tentativa. Só a fala da Lia é persistida: o follow-up não fabrica mensagem do lead.

No front, a aba aberta faz *polling* e a mensagem aparece ao vivo; reabrir a conversa também a traz, porque ela está na trilha como qualquer outra. O controle de ativar e desativar pela interface ainda não existe.

## O grafo da Lia e o supervisor (S-23)

O turno entra por um nó supervisor: `START → supervisor → {qualificador, agendador, consultor, reengajador}`. O supervisor é **função pura, sem chamada ao modelo**, e decide a rota por fato estrutural do estado — reengajamento ativo, slots na requisição, essenciais fechados com intenção de catálogo, ou a rota padrão de qualificação.

**Ele não chamar o LLM não é economia incidental, é o que torna o nó possível.** O critério do card exigia o supervisor e, na mesma frase, que o custo por turno não subisse do patamar de 1 chamada no turno comum e 2 no turno que sugere. Um supervisor movido a modelo custaria uma chamada em todo turno. O porquê está em [ESTADO.md](ESTADO.md) na linha de 13/09.

**Três nós chamam o LLM** — `_responder`, `_reengajar` e `_apresentar`. `_qualificar`, `_pontuar`, `_consultar`, `_agendar` e `_supervisor` são funções puras: régua determinística, fusão de perfil, busca vetorial, injeção de agenda e roteamento. Função determinística é passo de pipeline, não agente — descrever o sistema como agentes autônomos é exagero que não sobrevive à arguição.

Cada turno emite uma linha de log INFO com o GUID da conversa e o nó escolhido, e é por ela que se audita o roteamento sem instrumentar nada.

## Privacidade

Nenhum log, em nenhum dos três serviços, grava dado pessoal em texto claro. No agente, CPF, telefone, e-mail e CEP passam por uma camada única de regex e mapa de tokens antes das **três** fronteiras com o Google: geração da conversa/apresentação, embedding da busca e, desde o S-18, a geração do resumo do corretor. A resposta estruturada do turno é des-tokenizada antes de chegar ao lead, portanto a tela exibe o valor original e nunca a etiqueta interna.

**O resumo é a exceção à des-tokenização, e de propósito.** Ao contrário do turno, os tokens de contato **não** são restaurados na saída do `/resumo`: o corretor lê o telefone real no painel, vindo do banco, e nunca do texto gerado pelo modelo. Restaurar ali colocaria dado de contato dentro de um texto que o modelo escreveu, sem necessidade nenhuma — o painel já tem o dado pela via estruturada do S-37.

**Exceções — o que vai ao modelo em texto claro, e por quê.** Toda exceção mora aqui, nunca na cabeça de ninguém:

- **`nome` do lead, desde o S-06.** Vai em todo `TurnoRequest` dentro do `PerfilLead`, e volta em `CamposExtraidos` porque é o modelo que o extrai da conversa. Mascarar quebraria a função: a Lia chama a pessoa pelo nome, e é isso que sustenta o requisito de "conversa natural". Fica **fora** do mascaramento do S-34, e o consentimento do S-33 tem que cobrir o fato.

- **Valores necessários para qualificação e busca, desde o S-34.** Intenção, faixa de preço, quartos, região, urgência e expectativa de retorno continuam em texto claro porque o modelo precisa deles para extrair o perfil, conduzir a conversa e justificar imóveis. CPF, telefone, e-mail e CEP não têm função nessas decisões e são sempre tokenizados quando aparecem espontaneamente na fala do lead.

**O que deliberadamente não vai, e por construção (S-37):** `telefone` e `email` do lead. Eles entram por formulário próprio (`POST /conversas/{id}/contato`), vão do formulário ao Postgres e do Postgres ao painel — **nunca ao turno**. A garantia não é textual e sim estrutural: o contrato congelado do `/turn` não tem campo para eles, e os dois lados recusam campo desconhecido. `Solar.Api.Tests` afirma por reflexão que nenhum dos 7 tipos do espelho carrega campo de contato, e que o espelho continua com a contagem esperada de campos, 46 desde o S-45. O teste falha antes que qualquer vazamento entre em produção.

O free tier da Gemini usa o conteúdo enviado para treino, e o desenvolvimento roda nele. Enquanto não houver tier pago confirmado, o mascaramento do S-34 é o **único controle real** sobre o que sai daqui. **Desde 11/09 o texto de consentimento do S-33 descreve o regime alvo**, o tier pago, e não o de desenvolvimento: o aviso curto e a página `/privacidade` afirmam, de forma alinhada, que as mensagens não são usadas pelo provedor para treinar ou melhorar modelos. Isso é decisão de produto registrada, não descrição do estado atual — adotar o tier pago é pré-condição para a declaração ser verdadeira em uso real. O README do hub, entregue pelo S-30, usa essas mesmas palavras; os entregáveis não divergem.

**Retenção e eliminação moram no README do hub, e só lá (S-30).** O prazo declarado é de 12 meses contados do último contato, e o pedido de eliminação do titular chega pelo corretor ou pelo atendimento humano, que aciona os endpoints protegidos por `X-Chave-Privacidade`. Aqui fica apenas o fato técnico: **desde o S-39 o prazo é cumprido por rotina** — ver a seção do expurgo abaixo — e o pedido do titular continua sendo atendido sob demanda. Citar daqui, nunca reescrever: texto de conformidade escrito em dois lugares diverge em um.

**Exclusão pelo titular (S-38).** `DELETE /conversas/{id}/titular` é uma porta separada da administrativa. O cabeçalho administrativo não autoriza essa porta, e o cookie do titular não autoriza a administrativa.
- **Prova de posse:** a conversa anônima prova com o cookie `HttpOnly` emitido no consentimento, com `Path=/conversas/{id}`. O banco guarda só o hash, em `conversas.chave_exclusao_hash`. A conversa com conta prova com o login do dono.
- **O que apaga:** a conversa provada, as mensagens e os encaminhamentos dela, com `ExcluirApenasConversaAsync`. O lead só sai, pela cascata do S-29, quando aquela era a única conversa dele. Nunca sai outra conversa, nem da mesma conta, porque a deduplicação por contato pode juntar conversas de pessoas diferentes no mesmo lead.
- **Conversa antiga:** sem hash, recebe 403.

O porquê está nas linhas de 02/10 e 04/10 do `ESTADO.md`.

## O expurgo por retenção (S-39)

Um segundo `BackgroundService` na API, o `ServicoDeExpurgo`, elimina o lead cujo último contato passou do prazo. Mesmo formato do follow-up: configuração em `Expurgo`, padrão de produção no `appsettings.json` (12 meses de prazo, primeira varredura 5 min depois do boot, depois uma por dia) e valores de demonstração só no `appsettings.Development.json`. **O padrão do arquivo base nunca é o valor da demo**, e aqui isso pesa mais que no follow-up: um prazo de demonstração no arquivo base apagaria a base inteira na primeira varredura. Um teste lê o arquivo base e falha se isso acontecer.

**Último contato é a última mensagem com papel `lead`, somando todas as conversas dele.** Fala da Lia, incluindo o follow-up, e encaminhamento não estendem o prazo. Lead sem mensagem conta pela menor data entre `Lead.CriadoEm` e `Conversa.CriadaEm`. Desde o S-22, essa regra mora em `ConsultaDeUltimoContato`, e o card de privacidade das métricas do painel lê a mesma regra.

**Não existe segunda regra de exclusão.** A rotina chama `ConversaRepositorio.ExcluirLeadAsync`, a mesma cascata do S-29, sob `TravaDeConversas.TravarMultiplasAsync`, e revalida a elegibilidade depois de obter a trava — mensagem que chega durante a espera salva o lead. Quem mudar a exclusão muda o expurgo junto. A conta de login nunca é expurgada. O log de expurgo grava só a contagem e o horário: registro de eliminação com identidade recriaria o dado que a eliminação apagou.

## O deploy (S-26)

Os três serviços rodam no Cloud Run (gen2), no projeto `solar-ai-cloud`, em `southamerica-east1`, com Postgres 16 no Cloud SQL. **Só o front é público.** O nginx do front serve o SPA e repassa `/api`, `/conversas`, `/turn`, `/encaminhamentos` e `/health` para a API, com o token de identidade da conta de serviço do front. OpenAPI e Swagger devolvem 404 no próprio nginx, e a API só os expõe em Development. **A API é privada**, e só a conta do front a invoca. **O agente é privado**, e só a conta da API o invoca. A fronteira de confiança entre os serviços é o IAM, não a rede.

**O IP do cliente chega à API num header próprio.** O nginx normaliza o IP, confiando em um único salto (o proxy do Google), e **sobrescreve** `X-Solar-Client-IP`. A API ignora o `X-Forwarded-For` e só aceita esse header quando o peer é o proxy do Cloud Run, com `ForwardLimit=1` (`ProxyTrust`, em `ConfiancaDeProxies.cs`). O IP de saída do front vem de um pool compartilhado do Google e não serve para allow-list. O porquê está em [ESTADO.md](ESTADO.md), na linha de 02/10.

Segredos (conexão do banco, SMTP, chave da Gemini, chave de privacidade e senha inicial do supervisor) ficam no Secret Manager e entram por `--set-secrets`, nunca em imagem ou repositório. O e-mail sai por SMTP do Gmail. A API roda com `max-instances=1`, uma instância mínima e CPU contínua, porque o follow-up e o expurgo rodam em background. Front e agente escalam a zero. O deploy é manual, por scripts PowerShell em `solar-ai-docs/deploy/S-26/`; pipeline automático é o escopo do S-27 e do S-28.

## Regras que não mudam

- O agente Python é stateless e **nunca** acessa o banco.
- O contrato do `POST /turn` é versionado nos dois repos; mudança exige commit coordenado.
- Prompts da Lia vivem em `solar-ai/prompts/`, nunca embutidos no código.
- Nenhum segredo em repositório, em nenhuma hipótese.
- Modelo do LLM e do embedding são **fixos**, nunca alias: `-latest` é ponteiro móvel e muda o comportamento sozinho.
