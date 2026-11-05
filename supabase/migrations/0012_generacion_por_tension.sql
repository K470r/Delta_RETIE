-- ============================================================================
-- Ultra RETIE — 0012 Generación: competencia según la tensión de la instalación
--
-- Para las actividades de generación con FNCE, AGPE y GD y de generación con varias
-- fuentes (RETIE 2024):
--   · Más de 1.000 V AC o más de 1.500 V DC → personal con categoría a (generación).
--   · Hasta 1.000 V AC y hasta 1.500 V DC (exactamente 1.000 / 1.500 incluido)
--     → personal con categoría g (uso final).
-- Cómo se inspecciona la instalación:
--   · Conectada a la red → como generación (la actividad de generación), con a o g según la tensión.
--   · No conectada a la red → como uso final (autogeneración), con g;
--     salvo si supera 1.000 V AC o 1.500 V DC: como generación, con a.
--
-- Cada actividad de generación tiene una "variante de baja tensión" (código -BT) que
-- se autoriza al personal con categoría g. La variante no se acredita por separado:
-- la cubre la misma línea del alcance.
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

alter table actividades add column if not exists variante_de text references actividades(codigo);
alter table actividades add column if not exists tension text
  check (tension in ('hasta_1000ac_1500dc', 'mayor_1000ac_1500dc'));

insert into actividades (codigo, reglamento_id, grupo, nombre, referencias, categoria, variante_de, tension)
select a.codigo || '-BT', a.reglamento_id, a.grupo,
       a.nombre || ' — hasta 1.000 V AC y 1.500 V DC', a.referencias, 'g', a.codigo, 'hasta_1000ac_1500dc'
  from actividades a
 where a.codigo in ('RETIE24-GEN-FNCE', 'RETIE24-GEN-VARIAS')
on conflict (codigo) do nothing;

update actividades set tension = 'mayor_1000ac_1500dc'
 where codigo in ('RETIE24-GEN-FNCE', 'RETIE24-GEN-VARIAS') and tension is distinct from 'mayor_1000ac_1500dc';

-- Línea del alcance que cubre una actividad (la variante la cubre su actividad de generación).
create or replace function linea_de(p_actividad text) returns text
language sql stable as $$
  select coalesce((select a.variante_de from actividades a where a.codigo = p_actividad), p_actividad)
$$;

-- La variante no se agrega al alcance: se acredita la actividad de generación.
create or replace function validar_linea_alcance() returns trigger
language plpgsql as $$
begin
  if linea_de(new.actividad_codigo) <> new.actividad_codigo then
    raise exception 'La variante por tensión no se acredita por separado: agregue la actividad %', linea_de(new.actividad_codigo);
  end if;
  return new;
end $$;

drop trigger if exists a_validar_linea_alcance on alcance_acreditado;
create trigger a_validar_linea_alcance before insert or update of actividad_codigo on alcance_acreditado
  for each row execute function validar_linea_alcance();

-- ¿Puede ejercer? Igual que en 0001, con la línea del alcance de la variante.
create or replace function puede_ejercer(p_org uuid, p_persona uuid, p_actividad text, p_fecha date default current_date, p_rol text default 'inspector')
returns text language plpgsql stable as $$
begin
  if not exists (select 1 from alcance_acreditado a
                 where a.organismo_id = p_org and a.actividad_codigo = linea_de(p_actividad) and a.estado = 'acreditada') then
    return 'La actividad ' || linea_de(p_actividad) || ' no está en el alcance acreditado vigente del organismo (17020 §5.1 / RAC-3.0-01)';
  end if;
  if not exists (select 1 from vinculaciones v
                 where v.organismo_id = p_org and v.persona_id = p_persona
                   and v.desde <= p_fecha and (v.hasta is null or v.hasta >= p_fecha)) then
    return 'La persona no tiene vinculación vigente con el organismo (17020 §6.1)';
  end if;
  return motivo_competencia(p_persona, p_actividad, p_rol, p_fecha);
end $$;

-- Quitar por error: igual que en 0009, contando también las autorizaciones de la variante.
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
             where d.organismo_id = p_organismo and linea_de(da.actividad_codigo) = p_actividad) then
    raise exception 'La actividad ya está autorizada a alguien: no se puede quitar. Si dejó de estar acreditada, cámbiela a "retirada"';
  end if;
  if exists (select 1 from ordenes_servicio where organismo_id = p_organismo and linea_de(actividad_codigo) = p_actividad) then
    raise exception 'Ya hay órdenes de servicio con esta actividad: no se puede quitar. Cámbiela a "retirada"';
  end if;
  perform set_config('delta.correccion', trim(p_motivo), true);
  delete from alcance_acreditado where organismo_id = p_organismo and actividad_codigo = p_actividad;
  perform set_config('delta.correccion', '', true);
end $$;

-- Actividad con la que se atiende una instalación de generación (para asignar personal, fase 2).
--   p_actividad: actividad de generación (FNCE/AGPE/GD o varias fuentes)
--   p_conectada_red: ¿la instalación está conectada a la red?
--   p_vac, p_vdc: tensión máxima AC y DC de la instalación (V)
create or replace function actividad_segun_instalacion(p_actividad text, p_conectada_red boolean, p_vac numeric, p_vdc numeric)
returns text language plpgsql stable as $$
declare bt text;
begin
  select a.codigo into bt from actividades a where a.variante_de = p_actividad and a.tension = 'hasta_1000ac_1500dc';
  if bt is null then return p_actividad; end if;               -- actividad sin regla por tensión
  if p_conectada_red is null then raise exception 'Indique si la instalación está conectada a la red'; end if;
  if coalesce(p_vac, 0) > 1000 or coalesce(p_vdc, 0) > 1500 then
    return p_actividad;                                         -- generación, categoría a
  elsif p_conectada_red then
    return bt;                                                  -- generación, categoría g
  else
    return 'RETIE24-UF-AUTOGEN';                                -- uso final (autogeneración), categoría g
  end if;
end $$;

select 'Migración 0012 aplicada: generación según tensión y conexión a la red' as resultado;
