-- Prueba de 0007_quitar_por_error.sql (después de autenticacion.sql, logos.sql, acceso.sql y revision.sql).
\set ON_ERROR_STOP on
\ir funciones_prueba.sql
truncate prueba.resultados;

-- Datos: GCEI tiene minas por error y la inspectora tiene "básicas" autorizada.
insert into alcance_acreditado (organismo_id, actividad_codigo) values ('bbbbbbbb-0000-0000-0000-000000000001', 'RETIE24-UF-MINAS');
set session_replication_role = replica;   -- (solo en la prueba) autorizar sin cargar su hoja de vida
insert into designacion_actividades (designacion_id, actividad_codigo)
select id, 'RETIE24-UF-BASICAS' from designaciones where persona_id = 'dddddddd-0000-0000-0000-000000000002' and rol = 'inspector';
set session_replication_role = origin;

\echo '══ Quien no administra ══'
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000002"}', false);
set role authenticated;
select prueba.debe_fallar('la inspectora no puede corregir el alcance',
  $q$select quitar_alcance_por_error('bbbbbbbb-0000-0000-0000-000000000001', 'RETIE24-UF-MINAS', 'error')$q$, 'Solo');
reset role;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000003"}', false);
set role authenticated;
select prueba.debe_fallar('un usuario cualquiera tampoco',
  $q$select quitar_alcance_por_error('bbbbbbbb-0000-0000-0000-000000000001', 'RETIE24-UF-MINAS', 'error')$q$, 'Solo');
reset role;

\echo '══ Quien administra (director técnico) ══'
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}', false);
set role authenticated;
select prueba.debe_fallar('exige el motivo',
  $q$select quitar_alcance_por_error('bbbbbbbb-0000-0000-0000-000000000001', 'RETIE24-UF-MINAS', '  ')$q$, 'motivo');
select prueba.debe_pasar('quita minas, registrada por error',
  $q$select quitar_alcance_por_error('bbbbbbbb-0000-0000-0000-000000000001', 'RETIE24-UF-MINAS', 'Se marcó por error; GC&I no inspecciona minas')$q$);
select prueba.debe_ser('ya no está en el alcance',
  $q$select count(*)::text from alcance_acreditado where actividad_codigo = 'RETIE24-UF-MINAS'$q$, '0');
select prueba.debe_fallar('no quita una actividad que ya está autorizada a alguien',
  $q$select quitar_alcance_por_error('bbbbbbbb-0000-0000-0000-000000000001', 'RETIE24-UF-BASICAS', 'x')$q$, 'autorizada a alguien');
select prueba.debe_ser('borrar la autorización directamente no hace nada (0 filas)',
  $q$with b as (delete from designacion_actividades returning 1) select count(*)::text from b$q$, '0');
select prueba.debe_pasar('quita la actividad autorizada por error a la inspectora',
  $q$select quitar_autorizacion_por_error((select id from designaciones where persona_id = 'dddddddd-0000-0000-0000-000000000002' and rol = 'inspector'), 'RETIE24-UF-BASICAS', 'Autorizada por error')$q$);
select prueba.debe_ser('la inspectora queda sin esa actividad',
  $q$select count(*)::text from designacion_actividades da join designaciones d on d.id = da.designacion_id where d.persona_id = 'dddddddd-0000-0000-0000-000000000002'$q$, '0');
select prueba.debe_ser('borrar el alcance directamente sigue prohibido (0 filas)',
  $q$with b as (delete from alcance_acreditado where organismo_id = 'bbbbbbbb-0000-0000-0000-000000000001' returning 1) select count(*)::text from b$q$, '0');
reset role;

\echo '══ Bitácora ══'
select prueba.debe_ser('la bitácora guarda el alcance quitado, quién y el motivo',
  $q$select (despues->>'motivo') || ' · ' || (usuario::text) from bitacora where tabla = 'alcance_acreditado' and operacion = 'DELETE (registrada por error)'$q$,
  'Se marcó por error; GC&I no inspecciona minas · aaaaaaaa-0000-0000-0000-000000000001');
select prueba.debe_ser('y la autorización quitada con su motivo',
  $q$select despues->>'motivo' from bitacora where tabla = 'designacion_actividades' and operacion = 'DELETE (registrada por error)'$q$, 'Autorizada por error');
select prueba.debe_ser('la marca de corrección no queda activa', $q$select coalesce(nullif(current_setting('delta.correccion', true), ''), 'vacía')$q$, 'vacía');

\echo '══ Resumen ══'
select count(*) filter (where ok) as correctas, count(*) filter (where not ok) as fallidas from prueba.resultados;
select texto as fallidas from prueba.resultados where not ok;
