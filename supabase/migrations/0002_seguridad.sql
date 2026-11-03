-- ============================================================================
-- Seguridad por filas (RLS) — confidencialidad (17020 §4.2)
-- Cada usuario autenticado se vincula a una persona del OEC; lo que puede ver
-- y modificar depende de sus roles.
-- ============================================================================

create or replace function persona_actual() returns uuid
language sql stable security definer as $$
  select id from personas where usuario_id = auth.uid() and activo
$$;

create or replace function tiene_rol(r rol_oec) returns boolean
language sql stable security definer as $$
  select exists (select 1 from personas where usuario_id = auth.uid() and activo and r = any(roles))
$$;

create or replace function es_direccion() returns boolean
language sql stable as $$
  select tiene_rol('director_tecnico') or tiene_rol('director_tecnico_suplente') or tiene_rol('calidad')
$$;

do $$
declare t text;
begin
  foreach t in array array[
    'configuracion_oec','personas','autorizaciones','formacion','supervisiones','declaraciones',
    'clientes','conflictos_interes','riesgos_imparcialidad','equipos','calibraciones',
    'reglamentos','formatos','cotizaciones','ordenes_servicio','inspecciones',
    'inspeccion_equipos','resultados_item','mediciones','evidencias','dictamenes',
    'quejas_apelaciones','quejas_involucrados','documentos','auditorias_internas',
    'revisiones_direccion','acciones','subcontratistas','bitacora'
  ] loop
    execute format('alter table %I enable row level security', t);
    -- Lectura: todo el personal activo del OEC
    execute format('create policy lectura_personal on %I for select to authenticated using (persona_actual() is not null)', t);
  end loop;
end $$;

-- Dirección técnica / calidad: gestión completa del sistema de gestión y recursos
do $$
declare t text;
begin
  foreach t in array array[
    'configuracion_oec','personas','autorizaciones','formacion','supervisiones','declaraciones',
    'conflictos_interes','riesgos_imparcialidad','equipos','calibraciones','reglamentos','formatos',
    'ordenes_servicio','dictamenes','quejas_apelaciones','quejas_involucrados','documentos',
    'auditorias_internas','revisiones_direccion','acciones','subcontratistas'
  ] loop
    execute format('create policy gestion_direccion on %I for all to authenticated using (es_direccion()) with check (es_direccion())', t);
  end loop;
end $$;

-- Comercial
create policy comercial_clientes on clientes for all to authenticated
  using (tiene_rol('vendedor') or es_direccion()) with check (tiene_rol('vendedor') or es_direccion());
create policy comercial_cotizaciones on cotizaciones for all to authenticated
  using (tiene_rol('vendedor') or es_direccion()) with check (tiene_rol('vendedor') or es_direccion());

-- Inspector: solo registra sobre sus propias órdenes
create policy inspector_inspecciones on inspecciones for all to authenticated
  using (inspector_id = persona_actual()) with check (inspector_id = persona_actual());

create policy inspector_resultados on resultados_item for all to authenticated
  using (exists (select 1 from inspecciones i where i.id = inspeccion_id and i.inspector_id = persona_actual()))
  with check (exists (select 1 from inspecciones i where i.id = inspeccion_id and i.inspector_id = persona_actual()));

create policy inspector_mediciones on mediciones for all to authenticated
  using (exists (select 1 from inspecciones i where i.id = inspeccion_id and i.inspector_id = persona_actual()))
  with check (exists (select 1 from inspecciones i where i.id = inspeccion_id and i.inspector_id = persona_actual()));

create policy inspector_evidencias on evidencias for all to authenticated
  using (exists (select 1 from inspecciones i where i.id = inspeccion_id and i.inspector_id = persona_actual()))
  with check (exists (select 1 from inspecciones i where i.id = inspeccion_id and i.inspector_id = persona_actual()));

create policy inspector_equipos on inspeccion_equipos for all to authenticated
  using (exists (select 1 from inspecciones i where i.id = inspeccion_id and i.inspector_id = persona_actual()))
  with check (exists (select 1 from inspecciones i where i.id = inspeccion_id and i.inspector_id = persona_actual()));

-- Cualquier persona puede registrar sus propias declaraciones de imparcialidad/confidencialidad y conflictos
create policy propias_declaraciones on declaraciones for insert to authenticated
  with check (persona_id = persona_actual());
create policy propios_conflictos on conflictos_interes for insert to authenticated
  with check (persona_id = persona_actual());

-- La bitácora solo la escribe el trigger (security definer); nadie la modifica.
