---
tipo: decisao
data: 2026-10-01
status: vigente
tags: [decisao, arquitetura, deploy, seguranca, api, front]
---
# Decisão — Só o front é público; API e agente ficam privados por IAM no Cloud Run

## Problema

O S-26 publicou os três serviços no Cloud Run, no projeto `solar-ai-cloud`, em `southamerica-east1`. Com um serviço público por camada, qualquer pessoa chamaria a API e o agente direto, sem passar pelo front. E o rate limit da API, que conta por IP, precisava saber o IP real do cliente.

As medições do diagnóstico, em 01/10, mostraram que o IP de saída do front não serve para isso. A API recebe toda chamada vinda do mesmo peer link-local do proxy do Cloud Run (`169.254.169.126`, ambiente gen2). Esse peer não identifica o front: qualquer chamador autenticado chega por ele. O IP de saída do front sai de um pool dinâmico e compartilhado do Google, sem exclusividade. Usar esse IP numa allow-list, ou confiar em mais um salto do `X-Forwarded-For`, deixaria o rate limit nas mãos de quem forja o header.

## Decisão

- **Só o front é público** (`allUsers` com `run.invoker`). O nginx do front serve o SPA e repassa `/api`, `/conversas`, `/turn`, `/encaminhamentos` e `/health` para a API, com token de identidade do Cloud Run. OpenAPI e Swagger devolvem 404 já no nginx.
- **A API é privada.** Só a conta de serviço do front tem `run.invoker` nela. **O agente é privado**, e só a conta de serviço da API o invoca. A fronteira de confiança é o IAM, não a rede.
- **O IP do cliente viaja num header próprio.** O nginx normaliza o IP (confia em um salto, o do proxy do Google) e **sobrescreve** `X-Solar-Client-IP`. A API lê esse header (`ProxyTrust:ForwardedForHeaderName`, que só aceita dois valores) e ignora o `X-Forwarded-For`. Só confia nele quando o peer é `169.254.169.126`, com `ForwardLimit=1`. Um `X-Solar-Client-IP` ou `X-Forwarded-For` forjado pelo cliente não muda o IP efetivo nem o rate limit, o que foi provado na URL publicada.
- A API sobe com `max-instances=1`, porque a `TravaDeConversas` só vale dentro de um processo, e com CPU contínua e uma instância mínima, porque o follow-up e o expurgo rodam em background. Front e agente escalam a zero.

## Consequências

- Os owners do projeto também conseguem invocar a API e o agente. É limite aceito e documentado.
- A propagação de um binding IAM leva cerca de 2 minutos. O deploy espera por ela com sonda e limite de 10 minutos, senão o primeiro acesso dá 403 ou 502.
- O guard de URL dos scripts aceita a `status.url` com hash quando a URL determinística aparece em `run.googleapis.com/urls`.
- Se o peer da API mudar num deploy futuro, a regra é **parar**, não ampliar a lista de proxies confiáveis.
- Custo de referência, de 30/09: cerca de USD 74/mês para API mais Cloud SQL, que continuam ligados até o teardown com `Desmontar.ps1`.

## Relacionadas

- [[Decisao - Prefixo api separa painel do SPA]]: o nginx do front conserva a separação entre `/api` e `/painel`.
- [[Decisao - Login unico com tres papeis e sessao de 30 dias]]: o painel publicado é protegido pela sessão, não por rede.
- [[Decisao - Conversa em memoria com turno serializado]]: a origem da trava que obriga a instância única.
- [[Decisao - Dois projetos Google separados]]
