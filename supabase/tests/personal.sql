-- Prueba de 0011 (seguimiento del mes 30), 0012 (generación por tensión) y
-- 0013 (documentos del personal con firma), después de las pruebas anteriores.
\set ON_ERROR_STOP on
\ir funciones_prueba.sql
truncate prueba.resultados;

-- Iniciar sesión como un usuario; "hace" = minutos desde que confirmó su contraseña (null: sin confirmar).
create or replace function prueba.como(usuario text, hace int default 0) returns void language sql as $$
  select set_config('request.jwt.claims',
    case when hace is null then json_build_object('sub', usuario)::text
         else json_build_object('sub', usuario, 'amr', json_build_array(json_build_object('method', 'password',
                'timestamp', extract(epoch from now() - make_interval(mins => hace))::bigint)))::text end, false);
  select set_config('request.headers', '{"user-agent":"Navegador de prueba","x-forwarded-for":"190.0.0.1, 10.0.0.1"}', false);
$$;
grant execute on function prueba.como(text, int) to authenticated;

-- ─────────── Organismo de prueba (como superusuario) ───────────
select set_config('request.jwt.claims', '', false);
insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000021', 'gerente.p@example.com'),
  ('aaaaaaaa-0000-0000-0000-000000000022', 'dt.p@example.com'),
  ('aaaaaaaa-0000-0000-0000-000000000023', 'dts.p@example.com'),
  ('aaaaaaaa-0000-0000-0000-000000000024', 'insp.p@example.com'),
  ('aaaaaaaa-0000-0000-0000-000000000025', 'sg.p@example.com'),
  ('aaaaaaaa-0000-0000-0000-000000000026', 'asis.p@example.com');
insert into organismos (id, razon_social, nit) values ('cccccccc-0000-0000-0000-0000000000aa', 'OI de prueba', 'PRUEBA-P1');
insert into alcance_acreditado (organismo_id, actividad_codigo, estado) values
  ('cccccccc-0000-0000-0000-0000000000aa', 'RETIE24-UF-BASICAS', 'acreditada'),
  ('cccccccc-0000-0000-0000-0000000000aa', 'RETIE24-GEN-FNCE', 'acreditada');
insert into personas (id, documento, nombres, apellidos, correo) values
  ('eeeeeeee-0000-0000-0000-000000000001', 'P01', 'Gina', 'Gerente', 'gerente.p@example.com'),
  ('eeeeeeee-0000-0000-0000-000000000002', 'P02', 'Darío', 'Director', 'dt.p@example.com'),
  ('eeeeeeee-0000-0000-0000-000000000003', 'P03', 'Diana', 'Suplente', 'dts.p@example.com'),
  ('eeeeeeee-0000-0000-0000-000000000004', 'P04', 'Iván', 'Inspector', 'insp.p@example.com'),
  ('eeeeeeee-0000-0000-0000-000000000005', 'P05', 'Sonia', 'Calidad', 'sg.p@example.com'),
  ('eeeeeeee-0000-0000-0000-000000000006', 'P06', 'Andrés', 'Asistente', 'asis.p@example.com');
insert into vinculaciones (organismo_id, persona_id, tipo, cargo, desde)
  select 'cccccccc-0000-0000-0000-0000000000aa', id, 'laboral', 'Cargo', current_date - 30 from personas where documento like 'P0%';
insert into designaciones (id, organismo_id, persona_id, rol, desde) values
  ('ffffffff-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-0000000000aa', 'eeeeeeee-0000-0000-0000-000000000001', 'gerente', current_date),
  ('ffffffff-0000-0000-0000-000000000002', 'cccccccc-0000-0000-0000-0000000000aa', 'eeeeeeee-0000-0000-0000-000000000002', 'director_tecnico', current_date),
  ('ffffffff-0000-0000-0000-000000000003', 'cccccccc-0000-0000-0000-0000000000aa', 'eeeeeeee-0000-0000-0000-000000000003', 'director_tecnico_suplente', current_date),
  ('ffffffff-0000-0000-0000-000000000004', 'cccccccc-0000-0000-0000-0000000000aa', 'eeeeeeee-0000-0000-0000-000000000004', 'inspector', current_date),
  ('ffffffff-0000-0000-0000-000000000005', 'cccccccc-0000-0000-0000-0000000000aa', 'eeeeeeee-0000-0000-0000-000000000005', 'responsable_sg', current_date),
  ('ffffffff-0000-0000-0000-000000000006', 'cccccccc-0000-0000-0000-0000000000aa', 'eeeeeeee-0000-0000-0000-000000000006', 'asistente_direccion_tecnica', current_date);
-- Las actividades se autorizan sin revisar la competencia (eso lo prueban reglas_17020 y matricula).
alter table designacion_actividades disable trigger validar_designacion_actividad;
insert into designacion_actividades (designacion_id, actividad_codigo) values
  ('ffffffff-0000-0000-0000-000000000002', 'RETIE24-UF-BASICAS'),
  ('ffffffff-0000-0000-0000-000000000003', 'RETIE24-UF-BASICAS'),
  ('ffffffff-0000-0000-0000-000000000004', 'RETIE24-UF-BASICAS'),
  ('ffffffff-0000-0000-0000-000000000004', 'RETIE24-GEN-FNCE-BT');
alter table designacion_actividades enable trigger validar_designacion_actividad;

\echo '══ 0011 Seguimiento del mes 30 ══'
insert into certificados_competencia (id, persona_id, reglamento_id, numero, certificador, fecha_emision, fecha_vencimiento) values
  ('99999999-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000004', 'RETIE-2024', 'C-1', 'Certificador', current_date - interval '31 months', current_date + interval '2 years'),
  ('99999999-0000-0000-0000-000000000002', 'eeeeeeee-0000-0000-0000-000000000004', 'RETIE-2024', 'C-2', 'Certificador', current_date - interval '12 months', current_date + interval '3 years');
select prueba.debe_ser('vencido el plazo sin seguimiento, no cuenta',
  $q$select certificado_vigente(c, current_date)::text from certificados_competencia c where numero = 'C-1'$q$, 'false');
select prueba.debe_ser('pero sí contaba hasta el día límite',
  $q$select certificado_vigente(c, limite_seguimiento(c))::text from certificados_competencia c where numero = 'C-1'$q$, 'true');
select prueba.debe_ser('periodo sin habilitación abierto desde el día siguiente al límite',
  $q$select (lower(periodo_sin_seguimiento(c)) = limite_seguimiento(c) + 1 and upper_inf(periodo_sin_seguimiento(c)))::text from certificados_competencia c where numero = 'C-1'$q$, 'true');
select prueba.debe_fallar('el seguimiento no puede tener fecha futura',
  $q$update certificados_competencia set seguimiento_fecha = current_date + 1, seguimiento_resultado = 'conforme' where numero = 'C-1'$q$, 'futura');
select prueba.debe_fallar('ni anterior a la emisión',
  $q$update certificados_competencia set seguimiento_fecha = fecha_emision - 1, seguimiento_resultado = 'conforme' where numero = 'C-1'$q$, 'anterior a la emisión');
select prueba.debe_pasar('se registra tarde (hoy) un seguimiento hecho hace 10 días',
  $q$update certificados_competencia set seguimiento_fecha = current_date - 10, seguimiento_resultado = 'conforme' where numero = 'C-1'$q$);
select prueba.debe_ser('la fecha de registro la puso la base de datos (hoy)',
  $q$select ((seguimiento_registrado_en at time zone 'America/Bogota')::date = (now() at time zone 'America/Bogota')::date)::text from certificados_competencia where numero = 'C-1'$q$, 'true');
select prueba.debe_ser('vuelve a contar desde hoy',
  $q$select certificado_vigente(c, (now() at time zone 'America/Bogota')::date)::text from certificados_competencia c where numero = 'C-1'$q$, 'true');
select prueba.debe_ser('pero no hacia atrás: la fecha del seguimiento queda sin habilitación',
  $q$select certificado_vigente(c, current_date - 10)::text from certificados_competencia c where numero = 'C-1'$q$, 'false');
select prueba.debe_ser('el periodo no habilitado queda cerrado: del día siguiente al límite a ayer',
  $q$select (lower(periodo_sin_seguimiento(c)) = limite_seguimiento(c) + 1 and upper(periodo_sin_seguimiento(c)) = seguimiento_efectivo(c))::text from certificados_competencia c where numero = 'C-1'$q$, 'true');
select prueba.debe_pasar('intentar cambiar la fecha de registro a mano…',
  $q$update certificados_competencia set seguimiento_registrado_en = '2020-01-01' where numero = 'C-1'$q$);
select prueba.debe_ser('…no tiene efecto',
  $q$select (seguimiento_registrado_en > '2021-01-01')::text from certificados_competencia where numero = 'C-1'$q$, 'true');
select prueba.debe_pasar('seguimiento a tiempo', $q$update certificados_competencia set seguimiento_fecha = current_date - 5, seguimiento_resultado = 'conforme' where numero = 'C-2'$q$);
select prueba.debe_ser('a tiempo: cuenta siempre y no hay periodo sin habilitación',
  $q$select (certificado_vigente(c, current_date - 100) and certificado_vigente(c, current_date + 400) and periodo_sin_seguimiento(c) is null)::text from certificados_competencia c where numero = 'C-2'$q$, 'true');

\echo '══ 0012 Generación según tensión ══'
select prueba.debe_ser('la variante de baja tensión exige categoría g',
  $q$select categoria || ' ' || variante_de from actividades where codigo = 'RETIE24-GEN-FNCE-BT'$q$, 'g RETIE24-GEN-FNCE');
select prueba.debe_ser('la de generación sigue exigiendo la a', $q$select categoria from actividades where codigo = 'RETIE24-GEN-FNCE'$q$, 'a');
select prueba.debe_fallar('la variante no se acredita por separado',
  $q$insert into alcance_acreditado (organismo_id, actividad_codigo, estado) values ('cccccccc-0000-0000-0000-0000000000aa', 'RETIE24-GEN-FNCE-BT', 'acreditada')$q$, 'variante');
select prueba.debe_ser('la variante la cubre la línea de generación del alcance',
  $q$select (coalesce(puede_ejercer('cccccccc-0000-0000-0000-0000000000aa', 'eeeeeeee-0000-0000-0000-000000000004', 'RETIE24-GEN-FNCE-BT'), '') not like '%alcance%')::text$q$, 'true');
select prueba.debe_ser('conectada, 1.000 V AC y 1.500 V DC exactos → generación con g',
  $q$select actividad_segun_instalacion('RETIE24-GEN-FNCE', true, 1000, 1500)$q$, 'RETIE24-GEN-FNCE-BT');
select prueba.debe_ser('conectada, más de 1.000 V AC → generación con a',
  $q$select actividad_segun_instalacion('RETIE24-GEN-FNCE', true, 1000.5, 0)$q$, 'RETIE24-GEN-FNCE');
select prueba.debe_ser('conectada, más de 1.500 V DC → generación con a',
  $q$select actividad_segun_instalacion('RETIE24-GEN-VARIAS', true, 480, 1501)$q$, 'RETIE24-GEN-VARIAS');
select prueba.debe_ser('no conectada, baja tensión → uso final (autogeneración) con g',
  $q$select actividad_segun_instalacion('RETIE24-GEN-FNCE', false, 480, 1000)$q$, 'RETIE24-UF-AUTOGEN');
select prueba.debe_ser('no conectada, más de 1.000 V AC → generación con a',
  $q$select actividad_segun_instalacion('RETIE24-GEN-FNCE', false, 13200, 0)$q$, 'RETIE24-GEN-FNCE');
select prueba.debe_ser('otras actividades no cambian', $q$select actividad_segun_instalacion('RETIE24-UF-BASICAS', false, 208, 0)$q$, 'RETIE24-UF-BASICAS');
select prueba.debe_fallar('debe indicarse si está conectada a la red',
  $q$select actividad_segun_instalacion('RETIE24-GEN-FNCE', null, 208, 0)$q$, 'conectada a la red');

\echo '══ 0013 Documentos: designación de la gerente ══'
select prueba.como('aaaaaaaa-0000-0000-0000-000000000021');
set role authenticated;
select prueba.debe_pasar('la gerente genera su documento de designación',
  $q$insert into documentos_personal (id, organismo_id, designacion_id, tipo, titulo, contenido)
     values ('77777777-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-0000000000aa', 'ffffffff-0000-0000-0000-000000000001', 'x', 'Designación', 'Texto de la designación de la gerente')$q$);
select prueba.debe_ser('el tipo y la huella los pone la base de datos',
  $q$select tipo || ' ' || (huella = encode(sha256(convert_to('Texto de la designación de la gerente', 'UTF8')), 'hex')) from documentos_personal where id = '77777777-0000-0000-0000-000000000001'$q$, 'designacion_gerente true');
select prueba.debe_fallar('no lleva firma de gerente (la firma la designada)',
  $q$select firmar_documento('77777777-0000-0000-0000-000000000001', 'gerente', huella) from documentos_personal where id = '77777777-0000-0000-0000-000000000001'$q$, 'no lleva esa firma');
select prueba.debe_fallar('no firma si el texto no es el que vio',
  $q$select firmar_documento('77777777-0000-0000-0000-000000000001', 'designado', 'otra')$q$, 'cambió');
select prueba.como('aaaaaaaa-0000-0000-0000-000000000021', null);
select prueba.debe_fallar('sin confirmar la contraseña no firma',
  $q$select firmar_documento('77777777-0000-0000-0000-000000000001', 'designado', huella) from documentos_personal where id = '77777777-0000-0000-0000-000000000001'$q$, 'confirme su contraseña');
select prueba.como('aaaaaaaa-0000-0000-0000-000000000021', 15);
select prueba.debe_fallar('la confirmación vence a los 10 minutos',
  $q$select firmar_documento('77777777-0000-0000-0000-000000000001', 'designado', huella) from documentos_personal where id = '77777777-0000-0000-0000-000000000001'$q$, 'confirme su contraseña');
select prueba.como('aaaaaaaa-0000-0000-0000-000000000021');
select prueba.debe_pasar('firma su designación',
  $q$select firmar_documento('77777777-0000-0000-0000-000000000001', 'designado', huella) from documentos_personal where id = '77777777-0000-0000-0000-000000000001'$q$);
select prueba.debe_ser('queda firmado, con correo, navegador e IP',
  $q$select documento_firmado('77777777-0000-0000-0000-000000000001') || ' ' || correo || ' ' || agente || ' ' || ip from firmas_documento where documento_id = '77777777-0000-0000-0000-000000000001'$q$,
  'true gerente.p@example.com Navegador de prueba 190.0.0.1');
select prueba.debe_fallar('no se firma dos veces',
  $q$select firmar_documento('77777777-0000-0000-0000-000000000001', 'designado', huella) from documentos_personal where id = '77777777-0000-0000-0000-000000000001'$q$, 'ya está firmado');
select prueba.debe_fallar('las firmas no se escriben directamente',
  $q$insert into firmas_documento (documento_id, organismo_id, persona_id, en_calidad, huella) values ('77777777-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-0000000000aa', 'eeeeeeee-0000-0000-0000-000000000001', 'gerente', 'x')$q$, 'row-level security');
select prueba.debe_ser('el texto no se puede cambiar (0 filas)',
  $q$with u as (update documentos_personal set contenido = 'otro' where id = '77777777-0000-0000-0000-000000000001' returning 1) select count(*)::text from u$q$, '0');
select prueba.debe_ser('ni borrar (0 filas)',
  $q$with u as (delete from documentos_personal where id = '77777777-0000-0000-0000-000000000001' returning 1) select count(*)::text from u$q$, '0');
select prueba.debe_ser('el asistente de dirección técnica lleva documento; la suplente del SG y la gerencia ampliada no',
  $q$select tipo_documento_de_rol('asistente_direccion_tecnica') || ' ' || coalesce(tipo_documento_de_rol('suplente_sg'), '-') || ' ' || coalesce(tipo_documento_de_rol('miembro_gerencia'), '-')$q$,
  'designacion_asistente_direccion_tecnica - -');

\echo '══ Autorizaciones de dirección técnica ══'
select prueba.debe_pasar('genera la autorización del director técnico',
  $q$insert into documentos_personal (id, organismo_id, designacion_id, tipo, titulo, contenido)
     values ('77777777-0000-0000-0000-000000000002', 'cccccccc-0000-0000-0000-0000000000aa', 'ffffffff-0000-0000-0000-000000000002', 'x', 'Autorización DT', 'Autorización del director técnico')$q$);
select prueba.debe_ser('incluye las actividades autorizadas', $q$select array_to_string(actividades, ',') from documentos_personal where id = '77777777-0000-0000-0000-000000000002'$q$, 'RETIE24-UF-BASICAS');
reset role;
select prueba.como('aaaaaaaa-0000-0000-0000-000000000022');
set role authenticated;
select prueba.debe_fallar('el director técnico no la firma como gerente',
  $q$select firmar_documento('77777777-0000-0000-0000-000000000002', 'gerente', huella) from documentos_personal where id = '77777777-0000-0000-0000-000000000002'$q$, 'Firma el gerente');
reset role;
select prueba.como('aaaaaaaa-0000-0000-0000-000000000021');
set role authenticated;
select prueba.debe_pasar('la gerente la firma',
  $q$select firmar_documento('77777777-0000-0000-0000-000000000002', 'gerente', huella) from documentos_personal where id = '77777777-0000-0000-0000-000000000002'$q$);
select prueba.debe_pasar('genera la autorización de la directora técnica suplente',
  $q$insert into documentos_personal (id, organismo_id, designacion_id, tipo, titulo, contenido)
     values ('77777777-0000-0000-0000-000000000003', 'cccccccc-0000-0000-0000-0000000000aa', 'ffffffff-0000-0000-0000-000000000003', 'x', 'Autorización DTS', 'Autorización de la suplente')$q$);
select prueba.debe_pasar('la gerente la firma',
  $q$select firmar_documento('77777777-0000-0000-0000-000000000003', 'gerente', huella) from documentos_personal where id = '77777777-0000-0000-0000-000000000003'$q$);
select prueba.debe_ser('falta la firma del director técnico principal', $q$select documento_firmado('77777777-0000-0000-0000-000000000003')::text$q$, 'false');

\echo '══ Autorización del inspector ══'
select prueba.debe_fallar('exige el director técnico que lo evaluó',
  $q$insert into documentos_personal (organismo_id, designacion_id, tipo, titulo, contenido)
     values ('cccccccc-0000-0000-0000-0000000000aa', 'ffffffff-0000-0000-0000-000000000004', 'x', 'Autorización', 'Texto')$q$, 'Indique el director técnico');
select prueba.debe_fallar('quien evaluó debe ser director técnico',
  $q$insert into documentos_personal (organismo_id, designacion_id, tipo, titulo, contenido, evaluador_id)
     values ('cccccccc-0000-0000-0000-0000000000aa', 'ffffffff-0000-0000-0000-000000000004', 'x', 'Autorización', 'Texto', 'eeeeeeee-0000-0000-0000-000000000005')$q$, 'debe ser director técnico');
select prueba.debe_fallar('el inspector no se evalúa a sí mismo',
  $q$insert into documentos_personal (organismo_id, designacion_id, tipo, titulo, contenido, evaluador_id)
     values ('cccccccc-0000-0000-0000-0000000000aa', 'ffffffff-0000-0000-0000-000000000004', 'x', 'Autorización', 'Texto', 'eeeeeeee-0000-0000-0000-000000000004')$q$, 'sí mismo');
select prueba.debe_pasar('la evaluó la directora técnica suplente',
  $q$insert into documentos_personal (id, organismo_id, designacion_id, tipo, titulo, contenido, evaluador_id)
     values ('77777777-0000-0000-0000-000000000004', 'cccccccc-0000-0000-0000-0000000000aa', 'ffffffff-0000-0000-0000-000000000004', 'x', 'Autorización', 'Autorización del inspector', 'eeeeeeee-0000-0000-0000-000000000003')$q$);
select prueba.debe_ser('incluye la variante de baja tensión', $q$select array_to_string(actividades, ',') from documentos_personal where id = '77777777-0000-0000-0000-000000000004'$q$, 'RETIE24-GEN-FNCE-BT,RETIE24-UF-BASICAS');
reset role;
select prueba.como('aaaaaaaa-0000-0000-0000-000000000023');
set role authenticated;
select prueba.debe_fallar('la suplente no firma como evaluadora sin su propia autorización firmada',
  $q$select firmar_documento('77777777-0000-0000-0000-000000000004', 'evaluador', huella) from documentos_personal where id = '77777777-0000-0000-0000-000000000004'$q$, 'vigente y firmada');
select prueba.debe_fallar('ni firma su propia autorización como directora técnica',
  $q$select firmar_documento('77777777-0000-0000-0000-000000000003', 'director_tecnico', huella) from documentos_personal where id = '77777777-0000-0000-0000-000000000003'$q$, 'propia');
reset role;
select prueba.como('aaaaaaaa-0000-0000-0000-000000000022');
set role authenticated;
select prueba.debe_pasar('el director técnico principal firma la autorización de la suplente',
  $q$select firmar_documento('77777777-0000-0000-0000-000000000003', 'director_tecnico', huella) from documentos_personal where id = '77777777-0000-0000-0000-000000000003'$q$);
select prueba.debe_fallar('el principal no firma como evaluador si no evaluó',
  $q$select firmar_documento('77777777-0000-0000-0000-000000000004', 'evaluador', huella) from documentos_personal where id = '77777777-0000-0000-0000-000000000004'$q$, 'que evaluó');
reset role;
select prueba.como('aaaaaaaa-0000-0000-0000-000000000023');
set role authenticated;
select prueba.debe_pasar('ahora la suplente firma como evaluadora',
  $q$select firmar_documento('77777777-0000-0000-0000-000000000004', 'evaluador', huella) from documentos_personal where id = '77777777-0000-0000-0000-000000000004'$q$);
reset role;
select prueba.debe_ser('sin la firma de la gerente, el inspector aún no puede ejercer',
  $q$select actividad_firmada('ffffffff-0000-0000-0000-000000000004', 'RETIE24-UF-BASICAS')::text$q$, 'false');
select prueba.como('aaaaaaaa-0000-0000-0000-000000000021');
set role authenticated;
select prueba.debe_pasar('la gerente firma',
  $q$select firmar_documento('77777777-0000-0000-0000-000000000004', 'gerente', huella) from documentos_personal where id = '77777777-0000-0000-0000-000000000004'$q$);
reset role;
select prueba.debe_ser('el inspector ya puede ejercer las actividades del documento',
  $q$select (actividad_firmada('ffffffff-0000-0000-0000-000000000004', 'RETIE24-UF-BASICAS') and actividad_firmada('ffffffff-0000-0000-0000-000000000004', 'RETIE24-GEN-FNCE-BT'))::text$q$, 'true');
select prueba.debe_ser('pero no otras', $q$select actividad_firmada('ffffffff-0000-0000-0000-000000000004', 'RETIE24-UF-DIST')::text$q$, 'false');

select prueba.como('aaaaaaaa-0000-0000-0000-000000000021');
set role authenticated;
select prueba.debe_pasar('un documento nuevo del inspector (pendiente)…',
  $q$insert into documentos_personal (id, organismo_id, designacion_id, tipo, titulo, contenido, evaluador_id)
     values ('77777777-0000-0000-0000-000000000005', 'cccccccc-0000-0000-0000-0000000000aa', 'ffffffff-0000-0000-0000-000000000004', 'x', 'Autorización', 'Versión 2', 'eeeeeeee-0000-0000-0000-000000000002')$q$);
select prueba.debe_pasar('…y otro más',
  $q$insert into documentos_personal (id, organismo_id, designacion_id, tipo, titulo, contenido, evaluador_id)
     values ('77777777-0000-0000-0000-000000000006', 'cccccccc-0000-0000-0000-0000000000aa', 'ffffffff-0000-0000-0000-000000000004', 'x', 'Autorización', 'Versión 3', 'eeeeeeee-0000-0000-0000-000000000002')$q$);
select prueba.debe_ser('reemplaza solo al pendiente; el firmado se conserva',
  $q$select string_agg(right(id::text, 1) || ':' || (reemplazado_en is not null), ',' order by id) from documentos_personal where designacion_id = 'ffffffff-0000-0000-0000-000000000004'$q$,
  '4:false,5:true,6:false');
select prueba.debe_fallar('no se firma el reemplazado',
  $q$select firmar_documento('77777777-0000-0000-0000-000000000005', 'gerente', huella) from documentos_personal where id = '77777777-0000-0000-0000-000000000005'$q$, 'reemplazado');
select prueba.debe_pasar('genera el documento del asistente de dirección técnica',
  $q$insert into documentos_personal (id, organismo_id, designacion_id, tipo, titulo, contenido)
     values ('77777777-0000-0000-0000-000000000007', 'cccccccc-0000-0000-0000-0000000000aa', 'ffffffff-0000-0000-0000-000000000006', 'x', 'Designación', 'Asistente')$q$);
select prueba.debe_ser('es del tipo del asistente', $q$select tipo from documentos_personal where id = '77777777-0000-0000-0000-000000000007'$q$, 'designacion_asistente_direccion_tecnica');
reset role;

\echo '══ Quién ve los documentos ══'
select prueba.como('aaaaaaaa-0000-0000-0000-000000000024');
set role authenticated;
select prueba.debe_ser('el inspector ve solo los suyos', $q$select count(*)::text from documentos_personal$q$, '3');
select prueba.debe_ser('y sus firmas', $q$select count(*)::text from firmas_documento$q$, '2');
reset role;
select prueba.como('aaaaaaaa-0000-0000-0000-000000000026');
set role authenticated;
select prueba.debe_ser('el asistente ve el suyo', $q$select count(*)::text from documentos_personal$q$, '1');
reset role;
select prueba.como('aaaaaaaa-0000-0000-0000-000000000025');
set role authenticated;
select prueba.debe_ser('el responsable del SG ve todos los del organismo', $q$select count(*)::text from documentos_personal$q$, '7');

\echo '══ Respaldo: firmado a mano ══'
select prueba.debe_pasar('el SG genera su documento de designación',
  $q$insert into documentos_personal (id, organismo_id, designacion_id, tipo, titulo, contenido)
     values ('77777777-0000-0000-0000-000000000008', 'cccccccc-0000-0000-0000-0000000000aa', 'ffffffff-0000-0000-0000-000000000005', 'x', 'Designación SG', 'Responsable del SG')$q$);
select prueba.debe_pasar('carga el PDF firmado a mano en la carpeta del documento',
  $q$insert into storage.objects (bucket_id, name) values ('documentos', 'cccccccc-0000-0000-0000-0000000000aa/personal/77777777-0000-0000-0000-000000000008/firmado.pdf')$q$);
select prueba.debe_fallar('la ruta debe ser la del documento',
  $q$select registrar_firmado_a_mano('77777777-0000-0000-0000-000000000008', 'cccccccc-0000-0000-0000-0000000000aa/personal/otro/firmado.pdf')$q$, 'carpeta del documento');
select prueba.debe_pasar('registra el documento firmado a mano',
  $q$select registrar_firmado_a_mano('77777777-0000-0000-0000-000000000008', 'cccccccc-0000-0000-0000-0000000000aa/personal/77777777-0000-0000-0000-000000000008/firmado.pdf')$q$);
select prueba.debe_ser('queda firmado, con quién lo cargó',
  $q$select documento_firmado(id) || ' ' || (firmado_a_mano_por = 'eeeeeeee-0000-0000-0000-000000000005') from documentos_personal where id = '77777777-0000-0000-0000-000000000008'$q$, 'true true');
reset role;
select prueba.como('aaaaaaaa-0000-0000-0000-000000000024');
set role authenticated;
select prueba.debe_fallar('el inspector no carga documentos firmados a mano',
  $q$select registrar_firmado_a_mano('77777777-0000-0000-0000-000000000006', 'cccccccc-0000-0000-0000-0000000000aa/personal/77777777-0000-0000-0000-000000000006/f.pdf')$q$, 'gerencia o el responsable del SG');
select prueba.debe_fallar('ni genera documentos',
  $q$insert into documentos_personal (organismo_id, designacion_id, tipo, titulo, contenido, evaluador_id)
     values ('cccccccc-0000-0000-0000-0000000000aa', 'ffffffff-0000-0000-0000-000000000004', 'x', 'x', 'x', 'eeeeeeee-0000-0000-0000-000000000002')$q$, 'row-level security');
reset role;
select set_config('request.jwt.claims', '', false);

\echo '══ Resumen ══'
select count(*) filter (where ok) as correctas, count(*) filter (where not ok) as fallidas from prueba.resultados;
select texto as fallidas from prueba.resultados where not ok;
