-- ============================================================================
-- Delta RETIE — 0010 Matrícula profesional de ingeniero
--
-- Para director técnico e inspector se requiere matrícula de INGENIERO:
--   CPNIEMPA — Consejo Profesional Nacional de Ingenierías Eléctrica, Mecánica y
--              Profesiones Afines (Ley 51 de 1986)
--   COPNIA   — Consejo Profesional Nacional de Ingeniería (Ley 842 de 2003)
-- Otra entidad (por ejemplo un consejo poco común) solo cuenta si la gerencia la
-- acepta a mano, con motivo; nadie acepta la suya. Si cambian la entidad o el
-- número de la matrícula, la aceptación se pierde.
-- Los consejos de técnicos y tecnólogos no cuentan ni se pueden aceptar:
--   CONTE    — Consejo Nacional de Técnicos Electricistas
--   CONALTEL — Consejo Profesional Nacional de Tecnólogos en Electricidad,
--              Electromecánica, Electrónica y Afines (Ley 1264 de 2008)
--
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

alter table personas add column if not exists matricula_aceptada_por uuid;   -- persona de la gerencia
alter table personas add column if not exists matricula_aceptada_en timestamptz;
alter table personas add column if not exists matricula_aceptada_motivo text;

-- Normaliza la entidad: CPNIEMPA, COPNIA o el texto escrito.
create or replace function entidad_matricula(e text) returns text
language sql immutable as $$
  select case
    when e is null or trim(e) = '' then null
    when upper(e) like '%CPNIEMPA%' or upper(e) like '%ELÉCTRICA, MECÁNICA%' or upper(e) like '%ELECTRICA, MECANICA%' then 'CPNIEMPA'
    when upper(e) like '%COPNIA%' then 'COPNIA'
    else trim(e) end
$$;

-- ¿Es un consejo de técnicos o tecnólogos (no de ingenieros)?
create or replace function consejo_no_ingenieros(e text) returns boolean
language sql immutable as $$
  select upper(coalesce(e, '')) ~ '(CONTE|CONALTEL|T[ÉE]CNICOS ELECTRICISTAS|TECN[ÓO]LOGOS)'
$$;

-- ¿La matrícula sirve para director técnico o inspector?
create or replace function matricula_de_ingeniero(p personas) returns boolean
language sql stable as $$
  select coalesce(trim(p.matricula_numero), '') <> ''
     and (coalesce(entidad_matricula(p.matricula_entidad), '') in ('CPNIEMPA', 'COPNIA')
          or (p.matricula_aceptada_en is not null and not consejo_no_ingenieros(p.matricula_entidad)))
$$;

-- La aceptación no se escribe a mano: solo con la función de abajo. Y se pierde si cambia la matrícula.
create or replace function proteger_aceptacion_matricula() returns trigger
language plpgsql as $$
begin
  if coalesce(current_setting('delta.aceptacion', true), '') <> 'on' then
    if tg_op = 'INSERT' then
      new.matricula_aceptada_por := null; new.matricula_aceptada_en := null; new.matricula_aceptada_motivo := null;
    elsif new.matricula_entidad is distinct from old.matricula_entidad or new.matricula_numero is distinct from old.matricula_numero then
      new.matricula_aceptada_por := null; new.matricula_aceptada_en := null; new.matricula_aceptada_motivo := null;
    elsif (new.matricula_aceptada_por, new.matricula_aceptada_en, new.matricula_aceptada_motivo)
          is distinct from (old.matricula_aceptada_por, old.matricula_aceptada_en, old.matricula_aceptada_motivo) then
      raise exception 'La aceptación de la matrícula la registra la gerencia con el botón "Aceptar matrícula"';
    end if;
  end if;
  new.matricula_entidad := coalesce(entidad_matricula(new.matricula_entidad), new.matricula_entidad);
  return new;
end $$;

drop trigger if exists a_proteger_matricula on personas;
create trigger a_proteger_matricula before insert or update on personas
  for each row execute function proteger_aceptacion_matricula();

-- La gerencia de un organismo donde la persona está vinculada acepta una matrícula de otra entidad.
create or replace function aceptar_matricula(p_persona uuid, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
declare p personas;
begin
  select * into p from personas where id = p_persona;
  if p.id is null then raise exception 'La persona no existe'; end if;
  if not exists (select 1 from organismos_de(p_persona) o(id) where tiene_rol(o.id, roles_gerencia()) or en_arranque(o.id)) then
    raise exception 'Solo la gerencia de un organismo donde la persona está vinculada puede aceptar su matrícula';
  end if;
  if p_persona = persona_actual() then
    raise exception 'Nadie puede aceptar su propia matrícula';
  end if;
  if coalesce(trim(p_motivo), '') = '' then raise exception 'Indique el motivo de la aceptación'; end if;
  if coalesce(trim(p.matricula_numero), '') = '' then raise exception 'La persona no tiene número de matrícula'; end if;
  if coalesce(entidad_matricula(p.matricula_entidad), '') in ('CPNIEMPA', 'COPNIA') then
    raise exception 'Las matrículas del CPNIEMPA y del COPNIA no necesitan aceptación';
  end if;
  if consejo_no_ingenieros(p.matricula_entidad) then
    raise exception 'El CONTE y el CONALTEL matriculan técnicos y tecnólogos: no sirven para director técnico ni inspector';
  end if;
  perform set_config('delta.aceptacion', 'on', true);
  update personas set matricula_aceptada_por = persona_actual(), matricula_aceptada_en = now(), matricula_aceptada_motivo = trim(p_motivo)
   where id = p_persona;
  perform set_config('delta.aceptacion', '', true);
end $$;

revoke execute on function aceptar_matricula(uuid, text) from public, anon;
grant execute on function aceptar_matricula(uuid, text) to authenticated;

-- Requisitos de competencia: igual que en 0001, con la matrícula de ingeniero.
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
    where c.persona_id = p_persona and cc.reglamento_id = r.id and cc.categoria = k.codigo and certificado_vigente(c, p_fecha)) then
    return format('Sin certificado de competencias vigente (con seguimiento) en la categoría %s', k.codigo);
  end if;
  return null;
end $$;

-- Normaliza las entidades ya registradas.
update personas set matricula_entidad = entidad_matricula(matricula_entidad)
 where matricula_entidad is not null and matricula_entidad is distinct from entidad_matricula(matricula_entidad);

select 'Migración 0010 aplicada: matrícula profesional de ingeniero' as resultado;
