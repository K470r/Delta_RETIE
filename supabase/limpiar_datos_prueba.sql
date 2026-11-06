-- ============================================================================
-- Borra los datos de PRUEBA creados durante la verificación de la conexión:
--   * organismos cuyo NIT empieza por PRUEBA
--   * personas cuyo documento empieza por PRUEBA (con su hoja de vida)
-- Lo que una persona de prueba verificó en otras hojas de vida vuelve a "sin verificar".
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
  tablas text[] := array['firmas_documento','documentos_personal','documentos_organismo','accesos_revision','designacion_actividades','designaciones','declaraciones','revisiones_sg','vinculaciones',
                         'certificado_categorias','certificados_competencia','experiencias','formacion',
                         'alcance_acreditado','sedes','organismos','personas'];
begin
  -- Solo las tablas que existen (según las migraciones ejecutadas).
  tablas := array(select x from unnest(tablas) x where to_regclass('public.' || x) is not null);
  foreach t in array tablas loop
    execute format('alter table %I disable trigger user', t);
  end loop;
  des := array(select id from designaciones where organismo_id = any(orgs) or persona_id = any(pers));
  cer := array(select id from certificados_competencia where persona_id = any(pers));

  if 'firmas_documento' = any(tablas) then
    execute 'delete from firmas_documento where organismo_id = any($1) or persona_id = any($2)' using orgs, pers;
    execute 'update documentos_personal set firmado_a_mano_por = null where firmado_a_mano_por = any($1)' using pers;
    execute 'delete from documentos_personal where organismo_id = any($1) or designacion_id = any($2) or evaluador_id = any($3)' using orgs, des, pers;
  end if;
  if 'documentos_organismo' = any(tablas) then
    execute 'delete from documentos_organismo where organismo_id = any($1)' using orgs;
  end if;
  if 'accesos_revision' = any(tablas) then
    execute 'delete from accesos_revision where organismo_id = any($1)' using orgs;
  end if;
  delete from designacion_actividades where designacion_id = any(des);
  delete from designaciones where id = any(des);
  delete from declaraciones where organismo_id = any(orgs) or persona_id = any(pers);
  delete from revisiones_sg where organismo_id = any(orgs) or persona_id = any(pers);
  delete from vinculaciones where organismo_id = any(orgs) or persona_id = any(pers);
  delete from certificado_categorias where certificado_id = any(cer);
  delete from certificados_competencia where id = any(cer);
  update experiencias set verificada = false, verificada_por = null where verificada_por = any(pers);
  update formacion set verificada = false, verificada_por = null where verificada_por = any(pers);
  if exists (select 1 from information_schema.columns where table_name = 'certificados_competencia' and column_name = 'verificada_por') then
    execute 'update certificados_competencia set verificada = false, verificada_por = null, verificada_en = null where verificada_por = any($1)' using pers;
    update experiencias set verificada_en = null where not verificada and verificada_en is not null;
    update formacion set verificada_en = null where not verificada and verificada_en is not null;
  end if;
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
