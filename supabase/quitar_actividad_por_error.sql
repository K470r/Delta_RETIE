-- ============================================================================
-- Quita del alcance una actividad registrada POR ERROR (nunca estuvo acreditada).
-- Solo la quita si nadie la tiene autorizada (designaciones) en ese organismo.
-- Cambie las dos líneas marcadas con ◀ y pegue en Supabase → SQL Editor → Run.
-- ============================================================================
do $$
declare
  codigo_organismo text := '17-OIN-032';          -- ◀ código de acreditación del organismo
  actividad        text := 'RETIE24-UF-MINAS';    -- ◀ actividad registrada por error
  org uuid := (select id from organismos where codigo_acreditacion = codigo_organismo);
  quitadas int;
begin
  if org is null then raise exception 'No existe un organismo con código %', codigo_organismo; end if;
  if exists (select 1 from designacion_actividades da join designaciones d on d.id = da.designacion_id
             where d.organismo_id = org and da.actividad_codigo = actividad) then
    raise exception 'La actividad % ya está autorizada a alguien: no se puede quitar; cámbiela a "retirada"', actividad;
  end if;
  alter table alcance_acreditado disable trigger user;    -- la regla de no borrar, solo mientras tanto
  delete from alcance_acreditado where organismo_id = org and actividad_codigo = actividad;
  get diagnostics quitadas = row_count;
  alter table alcance_acreditado enable trigger user;
  insert into bitacora (tabla, registro, operacion, antes)
  values ('alcance_acreditado', actividad, 'DELETE (registrada por error)', jsonb_build_object('organismo_id', org, 'actividad_codigo', actividad));
  raise notice 'Quitada(s): % línea(s) de %', quitadas, actividad;
end $$;

select a.actividad_codigo, a.estado from alcance_acreditado a join organismos o on o.id = a.organismo_id
 where o.codigo_acreditacion = '17-OIN-032' order by 1;
