---
tipo: decisao
data: 2026-09-07
status: vigente
tags: [decisao, front, angular, privacidade]
---
# Decisão — Front do chat em Angular: proxy no `ng serve`, abertura por kickoff silencioso, e o handoff como fonte de verdade

## Problema

O S-09 tira o `solar-ai-front` do zero. Três perguntas não tinham resposta no card nem no [[Contrato POST turn]]:

1. Como o navegador fala com a API sem esbarrar em CORS.
2. Como a Lia diz a primeira frase, se o agente só responde **a uma mensagem do lead**.
3. Onde mora a direção visual, já que o S-08 foi feito em ferramenta de design e não em código.

## Decisão

### Proxy no `ng serve` para o dev, `AddCors` para o resto

`proxy.conf.json` redireciona `/conversas` e `/turn` para `http://localhost:8080`. Com o `ng serve`, o navegador só fala com `localhost:4200`, então **não há requisição cross-origin** e o front sobe sem depender de nada no outro repo.

Além disso, o `solar-ai-api` ganhou uma política de CORS nomeada (`Program.cs`), com as origens em `Cors:Origens` do `appsettings.json` — `http://localhost:4200` por padrão, sobrescrito por `Cors__Origens__0` no ambiente. `AllowAnyHeader` + `AllowAnyMethod`, sem `AllowCredentials` (não há cookie nem sessão). Lista de origens vazia = nada cross-origin liberado.

Por que os dois: o proxy é o caminho do dia a dia (o front cresce sem tocar na API), e o CORS é o cinto para qualquer acesso direto — `curl` de outro host, o front buildado servido de outra porta, e o S-26 servindo o front no Cloud Run apontando para a API em outro domínio. O card previa `AddCors` como "a primeira coisa que vai quebrar"; agora está feito, e o S-26 só troca a origem, não escreve a política.

### Abertura por kickoff silencioso

Depois do aceite, o front envia uma mensagem fixa (`"Olá"`) que **não é renderizada**. A primeira fala visível na conversa é a resposta da Lia a essa mensagem.

A alternativa — uma primeira frase da Lia escrita no front — criaria uma fala que o backend não conhece e que sairia do roteiro de prompt da [[LangGraph]]. O kickoff mantém o [[Agente stateless]] como única fonte do que a Lia diz.

### O handoff é a fonte de verdade dos tokens

S-08 virou o board **`Solar Chat - Handoff v1.0`** no Claude Design (projeto "Board de interface Lia"): paleta clara e escura com razões de contraste medidas par a par contra WCAG AA, tipografia Libre Franklin, escala de espaçamento, raios, os componentes isolados nos dois temas, dez telas canônicas e a matriz de 11 estados. Os nomes de token do board viraram custom properties em `src/styles.scss`, um a um.

## Motivo

O front é marco crítico e cabe em 4h de card — cada uma das três escolhas evita trabalho que não paga: um segundo repo mexido, um roteiro de conversa duplicado entre front e prompt, e um design reinventado a cada tela.

## Custo aceito

- **A mensagem de abertura precisa ser filtrada do histórico.** Ao recarregar, `GET /conversas/{id}` devolve o `"Olá"` como mensagem do lead. O front descarta a primeira mensagem do lead quando o texto é exatamente o kickoff. Frágil se o texto do kickoff mudar sem o filtro acompanhar.
- **`imoveisSugeridos` não é persistido pela API.** O `MensagemHistorico` do contrato tem só `papel`, `texto` e `em`. Num reload, os cards de turnos antigos não voltam — só o texto da conversa. É consequência de [[Decisao - Conversa em memoria com turno serializado]], não escolha do front.
- **Estado do front em `localStorage`.** `guid` da conversa e o aceite ficam no navegador. Trocar de máquina ou limpar o site perde a conversa. Aceitável até o S-10 dar persistência de verdade.

## O que a UI já entrega da privacidade

Metade do **S-33** ([[Consentimento na abertura]]) vive aqui: aceite **ativo** (checkbox desmarcada por padrão, sem pré-marcação), recusa **reversível** com evento "Conversa não iniciada", e nenhuma mensagem enviada ao provedor antes da marcação e da ação principal. O aviso fala em "provedor de inteligência artificial" — o nome do provedor não aparece na interface — e declara que as mensagens não treinam modelos.

Falta a outra metade: **registrar o consentimento com carimbo de tempo** no backend. Hoje o aceite só existe no `localStorage`.

## Estados implementados

Os 11 da matriz do handoff: aceite pendente, aceite recusado, conversa vazia, pessoa digitando, resposta em preparação, espera prolongada (troca de texto aos 8s), recomendação entregue (pilha de até 3 cards), falha ao responder (com "Tentar novamente" preservando a mensagem), encaminhado ao corretor, e conversa encerrada (composer removido, não desabilitado).

`proximaAcao` do [[Contrato POST turn]] mapeada para eventos de sistema fora das bolhas: `agendar_reuniao` → "Encaminhado", `direcionar_especialista` → "Próxima etapa", `encerrar` → evento terminal. `sugerir_imoveis` e `continuar_conversa` não geram evento.

## Verificado em 07/09

`npm run build` (produção) e `npm test` (2/2) passam. No navegador, contra uma API mock (Docker Desktop não estava de pé): fluxo completo do aceite ao "Encaminhado", nos temas claro e escuro, sem overflow horizontal, kickoff não aparece na trilha. **Ambiente real não exercitado nesta sessão.**

O CORS foi verificado com a API de pé (`dotnet run`, agente fora): preflight `OPTIONS` de `http://localhost:4200` volta `204` com `Access-Control-Allow-Origin`, `-Methods: POST` e `-Headers: content-type`; preflight de `http://evil.example` volta `204` **sem** nenhum header `Access-Control-*`; e o `GET /health` com `Origin` carrega o header na resposta. `dotnet build` sem aviso.

## Conceitos

[[Consentimento na abertura]] · [[Contrato POST turn]] · [[Agente stateless]] · [[Follow-up proativo]] · [[LGPD e GDPR]]

## Relacionadas

- [[Decisao - Canal da demo e chat web com Telegram cortavel]]
- [[Decisao - Conversa em memoria com turno serializado]]
- [[Decisao - Vocabulario do contrato alinhado ao enunciado]]
- [[Decisao - Camada minima de privacidade como Must]]
