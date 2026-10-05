BEGIN;
CREATE TEMP TABLE relogio AS SELECT now() AS t0;

UPDATE registro_metricas SET historico_desde = (SELECT t0 FROM relogio) - interval '20 days' WHERE id = 1;

INSERT INTO leads(id,nome,intencao,preco_max,regiao,score,criado_em,atualizado_em,status,consentimento_em,versao_aviso_privacidade)
SELECT ('45000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid, NULL, intencao, preco_max, regiao, score,
       t0 - dias * interval '1 day', t0, status, t0 - dias * interval '1 day', '2026-09-11'
FROM (VALUES
  (1,'compra',NULL,NULL,45,5,'encaminhado'),
  (2,'aluguel',NULL,'Moema',60,25,'encaminhado'),
  (3,'compra',800000,'Moema',75,2,'encaminhado'),
  (5,NULL,NULL,NULL,NULL,15,'novo'),
  (6,NULL,NULL,NULL,NULL,12,'novo'),
  (7,NULL,NULL,NULL,NULL,3,'novo')
) AS d(n,intencao,preco_max,regiao,score,dias,status) CROSS JOIN relogio;

INSERT INTO conversas(id,canal,lead_id,criada_em,atualizada_em,desfecho,tentativas_reengajamento,intencao_em,essenciais_em,encaminhada_em,corretor_atribuido_em,primeiro_reengajamento_em)
SELECT ('45100000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid, 'web', ('45000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
       t0 - dias * interval '1 day', t0 - dias * interval '1 day' + interval '2 minutes', desfecho, tentativas,
       t0 - dias * interval '1 day' + intencao_min * interval '1 minute',
       t0 - dias * interval '1 day' + essenciais_min * interval '1 minute',
       t0 - dias * interval '1 day' + encaminhada_min * interval '1 minute',
       t0 - dias * interval '1 day' + encaminhada_min * interval '1 minute',
       t0 - follow_dias * interval '1 day'
FROM (VALUES
  (1,5,'agendar_reuniao',0,1,NULL,7,NULL),
  (2,25,'agendar_reuniao',0,NULL,NULL,NULL,NULL),
  (3,2,'agendar_reuniao',0,1,1,14,NULL),
  (5,15,NULL,1,NULL,NULL,NULL,14),
  (6,12,NULL,1,NULL,NULL,NULL,10),
  (7,3,NULL,1,NULL,NULL,NULL,2)
) AS d(n,dias,desfecho,tentativas,intencao_min,essenciais_min,encaminhada_min,follow_dias) CROSS JOIN relogio;

INSERT INTO mensagens(conversa_id,papel,texto,em,proxima_acao)
SELECT ('45100000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid, papel, texto, t0 - dias * interval '1 day' + minutos * interval '1 minute', acao
FROM (VALUES
  (1,5,0,'agente','Olá! Sou a Lia, assistente da Solar.',NULL),
  (1,5,1,'lead','Mensagem sintetica S45 sem dados essenciais',NULL),
  (1,5,7,'agente','Resposta sintetica S45','agendar_reuniao'),
  (2,25,1,'lead','Mensagem sintetica S45 anterior ao registro',NULL),
  (2,25,2,'agente','Resposta sintetica S45','agendar_reuniao'),
  (3,2,1,'lead','Mensagem sintetica S45 a redistribuir',NULL),
  (3,2,14,'agente','Resposta sintetica S45','agendar_reuniao'),
  (5,15,1,'lead','Mensagem sintetica S45 com follow-up respondido',NULL),
  (5,15,2,'agente','Resposta sintetica S45','continuar_conversa'),
  (5,14,0,'agente','Follow-up sintetico S45','continuar_conversa'),
  (5,13,0,'lead','Resposta ao follow-up sintetica S45',NULL),
  (6,12,1,'lead','Mensagem sintetica S45 com follow-up sem resposta',NULL),
  (6,12,2,'agente','Resposta sintetica S45','continuar_conversa'),
  (6,10,0,'agente','Follow-up sintetico S45','continuar_conversa'),
  (7,3,1,'lead','Mensagem sintetica S45 com follow-up em observacao',NULL),
  (7,3,2,'agente','Resposta sintetica S45','continuar_conversa'),
  (7,2,0,'agente','Follow-up sintetico S45','continuar_conversa')
) AS d(n,dias,minutos,papel,texto,acao) CROSS JOIN relogio;

INSERT INTO encaminhamentos(conversa_id,lead_id,corretor_id,especialidade,status,em)
SELECT ('45100000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid, ('45000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
       (SELECT id FROM corretores WHERE email_normalizado = d.conta), 'moradia', 'atribuido',
       t0 - dias * interval '1 day' + minutos * interval '1 minute'
FROM (VALUES
  (1,5,7,'bruno.s45@solar.local'),
  (2,24,0,'bruno.s45@solar.local'),
  (3,2,14,'caio.s45@solar.local')
) AS d(n,dias,minutos,conta) CROSS JOIN relogio;

INSERT INTO slots(corretor_id,inicio,fim)
SELECT c.id, date_trunc('hour', t0) + h * interval '1 hour', date_trunc('hour', t0) + (h + 1) * interval '1 hour'
FROM corretores c CROSS JOIN relogio CROSS JOIN (VALUES (26),(27),(50)) AS d(h)
WHERE c.email_normalizado IN ('ana.s45@solar.local','bruno.s45@solar.local');

SELECT (SELECT historico_desde FROM registro_metricas WHERE id = 1) AS historico_desde,
       (SELECT count(*) FROM conversas WHERE id::text LIKE '45100000-%') AS conversas_semeadas,
       (SELECT count(*) FROM mensagens WHERE conversa_id::text LIKE '45100000-%') AS mensagens_semeadas,
       (SELECT count(*) FROM encaminhamentos WHERE conversa_id::text LIKE '45100000-%') AS encaminhamentos_semeados,
       (SELECT count(*) FROM slots) AS slots;
COMMIT;
