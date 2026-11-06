-- ============================================================================
-- Ultra RETIE — 0015 Generación hasta 1.000 V AC y 1.500 V DC: experiencia por tipo de instalación
--
-- Para las dos actividades de generación de baja tensión (variantes -BT de 0012):
--   · Certificado de competencias: categoría g.
--   · Experiencia: la que pide el RETIE para la categoría a (3 años), pero en ese tipo de
--     instalación: generación con FNCE, AGPE y GD, o generación con varias fuentes.
--   · Director técnico: la experiencia total y la de dirección también en ese tipo de instalación.
-- Para eso, cada experiencia de generación indica en qué tipo de instalación fue (columna
-- experiencias.actividades, con el código de la actividad de generación).
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

alter table experiencias add column if not exists actividades text[] not null default '{}';

alter table actividades add column if not exists experiencia_en_actividad text references actividades(codigo);
alter table actividades add column if not exists experiencia_anios numeric;

update actividades set experiencia_en_actividad = variante_de,
       experiencia_anios = (select k.experiencia_inspector_anios from categorias_competencia k
                             where k.reglamento_id = 'RETIE-2024' and k.codigo = 'a')
 where variante_de is not null and tension = 'hasta_1000ac_1500dc';

-- Años de experiencia verificada en un tipo de instalación (actividad), sin contar dos veces los traslapos.
create or replace function anios_experiencia_en(p_persona uuid, p_reglamento text, p_actividad text, p_tipos text[], p_fecha date)
returns numeric language sql stable as $$
  select coalesce(sum(upper(r) - lower(r)), 0) / 365.25
  from unnest((
    select range_agg(daterange(e.desde, least(coalesce(e.hasta, p_fecha), p_fecha), '[]'))
    from experiencias e
    where e.persona_id = p_persona and e.verificada and e.reglamento_id = p_reglamento
      and e.desde <= p_fecha and p_actividad = any(e.actividades) and e.tipos && p_tipos
  )) as r
$$;

-- Requisitos de competencia: igual que en 0014, con la experiencia por tipo de instalación.
create or replace function motivo_competencia(p_persona uuid, p_actividad text, p_rol text, p_fecha date default current_date)
returns text language plpgsql stable as $$
declare
  a actividades; r reglamentos; k categorias_competencia; p personas;
  cat_exp text; anios numeric; dir numeric; requeridos numeric; donde text;
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

  requeridos := coalesce(a.experiencia_anios, k.experiencia_inspector_anios);
  if a.experiencia_en_actividad is not null then
    anios := anios_experiencia_en(p_persona, r.id, a.experiencia_en_actividad, r.tipos_experiencia_tecnica, p_fecha);
    donde := ' en ' || (select x.nombre from actividades x where x.codigo = a.experiencia_en_actividad);
  else
    cat_exp := case when r.experiencia_por_categoria then k.codigo end;
    anios := anios_experiencia(p_persona, r.id, cat_exp, r.tipos_experiencia_tecnica, p_fecha);
    donde := '';
  end if;
  if anios < requeridos then
    return format('Experiencia verificada insuficiente%s: %s de %s años', donde, round(anios, 1), requeridos);
  end if;

  if p_rol = 'director_tecnico' then
    if a.experiencia_en_actividad is not null and r.dt_por_categoria then
      anios := anios_experiencia_en(p_persona, r.id, a.experiencia_en_actividad, r.tipos_experiencia_tecnica || r.dt_tipos_direccion, p_fecha);
      dir := anios_experiencia_en(p_persona, r.id, a.experiencia_en_actividad, r.dt_tipos_direccion, p_fecha);
    else
      cat_exp := case when r.dt_por_categoria then k.codigo end;
      anios := anios_experiencia(p_persona, r.id, cat_exp, r.tipos_experiencia_tecnica || r.dt_tipos_direccion, p_fecha);
      dir := anios_experiencia(p_persona, r.id, cat_exp, r.dt_tipos_direccion, p_fecha);
    end if;
    if (r.dt_total_estricta and anios <= r.dt_experiencia_total) or (not r.dt_total_estricta and anios < r.dt_experiencia_total) then
      return format('Experiencia de director técnico insuficiente%s: %s años (%s %s)', donde, round(anios, 1),
                    case when r.dt_total_estricta then 'más de' else 'mínimo' end, r.dt_experiencia_total);
    end if;
    if dir < r.dt_experiencia_direccion then
      return format('Experiencia en gerencia/dirección insuficiente%s: %s de %s años', donde, round(dir, 1), r.dt_experiencia_direccion);
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

select 'Migración 0015 aplicada: experiencia por tipo de instalación de generación' as resultado;
