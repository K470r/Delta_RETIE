-- ============================================================================
-- Delta RETIE — 0006 Acceso de revisión temporal
--
-- Permite que una persona vea TODO un organismo (solo lectura) durante un tiempo
-- limitado, sin cambiar sus roles reales ni crear designaciones falsas (17020 §8.4).
-- * Lo otorga solo el administrador de la plataforma, por correo y con fecha y hora
--   de vencimiento; al vencer se apaga solo.
-- * Solo lectura: para registrar o modificar siguen mandando los roles reales.
-- * Queda registrado quién lo otorgó, a quién, desde y hasta cuándo, y por qué.
--
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

create table if not exists accesos_revision (
  id           uuid primary key default gen_random_uuid(),
  organismo_id uuid not null references organismos(id),
  correo       text not null check (correo = lower(trim(correo))),
  desde        timestamptz not null default now(),
  hasta        timestamptz not null,
  motivo       text not null,
  otorgado_por uuid default auth.uid(),
  creado       timestamptz not null default now(),
  check (hasta > desde)
);
alter table accesos_revision enable row level security;

drop policy if exists admin_plataforma on accesos_revision;
create policy admin_plataforma on accesos_revision for all to authenticated
  using (es_admin_plataforma()) with check (es_admin_plataforma());
drop policy if exists propios on accesos_revision;
create policy propios on accesos_revision for select to authenticated using (correo = correo_actual());

drop trigger if exists bitacora_accesos_revision on accesos_revision;
create trigger bitacora_accesos_revision before insert or update or delete on accesos_revision
  for each row execute function registrar_bitacora();

-- ¿El usuario tiene acceso de revisión vigente al organismo?
create or replace function en_revision(org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from accesos_revision a
                  where a.organismo_id = org and a.correo = correo_actual() and now() between a.desde and a.hasta)
$$;

-- La aplicación lo consulta para mostrar todo el menú y el aviso de "solo lectura".
create or replace function mis_accesos_revision() returns table (organismo_id uuid, hasta timestamptz)
language sql stable security definer set search_path = public as $$
  select a.organismo_id, max(a.hasta) from accesos_revision a
   where a.correo = correo_actual() and now() between a.desde and a.hasta
   group by a.organismo_id
$$;

-- Lectura: los organismos en revisión cuentan como "mis organismos" (todas las tablas
-- con organismo_id, logos y personas vinculadas) …
create or replace function mis_organismos() returns setof uuid
language sql stable security definer set search_path = public as $$
  select v.organismo_id from vinculaciones v
  where v.persona_id = persona_actual() and v.desde <= current_date and (v.hasta is null or v.hasta >= current_date)
  union
  select o.id from organismos o where o.creado_por = auth.uid() and en_arranque(o.id)
  union
  select a.organismo_id from accesos_revision a
   where a.correo = correo_actual() and now() between a.desde and a.hasta
$$;

-- … y también se ven las hojas de vida y sus soportes del personal del organismo.
create or replace function ve_hoja_de_vida(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
       p = persona_actual()
    or exists (select 1 from organismos_de(p) o(id) where tiene_rol(o.id, roles_hoja_de_vida()) or en_arranque(o.id) or en_revision(o.id))
    or registrada_por_mi_sin_vincular(p))
$$;

select 'Migración 0006 aplicada: acceso de revisión temporal' as resultado;
