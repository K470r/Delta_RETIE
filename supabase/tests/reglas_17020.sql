-- Prueba de las reglas 17020 y de competencia del personal que impone la base de datos.
-- Ejecutar sobre una base recién migrada (0001, 0002 y seed.sql).
-- Cada paso indica si debe PASAR o FALLAR.
\set ON_ERROR_STOP off
\set org '''00000000-0000-0000-0000-00000000000a'''
\set dt '''00000000-0000-0000-0000-000000000001'''
\set insp '''00000000-0000-0000-0000-000000000002'''
\set sg '''00000000-0000-0000-0000-000000000003'''
\set sg2 '''00000000-0000-0000-0000-000000000004'''
\set ilum '''00000000-0000-0000-0000-000000000005'''

\echo '── Organismo y alcance ──'
insert into organismos (id, razon_social, nit, codigo_acreditacion, acreditacion_otorgada, acreditacion_vence)
values (:org, 'OIN Prueba S.A.S.', '900000001', '15-OIN-999', current_date - 400, current_date + 1000);
insert into alcance_acreditado (organismo_id, actividad_codigo) values
  (:org, 'RETIE24-UF-BASICAS'), (:org, 'RETIE24-SUB-MT'), (:org, 'RETILAP24-INTERIOR'), (:org, 'RETILAP24-TUNELES');
\echo '1) actividad inexistente en el catálogo → debe FALLAR'
insert into alcance_acreditado (organismo_id, actividad_codigo) values (:org, 'RETIE24-NO-EXISTE');

\echo '── Personas ──'
\echo '2) cédula con puntos → debe FALLAR'
insert into personas (documento, nombres, apellidos) values ('1.002.003', 'X', 'Y');
insert into personas (id, documento, nombres, apellidos, matricula_numero, matricula_entidad) values
  (:dt, '1001', 'Ana', 'Directora', 'CN-1', 'COPNIA'), (:insp, '1002', 'Luis', 'Inspector', 'CN-2', 'CPNIEMPA'),
  (:sg, '1003', 'Marta', 'Calidad', null, null), (:sg2, '1004', 'Pedro', 'Calidad', null, null),
  (:ilum, '1005', 'Sara', 'Luminotecnia', 'CN-5', 'COPNIA');

\echo '── Certificados ──'
\echo '3) vigencia mayor a 5 años → debe FALLAR'
insert into certificados_competencia (persona_id, reglamento_id, numero, certificador, fecha_emision, fecha_vencimiento)
values (:insp, 'RETIE-2024', 'X-1', 'OCP', '2025-01-10', '2030-01-10');
insert into certificados_competencia (id, persona_id, reglamento_id, numero, certificador, fecha_emision, fecha_vencimiento) values
  ('00000000-0000-0000-0000-0000000000c1', :insp, 'RETIE-2024', 'CP-INS-1', 'OCP', current_date - 100, current_date - 100 + interval '5 years' - interval '1 day'),
  ('00000000-0000-0000-0000-0000000000c2', :dt,   'RETIE-2024', 'CP-DT-1',  'OCP', current_date - 1000, current_date - 1000 + interval '5 years' - interval '1 day');
insert into certificado_categorias values
  ('00000000-0000-0000-0000-0000000000c1', 'RETIE-2024', 'g'),
  ('00000000-0000-0000-0000-0000000000c2', 'RETIE-2024', 'g');
\echo '4) categoría inexistente → debe FALLAR'
insert into certificado_categorias values ('00000000-0000-0000-0000-0000000000c1', 'RETIE-2024', 'z');

\echo '── Experiencia ──'
insert into experiencias (persona_id, empresa, cargo, desde, hasta, reglamento_id, categorias, tipos, verificada, verificada_por) values
  (:insp, 'E1', 'Diseñador', current_date - 900, null, 'RETIE-2024', '{g}', '{diseno}', true, :dt),           -- ~2,5 años
  (:insp, 'E2', 'Inspector', current_date - 800, null, 'RETIE-2024', '{g}', '{inspeccion}', true, :dt),       -- traslapa
  (:dt,   'E3', 'Constructor', current_date - 4500, current_date - 801, 'RETIE-2024', '{g}', '{construccion}', true, :insp),
  (:dt,   'E4', 'Gerente', current_date - 599, null, 'RETIE-2024', '{g}', '{gerencia_direccion}', true, :insp);  -- 1,6 años
\echo '5) autoverificación de experiencia → debe FALLAR'
insert into experiencias (persona_id, empresa, cargo, desde, reglamento_id, categorias, tipos, verificada, verificada_por)
values (:insp, 'E5', 'X', current_date - 100, 'RETIE-2024', '{g}', '{diseno}', true, :insp);
select 'años verificados inspector (sin doble conteo)' as dato,
       round(anios_experiencia(:insp, 'RETIE-2024', 'g', array['diseno','inspeccion'], current_date), 2) as valor;

\echo '── Vinculación y designaciones ──'
\echo '6) designar sin vinculación → debe FALLAR'
insert into designaciones (organismo_id, persona_id, rol, desde) values (:org, :insp, 'inspector', current_date);
insert into vinculaciones (organismo_id, persona_id, tipo, cargo, desde) values
  (:org, :dt, 'laboral', 'Director técnico', current_date - 30),
  (:org, :insp, 'prestacion_servicios', 'Inspector', current_date - 30),
  (:org, :sg, 'laboral', 'Coordinadora de calidad', current_date - 30),
  (:org, :sg2, 'laboral', 'Analista de calidad', current_date - 30),
  (:org, :ilum, 'laboral', 'Inspectora de iluminación', current_date - 30);
insert into designaciones (id, organismo_id, persona_id, rol, desde) values
  ('00000000-0000-0000-0000-0000000000d1', :org, :insp, 'inspector', current_date),
  ('00000000-0000-0000-0000-0000000000d2', :org, :dt, 'director_tecnico', current_date),
  ('00000000-0000-0000-0000-0000000000d3', :org, :sg, 'responsable_sg', current_date - 10),
  ('00000000-0000-0000-0000-0000000000d5', :org, :ilum, 'inspector', current_date);
\echo '7) segundo responsable del SG vigente → debe FALLAR'
insert into designaciones (organismo_id, persona_id, rol, desde) values (:org, :sg2, 'responsable_sg', current_date);

\echo '8) inspector g con 2+ años y certificado vigente → debe PASAR'
insert into designacion_actividades values ('00000000-0000-0000-0000-0000000000d1', 'RETIE24-UF-BASICAS');
\echo '9) inspector en SUB-MT (categoría c) sin certificado ni 3 años en c → debe FALLAR'
insert into designacion_actividades values ('00000000-0000-0000-0000-0000000000d1', 'RETIE24-SUB-MT');
\echo '10) director técnico con solo 1,6 años en gerencia/dirección → debe FALLAR'
insert into designacion_actividades values ('00000000-0000-0000-0000-0000000000d2', 'RETIE24-UF-BASICAS');
update experiencias set desde = current_date - 800 where empresa = 'E4';   -- ahora 2,2 años
\echo '11) certificado emitido hace 1000 días SIN seguimiento del mes 30 → debe FALLAR'
insert into designacion_actividades values ('00000000-0000-0000-0000-0000000000d2', 'RETIE24-UF-BASICAS');
update certificados_competencia set seguimiento_fecha = current_date - 150, seguimiento_resultado = 'conforme'
 where id = '00000000-0000-0000-0000-0000000000c2';
\echo '12) con seguimiento conforme registrado → debe PASAR'
insert into designacion_actividades values ('00000000-0000-0000-0000-0000000000d2', 'RETIE24-UF-BASICAS');

\echo '── RETILAP (sin certificado exigido) ──'
insert into experiencias (persona_id, empresa, cargo, desde, reglamento_id, tipos, verificada, verificada_por)
values (:ilum, 'E6', 'Diseñadora', current_date - 1200, 'RETILAP-2024', '{diseno}', true, :dt);
\echo '13) sin posgrado en iluminación → debe FALLAR'
insert into designacion_actividades values ('00000000-0000-0000-0000-0000000000d5', 'RETILAP24-INTERIOR');
insert into formacion (persona_id, tipo, titulo, institucion, fecha, en_iluminacion, verificada, verificada_por)
values (:ilum, 'especializacion', 'Esp. Iluminación', 'Universidad', '2020-06-01', true, true, :dt);
\echo '14) con posgrado, sin certificado (RETILAP no lo exige) → debe PASAR'
insert into designacion_actividades values ('00000000-0000-0000-0000-0000000000d5', 'RETILAP24-INTERIOR');
\echo '15) túneles sin curso de profundización → debe FALLAR'
insert into designacion_actividades values ('00000000-0000-0000-0000-0000000000d5', 'RETILAP24-TUNELES');
insert into formacion (persona_id, tipo, titulo, institucion, fecha, areas_iluminacion, verificada, verificada_por)
values (:ilum, 'curso_profundizacion', 'Iluminación de túneles', 'Universidad', '2021-06-01', '{tuneles}', true, :dt);
\echo '16) túneles con curso → debe PASAR'
insert into designacion_actividades values ('00000000-0000-0000-0000-0000000000d5', 'RETILAP24-TUNELES');

\echo '── Operación ──'
insert into clientes (id, organismo_id, nombre, nit) values ('00000000-0000-0000-0000-0000000000f1', :org, 'Cliente', '800');
\echo '17) orden en actividad no autorizada al inspector → debe FALLAR'
insert into ordenes_servicio (organismo_id, consecutivo, cliente_id, instalacion, actividad_codigo, inspector_id, solicitud_revisada_en)
values (:org, 'OS-1', '00000000-0000-0000-0000-0000000000f1', 'X', 'RETIE24-SUB-MT', :insp, now());
\echo '18) orden correcta → debe PASAR'
insert into ordenes_servicio (organismo_id, consecutivo, cliente_id, instalacion, actividad_codigo, inspector_id, solicitud_revisada_en)
values (:org, 'OS-2', '00000000-0000-0000-0000-0000000000f1', 'X', 'RETIE24-UF-BASICAS', :insp, now());
\echo '19) borrar una persona → debe FALLAR'
delete from personas where id = :sg;

\echo 'Personal en formato ONAC:'
select nombre_completo, documento, cargo, certificados from v_personal_onac order by 1;
