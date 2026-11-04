-- Funciones de apoyo para las pruebas locales (prueba.debe_pasar / debe_fallar / debe_ser).
create schema if not exists prueba;
grant usage on schema prueba to authenticated;
create table if not exists prueba.resultados (n serial, ok boolean, texto text);
grant all on prueba.resultados, prueba.resultados_n_seq to authenticated;

create or replace function prueba.debe_pasar(titulo text, sql text) returns void language plpgsql as $$
begin
  execute sql;
  insert into prueba.resultados(ok, texto) values (true, titulo);
  raise notice 'OK     %', titulo;
exception when others then
  insert into prueba.resultados(ok, texto) values (false, titulo || ' → ' || sqlerrm);
  raise notice 'FALLO  % → %', titulo, sqlerrm;
end $$;

create or replace function prueba.debe_fallar(titulo text, sql text, contiene text default '') returns void language plpgsql as $$
declare msg text;
begin
  begin
    execute sql;
  exception when others then
    msg := sqlerrm;
  end;
  if msg is not null and position(lower(contiene) in lower(msg)) > 0 then
    insert into prueba.resultados(ok, texto) values (true, titulo);
    raise notice 'OK     % (rechazado: %)', titulo, msg;
  else
    insert into prueba.resultados(ok, texto) values (false, titulo || ' → ' || coalesce(msg, 'no fue rechazado'));
    raise notice 'FALLO  % → %', titulo, coalesce(msg, 'no fue rechazado');
  end if;
end $$;

create or replace function prueba.debe_ser(titulo text, sql text, esperado text) returns void language plpgsql as $$
declare v text;
begin
  execute sql into v;
  if v is not distinct from esperado then
    insert into prueba.resultados(ok, texto) values (true, titulo);
    raise notice 'OK     % (= %)', titulo, v;
  else
    insert into prueba.resultados(ok, texto) values (false, titulo || ' → obtuvo ' || coalesce(v, 'null') || ', esperaba ' || esperado);
    raise notice 'FALLO  % → obtuvo %, esperaba %', titulo, v, esperado;
  end if;
end $$;
grant execute on all functions in schema prueba to authenticated;
