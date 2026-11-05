-- ============================================================================
-- Ultra RETIE — 0011 Seguimiento del mes 30 y asistente de dirección técnica
--
-- 1. Seguimiento del mes 30 del certificado de competencias:
--    - Después de la fecha límite, sin seguimiento registrado, el certificado no cuenta
--      y la persona no puede ejercer (ya era así).
--    - NUEVO: si el seguimiento se registra tarde, el certificado vuelve a contar solo
--      desde la fecha en que se registró en la plataforma (o la del seguimiento, la que
--      sea posterior). El periodo intermedio queda como NO habilitado, para siempre.
--    - La fecha de registro la pone la base de datos; no se escribe a mano.
--    - El seguimiento no puede tener fecha futura ni anterior a la emisión.
-- 2. Rol nuevo: asistente de dirección técnica (se usa a partir de 0013).
--
-- Ejecute este archivo solo (no junto con 0012 o 0013) y después los otros, en orden.
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

alter type rol_oec add value if not exists 'asistente_direccion_tecnica';

alter table certificados_competencia add column if not exists seguimiento_registrado_en timestamptz;

-- Los seguimientos ya registrados se toman como registrados a tiempo (en su fecha).
update certificados_competencia set seguimiento_registrado_en = seguimiento_fecha::timestamptz
 where seguimiento_fecha is not null and seguimiento_registrado_en is null;

-- Fecha límite del seguimiento: mes 30 contado desde el día siguiente a la emisión.
create or replace function limite_seguimiento(c certificados_competencia) returns date
language sql stable as $$
  select (c.fecha_emision + 1 + make_interval(months => (select r.seguimiento_mes from reglamentos r where r.id = c.reglamento_id)))::date
$$;

-- Desde cuándo vuelve a contar el certificado después del seguimiento.
create or replace function seguimiento_efectivo(c certificados_competencia) returns date
language sql stable as $$
  select case when c.seguimiento_fecha is null then null
    else greatest(c.seguimiento_fecha, coalesce((c.seguimiento_registrado_en at time zone 'America/Bogota')::date, c.seguimiento_fecha)) end
$$;

-- Vigencia: dentro de sus fechas, no anulado, sin seguimiento no conforme y
--   · hasta la fecha límite del seguimiento, o
--   · desde la fecha efectiva del seguimiento (si se registró tarde, hay un periodo sin habilitación).
create or replace function certificado_vigente(c certificados_competencia, p_fecha date)
returns boolean language sql stable as $$
  select not c.anulado
     and c.fecha_emision <= p_fecha and c.fecha_vencimiento >= p_fecha
     and coalesce(c.seguimiento_resultado, '') <> 'no_conforme'
     and (p_fecha <= limite_seguimiento(c)
          or (c.seguimiento_fecha is not null and p_fecha >= seguimiento_efectivo(c)))
$$;

-- Periodo en que la persona no pudo ejercer con este certificado por registrar tarde el seguimiento.
create or replace function periodo_sin_seguimiento(c certificados_competencia) returns daterange
language sql stable as $$
  select case
    when c.anulado or coalesce(c.seguimiento_resultado, '') = 'no_conforme' then null
    when c.seguimiento_fecha is null and current_date > limite_seguimiento(c)
      then daterange(limite_seguimiento(c) + 1, null)
    when c.seguimiento_fecha is not null and seguimiento_efectivo(c) > limite_seguimiento(c) + 1
      then daterange(limite_seguimiento(c) + 1, seguimiento_efectivo(c))
  end
$$;

-- La fecha de registro la pone la base de datos, y el seguimiento no puede ser futuro.
create or replace function proteger_seguimiento() returns trigger
language plpgsql as $$
begin
  if new.seguimiento_fecha is not null
     and (tg_op = 'INSERT' or new.seguimiento_fecha is distinct from old.seguimiento_fecha) then
    if new.seguimiento_fecha > (now() at time zone 'America/Bogota')::date then
      raise exception 'La fecha del seguimiento no puede ser futura';
    end if;
    if new.seguimiento_fecha < new.fecha_emision then
      raise exception 'La fecha del seguimiento no puede ser anterior a la emisión del certificado';
    end if;
    new.seguimiento_registrado_en := now();
  elsif new.seguimiento_fecha is null then
    new.seguimiento_registrado_en := null;
  else
    new.seguimiento_registrado_en := old.seguimiento_registrado_en;
  end if;
  return new;
end $$;

-- "a_" para que corra antes de la bitácora y esta registre la fecha de registro.
drop trigger if exists a_proteger_seguimiento on certificados_competencia;
create trigger a_proteger_seguimiento before insert or update on certificados_competencia
  for each row execute function proteger_seguimiento();

select 'Migración 0011 aplicada: seguimiento del mes 30 (periodo no habilitado) y rol de asistente de dirección técnica' as resultado;
