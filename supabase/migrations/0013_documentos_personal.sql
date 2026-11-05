-- ============================================================================
-- Ultra RETIE — 0013 Documentos de designación y autorización del personal, con firma
--
-- Documentos (los genera la aplicación con los datos de la designación):
--   designacion_gerente                     firma: el gerente designado (autodesignación;
--                                           si lo designó una junta, se carga el acta firmada a mano)
--   designacion_responsable_sg              firma: el gerente
--   autorizacion_director_tecnico           firma: el gerente
--   autorizacion_director_tecnico_suplente  firman: el gerente y el director técnico principal
--   autorizacion_inspector                  firman: el gerente y el director técnico (principal o
--                                           suplente) que evaluó al inspector
--   designacion_asistente_direccion_tecnica firma: el gerente
--
-- Firma electrónica (Ley 527 de 1999; Decreto 2364 de 2012, compilado en el Decreto 1074 de 2015):
-- cada firmante entra con su usuario, confirma su contraseña (vale 10 minutos) y firma el texto
-- exacto que vio: se guarda la huella SHA-256 del documento, la fecha y hora, el usuario, el
-- correo, el navegador y la dirección IP. Respaldo: imprimir, firmar a mano y cargar el PDF.
--
-- Sin el documento firmado, el director técnico o el inspector no puede ejercer las
-- actividades (no se le asignan órdenes de servicio). Un documento nuevo para la misma
-- designación (por ejemplo, con más actividades) reemplaza al pendiente; los firmados se
-- conservan y siguen valiendo para las actividades que incluyen.
--
-- Requiere 0011 ejecutada antes (rol de asistente de dirección técnica).
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

create table if not exists documentos_personal (
  id               uuid primary key default gen_random_uuid(),
  organismo_id     uuid not null references organismos(id),
  designacion_id   uuid not null references designaciones(id),
  tipo             text not null check (tipo in ('designacion_gerente', 'designacion_responsable_sg',
                     'autorizacion_director_tecnico', 'autorizacion_director_tecnico_suplente',
                     'autorizacion_inspector', 'designacion_asistente_direccion_tecnica')),
  titulo           text not null,
  contenido        text not null,                 -- texto completo que se firma
  huella           text not null,                 -- SHA-256 del contenido (la calcula la base de datos)
  actividades      text[] not null default '{}',  -- actividades autorizadas que incluye
  evaluador_id     uuid references personas(id),  -- director técnico que evaluó al inspector
  creado_por       uuid default auth.uid(),
  creado_en        timestamptz not null default now(),
  reemplazado_en   timestamptz,
  firmado_a_mano_ruta text,                       -- PDF firmado a mano (respaldo)
  firmado_a_mano_por  uuid references personas(id),
  firmado_a_mano_en   timestamptz
);
create index if not exists documentos_personal_designacion on documentos_personal (designacion_id, creado_en desc);

create table if not exists firmas_documento (
  id             uuid primary key default gen_random_uuid(),
  documento_id   uuid not null references documentos_personal(id),
  organismo_id   uuid not null references organismos(id),
  persona_id     uuid not null references personas(id),
  en_calidad     text not null check (en_calidad in ('designado', 'gerente', 'director_tecnico', 'evaluador')),
  huella         text not null,
  firmado_en     timestamptz not null default now(),
  usuario_id     uuid,
  correo         text,
  autenticado_en timestamptz,                     -- cuándo confirmó su contraseña
  agente         text,                            -- navegador
  ip             text,
  unique (documento_id, en_calidad)
);

drop trigger if exists bitacora_documentos_personal on documentos_personal;
create trigger bitacora_documentos_personal before insert or update or delete on documentos_personal
  for each row execute function registrar_bitacora();
drop trigger if exists bitacora_firmas_documento on firmas_documento;
create trigger bitacora_firmas_documento before insert or update or delete on firmas_documento
  for each row execute function registrar_bitacora();

-- ─────────────────── Qué documento lleva cada rol y quién lo firma ───────────────────
create or replace function tipo_documento_de_rol(p_rol text) returns text
language sql immutable as $$
  select case p_rol
    when 'gerente' then 'designacion_gerente'
    when 'responsable_sg' then 'designacion_responsable_sg'
    when 'director_tecnico' then 'autorizacion_director_tecnico'
    when 'director_tecnico_suplente' then 'autorizacion_director_tecnico_suplente'
    when 'inspector' then 'autorizacion_inspector'
    when 'asistente_direccion_tecnica' then 'designacion_asistente_direccion_tecnica'
  end
$$;

create or replace function firmas_requeridas(p_tipo text) returns text[]
language sql immutable as $$
  select case p_tipo
    when 'designacion_gerente' then array['designado']
    when 'autorizacion_director_tecnico_suplente' then array['gerente', 'director_tecnico']
    when 'autorizacion_inspector' then array['gerente', 'evaluador']
    else array['gerente']
  end
$$;

create or replace function documento_firmado(p_documento uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from documentos_personal x
     where x.id = p_documento
       and (x.firmado_a_mano_ruta is not null
            or firmas_requeridas(x.tipo) <@ coalesce((select array_agg(f.en_calidad) from firmas_documento f where f.documento_id = x.id), '{}')))
$$;

-- ¿La designación tiene su documento firmado? (los roles sin documento, siempre sí)
create or replace function designacion_firmada(p_designacion uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(tipo_documento_de_rol((select d.rol::text from designaciones d where d.id = p_designacion)) is null, true)
      or exists (select 1 from documentos_personal x where x.designacion_id = p_designacion and documento_firmado(x.id))
$$;

-- ¿La actividad está en un documento de autorización firmado de esa designación?
create or replace function actividad_firmada(p_designacion uuid, p_actividad text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from documentos_personal x
                  where x.designacion_id = p_designacion and p_actividad = any(x.actividades) and documento_firmado(x.id))
$$;

-- Designación vigente (y firmada) de la persona actual con uno de los roles.
create or replace function tengo_rol_firmado(org uuid, roles text[]) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from designaciones d
                  where d.organismo_id = org and d.persona_id = persona_actual() and d.rol::text = any(roles)
                    and d.desde <= current_date and (d.hasta is null or d.hasta >= current_date)
                    and designacion_firmada(d.id))
$$;

-- ─────────────────── Quién ve los documentos ───────────────────
create or replace function ve_documento_personal(p_documento uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and exists (
    select 1 from documentos_personal x join designaciones d on d.id = x.designacion_id
     where x.id = p_documento
       and (tiene_rol(x.organismo_id, roles_hoja_de_vida()) or en_arranque(x.organismo_id) or en_revision(x.organismo_id)
            or d.persona_id = persona_actual() or x.evaluador_id = persona_actual()))
$$;

-- ─────────────────── Al generar un documento ───────────────────
create or replace function preparar_documento_personal() returns trigger
language plpgsql security definer set search_path = public as $$
declare d designaciones;
begin
  select * into d from designaciones where id = new.designacion_id;
  if d.id is null then raise exception 'La designación no existe'; end if;
  new.organismo_id := d.organismo_id;
  new.tipo := tipo_documento_de_rol(d.rol::text);
  if new.tipo is null then raise exception 'Este rol no lleva documento de designación o autorización'; end if;
  if d.hasta is not null and d.hasta < current_date then raise exception 'La designación ya terminó'; end if;
  new.actividades := coalesce((select array_agg(da.actividad_codigo order by da.actividad_codigo)
                                 from designacion_actividades da where da.designacion_id = d.id), '{}');
  if new.tipo like 'autorizacion_%' and cardinality(new.actividades) = 0 then
    raise exception 'Primero autorice las actividades: el documento de autorización las incluye';
  end if;
  if new.tipo = 'autorizacion_inspector' then
    if new.evaluador_id is null then raise exception 'Indique el director técnico que evaluó al inspector'; end if;
    if new.evaluador_id = d.persona_id then raise exception 'El inspector no puede evaluarse a sí mismo'; end if;
    if not exists (select 1 from designaciones x
                    where x.organismo_id = d.organismo_id and x.persona_id = new.evaluador_id
                      and x.rol in ('director_tecnico', 'director_tecnico_suplente')
                      and x.desde <= current_date and (x.hasta is null or x.hasta >= current_date)) then
      raise exception 'Quien evaluó al inspector debe ser director técnico o director técnico suplente vigente del organismo';
    end if;
  else
    new.evaluador_id := null;
  end if;
  if coalesce(trim(new.contenido), '') = '' then raise exception 'El documento no tiene texto'; end if;
  new.huella := encode(sha256(convert_to(new.contenido, 'UTF8')), 'hex');
  new.creado_por := auth.uid();
  new.creado_en := now();
  new.reemplazado_en := null;
  new.firmado_a_mano_ruta := null; new.firmado_a_mano_por := null; new.firmado_a_mano_en := null;
  -- El pendiente de firma anterior queda reemplazado (los firmados se conservan).
  update documentos_personal x set reemplazado_en = now()
   where x.designacion_id = d.id and x.reemplazado_en is null and not documento_firmado(x.id);
  return new;
end $$;

drop trigger if exists a_preparar_documento_personal on documentos_personal;
create trigger a_preparar_documento_personal before insert on documentos_personal
  for each row execute function preparar_documento_personal();

alter table documentos_personal enable row level security;
alter table firmas_documento enable row level security;
drop policy if exists lectura on documentos_personal;
create policy lectura on documentos_personal for select to authenticated using (ve_documento_personal(id));
drop policy if exists generacion on documentos_personal;
create policy generacion on documentos_personal for insert to authenticated
  with check (gestiona_organismo(organismo_id)
              or tiene_rol(organismo_id, array['director_tecnico', 'director_tecnico_suplente']::rol_oec[]));
drop policy if exists lectura on firmas_documento;
create policy lectura on firmas_documento for select to authenticated using (ve_documento_personal(documento_id));
-- Sin más políticas: las firmas solo se registran con firmar_documento() y nada se modifica ni se borra.

-- ─────────────────── Firmar ───────────────────
create or replace function firmar_documento(p_documento uuid, p_en_calidad text, p_huella text)
returns void language plpgsql security definer set search_path = public as $$
declare
  x documentos_personal; d designaciones; yo uuid := persona_actual();
  claims jsonb := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  cabeceras jsonb;
  autenticado timestamptz;
begin
  select * into x from documentos_personal where id = p_documento;
  if x.id is null or not ve_documento_personal(x.id) then raise exception 'El documento no existe'; end if;
  if x.reemplazado_en is not null then raise exception 'Este documento fue reemplazado por uno más reciente'; end if;
  if documento_firmado(x.id) then raise exception 'El documento ya está firmado'; end if;
  if not p_en_calidad = any(firmas_requeridas(x.tipo)) then raise exception 'Este documento no lleva esa firma'; end if;
  if exists (select 1 from firmas_documento f where f.documento_id = x.id and f.en_calidad = p_en_calidad) then
    raise exception 'Esa firma ya está registrada';
  end if;
  if p_huella is distinct from x.huella then
    raise exception 'El documento cambió desde que lo abrió: vuelva a abrirlo y léalo antes de firmar';
  end if;
  if yo is null then raise exception 'Su usuario no está enlazado a una persona'; end if;
  select * into d from designaciones where id = x.designacion_id;

  if p_en_calidad = 'designado' and yo is distinct from d.persona_id then
    raise exception 'Solo la persona designada firma este documento';
  elsif p_en_calidad = 'gerente' and not tengo_rol_firmado(x.organismo_id, array['gerente']) then
    raise exception 'Firma el gerente del organismo, con su designación vigente y firmada';
  elsif p_en_calidad = 'director_tecnico' then
    if yo = d.persona_id then raise exception 'Nadie firma su propia autorización como director técnico'; end if;
    if not tengo_rol_firmado(x.organismo_id, array['director_tecnico']) then
      raise exception 'Firma el director técnico principal, con su autorización vigente y firmada';
    end if;
  elsif p_en_calidad = 'evaluador' then
    if yo is distinct from x.evaluador_id then raise exception 'Firma el director técnico que evaluó al inspector'; end if;
    if not tengo_rol_firmado(x.organismo_id, array['director_tecnico', 'director_tecnico_suplente']) then
      raise exception 'Quien evaluó debe tener su autorización de director técnico vigente y firmada';
    end if;
  end if;

  -- Confirmación de la contraseña (o código) en los últimos 10 minutos.
  select to_timestamp(max((e->>'timestamp')::bigint)) into autenticado
    from jsonb_array_elements(coalesce(claims->'amr', '[]'::jsonb)) e;
  if autenticado is null or autenticado < now() - interval '10 minutes' then
    raise exception 'Para firmar, confirme su contraseña (la confirmación vale 10 minutos)';
  end if;

  cabeceras := nullif(current_setting('request.headers', true), '')::jsonb;
  insert into firmas_documento (documento_id, organismo_id, persona_id, en_calidad, huella, usuario_id, correo,
                                autenticado_en, agente, ip)
  values (x.id, x.organismo_id, yo, p_en_calidad, x.huella, auth.uid(), correo_actual(), autenticado,
          cabeceras->>'user-agent',
          coalesce(cabeceras->>'cf-connecting-ip', split_part(cabeceras->>'x-forwarded-for', ',', 1), cabeceras->>'x-real-ip'));
end $$;

-- Respaldo: documento impreso, firmado a mano y escaneado. Lo carga la gerencia o el SG.
create or replace function registrar_firmado_a_mano(p_documento uuid, p_ruta text)
returns void language plpgsql security definer set search_path = public as $$
declare x documentos_personal;
begin
  select * into x from documentos_personal where id = p_documento;
  if x.id is null or not ve_documento_personal(x.id) then raise exception 'El documento no existe'; end if;
  if not gestiona_organismo(x.organismo_id) then
    raise exception 'El documento firmado a mano lo carga la gerencia o el responsable del SG';
  end if;
  if x.reemplazado_en is not null then raise exception 'Este documento fue reemplazado por uno más reciente'; end if;
  if documento_firmado(x.id) then raise exception 'El documento ya está firmado'; end if;
  if p_ruta not like x.organismo_id::text || '/personal/' || x.id::text || '/%' then
    raise exception 'El archivo debe estar en la carpeta del documento';
  end if;
  update documentos_personal set firmado_a_mano_ruta = p_ruta, firmado_a_mano_por = persona_actual(), firmado_a_mano_en = now()
   where id = x.id;
end $$;

revoke execute on function firmar_documento(uuid, text, text) from public, anon;
revoke execute on function registrar_firmado_a_mano(uuid, text) from public, anon;
grant execute on function firmar_documento(uuid, text, text) to authenticated;
grant execute on function registrar_firmado_a_mano(uuid, text) to authenticated;

-- ─────────────────── Carpeta de los documentos firmados a mano ───────────────────
-- Ruta: documentos/<organismo>/personal/<documento>/<archivo>.pdf
create or replace function documento_de_carpeta(nombre text) returns uuid
language plpgsql immutable as $$
begin
  return ((storage.foldername(nombre))[3])::uuid;
exception when others then
  return null;
end $$;

drop policy if exists personal_lectura on storage.objects;
create policy personal_lectura on storage.objects for select to authenticated
  using (bucket_id = 'documentos' and segunda_carpeta(name) = 'personal' and ve_documento_personal(documento_de_carpeta(name)));
drop policy if exists personal_carga on storage.objects;
create policy personal_carga on storage.objects for insert to authenticated
  with check (bucket_id = 'documentos' and segunda_carpeta(name) = 'personal'
              and gestiona_organismo(persona_de_carpeta(name)) and ve_documento_personal(documento_de_carpeta(name)));

-- ─────────────────── Ejercer exige la autorización firmada ───────────────────
-- Asignación de una orden: igual que en 0001, y además la actividad debe estar en una
-- autorización firmada del inspector.
create or replace function validar_asignacion() returns trigger
language plpgsql as $$
declare motivo text;
begin
  if new.inspector_id is null then return new; end if;
  if tg_op = 'UPDATE' and new.inspector_id is not distinct from old.inspector_id then return new; end if;

  if new.solicitud_revisada_en is null then
    raise exception 'La solicitud % no ha sido revisada (17020 §7.1.6)', new.consecutivo;
  end if;
  if not exists (
    select 1 from designaciones d join designacion_actividades da on da.designacion_id = d.id
    where d.organismo_id = new.organismo_id and d.persona_id = new.inspector_id and d.rol = 'inspector'
      and da.actividad_codigo = new.actividad_codigo
      and d.desde <= current_date and (d.hasta is null or d.hasta >= current_date)
  ) then
    raise exception 'El inspector no está autorizado para la actividad % en este organismo (17020 §6.1.6)', new.actividad_codigo;
  end if;
  if not exists (
    select 1 from designaciones d
    where d.organismo_id = new.organismo_id and d.persona_id = new.inspector_id and d.rol = 'inspector'
      and d.desde <= current_date and (d.hasta is null or d.hasta >= current_date)
      and actividad_firmada(d.id, new.actividad_codigo)
  ) then
    raise exception 'La autorización del inspector para la actividad % no está firmada (gerente y director técnico)', new.actividad_codigo;
  end if;
  motivo := puede_ejercer(new.organismo_id, new.inspector_id, new.actividad_codigo);
  if motivo is not null then raise exception '%', motivo; end if;
  if exists (
    select 1 from conflictos_interes c
    where c.persona_id = new.inspector_id and c.cliente_id = new.cliente_id and c.vigente
  ) then
    raise exception 'El inspector declaró conflicto de interés con este cliente (17020 §4.1)';
  end if;
  return new;
end $$;

select 'Migración 0013 aplicada: documentos de designación y autorización con firma electrónica' as resultado;
