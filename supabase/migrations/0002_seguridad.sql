-- ============================================================================
-- Seguridad por filas (RLS) — confidencialidad (17020 §4.2)
-- Cada usuario autenticado es una persona; ve y modifica solo la información
-- de los organismos con los que tiene vinculación vigente, según su rol.
-- ============================================================================

create or replace function persona_actual() returns uuid
language sql stable security definer set search_path = public as $$
  select id from personas where usuario_id = auth.uid()
$$;

-- Organismos con los que el usuario tiene vinculación vigente
create or replace function mis_organismos() returns setof uuid
language sql stable security definer set search_path = public as $$
  select v.organismo_id from vinculaciones v
  where v.persona_id = persona_actual() and v.desde <= current_date and (v.hasta is null or v.hasta >= current_date)
$$;

create or replace function tiene_rol(org uuid, roles rol_oec[]) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from designaciones d
    where d.organismo_id = org and d.persona_id = persona_actual() and d.rol = any(roles)
      and d.desde <= current_date and (d.hasta is null or d.hasta >= current_date))
$$;

-- Gerencia, responsable del SG y dirección técnica administran el organismo
create or replace function administra(org uuid) returns boolean
language sql stable as $$
  select tiene_rol(org, array['representante_legal','gerente','responsable_sg','suplente_sg',
                              'director_tecnico','director_tecnico_suplente']::rol_oec[])
$$;

-- Catálogos: lectura para todo usuario autenticado
alter table reglamentos enable row level security;
alter table actividades enable row level security;
create policy lectura on reglamentos for select to authenticated using (true);
create policy lectura on actividades for select to authenticated using (true);

-- Tablas con organismo_id: lectura para miembros, escritura para quien administra
do $$
declare t text;
begin
  foreach t in array array[
    'sedes','alcance_acreditado','vinculaciones','designaciones','revisiones_sg','supervisiones',
    'declaraciones','clientes','riesgos_imparcialidad','equipos','formatos','cotizaciones',
    'ordenes_servicio','quejas_apelaciones','documentos','auditorias_internas',
    'revisiones_direccion','acciones','subcontratistas'
  ] loop
    execute format('alter table %I enable row level security', t);
    execute format('create policy lectura_miembros on %I for select to authenticated using (organismo_id in (select mis_organismos()))', t);
    execute format('create policy gestion_administradores on %I for all to authenticated using (administra(organismo_id)) with check (administra(organismo_id))', t);
  end loop;
end $$;

-- Organismos
alter table organismos enable row level security;
create policy lectura_miembros on organismos for select to authenticated using (id in (select mis_organismos()));
create policy gestion_gerencia on organismos for update to authenticated
  using (tiene_rol(id, array['representante_legal','gerente','responsable_sg']::rol_oec[]));
-- La creación de un organismo nuevo la hace el administrador de la plataforma (service_role).

-- Personas: cada quien ve a las personas de sus organismos y su propio registro
alter table personas enable row level security;
create policy lectura on personas for select to authenticated using (
  id = persona_actual() or exists (
    select 1 from vinculaciones v where v.persona_id = personas.id and v.organismo_id in (select mis_organismos())));
create policy gestion on personas for all to authenticated using (
  exists (select 1 from organismos o where administra(o.id))) with check (true);

alter table certificados_competencia enable row level security;
create policy lectura on certificados_competencia for select to authenticated using (
  persona_id = persona_actual() or exists (
    select 1 from vinculaciones v where v.persona_id = certificados_competencia.persona_id and v.organismo_id in (select mis_organismos())));
create policy gestion on certificados_competencia for all to authenticated using (
  exists (select 1 from organismos o where administra(o.id))) with check (true);

alter table certificado_actividades enable row level security;
create policy lectura on certificado_actividades for select to authenticated using (true);
create policy gestion on certificado_actividades for all to authenticated using (
  exists (select 1 from organismos o where administra(o.id))) with check (true);

alter table designacion_actividades enable row level security;
create policy lectura on designacion_actividades for select to authenticated using (
  exists (select 1 from designaciones d where d.id = designacion_id and d.organismo_id in (select mis_organismos())));
create policy gestion on designacion_actividades for all to authenticated using (
  exists (select 1 from designaciones d where d.id = designacion_id and administra(d.organismo_id)))
  with check (exists (select 1 from designaciones d where d.id = designacion_id and administra(d.organismo_id)));

-- El responsable del SG registra sus propias revisiones
create policy registro_responsable_sg on revisiones_sg for insert to authenticated
  with check (persona_id = persona_actual() and tiene_rol(organismo_id, array['responsable_sg','suplente_sg']::rol_oec[]));

-- Cualquier miembro registra sus propias declaraciones
create policy propias_declaraciones on declaraciones for insert to authenticated
  with check (persona_id = persona_actual() and organismo_id in (select mis_organismos()));

-- Operación de inspección: el inspector registra sobre sus propias inspecciones
do $$
declare t text;
begin
  foreach t in array array['inspecciones','inspeccion_equipos','resultados_item','mediciones','evidencias','dictamenes',
                           'calibraciones','conflictos_interes','quejas_involucrados','formacion','bitacora'] loop
    execute format('alter table %I enable row level security', t);
  end loop;
end $$;

create policy propia on inspecciones for all to authenticated
  using (inspector_id = persona_actual()) with check (inspector_id = persona_actual());
create policy lectura_org on inspecciones for select to authenticated using (
  exists (select 1 from ordenes_servicio o where o.id = orden_id and o.organismo_id in (select mis_organismos())));

do $$
declare t text;
begin
  foreach t in array array['inspeccion_equipos','resultados_item','mediciones','evidencias'] loop
    execute format($f$create policy propia on %I for all to authenticated
      using (exists (select 1 from inspecciones i where i.id = inspeccion_id and i.inspector_id = persona_actual()))
      with check (exists (select 1 from inspecciones i where i.id = inspeccion_id and i.inspector_id = persona_actual()))$f$, t);
    execute format($f$create policy lectura_org on %I for select to authenticated
      using (exists (select 1 from inspecciones i join ordenes_servicio o on o.id = i.orden_id
                     where i.id = inspeccion_id and o.organismo_id in (select mis_organismos())))$f$, t);
  end loop;
end $$;

create policy organismo on dictamenes for all to authenticated
  using (exists (select 1 from ordenes_servicio o where o.id = orden_id and o.organismo_id in (select mis_organismos())))
  with check (exists (select 1 from ordenes_servicio o where o.id = orden_id and administra(o.organismo_id)));

create policy organismo on calibraciones for all to authenticated
  using (exists (select 1 from equipos e where e.id = equipo_id and e.organismo_id in (select mis_organismos())))
  with check (exists (select 1 from equipos e where e.id = equipo_id and administra(e.organismo_id)));

create policy propios on conflictos_interes for all to authenticated
  using (persona_id = persona_actual() or exists (select 1 from clientes c where c.id = cliente_id and administra(c.organismo_id)))
  with check (persona_id = persona_actual() or exists (select 1 from clientes c where c.id = cliente_id and administra(c.organismo_id)));

create policy organismo on quejas_involucrados for all to authenticated
  using (exists (select 1 from quejas_apelaciones q where q.id = queja_id and q.organismo_id in (select mis_organismos())))
  with check (exists (select 1 from quejas_apelaciones q where q.id = queja_id and administra(q.organismo_id)));

create policy propia on formacion for all to authenticated
  using (persona_id = persona_actual() or exists (select 1 from organismos o where administra(o.id)))
  with check (persona_id = persona_actual() or exists (select 1 from organismos o where administra(o.id)));

-- Bitácora: solo lectura para quien administra; la escriben los triggers (security definer).
create policy lectura on bitacora for select to authenticated using (exists (select 1 from organismos o where administra(o.id)));
