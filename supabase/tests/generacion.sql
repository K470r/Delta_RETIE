-- Prueba de 0015 y 0016 (generación hasta 1.000 V como la categoría g), después de verificacion.sql.
\set ON_ERROR_STOP on
\ir funciones_prueba.sql
truncate prueba.resultados;
select set_config('request.jwt.claims', '', false);

-- Inspectora con certificado g verificado y 4 años de experiencia verificada en uso final (g).
insert into personas (id, documento, nombres, apellidos, matricula_numero, matricula_entidad) values
  ('eeeeeeee-0000-0000-0000-000000000010', 'P10', 'Gloria', 'Generación', 'M-10', 'CPNIEMPA');
insert into certificados_competencia (id, persona_id, reglamento_id, numero, certificador, fecha_emision, fecha_vencimiento, verificada, verificada_por) values
  ('88888888-0000-0000-0000-000000000010', 'eeeeeeee-0000-0000-0000-000000000010', 'RETIE-2024', 'G-10', 'Certificador', current_date - 100, current_date + 1000, true, 'eeeeeeee-0000-0000-0000-000000000001');
insert into certificado_categorias (certificado_id, reglamento_id, categoria) values ('88888888-0000-0000-0000-000000000010', 'RETIE-2024', 'g');
insert into experiencias (id, persona_id, empresa, cargo, desde, hasta, reglamento_id, categorias, tipos, verificada, verificada_por) values
  ('88888888-0000-0000-0000-000000000011', 'eeeeeeee-0000-0000-0000-000000000010', 'E', 'Inspectora', current_date - 1500, current_date - 1, 'RETIE-2024', '{g}', '{inspeccion}', true, 'eeeeeeee-0000-0000-0000-000000000001');select prueba.debe_ser('la generación hasta 1.000 V no tiene regla especial de experiencia (0016)',
  $q$select coalesce(experiencia_en_actividad, '-') || ' ' || coalesce(experiencia_anios::text, '-') || ' ' || categoria from actividades where codigo = 'RETIE24-GEN-FNCE-BT'$q$, '- - g');
select prueba.debe_ser('con certificado g y experiencia de la g cumple uso final',
  $q$select coalesce(motivo_competencia('eeeeeeee-0000-0000-0000-000000000010', 'RETIE24-UF-BASICAS', 'inspector'), 'cumple')$q$, 'cumple');
select prueba.debe_ser('y también la generación con FNCE, AGPE y GD hasta 1.000 V',
  $q$select coalesce(motivo_competencia('eeeeeeee-0000-0000-0000-000000000010', 'RETIE24-GEN-FNCE-BT', 'inspector'), 'cumple')$q$, 'cumple');
select prueba.debe_ser('y la de varias fuentes hasta 1.000 V',
  $q$select coalesce(motivo_competencia('eeeeeeee-0000-0000-0000-000000000010', 'RETIE24-GEN-VARIAS-BT', 'inspector'), 'cumple')$q$, 'cumple');
select prueba.debe_ser('más de 1.000 V sigue pidiendo la a',
  $q$select (motivo_competencia('eeeeeeee-0000-0000-0000-000000000010', 'RETIE24-GEN-FNCE', 'inspector') like 'Experiencia verificada insuficiente: 0.0 de 3 años')::text$q$, 'true');
update experiencias set desde = current_date - 500 where id = '88888888-0000-0000-0000-000000000011';
update experiencias set verificada = true, verificada_por = 'eeeeeeee-0000-0000-0000-000000000001' where id = '88888888-0000-0000-0000-000000000011';
select prueba.debe_ser('con menos de 2 años en la g no alcanza',
  $q$select (motivo_competencia('eeeeeeee-0000-0000-0000-000000000010', 'RETIE24-GEN-FNCE-BT', 'inspector') like 'Experiencia verificada insuficiente: 1.4 de 2 años')::text$q$, 'true');



\echo '══ Resumen ══'
select count(*) filter (where ok) as correctas, count(*) filter (where not ok) as fallidas from prueba.resultados;
select texto as fallidas from prueba.resultados where not ok;
