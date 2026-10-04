BEGIN;
DELETE FROM slots;
DELETE FROM sessoes;
DELETE FROM recuperacoes_senha;
DELETE FROM corretores;
INSERT INTO corretores(id,nome,regioes,contato_interno,ativo,criado_em,email,email_normalizado,perfil,vinculo_ativo,aprovado_em,consentimento_em,especialidades,status_corretor,telefone,versao_aviso_privacidade)
SELECT ('22100000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,nome,ARRAY['Moema'],'contato sintetico S22',true,now(),email,lower(email),perfil,true,CASE WHEN status='aprovado' THEN now() END,now(),ARRAY['moradia','investimento'],status,'11000000000','seed-s22'
FROM (VALUES
 (1,'Silvia Supervisora','supervisor-s22@solar.local','supervisor','aprovado'),
 (2,'Helena Braga','hb-s22@solar.local','corretor','aprovado'),
 (3,'Rafael Nunes','rn-s22@solar.local','corretor','aprovado'),
 (4,'Pedro Pendente','pendente-s22@solar.local','corretor','em_analise'),
 (5,'Cliente Sintetico','cliente-s22@solar.local','cliente',NULL)
) AS contas(n,nome,email,perfil,status);
COMMIT;
