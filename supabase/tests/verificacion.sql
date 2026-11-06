-- Prueba de 0014_verificacion_soportes.sql (después de personal.sql, con su organismo de prueba).
\set ON_ERROR_STOP on
\ir funciones_prueba.sql
truncate prueba.resultados;

-- Persona que cumple todo para inspector RETIE g salvo, al comienzo, la verificación del certificado.
select set_config('request.jwt.claims', '', false);
insert into personas (id, documento, nombres, apellidos, matricula_numero, matricula_entidad) values
  ('eeeeeeee-0000-0000-0000-000000000009', 'P09', 'Vera', 'Verificable', 'M-9', 'COPNIA');
insert into vinculaciones (organismo_id, persona_id, tipo, cargo, desde)
  values ('cccccccc-0000-0000-0000-0000000000aa', 'eeeeeeee-0000-0000-0000-000000000009', 'laboral', 'Inspectora', current_date - 30);
insert into experiencias (id, persona_id, empresa, cargo, desde, reglamento_id, categorias, tipos, verificada, verificada_por) values
  ('88888888-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000009', 'E', 'Inspectora', current_date - 1500, 'RETIE-2024', '{g}', '{inspeccion}', true, 'eeeeeeee-0000-0000-0000-000000000001');
insert into certificados_competencia (id, persona_id, reglamento_id, numero, certificador, fecha_emision, fecha_vencimiento) values
  ('88888888-0000-0000-0000-000000000002', 'eeeeeeee-0000-0000-0000-000000000009', 'RETIE-2024', 'V-1', 'Certificador', current_date - 100, current_date + 1000);
insert into certificado_categorias (certificado_id, reglamento_id, categoria) values ('88888888-0000-0000-0000-000000000002', 'RETIE-2024', 'g');
insert into formacion (id, persona_id, tipo, titulo, institucion, fecha) values
  ('88888888-0000-0000-0000-000000000003', 'eeeeeeee-0000-0000-0000-000000000009', 'pregrado', 'Ingeniería eléctrica', 'U', '2010-01-01');

select prueba.debe_ser('el certificado registrado empieza sin verificar', $q$select verificada::text from certificados_competencia where numero = 'V-1'$q$, 'false');
select prueba.debe_ser('sin verificar, el certificado no cuenta',
  $q$select (motivo_competencia('eeeeeeee-0000-0000-0000-000000000009', 'RETIE24-UF-BASICAS', 'inspector') like '%verificado%')::text$q$, 'true');

\echo '══ No pueden verificar ══'
select prueba.como('aaaaaaaa-0000-0000-0000-000000000024');   -- inspector
set role authenticated;
select prueba.debe_ser('un inspector no verifica a otra persona (0 filas: no gestiona su hoja de vida)',
  $q$with u as (update certificados_competencia set verificada = true, verificada_por = 'eeeeeeee-0000-0000-0000-000000000004' where numero = 'V-1' returning 1) select count(*)::text from u$q$, '0');
reset role;
select prueba.como('aaaaaaaa-0000-0000-0000-000000000026');   -- asistente de dirección técnica
set role authenticated;
select prueba.debe_ser('el asistente de dirección técnica no verifica (0 filas: no gestiona la hoja de vida)',
  $q$with u as (update formacion set verificada = true, verificada_por = 'eeeeeeee-0000-0000-0000-000000000006' where id = '88888888-0000-0000-0000-000000000003' returning 1) select count(*)::text from u$q$, '0');
reset role;

\echo '══ Sí pueden verificar ══'
select prueba.como('aaaaaaaa-0000-0000-0000-000000000025');   -- responsable del SG
set role authenticated;
select prueba.debe_pasar('el responsable del SG verifica el certificado',
  $q$update certificados_competencia set verificada = true, verificada_por = 'eeeeeeee-0000-0000-0000-000000000005' where numero = 'V-1'$q$);
select prueba.debe_ser('queda quién verificó y cuándo',
  $q$select (verificada_por = 'eeeeeeee-0000-0000-0000-000000000005' and verificada_en > now() - interval '1 minute')::text from certificados_competencia where numero = 'V-1'$q$, 'true');
reset role;
select prueba.debe_ser('verificado, ya cuenta', $q$select coalesce(motivo_competencia('eeeeeeee-0000-0000-0000-000000000009', 'RETIE24-UF-BASICAS', 'inspector'), 'cumple')$q$, 'cumple');
select prueba.como('aaaaaaaa-0000-0000-0000-000000000022');   -- director técnico
set role authenticated;
select prueba.debe_pasar('el director técnico verifica la formación',
  $q$update formacion set verificada = true, verificada_por = 'eeeeeeee-0000-0000-0000-000000000002' where id = '88888888-0000-0000-0000-000000000003'$q$);
select prueba.debe_fallar('nadie verifica lo suyo',
  $q$insert into formacion (persona_id, tipo, titulo, institucion, fecha, verificada, verificada_por) values ('eeeeeeee-0000-0000-0000-000000000002', 'pregrado', 'X', 'U', '2000-01-01', true, 'eeeeeeee-0000-0000-0000-000000000002')$q$, 'autoverificación');
reset role;
select prueba.como('aaaaaaaa-0000-0000-0000-000000000023');   -- directora técnica suplente
set role authenticated;
select prueba.debe_pasar('la directora técnica suplente verifica la experiencia del director técnico',
  $q$insert into experiencias (persona_id, empresa, cargo, desde, reglamento_id, categorias, tipos, verificada, verificada_por) values ('eeeeeeee-0000-0000-0000-000000000002', 'E', 'C', current_date - 400, 'RETIE-2024', '{g}', '{inspeccion}', true, 'eeeeeeee-0000-0000-0000-000000000003')$q$);
reset role;

\echo '══ Cambios después de verificar ══'
select prueba.como('aaaaaaaa-0000-0000-0000-000000000021');   -- gerente
set role authenticated;
select prueba.debe_pasar('registrar el seguimiento no quita la verificación',
  $q$update certificados_competencia set seguimiento_fecha = (now() at time zone 'America/Bogota')::date, seguimiento_resultado = 'conforme' where numero = 'V-1'$q$);
select prueba.debe_ser('sigue verificado y a nombre del SG',
  $q$select verificada || ' ' || (verificada_por = 'eeeeeeee-0000-0000-0000-000000000005') from certificados_competencia where numero = 'V-1'$q$, 'true true');
select prueba.debe_pasar('cambiar el soporte…', $q$update certificados_competencia set soporte_ruta = 'eeeeeeee-0000-0000-0000-000000000009/nuevo.pdf' where numero = 'V-1'$q$);
select prueba.debe_ser('…quita la verificación', $q$select verificada || ' ' || coalesce(verificada_por::text, '-') from certificados_competencia where numero = 'V-1'$q$, 'false -');
select prueba.debe_pasar('cambiar las fechas de una experiencia verificada…', $q$update experiencias set desde = desde - 10 where id = '88888888-0000-0000-0000-000000000001'$q$);
select prueba.debe_ser('…también la quita', $q$select verificada::text from experiencias where id = '88888888-0000-0000-0000-000000000001'$q$, 'false');
select prueba.debe_pasar('la gerente la verifica de nuevo',
  $q$update experiencias set verificada = true, verificada_por = 'eeeeeeee-0000-0000-0000-000000000001' where id = '88888888-0000-0000-0000-000000000001'$q$);
select prueba.debe_pasar('y la desmarca', $q$update experiencias set verificada = false where id = '88888888-0000-0000-0000-000000000001'$q$);
select prueba.debe_ser('al desmarcar no queda a nombre de nadie', $q$select coalesce(verificada_por::text, '-') || coalesce(verificada_en::text, '-') from experiencias where id = '88888888-0000-0000-0000-000000000001'$q$, '--');
reset role;
update certificados_competencia set verificada = true, verificada_por = 'eeeeeeee-0000-0000-0000-000000000001' where numero = 'C-2';
select prueba.como('aaaaaaaa-0000-0000-0000-000000000024');   -- el inspector, en su propia hoja
set role authenticated;
select prueba.debe_fallar('el inspector no desmarca una verificación de otro',
  $q$update certificados_competencia set verificada = false where numero = 'C-2'$q$, 'Quitan la verificación');
reset role;
select set_config('request.jwt.claims', '', false);

\echo '══ Resumen ══'
select count(*) filter (where ok) as correctas, count(*) filter (where not ok) as fallidas from prueba.resultados;
select texto as fallidas from prueba.resultados where not ok;
