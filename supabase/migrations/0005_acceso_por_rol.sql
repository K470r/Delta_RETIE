-- ============================================================================
-- Delta RETIE — 0005 Acceso por rol y archivos privados
--
-- Tabla de acceso aprobada (docs/DECISIONES.md). En esta migración:
-- * Hoja de vida (formación, experiencia, certificados) y sus soportes: la ve la
--   persona misma y la gerencia, el responsable del SG y la dirección técnica de
--   los organismos donde está vinculada. Los demás inspectores no.
--   (Corrige 0002: la gerencia de cualquier organismo podía leer la hoja de vida
--   de personas de otros organismos.)
-- * Soportes en PDF o imagen en una carpeta privada ("soportes").
-- * Logos en carpeta privada: los ve solo el personal del organismo.
-- Los archivos se abren con enlaces que vencen en pocos minutos.
--
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

-- ─────────────────── ¿Quién ve y quién gestiona una hoja de vida? ───────────────────
create or replace function roles_hoja_de_vida() returns rol_oec[]
language sql immutable as $$
  select array['representante_legal','gerente','miembro_gerencia','responsable_sg','suplente_sg',
               'director_tecnico','director_tecnico_suplente']::rol_oec[]
$$;

-- Organismos donde la persona tiene vinculación vigente.
create or replace function organismos_de(p uuid) returns setof uuid
language sql stable security definer set search_path = public as $$
  select v.organismo_id from vinculaciones v
   where v.persona_id = p and v.desde <= current_date and (v.hasta is null or v.hasta >= current_date)
$$;

-- Persona registrada por el usuario y aún sin vincular a ningún organismo (en proceso de designación).
create or replace function registrada_por_mi_sin_vincular(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from personas x where x.id = p and x.creado_por = auth.uid())
     and not exists (select 1 from vinculaciones v where v.persona_id = p)
$$;

create or replace function ve_hoja_de_vida(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
       p = persona_actual()
    or exists (select 1 from organismos_de(p) o(id) where tiene_rol(o.id, roles_hoja_de_vida()) or en_arranque(o.id))
    or registrada_por_mi_sin_vincular(p))
$$;

create or replace function gestiona_hoja_de_vida(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
       p = persona_actual()
    or exists (select 1 from organismos_de(p) o(id) where administra(o.id))
    or registrada_por_mi_sin_vincular(p))
$$;

-- ─────────────────── Políticas de la hoja de vida ───────────────────
-- Personas: el directorio (nombres) sigue como en 0002/0003; modificar, solo quien gestiona.
drop policy if exists gestion on personas;
drop policy if exists registro on personas;
drop policy if exists modificacion on personas;
create policy registro on personas for insert to authenticated with check (true);
create policy modificacion on personas for update to authenticated
  using (gestiona_hoja_de_vida(id)) with check (gestiona_hoja_de_vida(id));

-- Certificados de competencias
drop policy if exists lectura on certificados_competencia;
drop policy if exists lectura_registradas on certificados_competencia;
drop policy if exists gestion on certificados_competencia;
drop policy if exists hoja_lectura on certificados_competencia;
drop policy if exists hoja_registro on certificados_competencia;
drop policy if exists hoja_modificacion on certificados_competencia;
create policy hoja_lectura on certificados_competencia for select to authenticated using (ve_hoja_de_vida(persona_id));
create policy hoja_registro on certificados_competencia for insert to authenticated with check (gestiona_hoja_de_vida(persona_id));
create policy hoja_modificacion on certificados_competencia for update to authenticated
  using (gestiona_hoja_de_vida(persona_id)) with check (gestiona_hoja_de_vida(persona_id));

-- Categorías de cada certificado
drop policy if exists lectura on certificado_categorias;
drop policy if exists gestion on certificado_categorias;
drop policy if exists hoja_lectura on certificado_categorias;
drop policy if exists hoja_registro on certificado_categorias;
drop policy if exists hoja_retiro on certificado_categorias;
create policy hoja_lectura on certificado_categorias for select to authenticated using (
  exists (select 1 from certificados_competencia c where c.id = certificado_id and ve_hoja_de_vida(c.persona_id)));
create policy hoja_registro on certificado_categorias for insert to authenticated with check (
  exists (select 1 from certificados_competencia c where c.id = certificado_id and gestiona_hoja_de_vida(c.persona_id)));
create policy hoja_retiro on certificado_categorias for delete to authenticated using (
  exists (select 1 from certificados_competencia c where c.id = certificado_id and gestiona_hoja_de_vida(c.persona_id)));

-- Experiencia y formación
do $$
declare t text;
begin
  foreach t in array array['experiencias', 'formacion'] loop
    execute format('drop policy if exists propia on %I', t);
    execute format('drop policy if exists hoja_lectura on %I', t);
    execute format('drop policy if exists hoja_registro on %I', t);
    execute format('drop policy if exists hoja_modificacion on %I', t);
    execute format('create policy hoja_lectura on %I for select to authenticated using (ve_hoja_de_vida(persona_id))', t);
    execute format('create policy hoja_registro on %I for insert to authenticated with check (gestiona_hoja_de_vida(persona_id))', t);
    execute format('create policy hoja_modificacion on %I for update to authenticated using (gestiona_hoja_de_vida(persona_id)) with check (gestiona_hoja_de_vida(persona_id))', t);
  end loop;
end $$;

-- ─────────────────── Archivos de soporte (privados) ───────────────────
-- Ruta: soportes/<persona>/<archivo>. Máximo 10 MB; PDF, JPG o PNG.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('soportes', 'soportes', false, 10485760, array['application/pdf', 'image/png', 'image/jpeg'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create or replace function persona_de_carpeta(nombre text) returns uuid
language plpgsql immutable as $$
begin
  return ((storage.foldername(nombre))[1])::uuid;
exception when others then
  return null;
end $$;

drop policy if exists soportes_lectura on storage.objects;
create policy soportes_lectura on storage.objects for select to authenticated
  using (bucket_id = 'soportes' and ve_hoja_de_vida(persona_de_carpeta(name)));
drop policy if exists soportes_carga on storage.objects;
create policy soportes_carga on storage.objects for insert to authenticated
  with check (bucket_id = 'soportes' and gestiona_hoja_de_vida(persona_de_carpeta(name)));

-- El soporte registrado debe estar en la carpeta de la persona.
create or replace function validar_ruta_soporte() returns trigger
language plpgsql as $$
begin
  if new.soporte_ruta is not null and new.soporte_ruta not like new.persona_id::text || '/%' then
    raise exception 'El soporte debe estar en la carpeta de la persona';
  end if;
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['certificados_competencia', 'experiencias', 'formacion'] loop
    execute format('drop trigger if exists validar_ruta_soporte on %I', t);
    execute format('create trigger validar_ruta_soporte before insert or update of soporte_ruta on %I for each row execute function validar_ruta_soporte()', t);
  end loop;
end $$;

-- ─────────────────── Logos privados ───────────────────
update storage.buckets set public = false where id = 'logos';

drop policy if exists logos_lectura on storage.objects;
create policy logos_lectura on storage.objects for select to authenticated
  using (bucket_id = 'logos' and persona_de_carpeta(name) in (select mis_organismos()));

select 'Migración 0005 aplicada: acceso por rol y archivos privados' as resultado;
