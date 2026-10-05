BEGIN;
CREATE TEMP TABLE relogio AS SELECT now() AS t0;
INSERT INTO leads(id,intencao,preco_max,regiao,score,criado_em,atualizado_em,status,consentimento_em,versao_aviso_privacidade)
SELECT '45000000-0000-0000-0000-000000000004'::uuid,'compra',700000,'Moema',70,t0 - interval '1 day',t0,'encaminhado',t0 - interval '1 day','2026-09-11' FROM relogio;
INSERT INTO conversas(id,canal,lead_id,criada_em,atualizada_em,desfecho,intencao_em,essenciais_em,encaminhada_em,corretor_atribuido_em)
SELECT '45100000-0000-0000-0000-000000000004'::uuid,'web','45000000-0000-0000-0000-000000000004'::uuid,t0 - interval '1 day',t0 - interval '1 day' + interval '9 minutes','agendar_reuniao',
       t0 - interval '1 day' + interval '1 minute',t0 - interval '1 day' + interval '1 minute',t0 - interval '1 day' + interval '9 minutes',t0 - interval '1 day' + interval '9 minutes' FROM relogio;
INSERT INTO mensagens(conversa_id,papel,texto,em,proxima_acao)
SELECT '45100000-0000-0000-0000-000000000004'::uuid,papel,texto,t0 - interval '1 day' + minutos * interval '1 minute',acao
FROM (VALUES (1,'lead','Mensagem sintetica S45 a reatribuir',NULL),(9,'agente','Resposta sintetica S45','agendar_reuniao')) AS d(minutos,papel,texto,acao) CROSS JOIN relogio;
INSERT INTO encaminhamentos(conversa_id,lead_id,corretor_id,especialidade,status,em)
SELECT '45100000-0000-0000-0000-000000000004'::uuid,'45000000-0000-0000-0000-000000000004'::uuid,
       (SELECT id FROM corretores WHERE email_normalizado = 'eva.s45@solar.local'),'moradia','atribuido',t0 - interval '1 day' + interval '9 minutes' FROM relogio;
COMMIT;
