-- ============================================================================
-- Borra los datos de PRUEBA creados durante la verificación de la conexión:
--   * organismos cuyo NIT empieza por PRUEBA
--   * personas cuyo documento empieza por PRUEBA (con su hoja de vida)
-- La aplicación nunca borra (17020 §8.4); por eso este bloque apaga los
-- disparadores de estas tablas mientras borra y los vuelve a encender al final
-- (dentro de la misma operación). La bitácora se conserva.
-- Es un solo bloque: se ejecuta completo o no se ejecuta nada.
-- Pegar en Supabase → SQL Editor → New query → Run.
-- ============================================================================
do $$
declare
  orgs uuid[] := array(select id from organismos where nit like 'PRUEBA%');
  pers uuid[] := array(select id from personas where documento like 'PRUEBA%');
  des  uuid[];
  cer  uuid[];
  t    text;
  tablas text[] := array['designacion_actividades','designaciones','declaraciones','revisiones_sg','vinculaciones',
                         'certificado_categorias','certificados_competencia','experiencias','formacion',
                         'alcance_acreditado','sedes','organismos','personas'];
begin
  foreach t in array tablas loop
    execute format('alter table %I disable trigger user', t);
  end loop;
  des := array(select id from designaciones where organismo_id = any(orgs) or persona_id = any(pers));
  cer := array(select id from certificados_competencia where persona_id = any(pers));

  delete from designacion_actividades where designacion_id = any(des);
  delete from designaciones where id = any(des);
  delete from declaraciones where organismo_id = any(orgs) or persona_id = any(pers);
  delete from revisiones_sg where organismo_id = any(orgs) or persona_id = any(pers);
  delete from vinculaciones where organismo_id = any(orgs) or persona_id = any(pers);
  delete from certificado_categorias where certificado_id = any(cer);
  delete from certificados_competencia where id = any(cer);
  update experiencias set verificada_por = null where verificada_por = any(pers);
  update formacion set verificada_por = null where verificada_por = any(pers);
  delete from experiencias where persona_id = any(pers);
  delete from formacion where persona_id = any(pers);
  delete from alcance_acreditado where organismo_id = any(orgs);
  delete from sedes where organismo_id = any(orgs);
  delete from organismos where id = any(orgs);
  delete from personas where id = any(pers);

  foreach t in array tablas loop
    execute format('alter table %I enable trigger user', t);
  end loop;
  raise notice 'Borrados: % organismo(s) y % persona(s) de prueba', cardinality(orgs), cardinality(pers);
end $$;

select (select count(*) from organismos where nit like 'PRUEBA%') as organismos_prueba_restantes,
       (select count(*) from personas where documento like 'PRUEBA%') as personas_prueba_restantes;
