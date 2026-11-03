-- Prueba de las reglas 17020 que impone la base de datos.
-- Ejecutar sobre una base recién migrada (0001, 0002 y seed.sql).
-- Cada paso indica si debe PASAR o FALLAR.
\set ON_ERROR_STOP off
\set org '''00000000-0000-0000-0000-00000000000a'''
\set dt '''00000000-0000-0000-0000-000000000001'''
\set insp '''00000000-0000-0000-0000-000000000002'''
\set sg '''00000000-0000-0000-0000-000000000003'''
\set sg2 '''00000000-0000-0000-0000-000000000004'''

\echo '── Organismo y alcance ──'
insert into organismos (id, razon_social, nit, codigo_acreditacion, acreditacion_otorgada, acreditacion_vence)
values (:org, 'OIN Prueba S.A.S.', '900000001', '15-OIN-999', current_date - 400, current_date + 1000);
insert into alcance_acreditado (organismo_id, actividad_codigo) values
  (:org, 'RETIE24-UF-BASICAS'), (:org, 'RETIE24-SUB-MT'), (:org, 'RETILAP24-INTERIOR');
\echo '1) actividad inexistente en el catálogo → debe FALLAR'
insert into alcance_acreditado (organismo_id, actividad_codigo) values (:org, 'RETIE24-NO-EXISTE');

\echo '── Personas, vinculación y certificados ──'
insert into personas (id, documento, nombres, apellidos) values
  (:dt, '1001', 'Ana', 'Directora'), (:insp, '1002', 'Luis', 'Inspector'),
  (:sg, '1003', 'Marta', 'Calidad'), (:sg2, '1004', 'Pedro', 'Calidad');
insert into certificados_competencia (id, persona_id, numero, certificador, fecha_emision, fecha_vencimiento) values
  ('00000000-0000-0000-0000-0000000000c1', :insp, 'CC-1', 'OCP Ejemplo', current_date - 100, current_date + 600),
  ('00000000-0000-0000-0000-0000000000c2', :dt,   'CC-2', 'OCP Ejemplo', current_date - 900, current_date - 5);
insert into certificado_actividades values
  ('00000000-0000-0000-0000-0000000000c1', 'RETIE24-UF-BASICAS'),
  ('00000000-0000-0000-0000-0000000000c2', 'RETIE24-UF-BASICAS');

\echo '2) designar sin vinculación → debe FALLAR'
insert into designaciones (organismo_id, persona_id, rol, desde) values (:org, :insp, 'inspector', current_date);

insert into vinculaciones (organismo_id, persona_id, tipo, cargo, desde) values
  (:org, :dt, 'laboral', 'Director técnico', current_date - 30),
  (:org, :insp, 'prestacion_servicios', 'Inspector', current_date - 30),
  (:org, :sg, 'laboral', 'Coordinadora de calidad', current_date - 30),
  (:org, :sg2, 'laboral', 'Analista de calidad', current_date - 30);
\echo '3) vinculación duplicada en el mismo periodo → debe FALLAR'
insert into vinculaciones (organismo_id, persona_id, tipo, cargo, desde) values (:org, :insp, 'laboral', 'X', current_date);

\echo '── Designaciones ──'
insert into designaciones (id, organismo_id, persona_id, rol, desde) values
  ('00000000-0000-0000-0000-0000000000d1', :org, :insp, 'inspector', current_date),
  ('00000000-0000-0000-0000-0000000000d2', :org, :dt, 'director_tecnico', current_date),
  ('00000000-0000-0000-0000-0000000000d3', :org, :sg, 'responsable_sg', current_date - 10);
\echo '4) segundo responsable del SG vigente al mismo tiempo → debe FALLAR'
insert into designaciones (organismo_id, persona_id, rol, desde) values (:org, :sg2, 'responsable_sg', current_date);

\echo '5) inspector autorizado en actividad certificada y acreditada → debe PASAR'
insert into designacion_actividades values ('00000000-0000-0000-0000-0000000000d1', 'RETIE24-UF-BASICAS');
\echo '6) inspector en actividad acreditada pero NO certificada → debe FALLAR'
insert into designacion_actividades values ('00000000-0000-0000-0000-0000000000d1', 'RETIE24-SUB-MT');
\echo '7) inspector en actividad NO acreditada → debe FALLAR'
insert into designacion_actividades values ('00000000-0000-0000-0000-0000000000d1', 'RETIE24-EQ-PISCINAS');
\echo '8) director técnico con certificado VENCIDO → debe FALLAR'
insert into designacion_actividades values ('00000000-0000-0000-0000-0000000000d2', 'RETIE24-UF-BASICAS');
\echo '9) actividades a un rol que no las lleva (responsable SG) → debe FALLAR'
insert into designacion_actividades values ('00000000-0000-0000-0000-0000000000d3', 'RETIE24-UF-BASICAS');

\echo '10) relevo del responsable SG: cerrar el actual y designar al nuevo → debe PASAR'
update designaciones set hasta = current_date - 1 where id = '00000000-0000-0000-0000-0000000000d3';
insert into designaciones (organismo_id, persona_id, rol, desde) values (:org, :sg2, 'responsable_sg', current_date);

\echo '── Operación ──'
insert into clientes (id, organismo_id, nombre, nit) values ('00000000-0000-0000-0000-0000000000f1', :org, 'Cliente', '800');
\echo '11) asignar orden en actividad no autorizada al inspector → debe FALLAR'
insert into ordenes_servicio (organismo_id, consecutivo, cliente_id, instalacion, actividad_codigo, inspector_id, solicitud_revisada_en)
values (:org, 'OS-1', '00000000-0000-0000-0000-0000000000f1', 'X', 'RETIE24-SUB-MT', :insp, now());
\echo '12) asignar orden correcta → debe PASAR'
insert into ordenes_servicio (organismo_id, consecutivo, cliente_id, instalacion, actividad_codigo, inspector_id, solicitud_revisada_en)
values (:org, 'OS-2', '00000000-0000-0000-0000-0000000000f1', 'X', 'RETIE24-UF-BASICAS', :insp, now());
\echo '13) borrar una persona → debe FALLAR'
delete from personas where id = :sg;

\echo 'Personal en formato ONAC:'
select sede, nombre_completo, documento, cargo, vinculacion, certificados from v_personal_onac order by 2;
\echo 'Bitácora:'
select tabla, operacion, count(*) from bitacora group by 1, 2 order by 1, 2;
