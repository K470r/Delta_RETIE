-- Prueba de 0005_acceso_por_rol.sql (PostgreSQL local, después de autenticacion.sql y logos.sql).
\set ON_ERROR_STOP on
\ir funciones_prueba.sql
truncate prueba.resultados;

-- Segundo organismo con su propio gerente (usuario 4), sin relación con GCEI.
insert into auth.users (id, email) values ('aaaaaaaa-0000-0000-0000-000000000004', 'gerente.otro@example.com');
insert into organismos (id, razon_social, nit) values ('bbbbbbbb-0000-0000-0000-000000000004', 'Otro organismo', '900444555');
insert into personas (id, documento, nombres, apellidos, correo) values
  ('dddddddd-0000-0000-0000-000000000004', '4004', 'Gerente', 'Otro', 'gerente.otro@example.com');
insert into vinculaciones (organismo_id, persona_id, tipo, cargo, desde) values
  ('bbbbbbbb-0000-0000-0000-000000000004', 'dddddddd-0000-0000-0000-000000000004', 'laboral', 'Gerente', current_date);
insert into designaciones (organismo_id, persona_id, rol, desde) values
  ('bbbbbbbb-0000-0000-0000-000000000004', 'dddddddd-0000-0000-0000-000000000004', 'gerente', current_date);
-- Un certificado del director técnico de GCEI (para ver que la inspectora no lo ve).
insert into certificados_competencia (id, persona_id, reglamento_id, numero, certificador, fecha_emision, fecha_vencimiento)
values ('cccccccc-0000-0000-0000-0000000000d1', 'dddddddd-0000-0000-0000-000000000001', 'RETIE-2024', 'CP-DT', 'OCP', current_date - 10, current_date + 1000);

\echo '══ La gerencia de otro organismo ══'
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000004"}', false);
set role authenticated;
select prueba.debe_ser('no ve la experiencia de personas de GCEI (fuga de 0002 corregida)', 'select count(*)::text from experiencias', '0');
select prueba.debe_ser('no ve los certificados de personas de GCEI', 'select count(*)::text from certificados_competencia', '0');
select prueba.debe_ser('no modifica personas de GCEI (0 filas)',
  $q$with u as (update personas set telefono = 'x' where documento = '2002' returning 1) select count(*)::text from u$q$, '0');
select prueba.debe_fallar('no registra experiencia a una persona de GCEI',
  $q$insert into experiencias (persona_id, empresa, cargo, desde, reglamento_id, tipos) values ('dddddddd-0000-0000-0000-000000000002', 'E', 'C', current_date - 10, 'RETIE-2024', '{diseno}')$q$, 'row-level security');
select prueba.debe_fallar('no ve ni descarga soportes de GCEI',
  $q$do $x$ begin if (select count(*) from storage.objects where bucket_id = 'soportes') > 0 then raise exception 've soportes'; end if;
     insert into storage.objects (bucket_id, name) values ('soportes', 'dddddddd-0000-0000-0000-000000000002/x.pdf'); end $x$$q$, 'row-level security');
select prueba.debe_ser('no ve el logo de GCEI', $q$select count(*)::text from storage.objects where bucket_id = 'logos'$q$, '0');
reset role;

\echo '══ El director técnico de GCEI (administra) ══'
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}', false);
set role authenticated;
select prueba.debe_ser('ve la experiencia de la inspectora de su organismo', $q$select count(*)::text from experiencias where persona_id = 'dddddddd-0000-0000-0000-000000000002'$q$, '1');
select prueba.debe_pasar('carga el soporte de la inspectora en su carpeta',
  $q$insert into storage.objects (bucket_id, name) values ('soportes', 'dddddddd-0000-0000-0000-000000000002/experiencia-1.pdf')$q$);
select prueba.debe_ser('y lo deja registrado en la experiencia',
  $q$with u as (update experiencias set soporte_ruta = 'dddddddd-0000-0000-0000-000000000002/experiencia-1.pdf' where id = 'ffffffff-0000-0000-0000-000000000001' returning 1) select count(*)::text from u$q$, '1');
select prueba.debe_fallar('el soporte debe estar en la carpeta de la persona',
  $q$update experiencias set soporte_ruta = 'dddddddd-0000-0000-0000-000000000001/x.pdf' where id = 'ffffffff-0000-0000-0000-000000000001'$q$, 'carpeta de la persona');
select prueba.debe_ser('registra a una persona nueva y la ve mientras la vincula',
  $q$with i as (insert into personas (id, documento, nombres, apellidos) values ('dddddddd-0000-0000-0000-000000000005', '5005', 'Nueva', 'Persona') returning 1)
     select count(*)::text from i$q$, '1');
select prueba.debe_pasar('y puede registrar su hoja de vida antes de vincularla',
  $q$insert into experiencias (persona_id, empresa, cargo, desde, reglamento_id, tipos) values ('dddddddd-0000-0000-0000-000000000005', 'E', 'C', current_date - 10, 'RETIE-2024', '{diseno}')$q$);
reset role;

\echo '══ La inspectora (no administra) ══'
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000002"}', false);
set role authenticated;
select prueba.debe_ser('ve su propia experiencia', $q$select count(*)::text from experiencias where persona_id = 'dddddddd-0000-0000-0000-000000000002'$q$, '1');
select prueba.debe_ser('ve su propio soporte', $q$select count(*)::text from storage.objects where bucket_id = 'soportes'$q$, '1');
select prueba.debe_ser('no ve el certificado de su compañero director técnico', 'select count(*)::text from certificados_competencia', '0');
select prueba.debe_ser('sí ve el logo de su organismo', $q$select count(*)::text from storage.objects where bucket_id = 'logos'$q$, '1');
select prueba.debe_pasar('puede cargar el soporte de su propia hoja de vida',
  $q$insert into storage.objects (bucket_id, name) values ('soportes', 'dddddddd-0000-0000-0000-000000000002/diploma-1.pdf')$q$);
select prueba.debe_fallar('no puede cargar soportes en la carpeta de otra persona',
  $q$insert into storage.objects (bucket_id, name) values ('soportes', 'dddddddd-0000-0000-0000-000000000001/x.pdf')$q$, 'row-level security');
reset role;

\echo '══ Un usuario cualquiera ══'
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000003"}', false);
set role authenticated;
select prueba.debe_ser('no ve soportes ni logos', $q$select count(*)::text from storage.objects$q$, '0');
select prueba.debe_ser('no ve hojas de vida', $q$select (select count(*) from experiencias) + (select count(*) from formacion) + (select count(*) from certificados_competencia) || ''$q$, '0');
reset role;

select prueba.debe_ser('los logos y los soportes no son públicos', $q$select count(*)::text from storage.buckets where id in ('logos', 'soportes') and public$q$, '0');

\echo '══ Resumen ══'
select count(*) filter (where ok) as correctas, count(*) filter (where not ok) as fallidas from prueba.resultados;
select texto as fallidas from prueba.resultados where not ok;
