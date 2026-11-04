-- Prueba de 0003_autenticacion.sql en PostgreSQL local (NO ejecutar en Supabase).
--   createdb prueba
--   psql -d prueba -f supabase/tests/simular_supabase.sql
--   psql -d prueba -f supabase/instalar_todo.sql
--   psql -d prueba -f supabase/migrations/0003_autenticacion.sql
--   psql -d prueba -f supabase/tests/autenticacion.sql
-- Cada verificación imprime OK o FALLO; al final se cuenta el total.
\set ON_ERROR_STOP on
set client_min_messages = notice;

\ir funciones_prueba.sql
truncate prueba.resultados;

-- Usuarios: el administrador de la plataforma, una inspectora registrada después, un intruso.
insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'DirectorTecnico.GCEISAS@gmail.com'),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'intruso@example.com');

\echo '══ 1. Como administrador de la plataforma ══'
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', false);
set role authenticated;

select prueba.debe_ser('es administrador de la plataforma (correo sin importar mayúsculas)', 'select soy_admin_plataforma()::text', 'true');
select prueba.debe_pasar('crea un organismo',
  $q$insert into organismos (id, razon_social, nit) values ('bbbbbbbb-0000-0000-0000-000000000001', 'GCEI S.A.S.', '900111222')$q$);
select prueba.debe_ser('creado_por queda con su usuario', $q$select creado_por::text from organismos where nit = '900111222'$q$, 'aaaaaaaa-0000-0000-0000-000000000001');
select prueba.debe_pasar('registra la sede (arranque)',
  $q$insert into sedes (id, organismo_id, nombre, principal) values ('cccccccc-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', 'Principal', true)$q$);
select prueba.debe_pasar('registra el alcance (arranque)',
  $q$insert into alcance_acreditado (organismo_id, actividad_codigo) values ('bbbbbbbb-0000-0000-0000-000000000001', 'RETIE24-UF-BASICAS')$q$);
select prueba.debe_pasar('edita el organismo (arranque)',
  $q$update organismos set ciudad = 'Bogotá' where id = 'bbbbbbbb-0000-0000-0000-000000000001'$q$);
select prueba.debe_ser('ve su organismo en arranque', 'select count(*)::text from organismos', '1');

select prueba.debe_pasar('registra a otra persona (inspectora, aún sin usuario)',
  $q$insert into personas (id, documento, nombres, apellidos, correo, matricula_numero)
     values ('dddddddd-0000-0000-0000-000000000002', '2002', 'Laura', 'Inspectora', 'laura@example.com', 'CN-2')$q$);
select prueba.debe_ser('la ve aunque no esté vinculada (la registró él)', 'select count(*)::text from personas', '1');
select prueba.debe_fallar('en arranque no puede vincular a otra persona antes de registrarse él',
  $q$insert into vinculaciones (organismo_id, persona_id, tipo, cargo, desde) values ('bbbbbbbb-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000002', 'laboral', 'Inspectora', current_date)$q$,
  'Primero regístrese');
select prueba.debe_fallar('no puede asignarse a mano el usuario de acceso',
  $q$insert into personas (documento, nombres, apellidos, usuario_id) values ('3003', 'X', 'Y', 'aaaaaaaa-0000-0000-0000-000000000003')$q$,
  'automáticamente');

select prueba.debe_pasar('se registra a sí mismo como persona con su correo',
  $q$insert into personas (id, documento, nombres, apellidos, correo, matricula_numero)
     values ('dddddddd-0000-0000-0000-000000000001', '1001', 'Director', 'Técnico', 'directortecnico.gceisas@gmail.com', 'CN-1')$q$);
select prueba.debe_ser('queda enlazado a su usuario (persona_actual)', 'select persona_actual()::text', 'dddddddd-0000-0000-0000-000000000001');
select prueba.debe_fallar('no puede cambiar el enlace de usuario',
  $q$update personas set usuario_id = null where id = 'dddddddd-0000-0000-0000-000000000001'$q$, 'automáticamente');
select prueba.debe_fallar('en arranque sigue sin poder vincular a otra persona',
  $q$insert into vinculaciones (organismo_id, persona_id, tipo, cargo, desde) values ('bbbbbbbb-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000002', 'laboral', 'Inspectora', current_date)$q$,
  'arranque');
select prueba.debe_pasar('se vincula a sí mismo',
  $q$insert into vinculaciones (organismo_id, persona_id, sede_id, tipo, cargo, desde) values ('bbbbbbbb-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001', 'laboral', 'Director técnico', current_date)$q$);
select prueba.debe_pasar('se designa director técnico (termina el arranque)',
  $q$insert into designaciones (id, organismo_id, persona_id, rol, desde) values ('eeeeeeee-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000001', 'director_tecnico', current_date)$q$);
select prueba.debe_ser('ya no está en arranque', $q$select en_arranque('bbbbbbbb-0000-0000-0000-000000000001')::text$q$, 'false');
select prueba.debe_ser('administra por su designación', $q$select administra('bbbbbbbb-0000-0000-0000-000000000001')::text$q$, 'true');
select prueba.debe_ser('sigue viendo el organismo (por vinculación)', 'select count(*)::text from organismos', '1');
select prueba.debe_pasar('registra sus declaraciones',
  $q$insert into declaraciones (organismo_id, persona_id, tipo, fecha) values ('bbbbbbbb-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000001', 'imparcialidad', current_date)$q$);
select prueba.debe_pasar('ahora sí vincula a la inspectora',
  $q$insert into vinculaciones (organismo_id, persona_id, tipo, cargo, desde) values ('bbbbbbbb-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000002', 'prestacion_servicios', 'Inspectora', current_date)$q$);
select prueba.debe_pasar('y la designa inspectora',
  $q$insert into designaciones (organismo_id, persona_id, rol, desde) values ('bbbbbbbb-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000002', 'inspector', current_date)$q$);

\echo '── Verificación de soportes ──'
select prueba.debe_fallar('no puede autoverificar su experiencia',
  $q$insert into experiencias (persona_id, empresa, cargo, desde, reglamento_id, categorias, tipos, verificada, verificada_por)
     values ('dddddddd-0000-0000-0000-000000000001', 'E', 'C', current_date - 100, 'RETIE-2024', '{g}', '{diseno}', true, 'dddddddd-0000-0000-0000-000000000001')$q$,
  'autoverificación');
select prueba.debe_fallar('no puede verificar a nombre de otra persona',
  $q$insert into experiencias (persona_id, empresa, cargo, desde, reglamento_id, categorias, tipos, verificada, verificada_por)
     values ('dddddddd-0000-0000-0000-000000000002', 'E', 'C', current_date - 100, 'RETIE-2024', '{g}', '{diseno}', true, 'dddddddd-0000-0000-0000-000000000002')$q$,
  'quien inició sesión');
select prueba.debe_pasar('verifica la experiencia de la inspectora a su nombre',
  $q$insert into experiencias (id, persona_id, empresa, cargo, desde, reglamento_id, categorias, tipos, verificada, verificada_por)
     values ('ffffffff-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000002', 'E', 'C', current_date - 100, 'RETIE-2024', '{g}', '{diseno}', true, 'dddddddd-0000-0000-0000-000000000001')$q$);
select prueba.debe_pasar('desmarca la verificación',
  $q$update experiencias set verificada = false where id = 'ffffffff-0000-0000-0000-000000000001'$q$);
select prueba.debe_ser('verificada_por se limpia al desmarcar', $q$select coalesce(verificada_por::text, 'null') from experiencias where id = 'ffffffff-0000-0000-0000-000000000001'$q$, 'null');
select prueba.debe_ser('la bitácora registra al usuario real', $q$select count(*)::text from bitacora where usuario is null$q$, '0');
reset role;
select prueba.debe_ser('la bitácora registra al usuario real', $q$select (count(*) filter (where usuario = 'aaaaaaaa-0000-0000-0000-000000000001') = count(*))::text from bitacora$q$, 'true');

\echo '══ 2. La inspectora crea su cuenta después ══'
insert into auth.users (id, email) values ('aaaaaaaa-0000-0000-0000-000000000002', 'Laura@Example.com');
select prueba.debe_ser('queda enlazada a su cédula por el correo', $q$select documento from personas where usuario_id = 'aaaaaaaa-0000-0000-0000-000000000002'$q$, '2002');
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000002","role":"authenticated"}', false);
set role authenticated;
select prueba.debe_ser('no es administradora de la plataforma', 'select soy_admin_plataforma()::text', 'false');
select prueba.debe_ser('ve su organismo', 'select count(*)::text from organismos', '1');
select prueba.debe_fallar('no puede crear organismos',
  $q$insert into organismos (razon_social, nit) values ('Otro', '900999999')$q$, 'row-level security');
select prueba.debe_ser('no administra (es inspectora)', $q$select administra('bbbbbbbb-0000-0000-0000-000000000001')::text$q$, 'false');
select prueba.debe_ser('no puede editar el organismo (0 filas)', $q$with u as (update organismos set ciudad = 'X' returning 1) select count(*)::text from u$q$, '0');
reset role;

\echo '══ 3. Un usuario cualquiera ══'
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000003","role":"authenticated"}', false);
set role authenticated;
select prueba.debe_ser('no ve organismos', 'select count(*)::text from organismos', '0');
select prueba.debe_ser('no ve personas', 'select count(*)::text from personas', '0');
select prueba.debe_ser('no ve el personal en la vista ONAC', 'select count(*)::text from v_personal_onac', '0');
select prueba.debe_fallar('no puede crear organismos',
  $q$insert into organismos (razon_social, nit) values ('Otro', '900999998')$q$, 'row-level security');
select prueba.debe_fallar('no puede crear sedes en un organismo ajeno',
  $q$insert into sedes (organismo_id, nombre) values ('bbbbbbbb-0000-0000-0000-000000000001', 'X')$q$, 'row-level security');
reset role;

\echo '══ 4. Un segundo organismo del administrador queda en arranque ══'
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', false);
set role authenticated;
select prueba.debe_pasar('crea otro organismo',
  $q$insert into organismos (id, razon_social, nit) values ('bbbbbbbb-0000-0000-0000-000000000002', 'Otro OIN', '900333444')$q$);
select prueba.debe_fallar('en arranque no designa a otra persona',
  $q$insert into vinculaciones (organismo_id, persona_id, tipo, cargo, desde) values ('bbbbbbbb-0000-0000-0000-000000000002', 'dddddddd-0000-0000-0000-000000000002', 'laboral', 'Inspectora', current_date)$q$,
  'arranque');
reset role;

\echo '══ Resumen ══'
select count(*) filter (where ok) as correctas, count(*) filter (where not ok) as fallidas from prueba.resultados;
select texto as fallidas from prueba.resultados where not ok;
