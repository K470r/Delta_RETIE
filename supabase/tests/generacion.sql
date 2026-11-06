-- Prueba de 0015 (experiencia por tipo de instalación de generación), después de verificacion.sql.
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
  ('88888888-0000-0000-0000-000000000011', 'eeeeeeee-0000-0000-0000-000000000010', 'E', 'Inspectora', current_date - 1500, current_date - 1, 'RETIE-2024', '{g}', '{inspeccion}', true, 'eeeeeeee-0000-0000-0000-000000000001');

select prueba.debe_ser('la variante de baja tensión pide 3 años en ese tipo de instalación',
  $q$select experiencia_en_actividad || ' ' || experiencia_anios from actividades where codigo = 'RETIE24-GEN-FNCE-BT'$q$, 'RETIE24-GEN-FNCE 3');
select prueba.debe_ser('con certificado g y experiencia en uso final cumple uso final',
  $q$select coalesce(motivo_competencia('eeeeeeee-0000-0000-0000-000000000010', 'RETIE24-UF-BASICAS', 'inspector'), 'cumple')$q$, 'cumple');
select prueba.debe_ser('pero no la generación hasta 1.000 V: falta experiencia en FNCE, AGPE y GD',
  $q$select (motivo_competencia('eeeeeeee-0000-0000-0000-000000000010', 'RETIE24-GEN-FNCE-BT', 'inspector') like 'Experiencia verificada insuficiente en %generación con fuentes no convencionales%: 0.0 de 3 años')::text$q$, 'true');

-- 2 años en AGPE y GD: no alcanza; 3,5 años: sí.
insert into experiencias (id, persona_id, empresa, cargo, desde, hasta, reglamento_id, categorias, actividades, tipos, verificada, verificada_por) values
  ('88888888-0000-0000-0000-000000000012', 'eeeeeeee-0000-0000-0000-000000000010', 'Solar SAS', 'Inspectora', current_date - 730, current_date, 'RETIE-2024', '{a}', '{RETIE24-GEN-FNCE}', '{inspeccion}', true, 'eeeeeeee-0000-0000-0000-000000000001');
select prueba.debe_ser('2 años en AGPE y GD no alcanzan',
  $q$select (motivo_competencia('eeeeeeee-0000-0000-0000-000000000010', 'RETIE24-GEN-FNCE-BT', 'inspector') like '%2.0 de 3 años')::text$q$, 'true');
update experiencias set desde = current_date - 1300 where id = '88888888-0000-0000-0000-000000000012';
update experiencias set verificada = true, verificada_por = 'eeeeeeee-0000-0000-0000-000000000001' where id = '88888888-0000-0000-0000-000000000012';
select prueba.debe_ser('con 3,5 años en AGPE y GD y certificado g, cumple',
  $q$select coalesce(motivo_competencia('eeeeeeee-0000-0000-0000-000000000010', 'RETIE24-GEN-FNCE-BT', 'inspector'), 'cumple')$q$, 'cumple');
select prueba.debe_ser('la experiencia en AGPE y GD no sirve para varias fuentes',
  $q$select (motivo_competencia('eeeeeeee-0000-0000-0000-000000000010', 'RETIE24-GEN-VARIAS-BT', 'inspector') like 'Experiencia verificada insuficiente en %varias fuentes%')::text$q$, 'true');
select prueba.debe_ser('y más de 1.000 V sigue pidiendo certificado de la a',
  $q$select (motivo_competencia('eeeeeeee-0000-0000-0000-000000000010', 'RETIE24-GEN-FNCE', 'inspector') like 'Sin certificado%categoría a')::text$q$, 'true');
select prueba.debe_ser('como director técnico, la experiencia total también es en ese tipo de instalación',
  $q$select (motivo_competencia('eeeeeeee-0000-0000-0000-000000000010', 'RETIE24-GEN-FNCE-BT', 'director_tecnico') like 'Experiencia de director técnico insuficiente en %')::text$q$, 'true');
select prueba.debe_pasar('cambiar el tipo de instalación de una experiencia verificada…',
  $q$update experiencias set actividades = '{RETIE24-GEN-VARIAS}' where id = '88888888-0000-0000-0000-000000000012'$q$);
select prueba.debe_ser('…quita la verificación', $q$select verificada::text from experiencias where id = '88888888-0000-0000-0000-000000000012'$q$, 'false');

\echo '══ Resumen ══'
select count(*) filter (where ok) as correctas, count(*) filter (where not ok) as fallidas from prueba.resultados;
select texto as fallidas from prueba.resultados where not ok;
