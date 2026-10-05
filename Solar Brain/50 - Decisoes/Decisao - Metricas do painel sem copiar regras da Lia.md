---
tipo: decisao
data: 2026-10-03
status: vigente
tags: [decisao, painel, metricas, api, front, lia]
---
# Decisão — Métricas do painel calculadas na API, sem copiar regras da Lia

## Problema

O S-22 nasceu como "três números em cards" e, no briefing original, mandava calcular a "qualificação completa" em SQL **espelhando** a tabela de dados essenciais do Python. Na aprovação do design das métricas, em 03/10, o usuário fechou as regras de dados. Duas delas contradiziam o briefing. O desenho aprovado também precisava de marcos por conversa, que só uma migration e uma mudança no `/turn` dariam.

## Decisão

- **O S-22 virou a Entrega 1**, sem migration, sem mudar a Lia e sem tocar o `/turn`. Ela inclui `GET /api/painel/metricas?dias=30`, com a mesma sessão e o mesmo recorte da fila, os cards principais e a área "Mais métricas".
- **O registro de etapas virou o S-45**, que é Could e cortável e só começa depois do S-38 integrado. Ele cobre o gráfico de avanço, os dados essenciais, o tempo até o encaminhamento e o follow-up.
- **A regra dos dados essenciais fica só na Lia.** A API não copia os critérios por trilha. No S-45, a Lia informará o indicador calculado pelo código determinístico, e a API gravará a primeira confirmação.
- **Base única:** conversas iniciadas no período.
- **"Horários confirmados"** são as conversas iniciadas no período com `mensagens.status_agendamento` confirmado. As reservas dos próximos 7 dias ficam numa linha à parte.
- **Faixas de score:** 0–39 frio, 40–69 morno, 70–100 quente, e "sem avaliação" à parte. Elas valem só para o painel e não mexem no cálculo da Lia nem no encaminhamento.
- **Uma regra, um lugar.** O recorte da fila saiu para `RegrasDaFilaDeLeads`, e o último contato saiu para `ConsultaDeUltimoContato`. A fila, o expurgo do S-39 e as métricas consomem a mesma extração.
- **Conversas antigas não ganham datas inventadas.** Quando o S-45 vier, a falta de registro vai significar "não disponível", e não "não atingiu".

## Por quê

Duas cópias de uma regra divergem em silêncio, e quem lê o painel acreditaria no número errado. A retenção mostrada no painel é a mesma que o expurgo aplica, porque as duas vêm do mesmo código. Separar em duas entregas manteve a Entrega 1 de pé sozinha antes do congelamento de 09/10.

## Custo aceito

- **O que o painel não mostra:** avanço no funil, taxa de dados essenciais e follow-up ficam de fora até o S-45, que pode ser cortado. *Atualização de 05/10: o S-45 foi integrado, e o painel passou a mostrar os três. Ver [[Decisao - Marcos imutaveis e inicio do registro gravado pela migration]].*
- **Agregações em memória:** são feitas na API, sem benchmark. Isso basta para o volume da demo.
- **Bundle do front:** o pacote inicial passou do orçamento de aviso de 500 kB, mas ainda não é erro.

## Relacionadas

- [[Decisao - Score por regua deterministica]]: as faixas leem o score que essa régua produz.
- [[Decisao - Prefixo api separa painel do SPA]]: a rota nova fica sob `/api/painel`.
- [[Decisao - Login unico com tres papeis e sessao de 30 dias]]: a sessão e o perfil definem o recorte das métricas.
