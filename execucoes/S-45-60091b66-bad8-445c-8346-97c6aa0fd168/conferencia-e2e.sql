\set ON_ERROR_STOP 1
CREATE TEMP VIEW parametros AS
SELECT :'ref'::timestamptz AS ref,
       :'ref'::timestamptz - interval '30 days' AS inicio,
       (SELECT historico_desde FROM registro_metricas WHERE id = 1) AS hd,
       7 AS janela;

CREATE TEMP VIEW primeira AS
SELECT conversa_id, min(em) AS em FROM mensagens WHERE papel = 'lead' GROUP BY conversa_id;

CREATE TEMP VIEW atual AS
SELECT DISTINCT ON (conversa_id) conversa_id, corretor_id FROM encaminhamentos ORDER BY conversa_id, em DESC, id DESC;

CREATE TEMP VIEW periodo AS
SELECT c.*, p.em AS primeira_em, a.corretor_id AS corretor_atual
FROM conversas c JOIN primeira p ON p.conversa_id = c.id LEFT JOIN atual a ON a.conversa_id = c.id, parametros
WHERE p.em >= parametros.inicio AND p.em <= parametros.ref;

CREATE TEMP VIEW base AS
SELECT periodo.* FROM periodo, parametros WHERE periodo.primeira_em >= parametros.hd;

SELECT 'recorte' AS recorte,
  count(*) AS iniciadas,
  count(*) FILTER (WHERE intencao_em <= ref) AS intencao,
  count(*) FILTER (WHERE essenciais_em <= ref) AS essenciais,
  count(*) FILTER (WHERE encaminhada_em <= ref) AS encaminhamento,
  count(*) FILTER (WHERE encaminhada_em <= ref AND (essenciais_em IS NULL OR essenciais_em > encaminhada_em)) AS sem_essenciais,
  count(*) FILTER (WHERE corretor_atribuido_em <= ref) AS corretor,
  count(*) FILTER (WHERE EXISTS (SELECT 1 FROM mensagens m WHERE m.conversa_id = base.id AND m.status_agendamento = 'confirmado' AND m.em <= ref)) AS horario
FROM base, parametros
WHERE :'corretor' = '' OR base.corretor_atual::text = :'corretor';

SELECT 'tempo' AS recorte,
  percentile_cont(0.5) WITHIN GROUP (ORDER BY extract(epoch FROM encaminhada_em - primeira_em) / 60) AS mediana_min,
  count(*) AS amostras
FROM periodo, parametros
WHERE encaminhada_em <= ref AND (:'corretor' = '' OR periodo.corretor_atual::text = :'corretor');

SELECT 'followup' AS recorte,
  count(*) AS com_follow_up,
  count(*) FILTER (WHERE primeiro_reengajamento_em + janela * interval '1 day' <= ref) AS janela_encerrada,
  count(*) FILTER (WHERE primeiro_reengajamento_em + janela * interval '1 day' <= ref AND EXISTS (
    SELECT 1 FROM mensagens m WHERE m.conversa_id = periodo.id AND m.papel = 'lead'
      AND m.em > periodo.primeiro_reengajamento_em
      AND m.em <= periodo.primeiro_reengajamento_em + janela * interval '1 day')) AS responderam,
  count(*) FILTER (WHERE primeiro_reengajamento_em + janela * interval '1 day' > ref) AS em_observacao
FROM periodo, parametros
WHERE primeiro_reengajamento_em <= ref AND (:'corretor' = '' OR periodo.corretor_atual::text = :'corretor');
