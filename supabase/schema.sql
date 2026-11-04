-- =====================================================================
-- Delta RETIE — esquema Supabase
-- Ejecutar UNA vez en: Supabase Dashboard → SQL Editor → New query → Run
-- Es seguro volver a ejecutarlo.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Perfiles y roles
-- ---------------------------------------------------------------------
create table if not exists public.perfiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  email      text not null,
  nombre     text,
  rol        text not null default 'inspector'
             check (rol in ('admin', 'inspector')),
  created_at timestamptz not null default now()
);

alter table public.perfiles enable row level security;

-- Administrador principal: se asigna automáticamente al registrarse.
create or replace function public.rol_inicial(p_email text)
returns text
language sql
immutable
as $$
  select case
    when lower(p_email) = 'directortecnico.gceisas@gmail.com' then 'admin'
    else 'inspector'
  end;
$$;

-- Crea el perfil cuando alguien se registra.
create or replace function public.crear_perfil()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.perfiles (id, email, rol)
  values (new.id, new.email, public.rol_inicial(new.email))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.crear_perfil();

-- Perfiles para usuarios que ya existían antes de este script.
insert into public.perfiles (id, email, rol)
select u.id, u.email, public.rol_inicial(u.email)
from auth.users u
on conflict (id) do update
  set rol = case when excluded.rol = 'admin' then 'admin'
                 else public.perfiles.rol end;

-- ¿El usuario actual es administrador?
create or replace function public.es_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.perfiles
    where id = auth.uid() and rol = 'admin'
  );
$$;

drop policy if exists "perfiles_select" on public.perfiles;
drop policy if exists "perfiles_update_admin" on public.perfiles;

create policy "perfiles_select" on public.perfiles
  for select to authenticated
  using (id = auth.uid() or public.es_admin());

-- Solo el administrador puede cambiar roles.
create policy "perfiles_update_admin" on public.perfiles
  for update to authenticated
  using (public.es_admin()) with check (public.es_admin());

-- ---------------------------------------------------------------------
-- 2) No conformidades
-- ---------------------------------------------------------------------
create table if not exists public.no_conformidades (
  id            uuid primary key default gen_random_uuid(),
  inspeccion_id text not null,
  codigo        text not null,
  creado_por    uuid default auth.uid()
                references auth.users (id) on delete set null,
  instructivo   text,
  articulo      text,
  actividad     text,
  requisito     text,
  aspecto       text,
  descripcion   text,
  observacion   text,
  evidencias    jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (inspeccion_id, codigo)
);

alter table public.no_conformidades enable row level security;

drop policy if exists "nc_select" on public.no_conformidades;
drop policy if exists "nc_insert" on public.no_conformidades;
drop policy if exists "nc_update" on public.no_conformidades;
drop policy if exists "nc_delete_admin" on public.no_conformidades;

-- Cada inspector ve lo suyo; el administrador ve todo.
create policy "nc_select" on public.no_conformidades
  for select to authenticated
  using (creado_por = auth.uid() or public.es_admin());

create policy "nc_insert" on public.no_conformidades
  for insert to authenticated
  with check (creado_por = auth.uid());

create policy "nc_update" on public.no_conformidades
  for update to authenticated
  using (creado_por = auth.uid() or public.es_admin())
  with check (creado_por = auth.uid() or public.es_admin());

create policy "nc_delete_admin" on public.no_conformidades
  for delete to authenticated
  using (public.es_admin());

-- ---------------------------------------------------------------------
-- 3) Evidencias (Storage, bucket privado)
--    Ruta: <user_id>/<inspeccion_id>/<codigo>/<tipo>/<archivo>
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('evidencias', 'evidencias', false)
on conflict (id) do update set public = false;

drop policy if exists "evidencias_select" on storage.objects;
drop policy if exists "evidencias_insert" on storage.objects;
drop policy if exists "evidencias_update" on storage.objects;
drop policy if exists "evidencias_delete_admin" on storage.objects;

create policy "evidencias_select" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'evidencias'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.es_admin())
  );

create policy "evidencias_insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'evidencias'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "evidencias_update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'evidencias'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "evidencias_delete_admin" on storage.objects
  for delete to authenticated
  using (bucket_id = 'evidencias' and public.es_admin());
