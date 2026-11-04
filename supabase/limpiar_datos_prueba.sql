-- ============================================================================
-- Borra los datos de PRUEBA creados durante la verificación de la conexión:
--   * organismos cuyo NIT empieza por PRUEBA
--   * personas cuyo documento empieza por PRUEBA (con su hoja de vida)
-- La aplicación nunca borra (17020 §8.4); por eso este script desactiva los
-- disparadores solo durante esta ejecución. La bitácora se conserva.
-- Pegar en Supabase → SQL Editor → New query → Run.
-- ============================================================================
begin;
set local session_replication_role = replica;   -- desactiva disparadores solo en esta transacción

create temporary table _org on commit drop as select id from organismos where nit like 'PRUEBA%';
create temporary table _per on commit drop as select id from personas where documento like 'PRUEBA%';
create temporary table _des on commit drop as
  select id from designaciones where organismo_id in (select id from _org) or persona_id in (select id from _per);
create temporary table _cer on commit drop as select id from certificados_competencia where persona_id in (select id from _per);

delete from designacion_actividades where designacion_id in (select id from _des);
delete from designaciones where id in (select id from _des);
delete from declaraciones where organismo_id in (select id from _org) or persona_id in (select id from _per);
delete from revisiones_sg where organismo_id in (select id from _org) or persona_id in (select id from _per);
delete from vinculaciones where organismo_id in (select id from _org) or persona_id in (select id from _per);
delete from certificado_categorias where certificado_id in (select id from _cer);
delete from certificados_competencia where id in (select id from _cer);
update experiencias set verificada_por = null where verificada_por in (select id from _per);
update formacion set verificada_por = null where verificada_por in (select id from _per);
delete from experiencias where persona_id in (select id from _per);
delete from formacion where persona_id in (select id from _per);
delete from alcance_acreditado where organismo_id in (select id from _org);
delete from sedes where organismo_id in (select id from _org);
delete from organismos where id in (select id from _org);
delete from personas where id in (select id from _per);

select (select count(*) from organismos where nit like 'PRUEBA%') as organismos_prueba_restantes,
       (select count(*) from personas where documento like 'PRUEBA%') as personas_prueba_restantes;
commit;
