---
tipo: decisao
data: 2026-09-15
status: vigente
tags: [decisao, privacidade, lgpd, painel, s-21]
---
# Decisão — Telefone, e-mail e transcrição exclusivos do detalhe do lead

Complementa [[Decisao - Encaminhamento ao corretor com contato fora do LLM]] e [[Decisao - Login por corretor substitui a chave unica no painel]], aplicando o princípio de minimização de dados da LGPD à interface do corretor e do supervisor.

## Problema

O card S-21 e o board de design v1.0 divergiam sobre o que exibir na listagem e no detalhe do lead. O board de design listava telefone, e-mail e transcrição como fora de escopo. No entanto, o corretor necessita desses dados para realizar o atendimento, ler o histórico completo da conversa e confirmar horários na agenda.

Ao mesmo tempo, trafegar dados de contato ou transcrições completas na listagem geral da fila (`GET /painel/leads`) exporia PII em massa para qualquer consulta de lista, contrariando o princípio de minimização da LGPD.

## Decisão

**Telefone, e-mail e transcrição entram exclusivamente no detalhe do lead (`GET /painel/leads/{id}`). A listagem da fila (`GET /painel/leads`) continua limpa de dados de contato e sem mensagens.**

1. **Minimização de dados:** A fila trafega apenas identificadores, score, intenção e status para triagem. PII e histórico são carregados sob demanda apenas quando o operador seleciona um lead específico.
2. **Transcrição integral:** O diálogo completo entre o titular e a Lia é exibido com badges identificadores ("Lia" e "Lead") e divisores temporais, permitindo ao corretor entender o contexto real sem depender unicamente de campos estruturados.
3. **Resumo da Lia em cinco seções nuláveis:** As cinco seções geradas pela IA (Perfil, Orçamento, Imóveis sugeridos, Objeções e restrições, Próximo passo) são nuláveis. Seção nula é dado esperado quando não há menção no diálogo; a interface renderiza fallback sem forçar alucinação de dados.
4. **Regeneração sob demanda ("Gerar de novo"):** O botão "Gerar de novo" aciona `POST /encaminhamentos/{id}/resumo?forcar=true`, contornando o cache `jsonb` persistido.
5. **Supervisor adaptativo:** Supervisores com `vinculoAtivo: false` têm o filtro "Minha fila" completamente removido do DOM sem frases explicativas, abrindo diretamente em "Sem corretor elegível".
6. **Interface unificada:** Cabeçalho único consolidado e rolagem vertical confinada às colunas internas, preservando a altura total da janela.

## Consequências

- O frontend faz duas requisições: listagem da fila e, na seleção de um item, busca dos detalhes completos.
- A privacidade é mantida por desenho (Privacy by Design), reduzindo o risco de vazamento de dados em massa.

## Conceitos

[[LGPD e GDPR]] · [[Qualificacao de leads]]
