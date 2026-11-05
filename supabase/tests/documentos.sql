-- Prueba de 0008_documentos_organismo.sql (después de autenticacion, logos, acceso, revision y correcciones).
\set ON_ERROR_STOP on
\ir funciones_prueba.sql
truncate prueba.resultados;

\echo '══ La gerencia carga los documentos ══'
-- (en logos.sql el director técnico de GCEI quedó también como gerente)
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}', false);
set role authenticated;
select prueba.debe_pasar('carga el PDF del certificado en la carpeta del organismo',
  $q$insert into storage.objects (bucket_id, name) values ('documentos', 'bbbbbbbb-0000-0000-0000-000000000001/acreditacion/v1.pdf')$q$);
select prueba.debe_pasar('registra el certificado de acreditación',
  $q$insert into documentos_organismo (organismo_id, tipo, archivo_ruta, numero, emisor, fecha, renovacion, actualizacion, hasta)
     values ('bbbbbbbb-0000-0000-0000-000000000001', 'acreditacion', 'bbbbbbbb-0000-0000-0000-000000000001/acreditacion/v1.pdf',
             '17-OIN-032', 'ONAC', '2018-02-05', '2026-02-05', '2026-10-06', '2031-02-04')$q$);
select prueba.debe_ser('el organismo toma las fechas del certificado vigente',
  $q$select codigo_acreditacion || ' ' || acreditacion_otorgada || ' ' || acreditacion_renovada || ' ' || acreditacion_vence from organismos where id = 'bbbbbbbb-0000-0000-0000-000000000001'$q$,
  '17-OIN-032 2018-02-05 2026-02-05 2031-02-04');
select prueba.debe_pasar('ONAC actualiza el certificado: se carga una versión nueva',
  $q$insert into documentos_organismo (organismo_id, tipo, archivo_ruta, numero, emisor, fecha, renovacion, actualizacion, hasta)
     values ('bbbbbbbb-0000-0000-0000-000000000001', 'acreditacion', 'bbbbbbbb-0000-0000-0000-000000000001/acreditacion/v2.pdf',
             '17-OIN-032', 'ONAC', '2018-02-05', '2026-02-05', '2026-11-20', '2031-02-04')$q$);
select prueba.debe_ser('la anterior queda reemplazada y se conserva (1 vigente de 2)',
  $q$select count(*) filter (where reemplazado_en is null) || ' de ' || count(*) from documentos_organismo where tipo = 'acreditacion'$q$, '1 de 2');
select prueba.debe_pasar('registra la póliza',
  $q$insert into documentos_organismo (organismo_id, tipo, archivo_ruta, numero, emisor, valor, desde, hasta)
     values ('bbbbbbbb-0000-0000-0000-000000000001', 'poliza_rc', 'bbbbbbbb-0000-0000-0000-000000000001/poliza_rc/p1.pdf', 'RC-123', 'Aseguradora X', 500000000, current_date - 10, current_date + 355)$q$);
select prueba.debe_ser('el organismo toma el número y vencimiento de la póliza',
  $q$select poliza_rc_numero || ' ' || (poliza_rc_vence = current_date + 355) from organismos where id = 'bbbbbbbb-0000-0000-0000-000000000001'$q$, 'RC-123 true');
select prueba.debe_pasar('registra la declaración de independencia',
  $q$insert into documentos_organismo (organismo_id, tipo, archivo_ruta, fecha, firmado_por)
     values ('bbbbbbbb-0000-0000-0000-000000000001', 'independencia', 'bbbbbbbb-0000-0000-0000-000000000001/independencia/d1.pdf', current_date, 'Representante legal')$q$);
select prueba.debe_ser('el organismo toma la fecha de la declaración',
  $q$select (declaracion_independencia = current_date)::text from organismos where id = 'bbbbbbbb-0000-0000-0000-000000000001'$q$, 'true');
select prueba.debe_fallar('la póliza exige su vigencia',
  $q$insert into documentos_organismo (organismo_id, tipo, archivo_ruta, numero) values ('bbbbbbbb-0000-0000-0000-000000000001', 'poliza_rc', 'bbbbbbbb-0000-0000-0000-000000000001/poliza_rc/p2.pdf', 'X')$q$, 'check');
select prueba.debe_fallar('el archivo debe estar en la carpeta del organismo',
  $q$insert into documentos_organismo (organismo_id, tipo, archivo_ruta, fecha) values ('bbbbbbbb-0000-0000-0000-000000000001', 'independencia', 'otro/independencia/x.pdf', current_date)$q$, 'carpeta del organismo');
select prueba.debe_ser('no se modifican (0 filas)', $q$with u as (update documentos_organismo set numero = 'X' returning 1) select count(*)::text from u$q$, '0');
select prueba.debe_ser('no se borran (0 filas)', $q$with u as (delete from documentos_organismo returning 1) select count(*)::text from u$q$, '0');
select prueba.debe_pasar('carga el PDF de la póliza', $q$insert into storage.objects (bucket_id, name) values ('documentos', 'bbbbbbbb-0000-0000-0000-000000000001/poliza_rc/p1.pdf')$q$);
reset role;

\echo '══ La inspectora ══'
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000002"}', false);
set role authenticated;
select prueba.debe_ser('ve el certificado de acreditación (y su historial)', $q$select count(*)::text from documentos_organismo where tipo = 'acreditacion'$q$, '2');
select prueba.debe_ser('no ve la póliza ni la declaración', $q$select count(*)::text from documentos_organismo where tipo <> 'acreditacion'$q$, '0');
select prueba.debe_ser('abre el PDF del certificado pero no el de la póliza',
  $q$select string_agg(segunda_carpeta(name), ',' order by name) from storage.objects where bucket_id = 'documentos'$q$, 'acreditacion');
select prueba.debe_fallar('no puede cargar documentos',
  $q$insert into documentos_organismo (organismo_id, tipo, archivo_ruta, fecha) values ('bbbbbbbb-0000-0000-0000-000000000001', 'independencia', 'bbbbbbbb-0000-0000-0000-000000000001/independencia/z.pdf', current_date)$q$, 'row-level security');
select prueba.debe_fallar('ni archivos',
  $q$insert into storage.objects (bucket_id, name) values ('documentos', 'bbbbbbbb-0000-0000-0000-000000000001/acreditacion/z.pdf')$q$, 'row-level security');
reset role;

\echo '══ Otro organismo y usuarios cualquiera ══'
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000004"}', false);
set role authenticated;
select prueba.debe_ser('la gerencia de otro organismo no ve nada', $q$select (select count(*) from documentos_organismo) + (select count(*) from storage.objects where bucket_id = 'documentos') || ''$q$, '0');
reset role;
select prueba.debe_ser('la carpeta de documentos no es pública', $q$select public::text from storage.buckets where id = 'documentos'$q$, 'false');

\echo '══ Resumen ══'
select count(*) filter (where ok) as correctas, count(*) filter (where not ok) as fallidas from prueba.resultados;
select texto as fallidas from prueba.resultados where not ok;
