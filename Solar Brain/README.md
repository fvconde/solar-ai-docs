# Solar Brain — memória técnica do projeto

Vault do Obsidian em português. Registra o **contexto que o código não mostra**: por que cada decisão foi tomada, o que ela custou, e os conceitos técnicos no recorte deste projeto.

A regra que decide o que entra aqui:

> **Se a IA errou porque faltava contexto, esse contexto precisa virar nota.**

## Como abrir

1. Instalar o [Obsidian](https://obsidian.md) (gratuito).
2. *Open folder as vault* → apontar para `solar-ai-docs/Solar Brain`.
3. `Ctrl+G` abre o **Graph View**.

A pasta `.obsidian/` fica no `.gitignore` — a configuração local não é versionada, só as notas.

## Estrutura

```
Solar Brain/
  10 - Projeto/     nota-hub que conecta tudo — comece por Solar.md
  20 - Bugs/        Bug - <titulo>.md — investigações resolvidas (vazio até a Fase 1)
  30 - Conceitos/   um conceito técnico por nota, no recorte do Solar
  50 - Decisoes/    Decisao - <titulo>.md — uma por linha da seção Decisões do ESTADO.md
```

## Relação com o ESTADO.md

O `ESTADO.md` continua sendo a **fonte única da verdade** e a seção `Decisões` continua **append-only**. Nada foi movido para cá.

- **ESTADO.md** → a linha curta e datada: *o que* foi decidido, e onde o projeto está.
- **Solar Brain** → a versão expandida: problema, motivo, custo aceito, e as conexões.

Cada linha da seção `Decisões` do ESTADO.md ganhou um link para a nota correspondente. Se as duas discordarem, **o ESTADO.md ganha**.

## Convenções

- **Nomes de arquivo sem acento** — evita atrito entre Windows, Linux e git. O texto dentro da nota usa acentuação normal.
- **Decisão** nunca é reescrita. Mudou de ideia? Nota nova, com link para a antiga, e `status: revogada` no frontmatter da velha.
- **Conceito** é sempre no recorte do Solar. Não se documenta o que é RAG em geral — documenta-se o que RAG significa *aqui*.
- Toda nota nova nasce ligada a pelo menos uma existente. Nota órfã não aparece no grafo, e o que não aparece no grafo se perde.
