-- Prueba de las reglas 17020 que impone la base de datos.
-- Ejecutar sobre una base recién migrada (con seed.sql). Cada bloque indica
-- si debe pasar o fallar; revisar que los errores coincidan.
\set ON_ERROR_STOP off
begin;
insert into personas (id,nombre,documento,roles) values
 ('00000000-0000-0000-0000-000000000001','DT','1',array['director_tecnico']::rol_oec[]),
 ('00000000-0000-0000-0000-000000000002','Insp','2',array['inspector']::rol_oec[]);
insert into clientes (id,nombre,nit) values ('00000000-0000-0000-0000-0000000000c1','Cli','900');
insert into autorizaciones (persona_id,alcance,otorgada,otorgada_por) values
 ('00000000-0000-0000-0000-000000000002','USO_FINAL_RESIDENCIAL',current_date-10,'00000000-0000-0000-0000-000000000001');
commit;

\echo '1) asignación sin revisión de solicitud → debe FALLAR (7.1)'
insert into ordenes_servicio (consecutivo,cliente_id,instalacion,alcance,inspector_id)
values ('OS-1','00000000-0000-0000-0000-0000000000c1','X','USO_FINAL_RESIDENCIAL','00000000-0000-0000-0000-000000000002');

\echo '2) alcance no autorizado → debe FALLAR (6.1)'
insert into ordenes_servicio (consecutivo,cliente_id,instalacion,alcance,inspector_id,solicitud_revisada_en)
values ('OS-2','00000000-0000-0000-0000-0000000000c1','X','TRANSFORMACION','00000000-0000-0000-0000-000000000002',now());

\echo '3) orden correcta → debe PASAR'
insert into ordenes_servicio (id,consecutivo,cliente_id,instalacion,alcance,inspector_id,solicitud_revisada_en,formato_codigo,formato_version)
values ('00000000-0000-0000-0000-0000000000a3','OS-3','00000000-0000-0000-0000-0000000000c1','X','USO_FINAL_RESIDENCIAL','00000000-0000-0000-0000-000000000002',now(),'F-229-D','1.0');
insert into inspecciones (id,orden_id,inspector_id)
values ('00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-0000000000a3','00000000-0000-0000-0000-000000000002');

\echo '4) NC sin descripción → debe FALLAR (7.3)'
insert into resultados_item (inspeccion_id,item_codigo,resultado) values ('00000000-0000-0000-0000-0000000000b1','IB200','NC');

insert into equipos (id,codigo,nombre) values ('00000000-0000-0000-0000-0000000000e1','EQ-1','Telurómetro');
insert into calibraciones (equipo_id,tipo,fecha,vence) values ('00000000-0000-0000-0000-0000000000e1','calibracion',current_date-400,current_date-35);
\echo '5) equipo con calibración vencida → debe FALLAR (6.2)'
insert into inspeccion_equipos values ('00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-0000000000e1');

\echo '6) dictamen revisado por el propio inspector → debe FALLAR (7.4)'
insert into dictamenes (orden_id,numero,resultado,revisado_por,revisado_en,aprobado_por,aprobado_en)
values ('00000000-0000-0000-0000-0000000000a3','D-1','conforme','00000000-0000-0000-0000-000000000002',now(),'00000000-0000-0000-0000-000000000001',now());

\echo '7) dictamen con revisión independiente → debe PASAR'
insert into dictamenes (orden_id,numero,resultado,revisado_por,revisado_en,aprobado_por,aprobado_en)
values ('00000000-0000-0000-0000-0000000000a3','D-2','conforme','00000000-0000-0000-0000-000000000001',now(),'00000000-0000-0000-0000-000000000001',now());

\echo '8) eliminar registros → debe FALLAR (8.4)'
delete from equipos;

\echo 'Bitácora generada:'
select tabla, operacion, count(*) from bitacora group by 1,2 order by 1;
