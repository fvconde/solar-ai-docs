---
tipo: decisao
data: 2026-09-09
status: vigente
tags: [decisao, produto, ia, contrato]
---
# Decisão — A agenda viaja na requisição, e o agendador é nó do grafo

## Problema

[[Decisao - Agenda simulada por slots]] resolveu *onde* a agenda mora — tabela de slots no Postgres, sem Google Calendar. Ficou de fora *como* a Lia a enxerga.

Dois fatos que não se conciliam sozinhos: os slots são do banco, e o [[Agente stateless]] nunca abre conexão com ele. E a Lia não pode inventar horário, pela mesma regra que a impede de inventar imóvel — *"os imóveis vêm da base, nunca da sua memória"*.

O S-17 carregava ainda uma pergunta em aberto: o agendador seria nó do grafo, ou os horários seriam devolvidos como dado e interpretados pelo .NET, deixando o [[Contrato POST turn]] intacto?

## Decisão

**A pergunta em aberto foi respondida de lado.** Escolher a opção B no S-23 — construir o supervisor de verdade — obriga o agendador a existir como nó: o critério do S-23 roteia para *"qualificador, consultor, agendador ou reengajador"*, e não há como rotear para algo que não existe. A alternativa barata deixou de estar disponível.

Daí, cinco pontos:

1. **A agenda viaja na requisição.** `TurnoRequest` ganha `agenda` — os slots livres do corretor que o encaminhamento atribuiu, lista vazia enquanto não houver encaminhamento.
2. **O nó `agendar` é puro** e injeta o bloco da agenda no `turno.md`; o `slotEscolhido` sai na **mesma saída estruturada** do `responder`. Padrão `qualificar`/`pontuar` de [[Decisao - Score por regua deterministica]]: **nenhuma chamada extra por turno**.
3. **Um gate descarta id fora da lista oferecida**, como em [[Decisao - Motivo do LLM como portao do cartao]]. Id inventado vira ambiguidade, não reserva errada.
4. **A reserva é update condicional no .NET**, e o horário confirmado aparece como **evento estruturado** na trilha — nunca no texto do LLM. A fala da Lia declara intenção ("vou reservar quinta às 15h"); o fato do banco é dado.
5. **Os horários só aparecem no turno seguinte ao handoff**, porque o corretor é atribuído depois que o agente responde.

## Motivo

O ponto 1 é o único desenho possível: sem receber os slots, a Lia ou inventa horário ou o agente vira stateful. Os dois são inaceitáveis, e o primeiro é pior — quebra a mesma promessa que sustenta o cartão de imóvel.

O ponto 4 é o que evita a Lia mentir. Numa corrida entre dois leads pelo mesmo slot, uma frase gerada antes da reserva afirmaria um fato que falhou. Separando intenção (texto) de confirmação (evento), a corrida perdida vira um evento honesto com alternativas, e a conversa continua.

## Custo aceito

**Segunda emenda do contrato congelado**, com commit coordenado nos dois repositórios — o espelho vai de 6 tipos e 37 campos para 7 e 42. A requisição cresce um pouco em toda conversa já encaminhada. E a agenda não pode ser semeada por migration com datas fixas: uma migration é estática, e slots gravados hoje estarão no passado em 29/09 — a geração tem que ser rotina de boot, relativa à data corrente.

## Consequência

Como este card já paga o commit coordenado e a migration, o `tipo` de imóvel — hoje heurística de palavra em `indice.tipo_pedido`, dívida do S-15 endereçada a um S-35 que não cabe na janela — pode pegar carona por cerca de 45 min em vez das 1 a 2h estimadas isoladamente. Decisão a tomar ao abrir o card.

## Conceitos

[[Agente stateless]] · [[Contrato POST turn]] · [[LangGraph]] · [[Regua de qualificacao]] · [[Gemini free tier]]

## Relacionadas

- [[Decisao - Agenda simulada por slots]] — amplia: aquela disse onde a agenda mora, esta diz como a Lia a enxerga
- [[Decisao - Agente Python stateless]] — a restrição que força a agenda a viajar na requisição
- [[Decisao - Contrato do POST turn congelado]] — a segunda emenda, com o mesmo mecanismo que tornou a primeira segura
- [[Decisao - Um no com saida estruturada]] — por que o `slotEscolhido` não custa chamada nova
- [[Decisao - Motivo do LLM como portao do cartao]] — o gate contra id inventado
- [[Decisao - Resumo do corretor escrito pelo LLM]] — mesma sessão, mesmo princípio: fato do banco não passa pelo texto do modelo
