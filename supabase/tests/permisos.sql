-- Prueba de 0009_permisos_alcance.sql (después de autenticacion, logos, acceso, revision, correcciones y documentos).
\set ON_ERROR_STOP on
\ir funciones_prueba.sql
truncate prueba.resultados;

-- Suplente del SG en GCEI (usuario 10).
insert into auth.users (id, email) values ('aaaaaaaa-0000-0000-0000-000000000010', 'suplente.sg@example.com');
insert into personas (id, documento, nombres, apellidos, correo) values ('dddddddd-0000-0000-0000-000000000010', '1010', 'Sara', 'Suplente', 'suplente.sg@example.com');
insert into vinculaciones (organismo_id, persona_id, tipo, cargo, desde) values ('bbbbbbbb-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000010', 'laboral', 'Calidad', current_date);
insert into designaciones (organismo_id, persona_id, rol, desde) values ('bbbbbbbb-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000010', 'suplente_sg', current_date);

\echo '══ Director técnico suplente (sin gerencia ni SG) ══'
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000009"}', false);
set role authenticated;
select prueba.debe_ser('no cambia el estado del alcance (0 filas)',
  $q$with u as (update alcance_acreditado set estado = 'suspendida' where organismo_id = 'bbbbbbbb-0000-0000-0000-000000000001' returning 1) select count(*)::text from u$q$, '0');
select prueba.debe_fallar('no agrega actividades',
  $q$insert into alcance_acreditado (organismo_id, actividad_codigo, estado) values ('bbbbbbbb-0000-0000-0000-000000000001', 'RETIE24-UF-DIST', 'en_tramite')$q$, 'row-level security');
select prueba.debe_fallar('no quita actividades por error',
  $q$select quitar_alcance_por_error('bbbbbbbb-0000-0000-0000-000000000001', 'RETIE24-UF-BASICAS', 'x')$q$, 'gerencia o el responsable del SG');
select prueba.debe_ser('no modifica el organismo (0 filas)',
  $q$with u as (update organismos set ciudad = 'X' where id = 'bbbbbbbb-0000-0000-0000-000000000001' returning 1) select count(*)::text from u$q$, '0');
select prueba.debe_fallar('no carga documentos del organismo',
  $q$insert into documentos_organismo (organismo_id, tipo, archivo_ruta, fecha) values ('bbbbbbbb-0000-0000-0000-000000000001', 'independencia', 'bbbbbbbb-0000-0000-0000-000000000001/independencia/s.pdf', current_date)$q$, 'row-level security');
reset role;

\echo '══ Suplente del SG ══'
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000010"}', false);
set role authenticated;
select prueba.debe_pasar('agrega una actividad en trámite',
  $q$insert into alcance_acreditado (organismo_id, actividad_codigo, estado) values ('bbbbbbbb-0000-0000-0000-000000000001', 'RETIE24-UF-DIST', 'en_tramite')$q$);
select prueba.debe_fallar('pero no la agrega como acreditada',
  $q$insert into alcance_acreditado (organismo_id, actividad_codigo, estado) values ('bbbbbbbb-0000-0000-0000-000000000001', 'RETIE24-UF-AUTOGEN', 'acreditada')$q$, 'row-level security');
select prueba.debe_ser('no cambia el estado (solo la gerencia) (0 filas)',
  $q$with u as (update alcance_acreditado set estado = 'acreditada' where actividad_codigo = 'RETIE24-UF-DIST' returning 1) select count(*)::text from u$q$, '0');
select prueba.debe_pasar('quita por error la que agregó',
  $q$select quitar_alcance_por_error('bbbbbbbb-0000-0000-0000-000000000001', 'RETIE24-UF-DIST', 'La agregué por error')$q$);
select prueba.debe_ser('modifica los datos del organismo',
  $q$with u as (update organismos set telefono = '601 000' where id = 'bbbbbbbb-0000-0000-0000-000000000001' returning 1) select count(*)::text from u$q$, '1');
select prueba.debe_pasar('carga un documento del organismo',
  $q$insert into documentos_organismo (organismo_id, tipo, archivo_ruta, fecha, firmado_por) values ('bbbbbbbb-0000-0000-0000-000000000001', 'independencia', 'bbbbbbbb-0000-0000-0000-000000000001/independencia/s.pdf', current_date, 'Rep. legal')$q$);
reset role;
select prueba.debe_ser('la bitácora indica que actuó la suplente del SG',
  $q$select array_to_string(en_calidad_de, ',') from bitacora where tabla = 'organismos' and operacion = 'UPDATE' and despues->>'telefono' = '601 000'$q$, 'suplente_sg');

\echo '══ Gerencia ══'
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}', false);
set role authenticated;
select prueba.debe_ser('cambia el estado del alcance',
  $q$with u as (update alcance_acreditado set estado = 'suspendida', observacion = 'Prueba' where organismo_id = 'bbbbbbbb-0000-0000-0000-000000000001' and actividad_codigo = 'RETIE24-UF-BASICAS' returning 1) select count(*)::text from u$q$, '1');
select prueba.debe_ser('queda quién y en qué calidad',
  $q$select (estado_por::text = 'dddddddd-0000-0000-0000-000000000001')::text || ' ' || estado_en_calidad from alcance_acreditado where actividad_codigo = 'RETIE24-UF-BASICAS' and organismo_id = 'bbbbbbbb-0000-0000-0000-000000000001'$q$,
  'true director_tecnico, gerente');
select prueba.debe_ser('lee la bitácora de su organismo', $q$select (count(*) > 0)::text from bitacora where organismo_id = 'bbbbbbbb-0000-0000-0000-000000000001'$q$, 'true');
reset role;

\echo '══ Arranque ══'
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}', false);
set role authenticated;
select prueba.debe_pasar('el creador agrega una actividad acreditada en el arranque',
  $q$insert into alcance_acreditado (organismo_id, actividad_codigo, estado) values ('bbbbbbbb-0000-0000-0000-000000000002', 'RETIE24-UF-BASICAS', 'acreditada')$q$);
select prueba.debe_ser('y cambia su estado',
  $q$with u as (update alcance_acreditado set estado = 'en_tramite' where organismo_id = 'bbbbbbbb-0000-0000-0000-000000000002' returning 1) select count(*)::text from u$q$, '1');
select prueba.debe_ser('queda como creador del organismo',
  $q$select estado_en_calidad from alcance_acreditado where organismo_id = 'bbbbbbbb-0000-0000-0000-000000000002'$q$, 'creador del organismo (arranque)');
reset role;

\echo '══ Otro organismo ══'
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000004"}', false);
set role authenticated;
select prueba.debe_ser('no lee la bitácora de GCEI', $q$select count(*)::text from bitacora where organismo_id = 'bbbbbbbb-0000-0000-0000-000000000001'$q$, '0');
reset role;

\echo '══ Resumen ══'
select count(*) filter (where ok) as correctas, count(*) filter (where not ok) as fallidas from prueba.resultados;
select texto as fallidas from prueba.resultados where not ok;
