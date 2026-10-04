BEGIN;
CREATE TEMP TABLE relogio_seed AS SELECT now() AS agora;
INSERT INTO leads(id,nome,intencao,score,regiao,email,telefone,criado_em,atualizado_em,status,consentimento_em,versao_aviso_privacidade)
SELECT ('22000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'Titular Canario Privado S22',intencao,score,regiao,'titular-canario-s22@tests.solar.local','11976543210',
 CASE n WHEN 6 THEN agora-interval '12 months'+interval '25 days' WHEN 7 THEN agora-interval '12 months'+interval '20 days' WHEN 8 THEN agora-interval '12 months' ELSE agora-interval '60 days' END,
 agora,'novo',CASE WHEN n<>4 THEN agora-interval '1 day' END,CASE WHEN n<>4 THEN 'seed-s22' END
FROM (VALUES
 (1,'compra',0,'Moema'),(2,'aluguel',39,'MOÉMA'),(3,'investimento',40,'Vila Mariana'),
 (4,'indefinida',69,'vila mariána'),(5,NULL,70,NULL),(6,'compra',100,'Tatuapé'),
 (7,'aluguel',NULL,'TATUAPE'),(8,'investimento',NULL,'Santana'),(9,'compra',NULL,'santána'),
 (10,'compra',70,'Freguesia do Ó'),(11,'aluguel',40,'Penha')
) AS dados(n,intencao,score,regiao) CROSS JOIN relogio_seed;
CREATE TEMP TABLE conversas_seed(n,lead_n,corretor_n,dias,confirmado) AS VALUES
 (101,1,2,2,true),(102,1,3,1,true),(103,1,2,15,false),(201,2,2,35,true),
 (301,3,2,10,true),(401,4,3,5,false),(501,5,NULL,1,false),(601,6,2,NULL,false),
 (801,8,3,NULL,false),(901,9,NULL,7,false),(1001,10,3,3,true),(1101,11,2,29,true);
INSERT INTO conversas(id,canal,lead_id,criada_em,atualizada_em)
SELECT ('22200000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'web',
 ('22000000-0000-0000-0000-'||lpad(lead_n::text,12,'0'))::uuid,
 CASE n WHEN 601 THEN agora-interval '12 months'+interval '12 days' WHEN 801 THEN agora-interval '12 months' ELSE agora-(dias+1)*interval '1 day' END,agora
FROM conversas_seed CROSS JOIN relogio_seed;
INSERT INTO encaminhamentos(conversa_id,lead_id,corretor_id,especialidade,status,em)
SELECT ('22200000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
 ('22000000-0000-0000-0000-'||lpad(lead_n::text,12,'0'))::uuid,
 CASE WHEN corretor_n IS NOT NULL THEN ('22100000-0000-0000-0000-'||lpad(corretor_n::text,12,'0'))::uuid END,
 'moradia',CASE WHEN corretor_n IS NULL THEN 'aguardando' ELSE 'atribuido' END,
 agora-CASE n WHEN 101 THEN interval '20 minutes' WHEN 102 THEN interval '2 hours' WHEN 103 THEN interval '4 hours' ELSE interval '1 hour' END
FROM conversas_seed CROSS JOIN relogio_seed;
INSERT INTO mensagens(conversa_id,papel,texto,em)
SELECT id,'agente','Olá automatico sintetico S22',criada_em FROM conversas WHERE id::text LIKE '22200000-%';
INSERT INTO mensagens(conversa_id,papel,texto,em)
SELECT ('22200000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'lead','Transcricao confidencial canario S22',agora-dias*interval '1 day'
FROM conversas_seed CROSS JOIN relogio_seed WHERE dias IS NOT NULL;
INSERT INTO mensagens(conversa_id,papel,texto,em)
SELECT '22200000-0000-0000-0000-000000000301'::uuid,'lead','Transcricao confidencial canario S22',agora-interval '9 days' FROM relogio_seed
UNION ALL SELECT '22200000-0000-0000-0000-000000000801'::uuid,'lead','Transcricao confidencial canario S22',agora-interval '12 months'+interval '5 days' FROM relogio_seed
UNION ALL SELECT '22200000-0000-0000-0000-000000000801'::uuid,'agente','Followup sintetico que nao renova prazo',agora-interval '2 days' FROM relogio_seed;
INSERT INTO mensagens(conversa_id,papel,texto,em,status_agendamento)
SELECT ('22200000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'agente','Confirmacao sintetica',agora-dias*interval '1 day'+interval '1 hour','confirmado'
FROM conversas_seed CROSS JOIN relogio_seed WHERE confirmado;
INSERT INTO mensagens(conversa_id,papel,texto,em,status_agendamento)
SELECT '22200000-0000-0000-0000-000000000301'::uuid,'agente','Repeticao de confirmacao sintetica',agora-interval '8 days','confirmado' FROM relogio_seed;
INSERT INTO mensagens(conversa_id,papel,texto,em,imoveis_sugeridos)
SELECT ('22200000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'agente','Sugestao sintetica',agora-interval '1 day',
 jsonb_build_array(jsonb_build_object('Id',imovel,'Tipo','apartamento','Bairro',bairro,'Quartos',2,'Metragem',60,'PrecoVenda',400000,'PrecoAluguel',NULL,'Motivo','Transcricao confidencial canario S22'))
FROM (VALUES
 (101,'IMV-001','Moema'),(102,'IMV-001','Moema'),(201,'IMV-001','Moema'),(301,'IMV-001','Moema'),(901,'IMV-001','Moema'),
 (101,'IMV-001','Moema'),(103,'IMV-002','Vila Mariana'),(301,'IMV-002','Vila Mariana'),(1101,'IMV-002','Vila Mariana'),
 (401,'IMV-003','Freguesia do Ó'),(1001,'IMV-003','Freguesia do Ó'),(801,'IMV-004','Santana')
) AS snapshots(n,imovel,bairro) CROSS JOIN relogio_seed;
INSERT INTO slots(corretor_id,lead_id,inicio,fim)
SELECT ('22100000-0000-0000-0000-'||lpad(corretor_n::text,12,'0'))::uuid,
 CASE WHEN lead_n IS NOT NULL THEN ('22000000-0000-0000-0000-'||lpad(lead_n::text,12,'0'))::uuid END,
 agora+dias*interval '1 day',agora+dias*interval '1 day'+interval '1 hour'
FROM (VALUES (2,1,1),(3,1,2),(2,3,3),(3,4,8),(3,10,6),(2,11,10),(2,2,-1),(2,NULL,4)) AS horarios(corretor_n,lead_n,dias) CROSS JOIN relogio_seed;
SELECT agora AS seed_em,(SELECT count(*) FROM leads) AS leads,(SELECT count(*) FROM conversas) AS conversas FROM relogio_seed;
COMMIT;
