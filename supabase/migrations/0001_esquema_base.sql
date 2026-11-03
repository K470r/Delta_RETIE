-- ============================================================================
-- Delta RETIE — Esquema base
-- Plataforma del OEC: cotización → orden de servicio → inspección → dictamen,
-- con trazabilidad para el control de cumplimiento de ISO/IEC 17020.
--
-- Principios:
--   * Nada se borra: los registros se anulan con justificación (17020 §8.4).
--   * Toda modificación queda en bitácora (quién, qué, cuándo).
--   * Normas y formatos versionados: cada inspección guarda la versión usada.
-- ============================================================================

create extension if not exists pgcrypto;

-- ─────────────────────────────── Tipos ───────────────────────────────
create type rol_oec as enum (
  'vendedor', 'inspector', 'revisor', 'director_tecnico',
  'director_tecnico_suplente', 'calidad', 'administrativo'
);
create type alcance_inspeccion as enum (
  'USO_FINAL_RESIDENCIAL', 'USO_FINAL_NO_RESIDENCIAL', 'DISTRIBUCION',
  'TRANSFORMACION', 'GENERACION', 'TRANSMISION'
);
create type estado_orden as enum (
  'cotizada', 'aprobada', 'asignada', 'en_inspeccion', 'en_revision',
  'emitida', 'entregada', 'cancelada'
);
create type resultado_item as enum ('C', 'NC', 'NA');

-- ─────────────────────────── Configuración ───────────────────────────
create table configuracion_oec (
  id                 boolean primary key default true check (id), -- fila única
  razon_social       text not null,
  nit                text not null,
  tipo_organismo     char(1) not null check (tipo_organismo in ('A','B','C')),
  codigo_acreditacion text,
  poliza_rc_numero   text,
  poliza_rc_vence    date,
  director_tecnico_id          uuid,
  director_tecnico_suplente_id uuid,
  plazos             jsonb not null default '{
    "vigenciaDeclaracionImparcialidad": 365, "vigenciaSupervisionEnSitio": 365,
    "revisionDocumentos": 365, "auditoriaInterna": 365, "revisionDireccion": 365,
    "analisisRiesgosImparcialidad": 365, "acuseQueja": 5, "resolucionQueja": 30,
    "emisionDictamen": 15, "alertaAnticipada": 30 }'::jsonb
);

-- ───────────────────────────── Personal (6.1) ─────────────────────────────
create table personas (
  id               uuid primary key default gen_random_uuid(),
  usuario_id       uuid unique,               -- auth.users.id en Supabase
  nombre           text not null,
  documento        text not null unique,
  correo           text,
  telefono         text,
  roles            rol_oec[] not null default '{}',
  matricula_numero text,
  matricula_vence  date,
  activo           boolean not null default true,
  creado           timestamptz not null default now()
);

alter table configuracion_oec
  add foreign key (director_tecnico_id) references personas(id),
  add foreign key (director_tecnico_suplente_id) references personas(id);

-- Autorización formal por alcance (17020 §6.1.5 / 6.1.6)
create table autorizaciones (
  id           uuid primary key default gen_random_uuid(),
  persona_id   uuid not null references personas(id),
  alcance      alcance_inspeccion not null,
  otorgada     date not null,
  otorgada_por uuid not null references personas(id),
  revocada     date,
  soporte_url  text
);

create table formacion (
  id          uuid primary key default gen_random_uuid(),
  persona_id  uuid not null references personas(id),
  tema        text not null,
  fecha       date not null,
  horas       numeric,
  soporte_url text
);

-- Supervisión y monitoreo en sitio (17020 §6.1.8 – 6.1.9)
create table supervisiones (
  id            uuid primary key default gen_random_uuid(),
  inspector_id  uuid not null references personas(id),
  supervisor_id uuid not null references personas(id),
  fecha         date not null,
  en_sitio      boolean not null default true,
  orden_id      uuid,
  resultado     text not null,
  soporte_url   text,
  check (inspector_id <> supervisor_id)
);

-- ─────────────────────── Imparcialidad y confidencialidad (4.1, 4.2) ───────────────────────
create table declaraciones (
  id          uuid primary key default gen_random_uuid(),
  persona_id  uuid not null references personas(id),
  tipo        text not null check (tipo in ('imparcialidad', 'confidencialidad')),
  fecha       date not null,
  soporte_url text
);

create table clientes (
  id         uuid primary key default gen_random_uuid(),
  nombre     text not null,
  nit        text not null unique,
  contacto   text,
  correo     text,
  telefono   text,
  direccion  text,
  creado     timestamptz not null default now()
);

create table conflictos_interes (
  id           uuid primary key default gen_random_uuid(),
  persona_id   uuid not null references personas(id),
  cliente_id   uuid not null references clientes(id),
  descripcion  text not null,
  declarado    date not null default current_date,
  vigente      boolean not null default true
);

create table riesgos_imparcialidad (
  id            uuid primary key default gen_random_uuid(),
  fecha_analisis date not null,
  fuente        text not null,
  riesgo        text not null,
  nivel         text not null check (nivel in ('bajo','medio','alto')),
  tratamiento   text not null,
  responsable_id uuid references personas(id)
);

-- ─────────────────────────── Equipos (6.2) ───────────────────────────
create table equipos (
  id            uuid primary key default gen_random_uuid(),
  codigo        text not null unique,
  nombre        text not null,
  marca_modelo  text,
  serie         text,
  estado        text not null default 'operativo' check (estado in ('operativo','fuera_de_servicio','dado_de_baja')),
  creado        timestamptz not null default now()
);

create table calibraciones (
  id            uuid primary key default gen_random_uuid(),
  equipo_id     uuid not null references equipos(id),
  tipo          text not null check (tipo in ('calibracion','verificacion_intermedia','mantenimiento')),
  fecha         date not null,
  vence         date,
  laboratorio   text,               -- laboratorio acreditado (trazabilidad)
  certificado   text,
  conforme      boolean not null default true,
  soporte_url   text
);

-- ──────────────────────── Normas y formatos versionados ────────────────────────
create table reglamentos (
  id        text primary key,       -- 'RETIE-2024', 'RETIE-2026'
  nombre    text not null,
  acto      text,                   -- resolución que lo adopta
  vigente_desde date,
  vigente_hasta date
);

create table formatos (
  codigo     text not null,         -- 'F-229-D'
  version    text not null,
  titulo     text not null,
  reglamento_id text not null references reglamentos(id),
  alcances   alcance_inspeccion[] not null default '{}',
  contenido  jsonb not null,        -- secciones e ítems de la lista de verificación
  vigente    boolean not null default false,
  aprobado_por uuid references personas(id),
  aprobado   date,
  primary key (codigo, version)
);
-- Solo una versión vigente por formato
create unique index formatos_una_vigente on formatos(codigo) where vigente;

-- ─────────────────── Comercial: cotización y revisión de solicitud (7.1.5 – 7.1.6) ───────────────────
create table cotizaciones (
  id            uuid primary key default gen_random_uuid(),
  consecutivo   text not null unique,
  cliente_id    uuid not null references clientes(id),
  vendedor_id   uuid not null references personas(id),
  fecha         date not null default current_date,
  valida_hasta  date,
  items         jsonb not null default '[]',  -- [{descripcion, alcance, cantidad, valor_unitario}]
  subtotal      numeric(14,2) not null default 0,
  iva           numeric(14,2) not null default 0,
  total         numeric(14,2) not null default 0,
  estado        text not null default 'borrador' check (estado in ('borrador','enviada','aprobada','rechazada','vencida')),
  aprobada_en   timestamptz,
  aprobada_por_cliente text,          -- nombre / correo de quien aceptó
  soporte_aprobacion_url text
);

create table ordenes_servicio (
  id              uuid primary key default gen_random_uuid(),
  consecutivo     text not null unique,
  cotizacion_id   uuid references cotizaciones(id),
  cliente_id      uuid not null references clientes(id),
  instalacion     text not null,
  direccion       text,
  municipio       text,
  alcance         alcance_inspeccion not null,
  estado          estado_orden not null default 'aprobada',
  -- Revisión de la solicitud
  solicitud_revisada_por uuid references personas(id),
  solicitud_revisada_en  timestamptz,
  solicitud_observaciones text,
  -- Asignación
  inspector_id    uuid references personas(id),
  asignada_por    uuid references personas(id),
  asignada_en     timestamptz,
  fecha_programada date,
  formato_codigo  text,
  formato_version text,
  creado          timestamptz not null default now(),
  foreign key (formato_codigo, formato_version) references formatos(codigo, version)
);

-- ─────────────────────── Inspección en sitio (7.2, 7.3) ───────────────────────
create table inspecciones (
  id             uuid primary key default gen_random_uuid(),
  orden_id       uuid not null unique references ordenes_servicio(id),
  inspector_id   uuid not null references personas(id),
  inicio         timestamptz,
  fin            timestamptz,
  latitud        double precision,
  longitud       double precision,
  precision_m    double precision,
  observaciones  text,
  dispositivo    text,
  sincronizado   timestamptz
);

create table inspeccion_equipos (
  inspeccion_id uuid not null references inspecciones(id),
  equipo_id     uuid not null references equipos(id),
  primary key (inspeccion_id, equipo_id)
);

create table resultados_item (
  id             uuid primary key default gen_random_uuid(),
  inspeccion_id  uuid not null references inspecciones(id),
  item_codigo    text not null,
  resultado      resultado_item not null,
  observacion    text,
  registrado     timestamptz not null default now(),
  unique (inspeccion_id, item_codigo),
  constraint nc_requiere_observacion check (resultado <> 'NC' or coalesce(trim(observacion), '') <> '')
);

create table mediciones (
  id             uuid primary key default gen_random_uuid(),
  inspeccion_id  uuid not null references inspecciones(id),
  item_codigo    text,
  magnitud       text not null,     -- 'resistencia de puesta a tierra', 'aislamiento'...
  valor          numeric not null,
  unidad         text not null,
  limite         text,
  equipo_id      uuid references equipos(id)
);

create table evidencias (
  id             uuid primary key default gen_random_uuid(),
  inspeccion_id  uuid not null references inspecciones(id),
  item_codigo    text,
  tipo           text not null,      -- MIME
  ruta           text not null,      -- ruta en Supabase Storage
  sha256         text not null,      -- integridad de la evidencia
  tomada         timestamptz not null,
  latitud        double precision,
  longitud       double precision
);

-- ───────────────────── Revisión, decisión y dictamen (7.4) ─────────────────────
create table dictamenes (
  id             uuid primary key default gen_random_uuid(),
  orden_id       uuid not null references ordenes_servicio(id),
  numero         text not null unique,
  version        int not null default 1,  -- modificaciones generan nueva versión (7.4.4)
  reemplaza_id   uuid references dictamenes(id),
  motivo_modificacion text,
  resultado      text not null check (resultado in ('conforme','no_conforme')),
  revisado_por   uuid not null references personas(id),
  revisado_en    timestamptz not null,
  aprobado_por   uuid not null references personas(id),
  aprobado_en    timestamptz not null,
  pdf_ruta       text,
  pdf_sha256     text,
  codigo_verificacion text not null unique default encode(gen_random_bytes(9), 'hex'),
  entregado_en   timestamptz,
  anulado        boolean not null default false,
  motivo_anulacion text
);

-- ─────────────────────── Quejas y apelaciones (7.5, 7.6) ───────────────────────
create table quejas_apelaciones (
  id             uuid primary key default gen_random_uuid(),
  consecutivo    text not null unique,
  tipo           text not null check (tipo in ('queja','apelacion')),
  cliente_id     uuid references clientes(id),
  orden_id       uuid references ordenes_servicio(id),
  descripcion    text not null,
  recibida       date not null,
  acuse          date,
  investigacion  text,
  decision       text,
  decidida_por   uuid references personas(id),
  decidida_en    date,
  notificada_en  date,
  estado         text not null default 'abierta' check (estado in ('abierta','cerrada'))
);

create table quejas_involucrados (
  queja_id   uuid not null references quejas_apelaciones(id),
  persona_id uuid not null references personas(id),
  primary key (queja_id, persona_id)
);

-- ─────────────────────────── Sistema de gestión (8.x) ───────────────────────────
create table documentos (
  id          uuid primary key default gen_random_uuid(),
  codigo      text not null,
  titulo      text not null,
  tipo        text not null check (tipo in ('manual','procedimiento','instructivo','formato','externo')),
  version     text not null,
  estado      text not null default 'borrador' check (estado in ('borrador','vigente','obsoleto')),
  elaborado_por uuid references personas(id),
  aprobado_por  uuid references personas(id),
  aprobado      date,
  ultima_revision date,
  archivo_ruta text,
  unique (codigo, version)
);
create unique index documentos_uno_vigente on documentos(codigo) where estado = 'vigente';

create table auditorias_internas (
  id          uuid primary key default gen_random_uuid(),
  fecha       date not null,
  auditor_id  uuid references personas(id),
  auditor_externo text,
  numerales   text[] not null,
  informe_ruta text
);

create table revisiones_direccion (
  id        uuid primary key default gen_random_uuid(),
  fecha     date not null,
  acta_ruta text,
  decisiones text
);

create table acciones (
  id            uuid primary key default gen_random_uuid(),
  consecutivo   text not null unique,
  tipo          text not null check (tipo in ('correctiva','preventiva','mejora')),
  origen        text not null,      -- auditoría, queja, revisión, trabajo no conforme...
  descripcion   text not null,
  analisis_causa text,
  responsable_id uuid references personas(id),
  fecha_limite  date not null,
  estado        text not null default 'abierta' check (estado in ('abierta','implementada','cerrada')),
  eficacia_verificada boolean not null default false,
  eficacia_verificada_por uuid references personas(id),
  cerrada_en    date
);

create table subcontratistas (
  id               uuid primary key default gen_random_uuid(),
  nombre           text not null,
  nit              text,
  servicio         text not null,
  evaluacion_fecha date,
  evaluacion_vence date
);

-- ─────────────────────────── Bitácora (8.4) ───────────────────────────
create table bitacora (
  id        bigserial primary key,
  tabla     text not null,
  registro  text not null,
  operacion text not null,
  usuario   uuid,
  fecha     timestamptz not null default now(),
  antes     jsonb,
  despues   jsonb
);

create or replace function registrar_bitacora() returns trigger
language plpgsql security definer as $$
declare
  uid uuid;
begin
  begin
    uid := nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
  exception when others then uid := null;
  end;
  if tg_op = 'DELETE' then
    raise exception 'No se permite eliminar registros de %; anúlelos con justificación (17020 §8.4)', tg_table_name;
  end if;
  insert into bitacora(tabla, registro, operacion, usuario, antes, despues)
  values (tg_table_name, coalesce((to_jsonb(new)->>'id'), ''), tg_op, uid,
          case when tg_op = 'UPDATE' then to_jsonb(old) end, to_jsonb(new));
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array[
    'personas','autorizaciones','supervisiones','declaraciones','conflictos_interes',
    'riesgos_imparcialidad','equipos','calibraciones','formatos','cotizaciones',
    'ordenes_servicio','inspecciones','resultados_item','mediciones','evidencias',
    'dictamenes','quejas_apelaciones','documentos','auditorias_internas',
    'revisiones_direccion','acciones','subcontratistas'
  ] loop
    execute format(
      'create trigger bitacora_%1$s before insert or update or delete on %1$I
         for each row execute function registrar_bitacora()', t);
  end loop;
end $$;

-- ───────────────── Reglas 17020 aplicadas por la base de datos ─────────────────
-- Asignación: el inspector debe tener autorización vigente para el alcance y
-- no tener conflicto de interés declarado con el cliente (4.1, 6.1).
create or replace function validar_asignacion() returns trigger
language plpgsql as $$
begin
  if new.inspector_id is null then return new; end if;
  if tg_op = 'UPDATE' and new.inspector_id is not distinct from old.inspector_id then return new; end if;

  if new.solicitud_revisada_en is null then
    raise exception 'La solicitud % no ha sido revisada (17020 §7.1.6)', new.consecutivo;
  end if;
  if not exists (
    select 1 from autorizaciones a
    where a.persona_id = new.inspector_id and a.alcance = new.alcance
      and a.otorgada <= current_date and (a.revocada is null or a.revocada > current_date)
  ) then
    raise exception 'El inspector no tiene autorización vigente para el alcance % (17020 §6.1)', new.alcance;
  end if;
  if exists (
    select 1 from conflictos_interes c
    where c.persona_id = new.inspector_id and c.cliente_id = new.cliente_id and c.vigente
  ) then
    raise exception 'El inspector declaró conflicto de interés con este cliente (17020 §4.1)';
  end if;
  return new;
end $$;

create trigger validar_asignacion before insert or update of inspector_id on ordenes_servicio
  for each row execute function validar_asignacion();

-- Equipos: no se puede registrar un equipo con calibración vencida en una inspección (6.2).
create or replace function validar_equipo_inspeccion() returns trigger
language plpgsql as $$
declare vence date;
begin
  select max(c.vence) into vence from calibraciones c
   where c.equipo_id = new.equipo_id and c.tipo = 'calibracion' and c.conforme;
  if vence is null or vence < current_date then
    raise exception 'Equipo sin calibración vigente (17020 §6.2)';
  end if;
  return new;
end $$;

create trigger validar_equipo_inspeccion before insert on inspeccion_equipos
  for each row execute function validar_equipo_inspeccion();

-- Dictamen: revisión y aprobación por persona distinta al inspector (7.4).
create or replace function validar_dictamen() returns trigger
language plpgsql as $$
declare insp uuid;
begin
  select o.inspector_id into insp from ordenes_servicio o where o.id = new.orden_id;
  if new.revisado_por = insp then
    raise exception 'La revisión técnica debe hacerla una persona distinta al inspector (17020 §7.4)';
  end if;
  return new;
end $$;

create trigger validar_dictamen before insert on dictamenes
  for each row execute function validar_dictamen();

-- Apelaciones: decididas por personal no involucrado (7.6.5).
create or replace function validar_decision_queja() returns trigger
language plpgsql as $$
begin
  if new.decidida_por is not null and exists (
    select 1 from quejas_involucrados i where i.queja_id = new.id and i.persona_id = new.decidida_por
  ) then
    raise exception 'La decisión debe tomarla personal no involucrado en el caso (17020 §7.6.5)';
  end if;
  return new;
end $$;

create trigger validar_decision_queja before update of decidida_por on quejas_apelaciones
  for each row execute function validar_decision_queja();

-- ─────────────────── Vistas de indicadores para el tablero ───────────────────
create view v_equipos_estado as
select e.*,
  (select max(c.vence) from calibraciones c where c.equipo_id = e.id and c.tipo = 'calibracion' and c.conforme) as vence_calibracion,
  (select max(c.vence) from calibraciones c where c.equipo_id = e.id and c.tipo = 'verificacion_intermedia') as vence_verificacion
from equipos e;

create view v_personas_estado as
select p.*,
  (select max(d.fecha) from declaraciones d where d.persona_id = p.id and d.tipo = 'imparcialidad') as ultima_declaracion_imparcialidad,
  (select max(d.fecha) from declaraciones d where d.persona_id = p.id and d.tipo = 'confidencialidad') as acuerdo_confidencialidad,
  (select max(s.fecha) from supervisiones s where s.inspector_id = p.id and s.en_sitio) as ultima_supervision_en_sitio,
  (select coalesce(array_agg(a.alcance), '{}') from autorizaciones a
     where a.persona_id = p.id and (a.revocada is null or a.revocada > current_date)) as alcances_autorizados
from personas p;
