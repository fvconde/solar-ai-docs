---
tipo: bug
tags: [bug, front, dados]
---
# Bug — falha de rede ao retomar apagava a conversa para sempre

## Sintoma

Nenhum. É esse o problema.

O lead abre o chat, a API está fora do ar por um instante, e a página carrega mostrando uma conversa nova em branco. Nada de errado aparece na tela. A conversa anterior — histórico, perfil, score — continua no Postgres, mas **ninguém consegue mais chegar nela**, porque o único ponteiro para ela era o `guid` no `localStorage` do navegador, e ele acabou de ser sobrescrito.

## Causa

O `iniciar()` do `ConversaStore` tinha esta forma:

```ts
const salva = this.ler(CHAVE_CONVERSA);
if (salva) {
  try {
    ...
    return;
  } catch {
    this.itens.set([]);   // engole o erro
  }
}
await this.abrir();        // <- gera guid NOVO e sobrescreve o localStorage
```

O `catch` limpava a tela e **caía para fora do `if`**. O `abrir()` então fazia `crypto.randomUUID()` e gravava o guid novo por cima do antigo.

Ou seja: **um `catch` vazio virou perda de dados**, porque o fluxo de erro compartilhava a saída com o fluxo de "não havia conversa salva".

## Por que passou despercebido até o S-13

O S-09 nasceu contra uma API mock que não falhava, e o caminho de retomada só é exercitado quando existe conversa salva **e** a API não responde — combinação que não aparece em uso normal nem em teste de caminho feliz. Achado durante a leitura do código para o S-13, não por um sintoma reportado.

## Solução

O bloco do `if` passou a ter `return` incondicional: a falha mostra um evento de erro com "Tentar novamente" e **preserva o guid**. O `abrir()` só roda quando genuinamente não há conversa salva.

```ts
if (salva) {
  try { ... } catch { this.registrarFalhaAoRetomar(); }
  return;                  // <- o que faltava
}
await this.abrir();
```

Sob teste, e a asserção é a que interessa:

```ts
it('falha ao retomar NAO cria conversa nova nem troca o guid salvo', ...)
expect(localStorage.getItem('solar.conversaId')).toBe('c1');
```

## A lição

> **Fluxo de erro que cai no fluxo normal é pior que erro que estoura.**

O `catch` parecia defensivo — limpava a tela e seguia. O que ele fazia era transformar uma falha temporária de rede numa perda permanente e silenciosa. Quando o `catch` não tem o que fazer, o mínimo é não deixar o código continuar como se nada tivesse acontecido.

Vale procurar o mesmo padrão nos outros `try/catch` do front antes do congelamento.

## Relacionadas

- [[Decisao - Front do chat em Angular]] — onde o `localStorage` virou o único ponteiro para a conversa
- [[Decisao - DTO proprio para a releitura da conversa]] — a outra metade do S-13
- [[Bug - turno real vira 504 sob cota por minuto]] — a falha de rede que torna este cenário realista
