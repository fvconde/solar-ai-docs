# Decisão — Mascaramento nas duas fronteiras com o Google

**Data:** 11/09/2026
**Card:** S-34 · Mascaramento de PII antes do LLM e nos logs
**Execução:** `002fad00-fcc8-4bf4-98f6-25ecfb91ba50`
**Integrado:** `solar-ai` `ad055f5` (PR #2), `solar-ai-docs` `e8cb761` (PR #4)

## O que foi decidido

CPF, telefone, e-mail e CEP são trocados por etiquetas antes de **toda** saída para a API do Google, e a resposta estruturada volta des-tokenizada antes de chegar ao lead.

Duas decisões dentro dessa frase, e nenhuma das duas estava no card.

## Primeira: são duas fronteiras, não uma

O card falava do LLM. A leitura literal protegeria `_invocar` e pararia ali — e deixaria o `embed_query` da busca do S-15 mandando a fala crua do lead para a mesma API, com a mesma política de free tier, pela porta ao lado. Um lead que escreve "moro perto do 01310-100, meu whats é (11) 98765-4321, quero algo na região" tem esse texto virando consulta ao índice desde o S-15, porque `texto_da_consulta` compõe a busca com a mensagem do turno.

Então a cobertura foi ampliada antes da reserva do card:

- **Geração** — `_invocar` virou funil único. `_responder` e `_apresentar` passam por ele, e `_mensagens_mascaradas` é a última barreira: nenhum texto cru atravessa, inclusive dentro de conteúdo em lista ou dicionário.
- **Embedding** — `Indice.buscar` recebe o mesmo `MascaradorPII` do turno e mascara antes do `embed_query`.

O parâmetro `mascarador` de `buscar` é opcional e, quando ausente, constrói um mascarador descartável. Isso é fail-safe deliberado: quem chamar `buscar` esquecendo de passar o mapa ainda manda etiqueta para o Google — perde só a reversibilidade, que no caminho do embedding não é usada.

## Segunda: a resposta volta des-tokenizada

A alternativa barata era deixar a etiqueta subir. Ela funciona, é mais simples, e teria mostrado `[TELEFONE_1]` no meio da fala da Lia. `_desmascarar_saida` reverte campo a campo antes do DTO, então o lead lê o valor que escreveu e o Google recebeu a etiqueta.

O mapa vive dentro do `EstadoTurno`, nasce em `responder()` e morre com o turno. Não há mapa global, não há persistência, e dois turnos da mesma conversa não compartilham numeração de token.

## O que continua em texto claro, e por quê

Toda exceção mora no `ARQUITETURA.md`, nunca na cabeça de ninguém. Duas entradas:

- **`nome` do lead**, desde o S-06. Mascarar quebraria a função — a Lia chama a pessoa pelo nome, e é isso que sustenta o requisito de conversa natural. O consentimento do S-33 tem que cobrir o fato.
- **Valores de qualificação e busca**, desde este card. Intenção, faixa de preço, quartos, região, urgência e expectativa de retorno vão em claro porque o modelo precisa deles para extrair o perfil, conduzir a conversa e justificar imóveis. A distinção que separa os dois grupos é função, não sensibilidade: CPF, telefone, e-mail e CEP não participam de nenhuma dessas decisões.

Vale lembrar que `telefone` e `email` do lead já não chegavam ao turno desde o S-37, e a garantia lá é estrutural — não existe campo para eles no contrato congelado. O mascaramento cobre o caso diferente: o lead digitar o número **espontaneamente no meio da conversa**, que nenhum contrato impede.

## Limitações conhecidas, aceitas com motivo

A ambiguidade numérica do pt-BR é real: CPF tem 11 dígitos, celular com DDD também tem 11, CEP tem 8, e fixo com DDD tem 10. Sem pontuação, o número sozinho não diz o que é.

A camada resolve por três caminhos, em ordem: formato pontuado (`123.456.789-09`, `(11) 98765-4321`, `01310-100`); rótulo escrito pelo lead (`meu cpf é 12345678909`); e, sem rótulo, validação de dígito verificador do CPF mais tabela de DDDs válidos para telefone.

O que sobra em claro, de propósito:

1. **Número solto de 8 dígitos.** `_NUMERO_LONGO` cobre 10–11. `meu cep é 01310100` é pego pelo rótulo; `01310100` sozinho não é.
2. **Número de 11 dígitos que não é CPF válido nem tem DDD conhecido.**

O preço de fechar esses dois seria tokenizar preço, metragem e código de imóvel — que são exatamente os valores que o modelo precisa ler para trabalhar. Falso positivo aqui custa mais que falso negativo: um preço virando `[CPF_3]` quebra a qualificação em todo turno, enquanto o caso descoberto exige que o lead escreva um número sem rótulo e sem pontuação.

## Por que isso importa nesta fase

O free tier da Gemini usa o conteúdo enviado para treino. Enquanto não houver tier pago confirmado, esta camada é o **único controle real** sobre o que sai do sistema, e o texto de consentimento do S-33 tem que declarar o fato.

## Custo aceito

Uma passada de regex por mensagem e por consulta; um módulo novo de 156 linhas para manter; e as duas limitações acima. Nenhuma migration, nenhum campo de contrato — o `/turn` segue com 7 tipos e 42 campos, e `solar-ai-api` e `solar-ai-front` não foram tocados.

## Relacionadas

- `Decisao - Encaminhamento ao corretor com contato fora do LLM.md` — a garantia estrutural do S-37, que este card complementa
- `Decisao - Versao minima de privacidade e nao a completa.md`
- `Decisao - Uma chave unica para privacidade e painel.md`
