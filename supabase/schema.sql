-- Delta RETIE — esquema Supabase
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query

-- 1) Tabla de no conformidades
create table if not exists public.no_conformidades (
  id            uuid primary key default gen_random_uuid(),
  inspeccion_id text not null,
  codigo        text not null,
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

-- ⚠️ Políticas de DESARROLLO: la app aún no tiene login, así que se permite
-- el acceso con la anon key. Antes de producción, agregar Supabase Auth y
-- restringir estas políticas a usuarios autenticados.
drop policy if exists "nc_anon_select" on public.no_conformidades;
drop policy if exists "nc_anon_insert" on public.no_conformidades;
drop policy if exists "nc_anon_update" on public.no_conformidades;

create policy "nc_anon_select" on public.no_conformidades
  for select to anon, authenticated using (true);
create policy "nc_anon_insert" on public.no_conformidades
  for insert to anon, authenticated with check (true);
create policy "nc_anon_update" on public.no_conformidades
  for update to anon, authenticated using (true) with check (true);

-- 2) Bucket de evidencias (fotos, documentos, videos, audios)
insert into storage.buckets (id, name, public)
values ('evidencias', 'evidencias', true)
on conflict (id) do nothing;

drop policy if exists "evidencias_anon_select" on storage.objects;
drop policy if exists "evidencias_anon_insert" on storage.objects;
drop policy if exists "evidencias_anon_update" on storage.objects;

create policy "evidencias_anon_select" on storage.objects
  for select to anon, authenticated using (bucket_id = 'evidencias');
create policy "evidencias_anon_insert" on storage.objects
  for insert to anon, authenticated with check (bucket_id = 'evidencias');
create policy "evidencias_anon_update" on storage.objects
  for update to anon, authenticated using (bucket_id = 'evidencias');
