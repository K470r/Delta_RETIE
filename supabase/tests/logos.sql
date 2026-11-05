-- Prueba de 0004_logos.sql (PostgreSQL local, después de autenticacion.sql).
\set ON_ERROR_STOP on
\ir funciones_prueba.sql
truncate prueba.resultados;

\echo '══ Logos ══'
-- El director técnico del organismo GCEI (de autenticacion.sql) también queda como gerente:
-- en 0002 solo la gerencia y el responsable del SG modifican los datos del organismo.
insert into designaciones (organismo_id, persona_id, rol, desde)
values ('bbbbbbbb-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000001', 'gerente', current_date);
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}', false);
set role authenticated;
select prueba.debe_pasar('quien administra carga el logo en la carpeta de su organismo',
  $q$insert into storage.objects (bucket_id, name) values ('logos', 'bbbbbbbb-0000-0000-0000-000000000001/logo-1.png')$q$);
select prueba.debe_ser('y lo deja como logo vigente',
  $q$with u as (update organismos set logo_ruta = 'bbbbbbbb-0000-0000-0000-000000000001/logo-1.png' where id = 'bbbbbbbb-0000-0000-0000-000000000001' returning 1) select count(*)::text from u$q$, '1');
select prueba.debe_fallar('no puede apuntar a la carpeta de otro organismo',
  $q$update organismos set simbolo_onac_ruta = 'bbbbbbbb-0000-0000-0000-000000000002/x.png' where id = 'bbbbbbbb-0000-0000-0000-000000000001'$q$, 'carpeta del organismo');
select prueba.debe_fallar('no puede cargar en una carpeta que no es un organismo',
  $q$insert into storage.objects (bucket_id, name) values ('logos', 'cualquiera/x.png')$q$, 'row-level security');
reset role;

-- Un director técnico que no es gerencia no modifica el organismo: tampoco carga logos.
reset role;
insert into personas (id, documento, nombres, apellidos) values ('dddddddd-0000-0000-0000-000000000009', '9009', 'Otro', 'Director');
insert into vinculaciones (organismo_id, persona_id, tipo, cargo, desde) values ('bbbbbbbb-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000009', 'laboral', 'DT', current_date);
insert into designaciones (organismo_id, persona_id, rol, desde) values ('bbbbbbbb-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000009', 'director_tecnico_suplente', current_date);
insert into auth.users (id, email) values ('aaaaaaaa-0000-0000-0000-000000000009', 'otro.dt@example.com');
update personas set correo = 'otro.dt@example.com' where id = 'dddddddd-0000-0000-0000-000000000009';
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000009"}', false);
set role authenticated;
select prueba.debe_fallar('un director técnico suplente (sin gerencia) no carga logos',
  $q$insert into storage.objects (bucket_id, name) values ('logos', 'bbbbbbbb-0000-0000-0000-000000000001/logo-9.png')$q$, 'row-level security');
reset role;

-- La inspectora (no administra)
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000002"}', false);
set role authenticated;
select prueba.debe_fallar('quien no administra no puede cargar logos',
  $q$insert into storage.objects (bucket_id, name) values ('logos', 'bbbbbbbb-0000-0000-0000-000000000001/logo-2.png')$q$, 'row-level security');
reset role;

-- Usuario cualquiera
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000003"}', false);
set role authenticated;
select prueba.debe_fallar('un usuario cualquiera no puede cargar logos',
  $q$insert into storage.objects (bucket_id, name) values ('logos', 'bbbbbbbb-0000-0000-0000-000000000001/logo-3.png')$q$, 'row-level security');
reset role;

\echo '══ Resumen ══'
select count(*) filter (where ok) as correctas, count(*) filter (where not ok) as fallidas from prueba.resultados;
select texto as fallidas from prueba.resultados where not ok;
