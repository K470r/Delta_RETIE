-- ============================================================================
-- Ultra RETIE — 0014 Verificación de los soportes de competencia y formación
--
-- Todo lo que tiene que ver con la competencia y la formación de una persona
-- (experiencia, formación académica y certificados de competencias) cuenta solo si
-- lo verificó alguien de:
--   · la gerencia (representante legal, gerente, miembro de la gerencia),
--   · el sistema de gestión (responsable del SG o su suplente),
--   · la dirección técnica (director técnico o su suplente),
-- de un organismo donde la persona está vinculada. Nunca la misma persona.
-- Queda quién verificó y cuándo (lo pone la base de datos).
-- Si después cambian los datos o el soporte de algo verificado, la verificación se
-- pierde y hay que verificarlo de nuevo. El seguimiento del mes 30 no la quita.
-- Los certificados de competencias ya registrados quedan SIN verificar.
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

alter table experiencias add column if not exists verificada_en timestamptz;
alter table formacion add column if not exists verificada_en timestamptz;
alter table certificados_competencia add column if not exists verificada boolean not null default false;
alter table certificados_competencia add column if not exists verificada_por uuid references personas(id);
alter table certificados_competencia add column if not exists verificada_en timestamptz;

create or replace function roles_verificacion() returns rol_oec[]
language sql immutable as $$
  select roles_gerencia() || array['responsable_sg', 'suplente_sg', 'director_tecnico', 'director_tecnico_suplente']::rol_oec[]
$$;

-- ¿Quien inició sesión puede verificar los soportes de esta persona?
create or replace function puede_verificar(p_persona uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and persona_actual() is not null and persona_actual() <> p_persona
     and exists (select 1 from organismos o
                  where tiene_rol(o.id, roles_verificacion())
                    and (o.id in (select organismos_de(p_persona)) or registrada_por_mi_sin_vincular(p_persona)))
$$;

-- Quienes verifican también pueden marcar la verificación en la hoja de vida.
create or replace function gestiona_hoja_de_vida(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
       p = persona_actual()
    or exists (select 1 from organismos_de(p) o(id) where administra(o.id) or tiene_rol(o.id, roles_verificacion()))
    or registrada_por_mi_sin_vincular(p))
$$;

-- Control de la verificación en experiencias, formación y certificados.
create or replace function controlar_verificacion() returns trigger
language plpgsql as $$
declare
  ignorar text[] := array['verificada', 'verificada_por', 'verificada_en', 'seguimiento_fecha', 'seguimiento_resultado',
                          'seguimiento_observacion', 'seguimiento_registrado_en', 'anulado'];
  cambio boolean := false;
begin
  -- Si cambian los datos o el soporte de algo verificado, la verificación se pierde.
  if tg_op = 'UPDATE' and old.verificada and new.verificada then
    cambio := (to_jsonb(new) - ignorar) is distinct from (to_jsonb(old) - ignorar);
    if cambio then new.verificada := false; end if;
  end if;

  if new.verificada and (tg_op = 'INSERT' or not old.verificada) then
    if auth.uid() is not null then
      if persona_actual() is null then
        raise exception 'Para verificar soportes, su usuario (%) debe estar registrado como persona', correo_actual();
      end if;
      if new.verificada_por is distinct from persona_actual() then
        raise exception 'La verificación queda a nombre de quien inició sesión';
      end if;
      if new.persona_id = persona_actual() then
        raise exception 'El soporte debe verificarlo otra persona del organismo (no se permite la autoverificación)';
      end if;
      if not puede_verificar(new.persona_id) then
        raise exception 'Verifican los soportes la gerencia, el responsable del SG (o su suplente) o un director técnico (o su suplente) del organismo';
      end if;
    end if;
    if new.verificada_por is null or new.verificada_por = new.persona_id then
      raise exception 'El soporte debe verificarlo otra persona del organismo (no se permite la autoverificación)';
    end if;
    new.verificada_en := now();
  elsif tg_op = 'UPDATE' and old.verificada and not new.verificada and not cambio then
    if auth.uid() is not null and not puede_verificar(new.persona_id) then
      raise exception 'Quitan la verificación la gerencia, el responsable del SG (o su suplente) o un director técnico (o su suplente)';
    end if;
    new.verificada_por := null; new.verificada_en := null;
  elsif not new.verificada then
    new.verificada_por := null; new.verificada_en := null;
  else
    new.verificada_por := old.verificada_por; new.verificada_en := old.verificada_en;
  end if;
  return new;
end $$;

drop trigger if exists validar_verificacion on experiencias;
drop trigger if exists validar_verificacion on formacion;
drop trigger if exists a_controlar_verificacion on experiencias;
drop trigger if exists a_controlar_verificacion on formacion;
drop trigger if exists a_controlar_verificacion on certificados_competencia;
create trigger a_controlar_verificacion before insert or update on experiencias
  for each row execute function controlar_verificacion();
create trigger a_controlar_verificacion before insert or update on formacion
  for each row execute function controlar_verificacion();
-- Los campos del seguimiento del mes 30 no cuentan como cambio (los maneja a_proteger_seguimiento, 0011).
create trigger a_controlar_verificacion before insert or update on certificados_competencia
  for each row execute function controlar_verificacion();

-- Requisitos de competencia: igual que en 0010; el certificado, además, verificado.
create or replace function motivo_competencia(p_persona uuid, p_actividad text, p_rol text, p_fecha date default current_date)
returns text language plpgsql stable as $$
declare
  a actividades; r reglamentos; k categorias_competencia; p personas;
  cat_exp text; anios numeric; dir numeric;
begin
  select * into a from actividades where codigo = p_actividad;
  select * into r from reglamentos where id = a.reglamento_id;
  select * into k from categorias_competencia where reglamento_id = a.reglamento_id and codigo = a.categoria;
  select * into p from personas where id = p_persona;

  if r.matricula_requerida and coalesce(p.matricula_numero, '') = '' then
    return 'Sin matrícula profesional registrada (Leyes 842 de 2003 y 51 de 1986)';
  end if;
  if r.matricula_requerida and not matricula_de_ingeniero(p) then
    return 'Se requiere matrícula profesional de ingeniero (CPNIEMPA o COPNIA); una matrícula de otra entidad debe aceptarla la gerencia';
  end if;

  if r.requiere_posgrado_iluminacion then
    if not exists (select 1 from formacion f where f.persona_id = p_persona and f.verificada and f.en_iluminacion
                   and f.tipo in ('especializacion','maestria','doctorado')) then
      return 'Sin posgrado verificado en iluminación y/o alumbrado público';
    end if;
    if a.area_profundizacion is not null and not exists (
      select 1 from formacion f where f.persona_id = p_persona and f.verificada and a.area_profundizacion = any(f.areas_iluminacion)
        and (f.tipo = 'curso_profundizacion' or (f.en_iluminacion and f.tipo in ('especializacion','maestria','doctorado')))) then
      return 'Falta curso de profundización en ' || a.area_profundizacion;
    end if;
  end if;

  cat_exp := case when r.experiencia_por_categoria then k.codigo end;
  anios := anios_experiencia(p_persona, r.id, cat_exp, r.tipos_experiencia_tecnica, p_fecha);
  if anios < k.experiencia_inspector_anios then
    return format('Experiencia verificada insuficiente: %s de %s años', round(anios, 1), k.experiencia_inspector_anios);
  end if;

  if p_rol = 'director_tecnico' then
    cat_exp := case when r.dt_por_categoria then k.codigo end;
    anios := anios_experiencia(p_persona, r.id, cat_exp, r.tipos_experiencia_tecnica || r.dt_tipos_direccion, p_fecha);
    dir := anios_experiencia(p_persona, r.id, cat_exp, r.dt_tipos_direccion, p_fecha);
    if (r.dt_total_estricta and anios <= r.dt_experiencia_total) or (not r.dt_total_estricta and anios < r.dt_experiencia_total) then
      return format('Experiencia de director técnico insuficiente: %s años (%s %s)', round(anios, 1),
                    case when r.dt_total_estricta then 'más de' else 'mínimo' end, r.dt_experiencia_total);
    end if;
    if dir < r.dt_experiencia_direccion then
      return format('Experiencia en gerencia/dirección insuficiente: %s de %s años', round(dir, 1), r.dt_experiencia_direccion);
    end if;
  end if;

  if r.exige_certificado and not exists (
    select 1 from certificados_competencia c join certificado_categorias cc on cc.certificado_id = c.id
    where c.persona_id = p_persona and cc.reglamento_id = r.id and cc.categoria = k.codigo
      and c.verificada and certificado_vigente(c, p_fecha)) then
    return format('Sin certificado de competencias vigente, verificado y con seguimiento en la categoría %s', k.codigo);
  end if;
  return null;
end $$;

select 'Migración 0014 aplicada: verificación de los soportes de competencia y formación' as resultado;
