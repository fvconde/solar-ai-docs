---
tipo: bug
tags: [bug, cota, ia, api]
---
# Bug — turno real vira 504 sob pressão da cota por minuto

## Sintoma

`POST :8080/conversas/{guid}/mensagens` devolve **504**:

```json
{ "title": "agente indisponivel", "status": 504,
  "detail": "o agente nao respondeu em 45s" }
```

Nada no código está errado. O mesmo turno, ~90 s depois, responde em **7,9 s**.

## Por que isso não é o timeout mal calibrado

`Agente:TimeoutSegundos` vale 45 s desde o S-06, quando o pior caso medido era 30,5 s. Sob cota saudável um turno leva de 1 a 8 s — sobra folga de cinco vezes.

O que estoura não é o modelo: é o [[Gemini free tier]] em **limite por minuto**, com o SDK em backoff silencioso. Ele repete sozinho e o que chega ao código é uma chamada que demorou muito, não um `429` (ver [[Bug - latencia de 30s por limite por minuto]]). Subir o timeout só faria o usuário esperar mais por uma resposta que a cota já atrasou.

## Linha do tempo — S-12, 07/09

1. `pytest -m llm` completo: 27 chamadas em 1009 s, média **37 s** por chamada. A cota por minuto já estava saturada.
2. Ponta a ponta iniciado **em seguida**, sem intervalo. Turno 1 → **504** em 45 s.
3. Conferido o banco: a conversa daquele guid tem **zero linhas**. Nem conversa vazia.
4. Pausa de ~90 s.
5. Os mesmos 4 turnos: **7,9 s · 1,3 s · 2,2 s · 4,9 s**. Score 25 → 45 → 65 → 75, tudo gravado.

## O que isso confirmou de bom

O invariante do S-10 — **turno que falha não deixa rastro** — foi exercitado por uma falha real, não simulada. O `RegistrarTurno` só roda depois da resposta do agente, e o `ObterOuCriar` rastreia a conversa nova em vez de gravá-la ([[Decisao - Persistencia em EF Core com Postgres]]). Resultado: um 504 no primeiro turno de uma conversa nova não deixa conversa órfã no banco.

## Consequências práticas

- **Não rodar suíte nem regravar roteiros na hora anterior à gravação do vídeo.** A cota é compartilhada entre teste e demo: se a suíte satura o minuto, a demo ao vivo dá 504 na frente da banca.
- Depois de uma bateria de chamadas, esperar ~90 s antes de qualquer verificação manual — senão o que se mede é a cota, não o código.
- Se um 504 aparecer no S-26 (Cloud Run) com o serviço saudável, suspeitar disto antes de suspeitar de rede.

## Relacionadas

- [[Bug - latencia de 30s por limite por minuto]] — a mesma cota, vista pelo lado da latência
- [[Gemini free tier]] — as duas cotas, e os números
- [[Decisao - Persistencia em EF Core com Postgres]] — o invariante que esta falha confirmou
- [[Decisao - Contrato do POST turn congelado]] — de onde vem o mapeamento 504
