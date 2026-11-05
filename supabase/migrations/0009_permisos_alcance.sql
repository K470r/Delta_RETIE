-- ============================================================================
-- Delta RETIE — 0009 Permisos del alcance y del organismo; actuación de suplentes
--
-- Reglas de GC&I (docs/DECISIONES.md):
-- * Mientras nadie esté designado, el creador del organismo puede ajustar todo (arranque).
-- * Cambiar el estado de una actividad del alcance: solo la gerencia.
-- * Agregar actividades (en trámite) y quitarlas por error: la gerencia y el SG.
-- * Datos, logos y documentos del organismo: la gerencia y el SG.
-- * Los suplentes pueden lo mismo que el titular y queda indicado que actuó el suplente:
--   la bitácora guarda en qué calidad actuó cada persona.
-- * La bitácora de un organismo la lee solo quien lo administra (antes, cualquiera
--   que administrara algún organismo).
--
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

-- ─────────────────── Grupos de roles ───────────────────
create or replace function roles_gerencia() returns rol_oec[]
language sql immutable as $$ select array['representante_legal','gerente','miembro_gerencia']::rol_oec[] $$;

create or replace function roles_gestion_organismo() returns rol_oec[]
language sql immutable as $$ select roles_gerencia() || array['responsable_sg','suplente_sg']::rol_oec[] $$;

-- Datos, logos y documentos del organismo; agregar y quitar actividades del alcance.
create or replace function gestiona_organismo(org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (tiene_rol(org, roles_gestion_organismo()) or en_arranque(org))
$$;

-- Estado de las actividades del alcance.
create or replace function decide_estado_alcance(org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (tiene_rol(org, roles_gerencia()) or en_arranque(org))
$$;

-- Los logos siguen la misma regla que los datos del organismo.
create or replace function gestiona_carpeta_organismo(nombre text) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  return gestiona_organismo(persona_de_carpeta(nombre));
end $$;

-- Datos del organismo
drop policy if exists gestion_gerencia on organismos;
drop policy if exists gestion_arranque on organismos;
drop policy if exists gestion_organismo on organismos;
create policy gestion_organismo on organismos for update to authenticated
  using (gestiona_organismo(id)) with check (gestiona_organismo(id));

-- ─────────────────── Alcance acreditado ───────────────────
alter table alcance_acreditado add column if not exists estado_por uuid;   -- persona que fijó el estado
alter table alcance_acreditado add column if not exists estado_en_calidad text;

drop policy if exists gestion_administradores on alcance_acreditado;
drop policy if exists alcance_agregar on alcance_acreditado;
drop policy if exists alcance_estado on alcance_acreditado;
-- Agregar: la gerencia y el SG, y la actividad nueva queda en trámite (en el arranque, cualquier estado).
create policy alcance_agregar on alcance_acreditado for insert to authenticated
  with check (en_arranque(organismo_id) or (gestiona_organismo(organismo_id) and estado = 'en_tramite'));
-- Cambiar el estado: solo la gerencia.
create policy alcance_estado on alcance_acreditado for update to authenticated
  using (decide_estado_alcance(organismo_id)) with check (decide_estado_alcance(organismo_id));

-- Nombre del rol con el que actúa la persona en el organismo (para la bitácora y el alcance).
create or replace function calidad_actuante(org uuid) returns text[]
language sql stable security definer set search_path = public as $$
  select case
    when auth.uid() is null then null
    when en_arranque(org) then array['creador del organismo (arranque)']
    else (select array_agg(distinct d.rol::text order by d.rol::text) from designaciones d
           where d.organismo_id = org and d.persona_id = persona_actual()
             and d.desde <= current_date and (d.hasta is null or d.hasta >= current_date))
  end
$$;

create or replace function registrar_estado_alcance() returns trigger
language plpgsql security definer set search_path = public as $$
declare c text[] := calidad_actuante(new.organismo_id);
begin
  if tg_op = 'INSERT' or new.estado is distinct from old.estado then
    new.estado_por := persona_actual();
    new.estado_en_calidad := array_to_string(c, ', ');
    if tg_op = 'UPDATE' then new.fecha_estado := current_date; end if;
  end if;
  return new;
end $$;

drop trigger if exists a_registrar_estado on alcance_acreditado;
create trigger a_registrar_estado before insert or update on alcance_acreditado
  for each row execute function registrar_estado_alcance();

-- Quitar por error: la gerencia y el SG (antes: quien administrara el organismo).
create or replace function quitar_alcance_por_error(p_organismo uuid, p_actividad text, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not gestiona_organismo(p_organismo) then
    raise exception 'Solo la gerencia o el responsable del SG pueden quitar actividades del alcance';
  end if;
  if coalesce(trim(p_motivo), '') = '' then
    raise exception 'Indique el motivo de la corrección';
  end if;
  if not exists (select 1 from alcance_acreditado where organismo_id = p_organismo and actividad_codigo = p_actividad) then
    raise exception 'La actividad no está en el alcance del organismo';
  end if;
  if exists (select 1 from designacion_actividades da join designaciones d on d.id = da.designacion_id
             where d.organismo_id = p_organismo and da.actividad_codigo = p_actividad) then
    raise exception 'La actividad ya está autorizada a alguien: no se puede quitar. Si dejó de estar acreditada, cámbiela a "retirada"';
  end if;
  if exists (select 1 from ordenes_servicio where organismo_id = p_organismo and actividad_codigo = p_actividad) then
    raise exception 'Ya hay órdenes de servicio con esta actividad: no se puede quitar. Cámbiela a "retirada"';
  end if;
  perform set_config('delta.correccion', trim(p_motivo), true);
  delete from alcance_acreditado where organismo_id = p_organismo and actividad_codigo = p_actividad;
  perform set_config('delta.correccion', '', true);
end $$;

-- ─────────────────── Bitácora: organismo y en qué calidad actuó ───────────────────
alter table bitacora add column if not exists organismo_id uuid;
alter table bitacora add column if not exists en_calidad_de text[];

create or replace function organismo_de_fila(tabla text, fila jsonb) returns uuid
language plpgsql stable security definer set search_path = public as $$
declare org uuid;
begin
  if tabla = 'organismos' then return (fila->>'id')::uuid; end if;
  if fila ? 'organismo_id' then return (fila->>'organismo_id')::uuid; end if;
  if tabla = 'designacion_actividades' then
    select d.organismo_id into org from designaciones d where d.id = (fila->>'designacion_id')::uuid;
  end if;
  return org;
exception when others then
  return null;
end $$;

create or replace function registrar_bitacora() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  motivo text := nullif(current_setting('delta.correccion', true), '');
  fila jsonb := to_jsonb(coalesce(new, old));
  org uuid := organismo_de_fila(tg_table_name, fila);
begin
  if tg_op = 'DELETE' then
    if motivo is null then
      raise exception 'No se permite eliminar registros de %; ciérrelos o anúlelos con justificación (17020 §8.4)', tg_table_name;
    end if;
    insert into bitacora(tabla, registro, operacion, usuario, antes, despues, organismo_id, en_calidad_de)
    values (tg_table_name, coalesce(fila->>'id', fila->>'actividad_codigo', ''), 'DELETE (registrada por error)',
            auth.uid(), to_jsonb(old), jsonb_build_object('motivo', motivo), org, calidad_actuante(org));
    return old;
  end if;
  insert into bitacora(tabla, registro, operacion, usuario, antes, despues, organismo_id, en_calidad_de)
  values (tg_table_name, coalesce(to_jsonb(new)->>'id', ''), tg_op, auth.uid(),
          case when tg_op = 'UPDATE' then to_jsonb(old) end, to_jsonb(new), org, calidad_actuante(org));
  return new;
end $$;

create or replace function registrar_bitacora_relacion() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  motivo text := nullif(current_setting('delta.correccion', true), '');
  org uuid := organismo_de_fila(tg_table_name, to_jsonb(coalesce(new, old)));
begin
  insert into bitacora(tabla, registro, operacion, usuario, antes, despues, organismo_id, en_calidad_de)
  values (tg_table_name, '', case when tg_op = 'DELETE' and motivo is not null then 'DELETE (registrada por error)' else tg_op end,
          auth.uid(),
          case when tg_op <> 'INSERT' then to_jsonb(old) end,
          case when tg_op <> 'DELETE' then to_jsonb(new) when motivo is not null then jsonb_build_object('motivo', motivo) end,
          org, calidad_actuante(org));
  return coalesce(new, old);
end $$;

drop policy if exists lectura on bitacora;
create policy lectura on bitacora for select to authenticated
  using (organismo_id is not null and (administra(organismo_id) or en_revision(organismo_id)));

select 'Migración 0009 aplicada: permisos del alcance y actuación de suplentes' as resultado;
