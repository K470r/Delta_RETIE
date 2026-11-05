-- Prueba de 0010_matricula_ingeniero.sql (después de las pruebas anteriores).
\set ON_ERROR_STOP on
\ir funciones_prueba.sql
truncate prueba.resultados;
\set laura '''dddddddd-0000-0000-0000-000000000002'''

select prueba.debe_ser('sin entidad, la matrícula no sirve para inspector',
  $q$select (motivo_competencia('dddddddd-0000-0000-0000-000000000002', 'RETIE24-UF-BASICAS', 'inspector') like '%matrícula profesional de ingeniero%')::text$q$, 'true');

\echo '══ La inspectora ══'
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000002"}', false);
set role authenticated;
select prueba.debe_pasar('registra su matrícula del CONTE',
  $q$update personas set matricula_entidad = 'CONTE' where id = 'dddddddd-0000-0000-0000-000000000002'$q$);
select prueba.debe_ser('con el CONTE tampoco sirve',
  $q$select (motivo_competencia('dddddddd-0000-0000-0000-000000000002', 'RETIE24-UF-BASICAS', 'inspector') like '%matrícula profesional de ingeniero%')::text$q$, 'true');
select prueba.debe_fallar('no puede marcarse la aceptación a mano',
  $q$update personas set matricula_aceptada_en = now() where id = 'dddddddd-0000-0000-0000-000000000002'$q$, 'Aceptar matrícula');
select prueba.debe_fallar('no puede aceptar su propia matrícula',
  $q$select aceptar_matricula('dddddddd-0000-0000-0000-000000000002', 'x')$q$, 'Solo la gerencia');
reset role;

\echo '══ La gerencia ══'
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}', false);
set role authenticated;
select prueba.debe_fallar('el CONTE no se puede aceptar',
  $q$select aceptar_matricula('dddddddd-0000-0000-0000-000000000002', 'x')$q$, 'CONTE matricula técnicos');
select prueba.debe_pasar('la inspectora cambia a otra entidad (consejo poco común)',
  $q$update personas set matricula_entidad = 'Consejo Profesional de Ingeniería de Ejemplo (Ley X)' where id = 'dddddddd-0000-0000-0000-000000000002'$q$);
select prueba.debe_fallar('exige motivo', $q$select aceptar_matricula('dddddddd-0000-0000-0000-000000000002', ' ')$q$, 'motivo');
select prueba.debe_pasar('la gerencia la acepta con motivo',
  $q$select aceptar_matricula('dddddddd-0000-0000-0000-000000000002', 'Matrícula expedida por consejo de ingeniería reconocido por ley')$q$);
select prueba.debe_ser('queda quién la aceptó',
  $q$select (matricula_aceptada_por::text = 'dddddddd-0000-0000-0000-000000000001')::text from personas where id = 'dddddddd-0000-0000-0000-000000000002'$q$, 'true');
select prueba.debe_ser('ya no la bloquea la matrícula',
  $q$select (coalesce(motivo_competencia('dddddddd-0000-0000-0000-000000000002', 'RETIE24-UF-BASICAS', 'inspector'), '') not like '%matrícula%')::text$q$, 'true');
select prueba.debe_pasar('si cambia el número de matrícula…',
  $q$update personas set matricula_numero = 'CN-2B' where id = 'dddddddd-0000-0000-0000-000000000002'$q$);
select prueba.debe_ser('…la aceptación se pierde',
  $q$select coalesce(matricula_aceptada_en::text, 'sin aceptación') from personas where id = 'dddddddd-0000-0000-0000-000000000002'$q$, 'sin aceptación');
select prueba.debe_fallar('nadie acepta su propia matrícula',
  $q$select aceptar_matricula('dddddddd-0000-0000-0000-000000000001', 'x')$q$, 'propia');
select prueba.debe_pasar('con COPNIA (escrito en minúsculas)…',
  $q$update personas set matricula_entidad = 'copnia' where id = 'dddddddd-0000-0000-0000-000000000002'$q$);
select prueba.debe_ser('…queda normalizado y sí sirve',
  $q$select matricula_entidad || ' ' || (coalesce(motivo_competencia('dddddddd-0000-0000-0000-000000000002', 'RETIE24-UF-BASICAS', 'inspector'), '') not like '%matrícula%') from personas where id = 'dddddddd-0000-0000-0000-000000000002'$q$, 'COPNIA true');
select prueba.debe_pasar('con el nombre completo del consejo de eléctrica y mecánica',
  $q$update personas set matricula_entidad = 'Consejo Profesional Nacional de Ingenierías Eléctrica, Mecánica y Profesiones Afines' where id = 'dddddddd-0000-0000-0000-000000000002'$q$);
select prueba.debe_ser('queda como CPNIEMPA', $q$select matricula_entidad from personas where id = 'dddddddd-0000-0000-0000-000000000002'$q$, 'CPNIEMPA');
reset role;

\echo '══ Resumen ══'
select count(*) filter (where ok) as correctas, count(*) filter (where not ok) as fallidas from prueba.resultados;
select texto as fallidas from prueba.resultados where not ok;
