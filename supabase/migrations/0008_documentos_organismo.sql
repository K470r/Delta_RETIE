-- ============================================================================
-- Delta RETIE — 0008 Documentos del organismo con historial
--
-- * Certificado de acreditación ONAC (con su anexo de alcance)
-- * Póliza de responsabilidad civil
-- * Declaración de independencia del organismo tipo A (17020 Anexo A.1)
--
-- Cada carga es una versión nueva con su PDF; la anterior queda como "reemplazada"
-- (nada se borra ni se modifica, 17020 §8.4). La versión vigente actualiza sola los
-- datos del organismo (fechas de acreditación, póliza, declaración) para el tablero.
-- Los cargan la gerencia y el responsable del SG (o el creador en el arranque).
-- El certificado lo ve todo el personal; la póliza y la declaración, la gerencia,
-- el SG y la dirección técnica. Los PDF van en una carpeta privada.
--
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

alter table organismos add column if not exists acreditacion_renovada date;
alter table organismos add column if not exists acreditacion_actualizada date;

create table if not exists documentos_organismo (
  id            uuid primary key default gen_random_uuid(),
  organismo_id  uuid not null references organismos(id),
  tipo          text not null check (tipo in ('acreditacion', 'poliza_rc', 'independencia')),
  archivo_ruta  text not null,
  numero        text,            -- código de acreditación o número de póliza
  emisor        text,            -- ONAC o aseguradora
  valor         numeric(16,2),   -- valor asegurado (póliza)
  fecha         date,            -- otorgamiento (acreditación) o firma (declaración)
  renovacion    date,            -- acreditación
  actualizacion date,            -- acreditación (última actualización publicada por ONAC)
  desde         date,            -- vigencia de la póliza
  hasta         date,            -- vencimiento de la acreditación o de la póliza
  firmado_por   text,            -- declaración de independencia
  observacion   text,
  cargado_por   uuid default auth.uid(),
  cargado       timestamptz not null default now(),
  reemplazado_en timestamptz,
  check (hasta is null or desde is null or hasta > desde),
  check (hasta is null or fecha is null or hasta > fecha),
  check (tipo <> 'acreditacion' or (numero is not null and hasta is not null)),
  check (tipo <> 'poliza_rc' or (numero is not null and desde is not null and hasta is not null)),
  check (tipo <> 'independencia' or fecha is not null)
);
create index if not exists documentos_organismo_tipo on documentos_organismo (organismo_id, tipo, cargado desc);

drop trigger if exists bitacora_documentos_organismo on documentos_organismo;
create trigger bitacora_documentos_organismo before insert or update or delete on documentos_organismo
  for each row execute function registrar_bitacora();

-- ─────────────────── ¿Quién carga y quién ve? ───────────────────
-- Cargar: lo mismo que modificar los datos del organismo (0002 / 0003).
create or replace function gestiona_organismo(org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null
     and (tiene_rol(org, array['representante_legal','gerente','responsable_sg']::rol_oec[]) or en_arranque(org))
$$;

-- Ver: el certificado de acreditación, todo el personal del organismo; lo demás, la
-- gerencia, el SG y la dirección técnica (y el acceso de revisión temporal).
create or replace function ve_documento_organismo(org uuid, p_tipo text) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and org in (select mis_organismos()) and (
       p_tipo = 'acreditacion'
    or tiene_rol(org, roles_hoja_de_vida()) or en_arranque(org) or en_revision(org))
$$;

alter table documentos_organismo enable row level security;
drop policy if exists lectura on documentos_organismo;
create policy lectura on documentos_organismo for select to authenticated using (ve_documento_organismo(organismo_id, tipo));
drop policy if exists carga on documentos_organismo;
create policy carga on documentos_organismo for insert to authenticated with check (gestiona_organismo(organismo_id));
-- Sin políticas de modificación ni borrado: cada versión queda como se cargó.

-- ─────────────────── Al cargar una versión nueva ───────────────────
create or replace function aplicar_documento_organismo() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.archivo_ruta not like new.organismo_id::text || '/' || new.tipo || '/%' then
    raise exception 'El archivo debe estar en la carpeta del organismo';
  end if;
  new.cargado_por := auth.uid();
  new.cargado := now();
  new.reemplazado_en := null;
  -- La versión anterior queda reemplazada (se conserva con su archivo).
  update documentos_organismo set reemplazado_en = now()
   where organismo_id = new.organismo_id and tipo = new.tipo and reemplazado_en is null;
  -- Los datos del organismo siguen a la versión vigente.
  if new.tipo = 'acreditacion' then
    update organismos set codigo_acreditacion = new.numero, acreditacion_otorgada = coalesce(new.fecha, acreditacion_otorgada),
           acreditacion_renovada = new.renovacion, acreditacion_actualizada = new.actualizacion, acreditacion_vence = new.hasta
     where id = new.organismo_id;
  elsif new.tipo = 'poliza_rc' then
    update organismos set poliza_rc_numero = new.numero, poliza_rc_vence = new.hasta where id = new.organismo_id;
  else
    update organismos set declaracion_independencia = new.fecha where id = new.organismo_id;
  end if;
  return new;
end $$;

-- "a_" para que corra antes de la bitácora y esta registre los valores finales.
drop trigger if exists a_aplicar_documento on documentos_organismo;
create trigger a_aplicar_documento before insert on documentos_organismo
  for each row execute function aplicar_documento_organismo();

-- ─────────────────── Carpeta privada de documentos ───────────────────
-- Ruta: documentos/<organismo>/<tipo>/<archivo>. PDF, máximo 15 MB.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('documentos', 'documentos', false, 15728640, array['application/pdf'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create or replace function segunda_carpeta(nombre text) returns text
language sql immutable as $$ select (storage.foldername(nombre))[2] $$;

drop policy if exists documentos_lectura on storage.objects;
create policy documentos_lectura on storage.objects for select to authenticated
  using (bucket_id = 'documentos' and ve_documento_organismo(persona_de_carpeta(name), segunda_carpeta(name)));
drop policy if exists documentos_carga on storage.objects;
create policy documentos_carga on storage.objects for insert to authenticated
  with check (bucket_id = 'documentos' and segunda_carpeta(name) in ('acreditacion', 'poliza_rc', 'independencia')
              and gestiona_organismo(persona_de_carpeta(name)));

select 'Migración 0008 aplicada: documentos del organismo con historial' as resultado;
