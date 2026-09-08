---
tipo: decisao
data: 2026-09-07
status: vigente
tags: [decisao, ia, produto]
---
# Decisão — Score por régua determinística, não por LLM

## Problema

Até o S-11, o `score` saía do mesmo nó e da mesma chamada que escrevia a resposta da Lia. Medido: regravando os mesmos seis roteiros **sem mudança relevante de prompt**, o score se moveu até **20 pontos** com entrada idêntica — 40→60, 30→20, 10→5, 30→40.

A direção estava certa: lead vago embaixo, decidido em cima. A granularidade não existia. E é esse número que o painel do S-19 mostra e que ordena a fila do corretor, onde 65 e 75 precisam significar coisas diferentes.

Some-se o que o card do S-12 já pedia: *"no pitch você precisa conseguir justificar o número"*. Um score que sai de um prompt não se justifica — se justifica a intenção do prompt.

## Decisão

O score é **regra determinística sobre o perfil**, calculada em nó próprio do grafo. O LLM deixou de pontuar: `CamposExtraidosLLM` é o `CamposExtraidos` do contrato **menos** o `score`, e a seção `score` saiu do `turno.md`.

Uma tabela de sinais por trilha, cada uma somando 100:

| moradia (compra/aluguel) | peso | | investimento | peso |
|---|---|---|---|---|
| intenção definida ✱ | 25 | | intenção definida ✱ | 25 |
| região ✱ | 20 | | ticket (faixa de preço) ✱ | 20 |
| faixa de preço ✱ | 20 | | expectativa de retorno ✱ | 20 |
| prazo (urgência) | 15 / 9 / 5 | | região | 15 |
| quartos | 10 | | prazo (urgência) | 10 / 6 / 3 |
| nome | 10 | | nome | 10 |

✱ = sinal **essencial**, ver abaixo.

## Motivo

**Duas trilhas, não uma.** Um investidor nunca informa `quartos` — na régua única, um investidor totalmente qualificado ficaria eternamente abaixo de um lead de moradia pior. A troca é limpa porque o [[Contrato POST turn]] já tem o campo que substitui: `quartos` sai, `expectativaRetorno` entra, e o `persona.md` já dizia em prosa que para quem investe "quartos e quando se mudar não fazem sentido".

**A mesma tabela gera a próxima pergunta.** A lacuna que mais vale pontos é a próxima pergunta. Uma regra, duas respostas — e é isso que entrega o "o agente decide sozinho qual a próxima pergunta" do aceite do card. O invariante `score + soma das lacunas abertas == 100` está sob teste.

**Urgência com pontos explícitos, não fator.** A primeira versão usava um multiplicador (`1.0 / 0.6 / 0.3`) e `round(15 * 0.3)` deu **4**, não 5: Python arredonda para o par mais próximo. Numa régua cujo propósito é ser explicável no pitch, "por que 4 e não 5" é uma pergunta que não se quer ter. Os pontos estão escritos um a um na tabela.

**Score monotônico é feature, não limitação.** O prompt antigo mandava o score *descer* com resposta vaga. A régua não desce: um lead vago simplesmente não acumula. Para ordenar uma fila, monotonia é o que se quer — e "por que caiu?" deixa de existir como pergunta.

## Onde mora: no agente Python

Não é escolha de gosto. O nó qualificador precisa da tabela de pesos para decidir a próxima pergunta, então a tabela existe em Python de qualquer jeito. Pôr o `pontuar` no .NET criaria uma **segunda cópia da mesma tabela em outra linguagem**, com a divergência falhando em silêncio.

Consequência: o [[Contrato POST turn]] fica **intacto** — `score` continua saindo em `camposExtraidos` e o `Lead.Fundir` do .NET não muda uma linha. Zero commit coordenado, o que é raro numa mudança deste tamanho.

O agente continua stateless ([[Agente stateless]]): ele funde `camposExtraidos` no perfil **em memória, dentro da requisição**, só para pontuar. Quem persiste continua sendo a API. O `qualificacao.fundir` espelha o `Lead.Fundir` nas duas regras que importam — nulo não apaga, `indefinida` não apaga intenção conhecida — e está sob teste.

## Três nós, uma chamada

```
START → qualificar → responder → pontuar → END
        (puro)       (Gemini)    (puro)
```

A [[Decisao - Um no com saida estruturada]] adiou a separação em nós porque dois nós **dobrariam a cota por turno**. Isso continua verdade e continua respeitado: os dois nós novos são puros, e o custo segue em **uma** chamada ao [[Gemini free tier]] por turno. A promessa daquela decisão — "a separação volta quando tiver trabalho próprio, no S-12" — foi cumprida sem pagar o preço que ela temia.

## Sinal essencial, e por que ele precisou existir

A primeira versão não tinha essa noção. Ela nasceu de uma falha real: com o investidor de ticket e expectativa já conhecidos, a lista de lacunas ainda mostrava região, prazo e nome, e a Lia **continuou perguntando** em vez de devolver `direcionar_especialista`. Falhou 3 de 3 — sistemático, não intermitente.

O conserto é a régua encodar os dois limiares que o `turno.md` só enunciava em prosa. Cada trilha marca os sinais que um humano precisa antes de assumir, e eles são exatamente o que o prompt já dizia:

- **moradia**: intenção, região, preço — *"quem ainda não disse nem o que quer, nem onde, nem quanto não está pronto para um corretor"*
- **investimento**: intenção, ticket, expectativa — a regra congelada do `direcionar_especialista`, palavra por palavra

**Essencial é piso, não gatilho.** Essa distinção custou uma iteração inteira: ao tratar o piso como condição suficiente, a Lia parou de qualificar assim que ele fechava, e num roteiro de 6 turnos repetiu "vou passar para um corretor" três vezes seguidas enquanto o lead ainda oferecia dados. Só a trilha de investimento tem gatilho — o `DESFECHO_DA_TRILHA` —, porque só ela tem regra positiva no contrato. Em moradia, o piso libera o handoff **quando a pessoa pedir**, e nada mais.

## O que realmente estava quebrando o investidor

Quatro tentativas de resolver com texto de prompt falharam antes de o diagnóstico aparecer, e ele não estava no código novo. O `turno.md` já trazia, desde o S-06, uma frase genérica logo abaixo do enum:

> *"Enquanto faltar informação para o corretor assumir, é `continuar_conversa`."*

Enquanto não havia lista de lacunas, "faltar informação" não tinha referente concreto e a regra do `direcionar_especialista` ganhava. **A lista passou a fornecer a evidência** de que faltava informação — região, prazo, nome, escritos ali — e a frase genérica passou a vencer a regra específica.

O conserto foi dar àquela frase o escopo que ela sempre quis dizer: falta **essencial**, não falta qualquer coisa. Item não essencial aberto não segura desfecho nenhum.

**A lição generalizável:** ao injetar informação nova num prompt, procurar as frases antigas que ficaram vagas por falta de dado. Elas não estavam erradas; estavam inertes. Dar dado a uma regra vaga é ativá-la, e ela pode ativar contra você.

## O bloco é informação, não comando

A primeira versão do bloco era uma **fila numerada de perguntas** com instruções imperativas ("pergunte o primeiro item", "siga para o próximo") e parágrafos de exceção. Cada correção adicionava mais texto disputando prioridade com o procedimento de `proximaAcao`, e a falha só mudava de lugar — em uma das rodadas a Lia chegou a errar um preço na resposta, dizendo "70.000" para um teto de 700 mil.

A versão final é curta e declarativa: as lacunas em prosa, separadas por ponto e vírgula, uma frase devolvendo a decisão (*"a regra de `proximaAcao` decide se há próxima pergunta; esta lista só decide qual seria"*) e, quando cabe, uma linha de fato sobre o piso ou sobre a regra já satisfeita. Nenhum imperativo, nenhuma lista numerada.

**A lição:** lista numerada num prompt lê como checklist a cumprir, e ganha de regra em prosa escrita quarenta linhas abaixo. Prosa compete com prosa.

## O nó calcula lacunas antes do turno

Limitação estrutural, não bug: `qualificar` roda sobre o perfil que **chegou**, então o turno que fecha um limiar sempre o vê aberto. Foi isso que quebrou o turno de transição do investidor — aquele em que o lead informa a expectativa de retorno.

Não dá para calcular depois: o desfecho precisa ir no mesmo prompt que produz a resposta. A saída foi o bloco declarar o que sabe e o que não sabe — *"esta lista foi montada sem a mensagem de agora; se ela fechar o que faltava, o essencial está fechado"* — e o `turno.md` mandar contar a mensagem antes de aplicar o piso. Honestidade sobre o limite do dado resolveu o que quatro reformulações imperativas não resolveram.

## Custo aceito

- A régua não lê **qualidade** de resposta, só presença. Quem diz "uns 500 mil, sei lá" pontua igual a quem diz "meu teto é 500 mil". Era exatamente o que o LLM prometia fazer e não fazia de forma reprodutível — trocou-se sensibilidade fingida por grosseria honesta.
- Os pesos são julgamento de produto, não medida. Não há base rotulada para calibrá-los, e não haverá ([[Decisao - Nenhum ML classico no escopo]]). São defensáveis, não ótimos.
- O score assume valores de um conjunto pequeno e discreto. Dois leads com os mesmos sinais empatam — e empatam **de propósito**.
- A regra de fusão perfil ⊕ extraídos passa a existir nos dois repositórios. É a mesma regra trivial, está sob teste dos dois lados, mas são duas cópias.

## Emenda a decisões anteriores

Corrige o **motivo** da [[Decisao - Nenhum ML classico no escopo]], não a decisão. Aquela linha justificava não treinar classificador dizendo que *"o score já sai do nó qualificador do S-12, via LLM"*. A conclusão continua certa e ficou **mais** forte: agora o score é reprodutível e explicável, que é mais do que um classificador treinado em base sintética entregaria.

## Conceitos

[[Qualificacao de leads]] · [[LangGraph]] · [[Contrato POST turn]] · [[Agente stateless]] · [[Testar a Lia]] · [[Gemini free tier]]

## Relacionadas

- [[Decisao - Um no com saida estruturada]] — a decisão que adiou esta separação, e a condição que ela pôs para voltar
- [[Decisao - Nenhum ML classico no escopo]] — o motivo emendado acima
- [[Decisao - Testes do agente em duas superficies]] — o gate que provou que a separação não quebrou a extração
- [[Decisao - Vocabulario do contrato alinhado ao enunciado]] — de onde vem a regra congelada do `direcionar_especialista`
