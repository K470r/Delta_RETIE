-- ============================================================================
-- Delta RETIE — 0004 Logos del organismo
--
-- * Logo del organismo: aparece arriba del panel y en los documentos.
-- * Símbolo de acreditado ONAC: solo en la entrega de resultados (informe de no
--   conformidades y dictamen).
-- Las imágenes se guardan en el almacenamiento de Supabase (carpeta "logos"), una
-- subcarpeta por organismo. Las ve cualquiera que tenga el enlace (son logos, no
-- datos reservados); las carga quien puede modificar los datos del organismo:
-- representante legal, gerente, responsable del SG (0002) o su creador en el arranque (0003).
-- Nada se borra: cada carga es un archivo nuevo y el organismo apunta al vigente.
--
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

alter table organismos add column if not exists logo_ruta text;
alter table organismos add column if not exists simbolo_onac_ruta text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('logos', 'logos', true, 2097152, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- ¿El usuario puede modificar el organismo de la carpeta? (logos/<organismo>/archivo)
create or replace function gestiona_carpeta_organismo(nombre text) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare org uuid;
begin
  begin
    org := ((storage.foldername(nombre))[1])::uuid;
  exception when others then
    return false;
  end;
  return tiene_rol(org, array['representante_legal','gerente','responsable_sg']::rol_oec[]) or en_arranque(org);
end $$;

drop policy if exists logos_carga on storage.objects;
create policy logos_carga on storage.objects for insert to authenticated
  with check (bucket_id = 'logos' and gestiona_carpeta_organismo(name));

-- La ruta guardada en el organismo debe ser de su propia carpeta.
create or replace function validar_rutas_logo() returns trigger
language plpgsql as $$
begin
  if new.logo_ruta is not null and new.logo_ruta not like new.id::text || '/%' then
    raise exception 'El logo debe estar en la carpeta del organismo';
  end if;
  if new.simbolo_onac_ruta is not null and new.simbolo_onac_ruta not like new.id::text || '/%' then
    raise exception 'El símbolo de ONAC debe estar en la carpeta del organismo';
  end if;
  return new;
end $$;

drop trigger if exists validar_rutas_logo on organismos;
create trigger validar_rutas_logo before insert or update of logo_ruta, simbolo_onac_ruta on organismos
  for each row execute function validar_rutas_logo();

select 'Migración 0004 aplicada: logos del organismo' as resultado;
