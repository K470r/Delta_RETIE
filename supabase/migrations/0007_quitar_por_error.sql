-- ============================================================================
-- Delta RETIE — 0007 Quitar registros hechos por error
--
-- La regla general sigue: nada se borra (17020 §8.4). La excepción es corregir un
-- error de digitación que nunca se usó:
-- * una actividad del alcance de un organismo (nadie la tiene autorizada y no hay
--   órdenes de servicio con ella);
-- * una actividad autorizada a un director técnico o inspector (no hay órdenes de
--   servicio de esa persona con esa actividad).
-- Solo quien administra el organismo; con motivo obligatorio. La bitácora guarda
-- el registro quitado, quién, cuándo y el motivo.
--
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

-- La bitácora permite el borrado solo dentro de estas funciones (que marcan el motivo).
create or replace function registrar_bitacora() returns trigger
language plpgsql security definer set search_path = public as $$
declare motivo text := nullif(current_setting('delta.correccion', true), '');
begin
  if tg_op = 'DELETE' then
    if motivo is null then
      raise exception 'No se permite eliminar registros de %; ciérrelos o anúlelos con justificación (17020 §8.4)', tg_table_name;
    end if;
    insert into bitacora(tabla, registro, operacion, usuario, antes, despues)
    values (tg_table_name, coalesce(to_jsonb(old)->>'id', to_jsonb(old)->>'actividad_codigo', ''), 'DELETE (registrada por error)',
            auth.uid(), to_jsonb(old), jsonb_build_object('motivo', motivo));
    return old;
  end if;
  insert into bitacora(tabla, registro, operacion, usuario, antes, despues)
  values (tg_table_name, coalesce(to_jsonb(new)->>'id', ''), tg_op, auth.uid(),
          case when tg_op = 'UPDATE' then to_jsonb(old) end, to_jsonb(new));
  return new;
end $$;

create or replace function registrar_bitacora_relacion() returns trigger
language plpgsql security definer set search_path = public as $$
declare motivo text := nullif(current_setting('delta.correccion', true), '');
begin
  insert into bitacora(tabla, registro, operacion, usuario, antes, despues)
  values (tg_table_name, '', case when tg_op = 'DELETE' and motivo is not null then 'DELETE (registrada por error)' else tg_op end,
          auth.uid(),
          case when tg_op <> 'INSERT' then to_jsonb(old) end,
          case when tg_op <> 'DELETE' then to_jsonb(new) when motivo is not null then jsonb_build_object('motivo', motivo) end);
  return coalesce(new, old);
end $$;

-- Las actividades autorizadas ya no se quitan directamente: solo con la función de abajo.
drop policy if exists gestion on designacion_actividades;
drop policy if exists autorizacion on designacion_actividades;
create policy autorizacion on designacion_actividades for insert to authenticated
  with check (exists (select 1 from designaciones d where d.id = designacion_id and administra(d.organismo_id)));

-- ─────────────────── Quitar del alcance una actividad registrada por error ───────────────────
create or replace function quitar_alcance_por_error(p_organismo uuid, p_actividad text, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or not administra(p_organismo) then
    raise exception 'Solo quien administra el organismo puede corregir su alcance';
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

-- ─────────────────── Quitar una actividad autorizada por error ───────────────────
create or replace function quitar_autorizacion_por_error(p_designacion uuid, p_actividad text, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
declare d designaciones;
begin
  select * into d from designaciones where id = p_designacion;
  if d.id is null or auth.uid() is null or not administra(d.organismo_id) then
    raise exception 'Solo quien administra el organismo puede corregir las actividades autorizadas';
  end if;
  if coalesce(trim(p_motivo), '') = '' then
    raise exception 'Indique el motivo de la corrección';
  end if;
  if not exists (select 1 from designacion_actividades where designacion_id = p_designacion and actividad_codigo = p_actividad) then
    raise exception 'La actividad no está autorizada en esta designación';
  end if;
  if exists (select 1 from ordenes_servicio o where o.organismo_id = d.organismo_id and o.actividad_codigo = p_actividad
               and d.persona_id in (o.inspector_id, o.director_tecnico_id)) then
    raise exception 'La persona ya tiene órdenes de servicio con esta actividad: no se puede quitar. Finalice la designación o retire la actividad del alcance';
  end if;
  perform set_config('delta.correccion', trim(p_motivo), true);
  delete from designacion_actividades where designacion_id = p_designacion and actividad_codigo = p_actividad;
  perform set_config('delta.correccion', '', true);
end $$;

revoke execute on function quitar_alcance_por_error(uuid, text, text) from public, anon;
revoke execute on function quitar_autorizacion_por_error(uuid, text, text) from public, anon;
grant execute on function quitar_alcance_por_error(uuid, text, text) to authenticated;
grant execute on function quitar_autorizacion_por_error(uuid, text, text) to authenticated;

select 'Migración 0007 aplicada: quitar registros hechos por error' as resultado;
