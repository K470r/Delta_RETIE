-- Prueba de 0006_acceso_revision.sql (después de autenticacion.sql, logos.sql y acceso.sql).
\set ON_ERROR_STOP on
\ir funciones_prueba.sql
truncate prueba.resultados;

\echo '══ Sin acceso de revisión ══'
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000003"}', false);
set role authenticated;
select prueba.debe_ser('un usuario cualquiera no ve el organismo', 'select count(*)::text from organismos', '0');
select prueba.debe_fallar('no puede darse acceso a sí mismo',
  $q$insert into accesos_revision (organismo_id, correo, hasta, motivo) values ('bbbbbbbb-0000-0000-0000-000000000001', 'intruso@example.com', now() + interval '1 day', 'x')$q$, 'row-level security');
reset role;

\echo '══ El administrador de la plataforma otorga el acceso ══'
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}', false);
set role authenticated;
select prueba.debe_pasar('otorga acceso de revisión por un día',
  $q$insert into accesos_revision (organismo_id, correo, hasta, motivo) select id, 'intruso@example.com', now() + interval '1 day', 'Revisión de la aplicación' from organismos where nit = '900111222'$q$);
reset role;

\echo '══ Con acceso de revisión vigente ══'
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000003"}', false);
set role authenticated;
select prueba.debe_ser('ve el organismo', $q$select count(*)::text from organismos where nit = '900111222'$q$, '1');
select prueba.debe_ser('ve las designaciones', $q$select (count(*) > 0)::text from designaciones$q$, 'true');
select prueba.debe_ser('ve las personas vinculadas', $q$select (count(*) >= 2)::text from personas$q$, 'true');
select prueba.debe_ser('ve la hoja de vida de la inspectora', $q$select count(*)::text from experiencias where persona_id = 'dddddddd-0000-0000-0000-000000000002'$q$, '1');
select prueba.debe_ser('ve los certificados del personal', $q$select (count(*) > 0)::text from certificados_competencia$q$, 'true');
select prueba.debe_ser('ve los soportes', $q$select (count(*) > 0)::text from storage.objects where bucket_id = 'soportes'$q$, 'true');
select prueba.debe_ser('ve los logos', $q$select (count(*) > 0)::text from storage.objects where bucket_id = 'logos'$q$, 'true');
select prueba.debe_ser('la aplicación sabe hasta cuándo', 'select count(*)::text from mis_accesos_revision()', '1');
select prueba.debe_ser('no ve el otro organismo', $q$select count(*)::text from organismos where nit = '900444555'$q$, '0');
select prueba.debe_fallar('solo lectura: no registra sedes',
  $q$insert into sedes (organismo_id, nombre) values ('bbbbbbbb-0000-0000-0000-000000000001', 'X')$q$, 'row-level security');
select prueba.debe_ser('solo lectura: no modifica el organismo (0 filas)',
  $q$with u as (update organismos set ciudad = 'X' where nit = '900111222' returning 1) select count(*)::text from u$q$, '0');
select prueba.debe_fallar('solo lectura: no registra experiencia',
  $q$insert into experiencias (persona_id, empresa, cargo, desde, reglamento_id, tipos) values ('dddddddd-0000-0000-0000-000000000002', 'E', 'C', current_date - 10, 'RETIE-2024', '{diseno}')$q$, 'row-level security');
select prueba.debe_fallar('solo lectura: no carga soportes',
  $q$insert into storage.objects (bucket_id, name) values ('soportes', 'dddddddd-0000-0000-0000-000000000002/z.pdf')$q$, 'row-level security');
select prueba.debe_ser('no puede alargar su propio acceso (0 filas)',
  $q$with u as (update accesos_revision set hasta = hasta + interval '30 days' returning 1) select count(*)::text from u$q$, '0');
reset role;

\echo '══ Al vencer se apaga solo ══'
update accesos_revision set desde = now() - interval '3 days', hasta = now() - interval '1 second';
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000003"}', false);
set role authenticated;
select prueba.debe_ser('ya no ve el organismo', 'select count(*)::text from organismos', '0');
select prueba.debe_ser('ya no ve hojas de vida ni soportes', $q$select ((select count(*) from experiencias) + (select count(*) from storage.objects))::text$q$, '0');
reset role;
select prueba.debe_ser('queda en la bitácora', $q$select (count(*) >= 2)::text from bitacora where tabla = 'accesos_revision'$q$, 'true');

\echo '══ Resumen ══'
select count(*) filter (where ok) as correctas, count(*) filter (where not ok) as fallidas from prueba.resultados;
select texto as fallidas from prueba.resultados where not ok;
