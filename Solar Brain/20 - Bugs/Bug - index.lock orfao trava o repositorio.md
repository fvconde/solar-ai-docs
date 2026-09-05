---
tipo: bug
data: 2026-09-05
status: resolvido
tags: [bug, git, infra, recorrente]
---
# Bug - `index.lock` órfão trava o repositório

**Recorrente.** Já aconteceu duas vezes, em repositórios diferentes. Se acontecer uma terceira, o diagnóstico abaixo resolve em trinta segundos.

## Sintoma

Qualquer comando que escreva no índice (`git add`, `git commit`, `git status` em alguns casos) falha com:

```
fatal: Unable to create '.../.git/index.lock': File exists.
Another git process seems to be running in this repository...
```

Determinístico: falha sempre, até o arquivo sair. O repositório parece funcionar — `git log`, `git remote` e leitura em geral respondem normalmente —, o que faz o problema parecer maior do que é.

## Linha do tempo

- **31/08** — `solar-ai` trava. O commit da fundação não entra. O repo fica sem nenhum commit por cinco dias, apesar de o S-01 constar como feito no board.
- **05/09** — descoberto e resolvido no `solar-ai`, no card S-00. Não virou nota na hora. **Esse foi o erro.**
- **04/09 19:52** — `solar-ai-docs` trava, durante a montagem do vault. Ninguém percebe, porque naquele momento não havia commit sendo feito.
- **05/09** — o primeiro commit do `solar-ai-docs` falha pelo mesmo motivo. Sem a nota, o diagnóstico foi refeito do zero.

## Hipóteses descartadas

- **Repositório corrompido.** Não é. O `.git` está íntegro; só o arquivo de lock sobra.
- **Antivírus ou OneDrive segurando handle.** Plausível no Windows, mas descartado: nenhum processo detinha o arquivo.
- **Outro processo git concorrente.** É o que a mensagem sugere, e é o que faz a pessoa esperar. Não havia nenhum.

## Causa raiz

O git cria `.git/index.lock` antes de escrever no índice e apaga depois. Se o processo morre no meio — terminal fechado, sessão de agente interrompida, IDE encerrada durante um `add` —, o arquivo fica. O git seguinte encontra o lock, presume um git concorrente vivo e recusa.

**O tamanho é o que diagnostica.** Lock de **0 bytes** significa que o git morreu antes de escrever qualquer coisa: o índice não chegou a ser tocado e apagar o lock é seguro. Lock **com conteúdo** significa escrita interrompida no meio, e aí apagar pode deixar o índice inconsistente — nesse caso o certo é `git status`, e se preciso reconstruir o índice.

Ambas as ocorrências foram de 0 bytes.

## Solução

Nunca apagar às cegas. Três checagens, nesta ordem:

```bash
# 1) tamanho e data — 0 bytes indica lock seguro de remover
ls -l .git/index.lock

# 2) existe git vivo?
#    PowerShell: Get-Process git -ErrorAction SilentlyContinue
#    (nenhuma saida = nenhum processo)

# 3) alguem segura o arquivo? (PowerShell)
#    [System.IO.File]::Open($lock,'Open','ReadWrite','None')
#    se abrir sem erro, e orfao
```

Passando as três, `rm -f .git/index.lock` e seguir.

Varredura nos quatro repos de uma vez:

```bash
for d in solar-ai solar-ai-api solar-ai-front solar-ai-docs; do
  [ -f "$d/.git/index.lock" ] && echo "$d: LOCK ($(stat -c%s "$d/.git/index.lock") bytes)"
done
```

## Por que dói mais neste projeto

Quatro repositórios ([[Multi-repo e CI-CD]]) significam quatro lugares onde isso pode acontecer, e um repo travado é silencioso: nada avisa que o trabalho não está sendo versionado. Foi assim que o `solar-ai` passou cinco dias sem um único commit com o board dizendo que o S-01 estava feito. Vale rodar a varredura acima no início de qualquer sessão que vá commitar.

## Conceitos

[[Multi-repo e CI-CD]]
