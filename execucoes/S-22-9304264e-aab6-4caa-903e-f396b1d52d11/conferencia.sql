\pset tuples_only on
\pset format unaligned
CREATE TEMP VIEW contexto AS SELECT '{{AGORA}}'::timestamptz AS agora,NULLIF('{{CORRETOR}}','')::uuid AS corretor,{{EM_ANALISE}}::boolean AS em_analise;
CREATE TEMP VIEW ultimo_encaminhamento AS
SELECT DISTINCT ON (lead_id) lead_id,corretor_id FROM encaminhamentos ORDER BY lead_id,em DESC,id DESC;
CREATE TEMP VIEW leads_autorizados AS
SELECT l.* FROM leads l CROSS JOIN contexto c LEFT JOIN ultimo_encaminhamento e ON e.lead_id=l.id
WHERE NOT c.em_analise AND (c.corretor IS NULL OR e.corretor_id=c.corretor);
CREATE TEMP VIEW conversas_autorizadas AS
SELECT v.* FROM conversas v JOIN leads_autorizados l ON l.id=v.lead_id CROSS JOIN contexto c
WHERE c.corretor IS NULL OR EXISTS(SELECT 1 FROM encaminhamentos e WHERE e.conversa_id=v.id AND e.corretor_id=c.corretor);
CREATE TEMP VIEW iniciadas AS
SELECT v.id FROM conversas_autorizadas v JOIN mensagens m ON m.conversa_id=v.id AND m.papel='lead' CROSS JOIN contexto c
GROUP BY v.id,c.agora HAVING min(m.em) BETWEEN c.agora-interval '30 days' AND c.agora;
CREATE TEMP VIEW horarios_futuros AS
SELECT s.*,c.nome FROM slots s JOIN leads_autorizados l ON l.id=s.lead_id JOIN corretores c ON c.id=s.corretor_id CROSS JOIN contexto ctx
WHERE s.inicio>=ctx.agora AND (ctx.corretor IS NULL OR s.corretor_id=ctx.corretor);
CREATE TEMP VIEW regioes_normalizadas AS
SELECT translate(upper(btrim(regiao)),'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','AAAAAEEEEIIIIOOOOOUUUUC') AS regiao,count(*) AS leads
FROM leads_autorizados WHERE regiao IS NOT NULL AND btrim(regiao)<>'' GROUP BY 1;
CREATE TEMP VIEW ranking_regioes AS SELECT *,row_number() OVER(ORDER BY leads DESC,regiao COLLATE "C") AS posicao FROM regioes_normalizadas;
CREATE TEMP VIEW snapshots AS
SELECT m.conversa_id,m.em,m.id AS mensagem_id,s->>'Id' AS id,s->>'Bairro' AS bairro
FROM mensagens m JOIN conversas_autorizadas v ON v.id=m.conversa_id CROSS JOIN LATERAL jsonb_array_elements(m.imoveis_sugeridos) s;
CREATE TEMP VIEW ranking_imoveis AS
SELECT id,(array_agg(bairro ORDER BY em DESC,mensagem_id DESC,bairro COLLATE "C"))[1] AS bairro,count(DISTINCT conversa_id) AS conversas FROM snapshots GROUP BY id;
CREATE TEMP VIEW contatos AS
SELECT l.id,l.consentimento_em,COALESCE(
 (SELECT max(m.em) FROM mensagens m JOIN conversas v ON v.id=m.conversa_id WHERE v.lead_id=l.id AND m.papel='lead'),
 LEAST(l.criado_em,(SELECT min(v.criada_em) FROM conversas v WHERE v.lead_id=l.id))) AS contato FROM leads_autorizados l;
CREATE TEMP VIEW vencimentos AS SELECT *,contato+interval '12 months' AS vence_em FROM contatos;
CREATE TEMP VIEW atribuicoes AS
SELECT c.id,c.nome,count(*) AS conversas FROM encaminhamentos e JOIN conversas_autorizadas v ON v.id=e.conversa_id JOIN corretores c ON c.id=e.corretor_id GROUP BY c.id,c.nome;
SELECT jsonb_build_object(
 'conversasIniciadas',(SELECT count(*) FROM iniciadas),
 'horariosConfirmados',(SELECT count(*) FROM iniciadas i WHERE EXISTS(SELECT 1 FROM mensagens m WHERE m.conversa_id=i.id AND m.status_agendamento='confirmado')),
 'reservasProximos7Dias',(SELECT count(*) FROM horarios_futuros h CROSS JOIN contexto c WHERE h.inicio<=c.agora+interval '7 days'),
 'leadsPorIntencao',(SELECT jsonb_build_object('compra',count(*) FILTER(WHERE intencao='compra'),'aluguel',count(*) FILTER(WHERE intencao='aluguel'),'investimento',count(*) FILTER(WHERE intencao='investimento'),'semIntencao',count(*) FILTER(WHERE intencao IS NULL OR intencao IN ('','indefinida'))) FROM leads_autorizados),
 'equipe',CASE WHEN (SELECT corretor FROM contexto) IS NOT NULL THEN NULL ELSE jsonb_build_object(
  'atribuidasPorCorretor',COALESCE((SELECT jsonb_agg(jsonb_build_object('corretor',jsonb_build_object('id',id,'nome',nome,'iniciais',left(nome,1)||left(split_part(nome,' ',2),1)),'conversas',conversas) ORDER BY conversas DESC,id) FROM atribuicoes),'[]'::jsonb),
  'aguardandoCorretor',(SELECT count(*) FROM encaminhamentos e JOIN conversas_autorizadas v ON v.id=e.conversa_id WHERE e.corretor_id IS NULL),
  'pendentesAprovacao',(SELECT count(*) FROM corretores WHERE ativo AND perfil='corretor' AND status_corretor='em_analise')) END,
 'extras',jsonb_build_object(
  'score',(SELECT jsonb_build_object('frio',count(*) FILTER(WHERE score BETWEEN 0 AND 39),'morno',count(*) FILTER(WHERE score BETWEEN 40 AND 69),'quente',count(*) FILTER(WHERE score BETWEEN 70 AND 100),'semAvaliacao',count(*) FILTER(WHERE score IS NULL)) FROM leads_autorizados),
  'regioes',jsonb_build_object('top',COALESCE((SELECT jsonb_agg(jsonb_build_object('regiao',regiao,'leads',leads) ORDER BY posicao) FROM ranking_regioes WHERE posicao<=5),'[]'::jsonb),'outras',COALESCE((SELECT sum(leads) FROM ranking_regioes WHERE posicao>5),0),'informaram',COALESCE((SELECT sum(leads) FROM ranking_regioes),0),'leads',(SELECT count(*) FROM leads_autorizados)),
  'imoveis',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',id,'bairro',bairro,'conversas',conversas) ORDER BY conversas DESC,id COLLATE "C") FROM ranking_imoveis),'[]'::jsonb),
  'proximosHorarios',COALESCE((SELECT jsonb_agg(jsonb_build_object('inicio',inicio,'iniciais',left(nome,1)||left(split_part(nome,' ',2),1)) ORDER BY inicio,id) FROM horarios_futuros),'[]'::jsonb),
  'privacidade',jsonb_build_object('leads',(SELECT count(*) FROM leads_autorizados),'comConsentimento',(SELECT count(*) FROM leads_autorizados WHERE consentimento_em IS NOT NULL),'prazoRetencaoMeses',12,'vencem30Dias',(SELECT count(*) FROM vencimentos v CROSS JOIN contexto c WHERE v.vence_em BETWEEN c.agora AND c.agora+interval '30 days'),'proximoVencimento',(SELECT min(v.vence_em) FROM vencimentos v CROSS JOIN contexto c WHERE v.vence_em>=c.agora))
 )) AS resultado_sql;
