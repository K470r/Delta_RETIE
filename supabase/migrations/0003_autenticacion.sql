-- ============================================================================
-- Delta RETIE — 0003 Autenticación y arranque inicial
--
-- * Administradores de la plataforma: los únicos que pueden crear organismos.
-- * Cada usuario de Supabase Auth queda enlazado a su persona (cédula) por el
--   correo: al registrarse, o cuando se registra la persona con ese correo.
--   El enlace no se puede cambiar desde la aplicación (evita suplantación).
-- * Arranque: quien crea un organismo lo administra mientras no haya nadie
--   designado vigente en gerencia, SG o dirección técnica. En ese periodo solo
--   puede vincularse y designarse a sí mismo; desde ese momento rigen los roles.
-- * La verificación de soportes de la hoja de vida queda a nombre de quien
--   inició sesión (no se puede verificar a nombre de otro ni autoverificar).
-- * Las vistas respetan la seguridad por filas de quien consulta.
--
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

-- ─────────────────── Administradores de la plataforma ───────────────────
create table if not exists administradores_plataforma (
  correo text primary key check (correo = lower(trim(correo)))
);
insert into administradores_plataforma (correo) values ('directortecnico.gceisas@gmail.com')
on conflict (correo) do nothing;
alter table administradores_plataforma enable row level security;
-- Sin políticas: solo se consulta por medio de las funciones siguientes.

create or replace function correo_actual() returns text
language sql stable security definer set search_path = public, auth as $$
  select lower(trim(email)) from auth.users where id = auth.uid()
$$;

create or replace function es_admin_plataforma() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from administradores_plataforma a where a.correo = correo_actual())
$$;

-- La aplicación lo consulta para mostrar u ocultar "Nuevo organismo".
create or replace function soy_admin_plataforma() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(es_admin_plataforma(), false)
$$;

-- ─────────────────── Quién creó cada registro ───────────────────
alter table organismos add column if not exists creado_por uuid;
alter table personas   add column if not exists creado_por uuid;

create or replace function asignar_creador() returns trigger
language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    new.creado_por := auth.uid();
  else
    new.creado_por := old.creado_por;   -- no se puede reescribir
  end if;
  return new;
end $$;

drop trigger if exists asignar_creador on organismos;
create trigger asignar_creador before insert or update on organismos
  for each row execute function asignar_creador();
drop trigger if exists asignar_creador on personas;
create trigger asignar_creador before insert or update on personas
  for each row execute function asignar_creador();

-- ─────────────────── Enlace usuario ↔ persona por correo ───────────────────

-- Al registrarse un usuario: si su correo coincide con una persona sin usuario, se enlaza.
create or replace function enlazar_persona_nuevo_usuario() returns trigger
language plpgsql security definer set search_path = public, auth as $$
begin
  if new.email is null or exists (select 1 from public.personas where usuario_id = new.id) then
    return new;
  end if;
  perform set_config('delta.enlace_automatico', 'on', true);
  update public.personas set usuario_id = new.id
   where id = (select p.id from public.personas p
                where p.usuario_id is null and lower(trim(p.correo)) = lower(trim(new.email))
                order by p.creado limit 1);
  perform set_config('delta.enlace_automatico', '', true);
  return new;
end $$;

drop trigger if exists enlazar_persona on auth.users;
create trigger enlazar_persona after insert or update of email on auth.users
  for each row execute function enlazar_persona_nuevo_usuario();

-- Al registrar (o corregir el correo de) una persona: si ya existe un usuario con
-- ese correo y aún no tiene persona, se enlaza. El enlace no se edita a mano.
create or replace function enlazar_usuario_persona() returns trigger
language plpgsql security definer set search_path = public, auth as $$
begin
  if auth.uid() is not null and coalesce(current_setting('delta.enlace_automatico', true), '') <> 'on' then
    if tg_op = 'INSERT' and new.usuario_id is not null then
      raise exception 'El usuario de acceso se enlaza automáticamente por el correo de la persona; no se puede asignar a mano';
    end if;
    if tg_op = 'UPDATE' and new.usuario_id is distinct from old.usuario_id then
      raise exception 'El usuario de acceso se enlaza automáticamente por el correo de la persona; no se puede cambiar a mano';
    end if;
  end if;
  if new.usuario_id is null and coalesce(trim(new.correo), '') <> '' then
    select u.id into new.usuario_id from auth.users u
     where lower(trim(u.email)) = lower(trim(new.correo))
       and not exists (select 1 from public.personas p where p.usuario_id = u.id and p.id <> new.id)
     limit 1;
  end if;
  return new;
end $$;

-- (Nombre elegido para que corra antes del disparador de bitácora y esta registre el enlace.)
drop trigger if exists asignar_usuario on personas;
create trigger asignar_usuario before insert or update on personas
  for each row execute function enlazar_usuario_persona();

-- Enlaza a los usuarios que ya existían antes de esta migración.
update personas p set usuario_id = u.id
  from auth.users u
 where p.usuario_id is null and lower(trim(p.correo)) = lower(trim(u.email))
   and not exists (select 1 from personas x where x.usuario_id = u.id);

-- ─────────────────── Arranque del organismo ───────────────────
-- Roles que administran el organismo (deben coincidir con administra()).
create or replace function roles_administracion() returns rol_oec[]
language sql immutable as $$
  select array['representante_legal','gerente','responsable_sg','suplente_sg',
               'director_tecnico','director_tecnico_suplente']::rol_oec[]
$$;

-- El organismo está "en arranque" para quien lo creó (administrador de la plataforma)
-- mientras nadie tenga una designación vigente de administración.
create or replace function en_arranque(org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null
     and exists (select 1 from organismos o where o.id = org and o.creado_por = auth.uid())
     and es_admin_plataforma()
     and not exists (select 1 from designaciones d
                      where d.organismo_id = org and d.rol = any(roles_administracion())
                        and d.desde <= current_date and (d.hasta is null or d.hasta >= current_date))
$$;

create or replace function mis_organismos() returns setof uuid
language sql stable security definer set search_path = public as $$
  select v.organismo_id from vinculaciones v
  where v.persona_id = persona_actual() and v.desde <= current_date and (v.hasta is null or v.hasta >= current_date)
  union
  select o.id from organismos o where o.creado_por = auth.uid() and en_arranque(o.id)
$$;

create or replace function administra(org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select tiene_rol(org, roles_administracion()) or en_arranque(org)
$$;

-- En arranque, quien creó el organismo solo puede vincularse y designarse a sí mismo.
create or replace function validar_arranque() returns trigger
language plpgsql as $$
begin
  if en_arranque(new.organismo_id) and new.persona_id is distinct from persona_actual() then
    if persona_actual() is null then
      raise exception 'Primero regístrese usted mismo como persona (con su correo %) y desígnese en el organismo', correo_actual();
    end if;
    raise exception 'El organismo está en arranque: primero vincúlese y desígnese usted mismo en gerencia, sistema de gestión o dirección técnica; después podrá designar a las demás personas';
  end if;
  return new;
end $$;

drop trigger if exists validar_arranque on vinculaciones;
create trigger validar_arranque before insert on vinculaciones
  for each row execute function validar_arranque();
drop trigger if exists validar_arranque on designaciones;
create trigger validar_arranque before insert on designaciones
  for each row execute function validar_arranque();

-- ─────────────────── Políticas ───────────────────
-- Organismos: los crea el administrador de la plataforma.
drop policy if exists creacion_admin_plataforma on organismos;
create policy creacion_admin_plataforma on organismos for insert to authenticated
  with check (es_admin_plataforma());

drop policy if exists gestion_arranque on organismos;
create policy gestion_arranque on organismos for update to authenticated
  using (en_arranque(id)) with check (true);

-- Personas que uno registró (aún sin vincular) siguen visibles para quien las registró.
create or replace function persona_visible(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p = persona_actual()
      or exists (select 1 from personas x where x.id = p and x.creado_por = auth.uid())
      or exists (select 1 from vinculaciones v where v.persona_id = p and v.organismo_id in (select mis_organismos()))
$$;

drop policy if exists lectura_registradas on personas;
create policy lectura_registradas on personas for select to authenticated using (creado_por = auth.uid());

drop policy if exists lectura_registradas on certificados_competencia;
create policy lectura_registradas on certificados_competencia for select to authenticated using (persona_visible(persona_id));

-- La persona puede registrarse a sí misma (su correo debe ser el de su usuario).
-- (La política "gestion" de 0002 ya permite insertar personas; esta regla se impone
--  con el disparador enlazar_usuario.)

-- ─────────────────── Verificación de soportes ───────────────────
-- La verificación queda a nombre de quien inició sesión y nunca de la misma persona.
create or replace function validar_verificacion() returns trigger
language plpgsql as $$
begin
  if new.verificada and (tg_op = 'INSERT' or not old.verificada) then
    if auth.uid() is not null then
      if persona_actual() is null then
        raise exception 'Para verificar soportes, su usuario (%) debe estar registrado como persona', correo_actual();
      end if;
      if new.verificada_por is distinct from persona_actual() then
        raise exception 'La verificación queda a nombre de quien inició sesión';
      end if;
    end if;
    if new.verificada_por is null or new.verificada_por = new.persona_id then
      raise exception 'El soporte debe verificarlo otra persona del organismo (no se permite la autoverificación)';
    end if;
  end if;
  if not new.verificada then
    new.verificada_por := null;
  end if;
  return new;
end $$;

-- ─────────────────── Bitácora con el usuario real ───────────────────
create or replace function registrar_bitacora() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'No se permite eliminar registros de %; ciérrelos o anúlelos con justificación (17020 §8.4)', tg_table_name;
  end if;
  insert into bitacora(tabla, registro, operacion, usuario, antes, despues)
  values (tg_table_name, coalesce(to_jsonb(new)->>'id', ''), tg_op, auth.uid(),
          case when tg_op = 'UPDATE' then to_jsonb(old) end, to_jsonb(new));
  return new;
end $$;

create or replace function registrar_bitacora_relacion() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into bitacora(tabla, registro, operacion, usuario, antes, despues)
  values (tg_table_name, '', tg_op, auth.uid(),
          case when tg_op <> 'INSERT' then to_jsonb(old) end,
          case when tg_op <> 'DELETE' then to_jsonb(new) end);
  return coalesce(new, old);
end $$;

-- ─────────────────── Vistas con la seguridad de quien consulta ───────────────────
alter view v_personal_onac set (security_invoker = true);
alter view v_equipos_estado set (security_invoker = true);

select 'Migración 0003 aplicada. Administradores de la plataforma: '
       || (select string_agg(correo, ', ') from administradores_plataforma) as resultado;
