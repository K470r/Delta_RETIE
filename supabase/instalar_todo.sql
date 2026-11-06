-- ============================================================================
-- Ultra RETIE — INSTALACIÓN COMPLETA PARA SUPABASE
-- Pegar TODO este archivo en Supabase → SQL Editor → New query → Run.
-- Ejecutar UNA sola vez sobre un proyecto vacío.
-- Si ya lo ejecutó antes, NO lo repita: pegue solo las migraciones nuevas
-- (por ejemplo supabase/migrations/0015_experiencia_por_tipo_generacion.sql).
-- Generado a partir de supabase/migrations/*.sql y supabase/seed.sql
-- ============================================================================


-- >>>>>>>>>> supabase/migrations/0001_esquema_base.sql
-- ============================================================================
-- Delta RETIE — Esquema base (multi-organismo)
-- Plataforma para Organismos de Inspección tipo A (RETIE / RETILAP):
-- organismo y alcance acreditado → personal y designaciones → cotización →
-- orden de servicio → inspección → dictamen, con trazabilidad ISO/IEC 17020.
--
-- Principios:
--   * Nada se borra: los registros se anulan o se cierran con fecha (17020 §8.4).
--   * Toda modificación queda en bitácora (quién, qué, cuándo).
--   * Reglamentos, actividades y formatos versionados.
-- ============================================================================

create extension if not exists pgcrypto;
create extension if not exists btree_gist;

-- ─────────────────────────────── Tipos ───────────────────────────────
create type rol_oec as enum (
  'representante_legal',        -- gerencia (17020 §5.2.1)
  'gerente',
  'miembro_gerencia',
  'responsable_sg',             -- responsable del sistema de gestión (§8)
  'suplente_sg',
  'director_tecnico',           -- §5.2.5
  'director_tecnico_suplente',  -- §5.2.6
  'inspector',                  -- §6.1
  'revisor',
  'vendedor',
  'administrativo'
);
create type estado_linea_alcance as enum ('en_tramite', 'acreditada', 'suspendida', 'retirada');
create type estado_orden as enum (
  'cotizada', 'aprobada', 'asignada', 'en_inspeccion', 'en_revision',
  'emitida', 'entregada', 'cancelada'
);
create type resultado_item as enum ('C', 'NC', 'NA');

-- ─────────────────────── Catálogo normativo ───────────────────────
create table reglamentos (
  id            text primary key,        -- 'RETIE-2024', 'RETILAP-2024', 'RETIE-2026'
  nombre        text not null,
  acto          text,                    -- resoluciones que lo adoptan/modifican
  fuente_alcances text,                  -- nota técnica de ONAC de la que sale el catálogo
  fuente_requisitos text,                -- numerales del reglamento con los requisitos de personal
  vigente_desde date,
  vigente_hasta date,
  -- Requisitos de competencia del personal técnico
  exige_certificado          boolean not null default true,  -- RETILAP: false mientras no exista certificador
  vigencia_certificado_anios int not null default 5,
  seguimiento_mes            int not null default 30,
  matricula_requerida        boolean not null default true,
  requiere_posgrado_iluminacion boolean not null default false,
  experiencia_por_categoria  boolean not null default true,
  tipos_experiencia_tecnica  text[] not null default '{}',
  dt_experiencia_total       numeric,
  dt_total_estricta          boolean not null default false,   -- "más de" (RETIE) vs "mínimo" (RETILAP)
  dt_experiencia_direccion   numeric,
  dt_tipos_direccion         text[] not null default '{}',
  dt_por_categoria           boolean not null default true
);

-- Categorías de certificación de competencias de inspectores (RETIE a–g, RETILAP 1–5)
create table categorias_competencia (
  reglamento_id  text not null references reglamentos(id),
  codigo         text not null,
  nombre         text not null,
  experiencia_inspector_anios numeric not null,
  requiere_categoria_vigente text,     -- RETIE c–f exigen certificado vigente en g
  primary key (reglamento_id, codigo)
);

-- Actividades de inspección acreditables (catálogo ONAC)
create table actividades (
  codigo        text primary key,        -- 'RETIE24-UF-BASICAS'
  reglamento_id text not null references reglamentos(id),
  grupo         text not null,
  nombre        text not null,
  referencias   text[] not null default '{}',
  categoria     text not null,           -- categoría de certificación que la cubre
  area_profundizacion text,              -- RETILAP: curso de profundización exigido
  activa        boolean not null default true,
  foreign key (reglamento_id, categoria) references categorias_competencia(reglamento_id, codigo)
);

-- ─────────────────────────── Organismos ───────────────────────────
create table organismos (
  id                   uuid primary key default gen_random_uuid(),
  razon_social         text not null,
  sigla                text,
  nit                  text not null unique,
  tipo                 char(1) not null default 'A' check (tipo in ('A','B','C')),
  codigo_acreditacion  text unique,              -- p. ej. 15-OIN-001
  acreditacion_otorgada date,
  acreditacion_vence   date,
  direccion            text,
  ciudad               text,
  telefono             text,
  correo               text,
  -- Tipo A (17020 Anexo A.1): declaración de independencia del organismo
  declaracion_independencia date,
  poliza_rc_numero     text,
  poliza_rc_vence      date,
  plazos               jsonb not null default '{
    "vigenciaDeclaraciones": 365, "revisionResponsableSG": 30,
    "vigenciaSupervisionEnSitio": 365, "revisionDocumentos": 365,
    "auditoriaInterna": 365, "revisionDireccion": 365,
    "analisisRiesgosImparcialidad": 365, "acuseQueja": 5, "resolucionQueja": 30,
    "emisionDictamen": 15, "alertaAnticipada": 30, "alertaAcreditacion": 90 }'::jsonb,
  activo               boolean not null default true,
  creado               timestamptz not null default now(),
  check (acreditacion_vence is null or acreditacion_otorgada is null or acreditacion_vence > acreditacion_otorgada)
);

create table sedes (
  id           uuid primary key default gen_random_uuid(),
  organismo_id uuid not null references organismos(id),
  nombre       text not null,
  direccion    text,
  ciudad       text,
  principal    boolean not null default false
);
create unique index sedes_una_principal on sedes(organismo_id) where principal;

-- Alcance acreditado: líneas del catálogo con su estado ante ONAC
create table alcance_acreditado (
  organismo_id    uuid not null references organismos(id),
  actividad_codigo text not null references actividades(codigo),
  estado          estado_linea_alcance not null default 'acreditada',
  fecha_estado    date not null default current_date,
  observacion     text,
  primary key (organismo_id, actividad_codigo)
);

-- ─────────────────────────── Personas ───────────────────────────
create table personas (
  id               uuid primary key default gen_random_uuid(),
  usuario_id       uuid unique,               -- auth.users.id en Supabase
  tipo_documento   text not null default 'CC' check (tipo_documento in ('CC','CE','PA','PPT')),
  documento        text not null unique,
  nombres          text not null,
  apellidos        text not null,
  correo           text,
  telefono         text,
  profesion        text,
  matricula_numero text,
  matricula_entidad text,                     -- CONTE, COPNIA, CPIEMAP...
  matricula_especialidad text,                -- Ley 842 de 2003 / Ley 51 de 1986
  creado           timestamptz not null default now(),
  check (documento ~ '^[0-9A-Za-z]+$')
);

-- Certificado de competencias (organismo de certificación de personas, ISO/IEC 17024)
create table certificados_competencia (
  id                uuid primary key default gen_random_uuid(),
  persona_id        uuid not null references personas(id),
  reglamento_id     text not null references reglamentos(id),
  numero            text not null,
  certificador      text not null,
  fecha_emision     date not null,
  fecha_vencimiento date not null,
  -- Seguimiento obligatorio al mes 30 (RETIE §4.4.2.6 / RETILAP §4.5.2.6)
  seguimiento_fecha     date,
  seguimiento_resultado text check (seguimiento_resultado in ('conforme','no_conforme')),
  seguimiento_observacion text,
  soporte_ruta      text,
  anulado           boolean not null default false,
  check (fecha_vencimiento > fecha_emision),
  check ((seguimiento_fecha is null) = (seguimiento_resultado is null)),
  unique (certificador, numero)
);

create table certificado_categorias (
  certificado_id uuid not null references certificados_competencia(id),
  reglamento_id  text not null,
  categoria      text not null,
  primary key (certificado_id, categoria),
  foreign key (reglamento_id, categoria) references categorias_competencia(reglamento_id, codigo)
);

-- Formación académica (RETILAP exige posgrado en iluminación y cursos de profundización)
create table formacion (
  id                uuid primary key default gen_random_uuid(),
  persona_id        uuid not null references personas(id),
  tipo              text not null check (tipo in ('pregrado','especializacion','maestria','doctorado','curso_profundizacion','otro')),
  titulo            text not null,
  institucion       text not null,
  fecha             date not null,
  en_iluminacion    boolean not null default false,
  areas_iluminacion text[] not null default '{}',
  verificada        boolean not null default false,
  verificada_por    uuid references personas(id),
  soporte_ruta      text
);

-- Experiencia laboral del ejercicio profesional (solo cuenta la verificada)
create table experiencias (
  id             uuid primary key default gen_random_uuid(),
  persona_id     uuid not null references personas(id),
  empresa        text not null,
  cargo          text not null,
  desde          date not null,
  hasta          date,
  reglamento_id  text not null references reglamentos(id),
  categorias     text[] not null default '{}',
  tipos          text[] not null check (cardinality(tipos) > 0),
  descripcion    text,
  verificada     boolean not null default false,
  verificada_por uuid references personas(id),
  soporte_ruta   text,
  check (hasta is null or hasta >= desde)
);

-- Vinculación persona ↔ organismo (lo que ONAC pide: tipo y fecha de vinculación, sede)
create table vinculaciones (
  id              uuid primary key default gen_random_uuid(),
  organismo_id    uuid not null references organismos(id),
  persona_id      uuid not null references personas(id),
  sede_id         uuid references sedes(id),
  tipo            text not null check (tipo in ('laboral','prestacion_servicios','otro')),
  cargo           text not null,
  desde           date not null,
  hasta           date,
  check (hasta is null or hasta >= desde),
  exclude using gist (organismo_id with =, persona_id with =, daterange(desde, hasta, '[]') with &&)
);

-- Designaciones de rol dentro del organismo (gerencia, SG, dirección técnica, inspección)
create table designaciones (
  id              uuid primary key default gen_random_uuid(),
  organismo_id    uuid not null references organismos(id),
  persona_id      uuid not null references personas(id),
  rol             rol_oec not null,
  desde           date not null,
  hasta           date,
  acto            text,                          -- acta / resolución interna de designación
  designado_por   uuid references personas(id),
  check (hasta is null or hasta >= desde),
  -- Una sola persona vigente a la vez en roles únicos
  exclude using gist (organismo_id with =, rol with =, daterange(desde, hasta, '[]') with &&)
    where (rol in ('representante_legal', 'responsable_sg'))
);

-- Actividades autorizadas a un director técnico o inspector (17020 §6.1.6)
create table designacion_actividades (
  designacion_id   uuid not null references designaciones(id),
  actividad_codigo text not null references actividades(codigo),
  primary key (designacion_id, actividad_codigo)
);

-- Registro de la revisión continua del responsable del sistema de gestión
create table revisiones_sg (
  id            uuid primary key default gen_random_uuid(),
  organismo_id  uuid not null references organismos(id),
  persona_id    uuid not null references personas(id),
  fecha         date not null default current_date,
  aspectos      text[] not null default '{}',     -- numerales revisados
  observaciones text,
  requiere_accion boolean not null default false
);

-- Supervisión y monitoreo en sitio (17020 §6.1.8 – 6.1.9)
create table supervisiones (
  id            uuid primary key default gen_random_uuid(),
  organismo_id  uuid not null references organismos(id),
  inspector_id  uuid not null references personas(id),
  supervisor_id uuid not null references personas(id),
  fecha         date not null,
  en_sitio      boolean not null default true,
  orden_id      uuid,
  resultado     text not null,
  soporte_ruta  text,
  check (inspector_id <> supervisor_id)
);

-- ─────────────────────── Imparcialidad y confidencialidad (4.1, 4.2) ───────────────────────
create table declaraciones (
  id           uuid primary key default gen_random_uuid(),
  organismo_id uuid not null references organismos(id),
  persona_id   uuid not null references personas(id),
  tipo         text not null check (tipo in ('imparcialidad', 'confidencialidad')),
  fecha        date not null,
  soporte_ruta text
);

create table clientes (
  id           uuid primary key default gen_random_uuid(),
  organismo_id uuid not null references organismos(id),
  nombre       text not null,
  nit          text not null,
  contacto     text,
  correo       text,
  telefono     text,
  direccion    text,
  creado       timestamptz not null default now(),
  unique (organismo_id, nit)
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
  id             uuid primary key default gen_random_uuid(),
  organismo_id   uuid not null references organismos(id),
  fecha_analisis date not null,
  fuente         text not null,
  riesgo         text not null,
  nivel          text not null check (nivel in ('bajo','medio','alto')),
  tratamiento    text not null,
  responsable_id uuid references personas(id)
);

-- ─────────────────────────── Equipos (6.2) ───────────────────────────
create table equipos (
  id            uuid primary key default gen_random_uuid(),
  organismo_id  uuid not null references organismos(id),
  sede_id       uuid references sedes(id),
  codigo        text not null,
  nombre        text not null,
  marca         text,
  modelo        text,
  serie         text,
  rango_medicion text,
  estado        text not null default 'operativo' check (estado in ('operativo','fuera_de_servicio','dado_de_baja')),
  creado        timestamptz not null default now(),
  unique (organismo_id, codigo)
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
  soporte_ruta  text
);

-- ─────────────────────────── Formatos versionados ───────────────────────────
create table formatos (
  organismo_id uuid not null references organismos(id),
  codigo       text not null,         -- 'F-229-D'
  version      text not null,
  titulo       text not null,
  reglamento_id text not null references reglamentos(id),
  actividades  text[] not null default '{}',
  contenido    jsonb not null,        -- secciones e ítems de la lista de verificación
  vigente      boolean not null default false,
  aprobado_por uuid references personas(id),
  aprobado     date,
  primary key (organismo_id, codigo, version)
);
create unique index formatos_una_vigente on formatos(organismo_id, codigo) where vigente;

-- ─────────────────── Comercial: cotización y revisión de solicitud (7.1.5 – 7.1.6) ───────────────────
create table cotizaciones (
  id            uuid primary key default gen_random_uuid(),
  organismo_id  uuid not null references organismos(id),
  consecutivo   text not null,
  cliente_id    uuid not null references clientes(id),
  vendedor_id   uuid not null references personas(id),
  fecha         date not null default current_date,
  valida_hasta  date,
  items         jsonb not null default '[]',
  subtotal      numeric(14,2) not null default 0,
  iva           numeric(14,2) not null default 0,
  total         numeric(14,2) not null default 0,
  estado        text not null default 'borrador' check (estado in ('borrador','enviada','aprobada','rechazada','vencida')),
  aprobada_en   timestamptz,
  aprobada_por_cliente text,
  soporte_aprobacion_ruta text,
  unique (organismo_id, consecutivo)
);

create table ordenes_servicio (
  id              uuid primary key default gen_random_uuid(),
  organismo_id    uuid not null references organismos(id),
  consecutivo     text not null,
  cotizacion_id   uuid references cotizaciones(id),
  cliente_id      uuid not null references clientes(id),
  instalacion     text not null,
  direccion       text,
  municipio       text,
  actividad_codigo text not null references actividades(codigo),
  estado          estado_orden not null default 'aprobada',
  solicitud_revisada_por uuid references personas(id),
  solicitud_revisada_en  timestamptz,
  solicitud_observaciones text,
  inspector_id    uuid references personas(id),
  director_tecnico_id uuid references personas(id),
  asignada_por    uuid references personas(id),
  asignada_en     timestamptz,
  fecha_programada date,
  formato_codigo  text,
  formato_version text,
  creado          timestamptz not null default now(),
  unique (organismo_id, consecutivo),
  foreign key (organismo_id, formato_codigo, formato_version) references formatos(organismo_id, codigo, version)
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
  magnitud       text not null,
  valor          numeric not null,
  unidad         text not null,
  limite         text,
  equipo_id      uuid references equipos(id)
);

create table evidencias (
  id             uuid primary key default gen_random_uuid(),
  inspeccion_id  uuid not null references inspecciones(id),
  item_codigo    text,
  tipo           text not null,
  ruta           text not null,
  sha256         text not null,
  tomada         timestamptz not null,
  latitud        double precision,
  longitud       double precision
);

-- ───────────────────── Revisión, decisión y dictamen (7.4) ─────────────────────
create table dictamenes (
  id             uuid primary key default gen_random_uuid(),
  orden_id       uuid not null references ordenes_servicio(id),
  numero         text not null unique,
  version        int not null default 1,
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
  organismo_id   uuid not null references organismos(id),
  consecutivo    text not null,
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
  estado         text not null default 'abierta' check (estado in ('abierta','cerrada')),
  unique (organismo_id, consecutivo)
);

create table quejas_involucrados (
  queja_id   uuid not null references quejas_apelaciones(id),
  persona_id uuid not null references personas(id),
  primary key (queja_id, persona_id)
);

-- ─────────────────────────── Sistema de gestión (8.x) ───────────────────────────
create table documentos (
  id            uuid primary key default gen_random_uuid(),
  organismo_id  uuid not null references organismos(id),
  codigo        text not null,
  titulo        text not null,
  tipo          text not null check (tipo in ('manual','procedimiento','instructivo','formato','externo')),
  version       text not null,
  estado        text not null default 'borrador' check (estado in ('borrador','vigente','obsoleto')),
  elaborado_por uuid references personas(id),
  aprobado_por  uuid references personas(id),
  aprobado      date,
  ultima_revision date,
  archivo_ruta  text,
  unique (organismo_id, codigo, version)
);
create unique index documentos_uno_vigente on documentos(organismo_id, codigo) where estado = 'vigente';

create table auditorias_internas (
  id           uuid primary key default gen_random_uuid(),
  organismo_id uuid not null references organismos(id),
  fecha        date not null,
  auditor_id   uuid references personas(id),
  auditor_externo text,
  numerales    text[] not null,
  informe_ruta text
);

create table revisiones_direccion (
  id           uuid primary key default gen_random_uuid(),
  organismo_id uuid not null references organismos(id),
  fecha        date not null,
  acta_ruta    text,
  decisiones   text
);

create table acciones (
  id            uuid primary key default gen_random_uuid(),
  organismo_id  uuid not null references organismos(id),
  consecutivo   text not null,
  tipo          text not null check (tipo in ('correctiva','preventiva','mejora')),
  origen        text not null,
  descripcion   text not null,
  analisis_causa text,
  responsable_id uuid references personas(id),
  fecha_limite  date not null,
  estado        text not null default 'abierta' check (estado in ('abierta','implementada','cerrada')),
  eficacia_verificada boolean not null default false,
  eficacia_verificada_por uuid references personas(id),
  cerrada_en    date,
  unique (organismo_id, consecutivo)
);

create table subcontratistas (
  id               uuid primary key default gen_random_uuid(),
  organismo_id     uuid not null references organismos(id),
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
    raise exception 'No se permite eliminar registros de %; ciérrelos o anúlelos con justificación (17020 §8.4)', tg_table_name;
  end if;
  insert into bitacora(tabla, registro, operacion, usuario, antes, despues)
  values (tg_table_name, coalesce(to_jsonb(new)->>'id', ''), tg_op, uid,
          case when tg_op = 'UPDATE' then to_jsonb(old) end, to_jsonb(new));
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array[
    'organismos','sedes','alcance_acreditado','personas','certificados_competencia','formacion','experiencias',
    'vinculaciones','designaciones','revisiones_sg','supervisiones','declaraciones',
    'conflictos_interes','riesgos_imparcialidad','equipos','calibraciones','formatos',
    'cotizaciones','ordenes_servicio','inspecciones','resultados_item','mediciones',
    'evidencias','dictamenes','quejas_apelaciones','documentos','auditorias_internas',
    'revisiones_direccion','acciones','subcontratistas'
  ] loop
    execute format(
      'create trigger bitacora_%1$s before insert or update or delete on %1$I
         for each row execute function registrar_bitacora()', t);
  end loop;
end $$;

-- Las tablas de relación (actividades de certificados y designaciones) sí admiten
-- borrado, pero también quedan en bitácora.
create or replace function registrar_bitacora_relacion() returns trigger
language plpgsql security definer as $$
begin
  insert into bitacora(tabla, registro, operacion, antes, despues)
  values (tg_table_name, '', tg_op,
          case when tg_op <> 'INSERT' then to_jsonb(old) end,
          case when tg_op <> 'DELETE' then to_jsonb(new) end);
  return coalesce(new, old);
end $$;

create trigger bitacora_certificado_categorias after insert or delete on certificado_categorias
  for each row execute function registrar_bitacora_relacion();
create trigger bitacora_designacion_actividades after insert or delete on designacion_actividades
  for each row execute function registrar_bitacora_relacion();

-- ───────────────── Reglas 17020 aplicadas por la base de datos ─────────────────

-- Vigencia de un certificado: dentro de sus fechas, no anulado y con el seguimiento
-- del mes 30 (contado desde el día siguiente a la emisión) registrado y conforme.
create or replace function certificado_vigente(c certificados_competencia, p_fecha date)
returns boolean language sql stable as $$
  select not c.anulado
     and c.fecha_emision <= p_fecha and c.fecha_vencimiento >= p_fecha
     and coalesce(c.seguimiento_resultado, '') <> 'no_conforme'
     and (c.seguimiento_fecha is not null
          or p_fecha <= (c.fecha_emision + 1 + make_interval(months => (select r.seguimiento_mes from reglamentos r where r.id = c.reglamento_id)))::date)
$$;

-- La vigencia no puede exceder la del reglamento (5 años).
create or replace function validar_certificado() returns trigger
language plpgsql as $$
declare anios int;
begin
  select vigencia_certificado_anios into anios from reglamentos where id = new.reglamento_id;
  if new.fecha_vencimiento > (new.fecha_emision + make_interval(years => anios))::date - 1 then
    raise exception 'La vigencia del certificado no puede superar % años', anios;
  end if;
  return new;
end $$;

create trigger validar_certificado before insert or update of fecha_emision, fecha_vencimiento on certificados_competencia
  for each row execute function validar_certificado();

-- Años de experiencia verificada, uniendo periodos traslapados (no se cuentan dos veces).
create or replace function anios_experiencia(p_persona uuid, p_reglamento text, p_categoria text, p_tipos text[], p_fecha date)
returns numeric language sql stable as $$
  select coalesce(sum(upper(r) - lower(r)), 0) / 365.25
  from unnest((
    select range_agg(daterange(e.desde, least(coalesce(e.hasta, p_fecha), p_fecha), '[]'))
    from experiencias e
    where e.persona_id = p_persona and e.verificada and e.reglamento_id = p_reglamento
      and e.desde <= p_fecha
      and (p_categoria is null or p_categoria = any(e.categorias))
      and e.tipos && p_tipos
  )) as r
$$;

-- Requisitos de competencia de la persona para una actividad y rol.
-- Devuelve el primer requisito incumplido (texto) o null si cumple.
create or replace function motivo_competencia(p_persona uuid, p_actividad text, p_rol text, p_fecha date default current_date)
returns text language plpgsql stable as $$
declare
  a actividades; r reglamentos; k categorias_competencia; p personas;
  cat_exp text; anios numeric; dir numeric;
begin
  select * into a from actividades where codigo = p_actividad;
  select * into r from reglamentos where id = a.reglamento_id;
  select * into k from categorias_competencia where reglamento_id = a.reglamento_id and codigo = a.categoria;
  select * into p from personas where id = p_persona;

  if r.matricula_requerida and coalesce(p.matricula_numero, '') = '' then
    return 'Sin matrícula profesional registrada (Leyes 842 de 2003 y 51 de 1986)';
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

  cat_exp := case when r.experiencia_por_categoria then k.codigo end;
  anios := anios_experiencia(p_persona, r.id, cat_exp, r.tipos_experiencia_tecnica, p_fecha);
  if anios < k.experiencia_inspector_anios then
    return format('Experiencia verificada insuficiente: %s de %s años', round(anios, 1), k.experiencia_inspector_anios);
  end if;

  if p_rol = 'director_tecnico' then
    cat_exp := case when r.dt_por_categoria then k.codigo end;
    anios := anios_experiencia(p_persona, r.id, cat_exp, r.tipos_experiencia_tecnica || r.dt_tipos_direccion, p_fecha);
    dir := anios_experiencia(p_persona, r.id, cat_exp, r.dt_tipos_direccion, p_fecha);
    if (r.dt_total_estricta and anios <= r.dt_experiencia_total) or (not r.dt_total_estricta and anios < r.dt_experiencia_total) then
      return format('Experiencia de director técnico insuficiente: %s años (%s %s)', round(anios, 1),
                    case when r.dt_total_estricta then 'más de' else 'mínimo' end, r.dt_experiencia_total);
    end if;
    if dir < r.dt_experiencia_direccion then
      return format('Experiencia en gerencia/dirección insuficiente: %s de %s años', round(dir, 1), r.dt_experiencia_direccion);
    end if;
  end if;

  if r.exige_certificado and not exists (
    select 1 from certificados_competencia c join certificado_categorias cc on cc.certificado_id = c.id
    where c.persona_id = p_persona and cc.reglamento_id = r.id and cc.categoria = k.codigo and certificado_vigente(c, p_fecha)) then
    return format('Sin certificado de competencias vigente (con seguimiento) en la categoría %s', k.codigo);
  end if;
  return null;
end $$;

-- Verificación de soportes de hoja de vida: la registra otra persona (no autoverificación).
create or replace function validar_verificacion() returns trigger
language plpgsql as $$
begin
  if new.verificada and (tg_op = 'INSERT' or not old.verificada) then
    if new.verificada_por is null or new.verificada_por = new.persona_id then
      raise exception 'El soporte debe verificarlo otra persona del organismo (indique verificada_por)';
    end if;
  end if;
  return new;
end $$;

create trigger validar_verificacion before insert or update of verificada on experiencias
  for each row execute function validar_verificacion();
create trigger validar_verificacion before insert or update of verificada on formacion
  for each row execute function validar_verificacion();

-- ¿La persona puede ejercer la actividad en el organismo con el rol, en una fecha?
-- Requiere: línea acreditada, vinculación vigente y requisitos de competencia.
create or replace function puede_ejercer(p_org uuid, p_persona uuid, p_actividad text, p_fecha date default current_date, p_rol text default 'inspector')
returns text language plpgsql stable as $$
begin
  if not exists (select 1 from alcance_acreditado a
                 where a.organismo_id = p_org and a.actividad_codigo = p_actividad and a.estado = 'acreditada') then
    return 'La actividad ' || p_actividad || ' no está en el alcance acreditado vigente del organismo (17020 §5.1 / RAC-3.0-01)';
  end if;
  if not exists (select 1 from vinculaciones v
                 where v.organismo_id = p_org and v.persona_id = p_persona
                   and v.desde <= p_fecha and (v.hasta is null or v.hasta >= p_fecha)) then
    return 'La persona no tiene vinculación vigente con el organismo (17020 §6.1)';
  end if;
  return motivo_competencia(p_persona, p_actividad, p_rol, p_fecha);
end $$;

-- Las actividades se autorizan solo a directores técnicos e inspectores, y solo si puede_ejercer.
create or replace function validar_designacion_actividad() returns trigger
language plpgsql as $$
declare d designaciones; motivo text;
begin
  select * into d from designaciones where id = new.designacion_id;
  if d.rol not in ('director_tecnico', 'director_tecnico_suplente', 'inspector') then
    raise exception 'Solo los directores técnicos e inspectores tienen actividades autorizadas';
  end if;
  motivo := puede_ejercer(d.organismo_id, d.persona_id, new.actividad_codigo, greatest(d.desde, current_date),
                          case when d.rol = 'inspector' then 'inspector' else 'director_tecnico' end);
  if motivo is not null then raise exception '% (17020 §6.1)', motivo; end if;
  return new;
end $$;

create trigger validar_designacion_actividad before insert on designacion_actividades
  for each row execute function validar_designacion_actividad();

-- Toda designación exige vinculación vigente con el organismo.
create or replace function validar_designacion() returns trigger
language plpgsql as $$
begin
  if not exists (select 1 from vinculaciones v
                 where v.organismo_id = new.organismo_id and v.persona_id = new.persona_id
                   and v.desde <= new.desde and (v.hasta is null or v.hasta >= new.desde)) then
    raise exception 'La persona debe estar vinculada al organismo antes de designarla (17020 §5.2 / §6.1)';
  end if;
  return new;
end $$;

create trigger validar_designacion before insert on designaciones
  for each row execute function validar_designacion();

-- Asignación de una orden: solicitud revisada, inspector autorizado para la actividad
-- y sin conflicto de interés con el cliente (4.1, 6.1, 7.1).
create or replace function validar_asignacion() returns trigger
language plpgsql as $$
declare motivo text;
begin
  if new.inspector_id is null then return new; end if;
  if tg_op = 'UPDATE' and new.inspector_id is not distinct from old.inspector_id then return new; end if;

  if new.solicitud_revisada_en is null then
    raise exception 'La solicitud % no ha sido revisada (17020 §7.1.6)', new.consecutivo;
  end if;
  if not exists (
    select 1 from designaciones d join designacion_actividades da on da.designacion_id = d.id
    where d.organismo_id = new.organismo_id and d.persona_id = new.inspector_id and d.rol = 'inspector'
      and da.actividad_codigo = new.actividad_codigo
      and d.desde <= current_date and (d.hasta is null or d.hasta >= current_date)
  ) then
    raise exception 'El inspector no está autorizado para la actividad % en este organismo (17020 §6.1.6)', new.actividad_codigo;
  end if;
  motivo := puede_ejercer(new.organismo_id, new.inspector_id, new.actividad_codigo);
  if motivo is not null then raise exception '%', motivo; end if;
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

-- Dictamen: revisión por persona distinta al inspector (7.4).
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

-- ─────────────────── Vistas ───────────────────

-- Personal en el formato que ONAC solicita (NTE-3.3-88 / 3.3-89, numeral 4.1 ítem 2)
create view v_personal_onac as
select v.organismo_id, s.nombre as sede,
       p.nombres || ' ' || p.apellidos as nombre_completo,
       p.tipo_documento || ' ' || p.documento as documento,
       v.cargo, v.tipo || ' desde ' || to_char(v.desde, 'YYYY-MM-DD') as vinculacion,
       (select string_agg(c.numero || ' (' || c.reglamento_id || ' cat. ' ||
                 (select string_agg(cc.categoria, ',' order by cc.categoria) from certificado_categorias cc where cc.certificado_id = c.id)
                 || ', vence ' || c.fecha_vencimiento || ')', '; ')
          from certificados_competencia c
         where c.persona_id = p.id and certificado_vigente(c, current_date)) as certificados
from vinculaciones v
join personas p on p.id = v.persona_id
left join sedes s on s.id = v.sede_id
where v.hasta is null or v.hasta >= current_date;

create view v_equipos_estado as
select e.*,
  (select max(c.vence) from calibraciones c where c.equipo_id = e.id and c.tipo = 'calibracion' and c.conforme) as vence_calibracion,
  (select max(c.vence) from calibraciones c where c.equipo_id = e.id and c.tipo = 'verificacion_intermedia') as vence_verificacion
from equipos e;

-- >>>>>>>>>> supabase/migrations/0002_seguridad.sql
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
alter table categorias_competencia enable row level security;
create policy lectura on categorias_competencia for select to authenticated using (true);
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

alter table certificado_categorias enable row level security;
create policy lectura on certificado_categorias for select to authenticated using (true);
create policy gestion on certificado_categorias for all to authenticated using (
  exists (select 1 from organismos o where administra(o.id))) with check (true);

-- Hoja de vida: la persona ve la suya; quien administra un organismo la gestiona y verifica
do $$
declare t text;
begin
  foreach t in array array['experiencias'] loop
    execute format('alter table %I enable row level security', t);
    execute format($f$create policy propia on %I for all to authenticated
      using (persona_id = persona_actual() or exists (select 1 from organismos o where administra(o.id)))
      with check (persona_id = persona_actual() or exists (select 1 from organismos o where administra(o.id)))$f$, t);
  end loop;
end $$;

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

-- >>>>>>>>>> supabase/seed.sql
-- Generado por scripts/generar_seed.py — no editar a mano

-- retie_2024.json
insert into reglamentos (id, nombre, acto, fuente_alcances, fuente_requisitos, exige_certificado,
  vigencia_certificado_anios, seguimiento_mes, matricula_requerida, requiere_posgrado_iluminacion,
  experiencia_por_categoria, tipos_experiencia_tecnica, dt_experiencia_total, dt_total_estricta,
  dt_experiencia_direccion, dt_tipos_direccion, dt_por_categoria) values
  ('RETIE-2024', 'Reglamento Técnico de Instalaciones Eléctricas – RETIE 2024', 'Resolución MinEnergía 40117 del 2 de abril de 2024, modificada por la Resolución 40304 del 2 de julio de 2025', 'ONAC NTE-3.3-88 v01 (2025-07-23), Anexo 1 — columna ''Alcance RETIE 2024 NTE 3.3-84 (Derogada)''', 'Resolución 40117 de 2024, numerales 4.4.2.2 (categorías), 4.4.2.5 (prerrequisitos) y 4.4.2.6 (vigencia)', true, 5, 30, true, false, true, array['diseno', 'construccion', 'operacion', 'mantenimiento', 'inspeccion']::text[], 10, true, 2, array['gerencia_direccion']::text[], true)
on conflict (id) do nothing;

insert into categorias_competencia (reglamento_id, codigo, nombre, experiencia_inspector_anios, requiere_categoria_vigente) values
  ('RETIE-2024', 'a', 'Generación de energía eléctrica en tensión DC superior a 1.500 V y AC superior a 1.000 V', 3, null),
  ('RETIE-2024', 'b', 'Transmisión de energía eléctrica y subestaciones o transformación en tensión igual o superior a 57.500 V', 3, null),
  ('RETIE-2024', 'c', 'Redes de distribución y subestaciones o transformación en tensión inferior a 57.500 V', 3, 'g'),
  ('RETIE-2024', 'd', 'Uso final en instituciones de asistencia médica', 3, 'g'),
  ('RETIE-2024', 'e', 'Uso final en sitios clasificados como peligrosos, minas, minas subterráneas, túneles y cavernas', 3, 'g'),
  ('RETIE-2024', 'f', 'Uso final para equipos especiales e instalaciones de uso final especiales', 3, 'g'),
  ('RETIE-2024', 'g', 'Uso final distintas a d, e, f, con autogeneración a pequeña escala (DC < 1.500 V, AC < 1.000 V), redes de distribución y subestaciones asociadas (< 57.500 V)', 2, null)
on conflict do nothing;

insert into actividades (codigo, reglamento_id, grupo, nombre, referencias, categoria, area_profundizacion) values
  ('RETIE24-GEN-CENTRAL', 'RETIE-2024', 'Generación', 'Inspección de instalaciones eléctricas de centrales de generación', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 2 – Requisitos para el proceso de generación', 'Título 18 – Requisitos generales para centrales de generación', '3.18.1 Edificaciones de centrales de generación']::text[], 'a', null),
  ('RETIE24-GEN-FNCE', 'RETIE-2024', 'Generación', 'Inspección de instalaciones eléctricas de generación con fuentes no convencionales de energía, autogeneradores a pequeña escala – AGPE y generación distribuida – GD', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 2 – Requisitos para el proceso de generación', 'Título 18 – Requisitos generales para centrales de generación', '3.18.2 Requisitos generales para instalaciones de generación con FNCE, AGPE y GD']::text[], 'a', null),
  ('RETIE24-GEN-VARIAS', 'RETIE-2024', 'Generación', 'Inspección de instalaciones de generación de energía eléctrica con varias fuentes', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 2 – Requisitos para el proceso de generación', 'Título 18 – Requisitos generales para centrales de generación', '3.18.3 Instalaciones de generación de energía eléctrica con varias fuentes']::text[], 'a', null),
  ('RETIE24-TRANS-LINEAS', 'RETIE-2024', 'Transmisión', 'Inspección de instalaciones eléctricas de líneas de transmisión', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 3 – Requisitos para las líneas de transmisión', 'Título 19 – Requisitos generales de las líneas de transmisión']::text[], 'b', null),
  ('RETIE24-SUB-AT', 'RETIE-2024', 'Transformación', 'Inspección de instalaciones eléctricas de transformación (subestación) de alta y extra alta tensión', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 5 – Requisitos para instalaciones de transformación (subestaciones)', 'Título 22 – Requisitos generales de subestaciones', 'Título 23 – Requisitos específicos según tipo de subestación', '3.23.1 Subestaciones de alta y extra alta tensión']::text[], 'b', null),
  ('RETIE24-SUB-MT', 'RETIE-2024', 'Transformación', 'Inspección de instalaciones eléctricas de transformación (subestación) en media tensión', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 5 – Requisitos para instalaciones de transformación (subestaciones)', 'Título 22 – Requisitos generales de subestaciones', 'Título 23 – Requisitos específicos según tipo de subestación', '3.23.2 Subestaciones de media tensión tipo interior o en edificaciones', '3.23.3 Subestaciones tipo poste', '3.23.4 Subestaciones tipo pedestal o tipo jardín', '3.23.5 Cuartos de subestación paquetizados o prefabricados', '3.23.6 Mantenimiento de subestaciones']::text[], 'c', null),
  ('RETIE24-UF-SUB-MT', 'RETIE-2024', 'Uso final', 'Inspección de instalaciones eléctricas de uso final. Transformación (subestación) en media tensión', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 24 – Aplicación de normas técnicas', 'Título 25 – Régimen de conexión a tierra – RCT', 'Título 26 – Acometidas', 'Título 27 – Protección de las instalaciones de uso final']::text[], 'g', null),
  ('RETIE24-DIST-REDES', 'RETIE-2024', 'Distribución', 'Inspección de instalaciones eléctricas de redes de distribución', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 4 – Requisitos para las redes de distribución', 'Título 20 – Requisitos generales de redes de distribución']::text[], 'c', null),
  ('RETIE24-UF-DIST', 'RETIE-2024', 'Uso final', 'Inspección de instalaciones eléctricas de uso final. Redes de distribución', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 24 – Aplicación de normas técnicas', 'Título 25 – Régimen de conexión a tierra – RCT', 'Título 26 – Acometidas', 'Título 27 – Protección de las instalaciones de uso final', 'Capítulo 4 – Requisitos para las redes de distribución', 'Título 20 – Requisitos generales de redes de distribución']::text[], 'g', null),
  ('RETIE24-UF-MEDICA', 'RETIE-2024', 'Uso final especial', 'Instalaciones eléctricas de uso final en instituciones de asistencia médica', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 27 – Protección de las instalaciones de uso final', 'Título 28 – Clasificación de las instalaciones de uso final y requisitos específicos según el tipo de instalación', '3.28.3 Instalaciones especiales', '3.28.3.2 Instituciones de asistencia médica']::text[], 'd', null),
  ('RETIE24-UF-PELIG-I', 'RETIE-2024', 'Uso final especial', 'Instalaciones eléctricas de uso final en sitios clasificados como peligrosos, para clase I divisiones 1 y 2', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 27 – Protección de las instalaciones de uso final', 'Título 28 – Clasificación de las instalaciones de uso final y requisitos específicos según el tipo de instalación', '3.28.3 Instalaciones especiales', '3.28.3.1 Instalaciones eléctricas en lugares clasificados como peligrosos']::text[], 'e', null),
  ('RETIE24-UF-PELIG-II', 'RETIE-2024', 'Uso final especial', 'Instalaciones eléctricas de uso final en sitios clasificados como peligrosos, para clase II divisiones 1 y 2', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 27 – Protección de las instalaciones de uso final', 'Título 28 – Clasificación de las instalaciones de uso final y requisitos específicos según el tipo de instalación', '3.28.3 Instalaciones especiales', '3.28.3.1 Instalaciones eléctricas en lugares clasificados como peligrosos']::text[], 'e', null),
  ('RETIE24-UF-PELIG-III', 'RETIE-2024', 'Uso final especial', 'Instalaciones eléctricas de uso final en sitios clasificados como peligrosos, para clase III divisiones 1 y 2', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 27 – Protección de las instalaciones de uso final', 'Título 28 – Clasificación de las instalaciones de uso final y requisitos específicos según el tipo de instalación', '3.28.3 Instalaciones especiales', '3.28.3.1 Instalaciones eléctricas en lugares clasificados como peligrosos']::text[], 'e', null),
  ('RETIE24-UF-TUNELES', 'RETIE-2024', 'Uso final especial', 'Inspección de instalaciones eléctricas de uso final: túneles y cavernas subterráneas', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 27 – Protección de las instalaciones de uso final', 'Título 28 – Clasificación de las instalaciones de uso final y requisitos específicos según el tipo de instalación', '3.28.5 Túneles y cavernas subterráneas']::text[], 'e', null),
  ('RETIE24-UF-MINAS', 'RETIE-2024', 'Uso final especial', 'Inspección de instalaciones eléctricas de uso final: minas y minas subterráneas', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 27 – Protección de las instalaciones de uso final', 'Título 28 – Clasificación de las instalaciones de uso final y requisitos específicos según el tipo de instalación', '3.28.6 Instalaciones eléctricas en minas']::text[], 'e', null),
  ('RETIE24-EQ-ASCENSORES', 'RETIE-2024', 'Equipos especiales', 'Inspección de instalaciones eléctricas de uso final para equipos especiales: ascensores, escaleras y andenes móviles electromecánicos y rampas para el transporte de personas', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 27 – Protección de las instalaciones de uso final', 'Título 28 – Clasificación de las instalaciones de uso final y requisitos específicos según el tipo de instalación', '3.28.4 Instalación de equipos especiales', '3.28.4.2 Ascensores, escaleras y andenes móviles electromecánicos y rampas para el transporte de personas']::text[], 'f', null),
  ('RETIE24-EQ-GRUAS', 'RETIE-2024', 'Equipos especiales', 'Inspección de instalaciones eléctricas de uso final para equipos especiales: grúas colgantes y elevadores de carga', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 27 – Protección de las instalaciones de uso final', 'Título 28 – Clasificación de las instalaciones de uso final y requisitos específicos según el tipo de instalación', '3.28.4 Instalación de equipos especiales', '3.28.4.1 Grúas colgantes y elevadores de carga']::text[], 'f', null),
  ('RETIE24-EQ-RAYOSX', 'RETIE-2024', 'Equipos especiales', 'Inspección de instalaciones eléctricas de uso final para equipos especiales: equipos de rayos X', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 27 – Protección de las instalaciones de uso final', 'Título 28 – Clasificación de las instalaciones de uso final y requisitos específicos según el tipo de instalación', '3.28.4 Instalación de equipos especiales', '3.28.4.3 Equipos de rayos X']::text[], 'f', null),
  ('RETIE24-EQ-CELDAS', 'RETIE-2024', 'Equipos especiales', 'Inspección de instalaciones eléctricas de uso final para equipos especiales: celdas electrolíticas', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 27 – Protección de las instalaciones de uso final', 'Título 28 – Clasificación de las instalaciones de uso final y requisitos específicos según el tipo de instalación', '3.28.4 Instalación de equipos especiales', '3.28.4.4 Celdas electrolíticas']::text[], 'f', null),
  ('RETIE24-EQ-GALVANO', 'RETIE-2024', 'Equipos especiales', 'Inspección de instalaciones eléctricas de uso final para equipos especiales: equipos de galvanoplastia', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 27 – Protección de las instalaciones de uso final', 'Título 28 – Clasificación de las instalaciones de uso final y requisitos específicos según el tipo de instalación', '3.28.4 Instalación de equipos especiales', '3.28.4.5 Equipos de galvanoplastia']::text[], 'f', null),
  ('RETIE24-EQ-BOMBAS', 'RETIE-2024', 'Equipos especiales', 'Inspección de instalaciones eléctricas de uso final para equipos especiales: bombas contra incendio', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 27 – Protección de las instalaciones de uso final', 'Título 28 – Clasificación de las instalaciones de uso final y requisitos específicos según el tipo de instalación', '3.28.4 Instalación de equipos especiales', '3.28.4.7 Bombas contra incendio']::text[], 'f', null),
  ('RETIE24-EQ-EMERGENCIA', 'RETIE-2024', 'Equipos especiales', 'Inspección de instalaciones eléctricas de uso final para equipos especiales: sistemas de emergencia', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 27 – Protección de las instalaciones de uso final', 'Título 28 – Clasificación de las instalaciones de uso final y requisitos específicos según el tipo de instalación', '3.28.4 Instalación de equipos especiales', '3.28.4.8 Sistemas de emergencia']::text[], 'f', null),
  ('RETIE24-EQ-PISCINAS', 'RETIE-2024', 'Equipos especiales', 'Inspección de instalaciones eléctricas de uso final para equipos especiales: piscinas, fuentes y similares', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 27 – Protección de las instalaciones de uso final', 'Título 28 – Clasificación de las instalaciones de uso final y requisitos específicos según el tipo de instalación', '3.28.4 Instalación de equipos especiales', '3.28.4.6 Piscinas, fuentes e instalaciones similares']::text[], 'f', null),
  ('RETIE24-UF-CONCENTRACION', 'RETIE-2024', 'Uso final especial', 'Inspección de instalaciones eléctricas de uso final especiales: alta concentración de personas y sitios de reuniones públicas', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 27 – Protección de las instalaciones de uso final', 'Título 28 – Clasificación de las instalaciones de uso final y requisitos específicos según el tipo de instalación', '3.28.3 Instalaciones especiales', '3.28.3.3 Instalaciones en sitios con alta concentración de personas y sitios de reuniones públicas']::text[], 'f', null),
  ('RETIE24-UF-AGRICOLA', 'RETIE-2024', 'Uso final especial', 'Inspección de instalaciones eléctricas de uso final especiales: edificios para usos agrícolas o pecuarios', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 27 – Protección de las instalaciones de uso final', 'Título 28 – Clasificación de las instalaciones de uso final y requisitos específicos según el tipo de instalación', '3.28.3 Instalaciones especiales', '3.28.3.4 Edificios para usos agrícolas o pecuarios']::text[], 'f', null),
  ('RETIE24-UF-MOVILES', 'RETIE-2024', 'Uso final especial', 'Inspección de instalaciones eléctricas de uso final especiales: viviendas móviles, vehículos recreativos, remolques estacionados', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 27 – Protección de las instalaciones de uso final', 'Título 28 – Clasificación de las instalaciones de uso final y requisitos específicos según el tipo de instalación', '3.28.3 Instalaciones especiales', '3.28.3.6 Viviendas móviles, vehículos recreativos, remolques estacionados']::text[], 'f', null),
  ('RETIE24-UF-FLOTANTES', 'RETIE-2024', 'Uso final especial', 'Inspección de instalaciones eléctricas de uso final especiales: casas flotantes y palafíticas', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 27 – Protección de las instalaciones de uso final', 'Título 28 – Clasificación de las instalaciones de uso final y requisitos específicos según el tipo de instalación', '3.28.3 Instalaciones especiales', '3.28.3.5 Casas flotantes y palafíticas']::text[], 'f', null),
  ('RETIE24-UF-BASICAS', 'RETIE-2024', 'Uso final', 'Inspección de instalaciones eléctricas de uso final. Instalaciones básicas', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 24 – Aplicación de normas técnicas', 'Título 25 – Régimen de conexión a tierra – RCT', 'Título 26 – Acometidas', 'Título 27 – Protección de las instalaciones de uso final', 'Título 28 – Clasificación de las instalaciones de uso final', '3.28.1 Instalaciones básicas']::text[], 'g', null),
  ('RETIE24-UF-AUTOGEN', 'RETIE-2024', 'Uso final', 'Inspección de instalaciones eléctricas de uso final. Autogeneración de energía', array['Libro 3, Título 1 – Campo de aplicación', 'Capítulo 1 – Requerimientos generales de las instalaciones eléctricas', 'Capítulo 6 – Requisitos para instalaciones de uso final', 'Título 24 – Aplicación de normas técnicas', 'Título 25 – Régimen de conexión a tierra – RCT', 'Título 26 – Acometidas', 'Título 27 – Protección de las instalaciones de uso final', 'Capítulo 2 – Requisitos para el proceso de generación', '3.18.2 Generación con FNCE, AGPE y GD', '3.18.3 Generación con varias fuentes']::text[], 'g', null)
on conflict (codigo) do nothing;

-- retilap_2024.json
insert into reglamentos (id, nombre, acto, fuente_alcances, fuente_requisitos, exige_certificado,
  vigencia_certificado_anios, seguimiento_mes, matricula_requerida, requiere_posgrado_iluminacion,
  experiencia_por_categoria, tipos_experiencia_tecnica, dt_experiencia_total, dt_total_estricta,
  dt_experiencia_direccion, dt_tipos_direccion, dt_por_categoria) values
  ('RETILAP-2024', 'Reglamento Técnico de Iluminación y Alumbrado Público – RETILAP 2024', 'Resolución MinEnergía 40150 del 3 de mayo de 2024, modificada por la Resolución 40318 del 9 de julio de 2025', 'ONAC NTE-3.3-89 v01 (2025-08-12), tabla ''Alcance RETILAP 2024''', 'Resolución 40150 de 2024, numerales 4.5.2.x (categorías), 4.5.2.5 (prerrequisitos) y 4.5.2.6 (vigencia)', false, 5, 30, true, true, false, array['diseno', 'construccion', 'operacion', 'mantenimiento', 'interventoria', 'inspeccion', 'direccion_tecnica_oi']::text[], 7, false, 1, array['coordinacion_proyectos', 'gerencia_direccion']::text[], false)
on conflict (id) do nothing;

insert into categorias_competencia (reglamento_id, codigo, nombre, experiencia_inspector_anios, requiere_categoria_vigente) values
  ('RETILAP-2024', '1', 'Instalaciones de sistemas de iluminación interior', 3, null),
  ('RETILAP-2024', '2', 'Iluminación exterior y escenarios deportivos (incluye profesionales con transmisión de TV)', 3, null),
  ('RETILAP-2024', '3', 'Alumbrado público y sistemas de telegestión', 3, null),
  ('RETILAP-2024', '4', 'Iluminación en túneles', 3, null),
  ('RETILAP-2024', '5', 'Áreas clasificadas y especiales, aeropuertos y helipuertos, hospitales o centros de atención médica', 3, null)
on conflict do nothing;

insert into actividades (codigo, reglamento_id, grupo, nombre, referencias, categoria, area_profundizacion) values
  ('RETILAP24-EXTERIOR', 'RETILAP-2024', 'Iluminación exterior', 'Inspección de instalaciones de sistemas de iluminación exterior y escenarios deportivos (incluyendo los escenarios profesionales con sistemas de transmisión de televisión)', array['Libro 1, Título 1 – Objeto y ámbito de aplicación (Art. 1.1.1)', 'Libro 3, Título 1 – Requisitos generales para la realización de proyectos de iluminación', 'Título 4 – Instalaciones de proyectos de iluminación exterior (Art. 3.4.1 a 3.4.5)', 'Libro 4, Título 3 – Demostración de conformidad de instalaciones: Art. 4.3.1, 4.3.2, 4.3.3, 4.3.4, 4.3.5, 4.3.8', 'Art. 4.3.17 Mediciones fotométricas en escenarios deportivos']::text[], '2', 'deportivos_profesionales'),
  ('RETILAP24-ALUMBRADO', 'RETILAP-2024', 'Alumbrado público', 'Inspección de instalaciones de sistemas de iluminación de alumbrado público y sistemas de telegestión', array['Libro 1, Título 1 – Objeto y ámbito de aplicación (Art. 1.1.1)', 'Libro 3, Título 1 – Requisitos generales para la realización de proyectos de iluminación', 'Título 3 – Instalaciones de proyectos de alumbrado público', 'Título 7 – Sistemas de telegestión', 'Libro 4, Título 3 – Demostración de conformidad de instalaciones: Art. 4.3.1, 4.3.2, 4.3.3, 4.3.4, 4.3.5, 4.3.8', 'Art. 4.3.10 a 4.3.14 Mediciones fotométricas en alumbrado público']::text[], '3', null),
  ('RETILAP24-TUNELES', 'RETILAP-2024', 'Iluminación exterior', 'Inspección de instalaciones de sistemas de iluminación en túneles', array['Libro 1, Título 1 – Objeto y ámbito de aplicación (Art. 1.1.1)', 'Libro 3, Título 1 – Requisitos generales para la realización de proyectos de iluminación', 'Título 5 – Instalaciones de proyectos de iluminación en túneles', 'Libro 4, Título 3 – Demostración de conformidad de instalaciones: Art. 4.3.1, 4.3.2, 4.3.3, 4.3.4, 4.3.5, 4.3.8', 'Art. 4.3.9 Mediciones fotométricas en iluminación interior']::text[], '4', 'tuneles'),
  ('RETILAP24-AEROPUERTOS', 'RETILAP-2024', 'Iluminación exterior', 'Inspección de instalaciones de iluminación en plataformas, calles de rodaje y pistas de aeropuertos y helipuertos', array['Libro 1, Título 1 – Objeto y ámbito de aplicación (Art. 1.1.1)', 'Libro 3, Título 1 – Requisitos generales para la realización de proyectos de iluminación', 'Título 2 – Iluminación interior', 'Título 4 – Iluminación exterior (Art. 3.4.6 aeródromos, aeropuertos y helipuertos)', 'Libro 4, Título 3 – Demostración de conformidad de instalaciones: Art. 4.3.1, 4.3.2, 4.3.3, 4.3.4, 4.3.5, 4.3.8', 'Art. 4.3.9']::text[], '5', 'aeropuertos'),
  ('RETILAP24-CLASIFICADAS', 'RETILAP-2024', 'Iluminación especial', 'Inspección de instalaciones de sistemas de iluminación en áreas clasificadas y especiales', array['Libro 1, Título 1 – Objeto y ámbito de aplicación (Art. 1.1.1)', 'Libro 3, Título 1 – Requisitos generales para la realización de proyectos de iluminación', 'Título 2 – Iluminación interior', 'Título 4 – Iluminación exterior', 'Título 6 – Instalaciones de iluminación de áreas clasificadas y especiales', 'Libro 4, Título 3 – Demostración de conformidad de instalaciones: Art. 4.3.1, 4.3.2, 4.3.3, 4.3.4, 4.3.5, 4.3.8', 'Art. 4.3.9']::text[], '5', 'clasificadas_especiales'),
  ('RETILAP24-HOSPITALES', 'RETILAP-2024', 'Iluminación interior', 'Inspección de instalaciones de iluminación en hospitales o centros de atención médica', array['Libro 1, Título 1 – Objeto y ámbito de aplicación (Art. 1.1.1)', 'Libro 3, Título 1 – Requisitos generales para la realización de proyectos de iluminación', 'Título 2 – Iluminación interior (3.2.2.5 instituciones de asistencia médica)', 'Título 4 – Iluminación exterior', 'Libro 4, Título 3 – Demostración de conformidad de instalaciones: Art. 4.3.1, 4.3.2, 4.3.3, 4.3.4, 4.3.5, 4.3.8', 'Art. 4.3.9']::text[], '5', 'hospitales'),
  ('RETILAP24-INTERIOR', 'RETILAP-2024', 'Iluminación interior', 'Inspección de instalaciones de sistemas de iluminación interior', array['Libro 1, Título 1 – Objeto y ámbito de aplicación (Art. 1.1.1)', 'Libro 3, Título 1 – Requisitos generales para la realización de proyectos de iluminación', 'Título 2 – Instalaciones de sistemas de iluminación interior', 'Libro 4, Título 3 – Demostración de conformidad de instalaciones: Art. 4.3.1, 4.3.2, 4.3.3, 4.3.4, 4.3.5, 4.3.8', 'Art. 4.3.9 Mediciones fotométricas en iluminación interior']::text[], '1', null)
on conflict (codigo) do nothing;

insert into reglamentos (id, nombre) values ('RETIE-2026', 'Reglamento Técnico de Instalaciones Eléctricas – RETIE 2026')
on conflict (id) do nothing;

select 'Instalación terminada: ' || (select count(*) from actividades) || ' actividades, ' || (select count(*) from categorias_competencia) || ' categorías' as resultado;


-- >>>>>>>>>> supabase/migrations/0003_autenticacion.sql
-- ============================================================================
-- Delta RETIE — 0003 Autenticación y arranque inicial
--
-- * Administradores de la plataforma: los únicos que pueden crear organismos.
-- * Cada usuario de Supabase Auth queda enlazado a su persona (cédula) por el
--   correo: al registrarse, o cuando se registra la persona con ese correo.
--   El enlace no se puede cambiar desde la aplicación (evita suplantación).
-- * Arranque: quien crea un organismo lo administra mientras no haya nadie
--   designado vigente en gerencia, SG o dirección técnica. En ese periodo solo
--   puede vincularse y designarse a sí mismo; desde ese momento rigen los roles.
-- * La verificación de soportes de la hoja de vida queda a nombre de quien
--   inició sesión (no se puede verificar a nombre de otro ni autoverificar).
-- * Las vistas respetan la seguridad por filas de quien consulta.
--
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

-- ─────────────────── Administradores de la plataforma ───────────────────
create table if not exists administradores_plataforma (
  correo text primary key check (correo = lower(trim(correo)))
);
insert into administradores_plataforma (correo) values ('directortecnico.gceisas@gmail.com')
on conflict (correo) do nothing;
alter table administradores_plataforma enable row level security;
-- Sin políticas: solo se consulta por medio de las funciones siguientes.

create or replace function correo_actual() returns text
language sql stable security definer set search_path = public, auth as $$
  select lower(trim(email)) from auth.users where id = auth.uid()
$$;

create or replace function es_admin_plataforma() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from administradores_plataforma a where a.correo = correo_actual())
$$;

-- La aplicación lo consulta para mostrar u ocultar "Nuevo organismo".
create or replace function soy_admin_plataforma() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(es_admin_plataforma(), false)
$$;

-- ─────────────────── Quién creó cada registro ───────────────────
alter table organismos add column if not exists creado_por uuid;
alter table personas   add column if not exists creado_por uuid;

create or replace function asignar_creador() returns trigger
language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    new.creado_por := auth.uid();
  else
    new.creado_por := old.creado_por;   -- no se puede reescribir
  end if;
  return new;
end $$;

drop trigger if exists asignar_creador on organismos;
create trigger asignar_creador before insert or update on organismos
  for each row execute function asignar_creador();
drop trigger if exists asignar_creador on personas;
create trigger asignar_creador before insert or update on personas
  for each row execute function asignar_creador();

-- ─────────────────── Enlace usuario ↔ persona por correo ───────────────────

-- Al registrarse un usuario: si su correo coincide con una persona sin usuario, se enlaza.
create or replace function enlazar_persona_nuevo_usuario() returns trigger
language plpgsql security definer set search_path = public, auth as $$
begin
  if new.email is null or exists (select 1 from public.personas where usuario_id = new.id) then
    return new;
  end if;
  perform set_config('delta.enlace_automatico', 'on', true);
  update public.personas set usuario_id = new.id
   where id = (select p.id from public.personas p
                where p.usuario_id is null and lower(trim(p.correo)) = lower(trim(new.email))
                order by p.creado limit 1);
  perform set_config('delta.enlace_automatico', '', true);
  return new;
end $$;

drop trigger if exists enlazar_persona on auth.users;
create trigger enlazar_persona after insert or update of email on auth.users
  for each row execute function enlazar_persona_nuevo_usuario();

-- Al registrar (o corregir el correo de) una persona: si ya existe un usuario con
-- ese correo y aún no tiene persona, se enlaza. El enlace no se edita a mano.
create or replace function enlazar_usuario_persona() returns trigger
language plpgsql security definer set search_path = public, auth as $$
begin
  if auth.uid() is not null and coalesce(current_setting('delta.enlace_automatico', true), '') <> 'on' then
    if tg_op = 'INSERT' and new.usuario_id is not null then
      raise exception 'El usuario de acceso se enlaza automáticamente por el correo de la persona; no se puede asignar a mano';
    end if;
    if tg_op = 'UPDATE' and new.usuario_id is distinct from old.usuario_id then
      raise exception 'El usuario de acceso se enlaza automáticamente por el correo de la persona; no se puede cambiar a mano';
    end if;
  end if;
  if new.usuario_id is null and coalesce(trim(new.correo), '') <> '' then
    select u.id into new.usuario_id from auth.users u
     where lower(trim(u.email)) = lower(trim(new.correo))
       and not exists (select 1 from public.personas p where p.usuario_id = u.id and p.id <> new.id)
     limit 1;
  end if;
  return new;
end $$;

-- (Nombre elegido para que corra antes del disparador de bitácora y esta registre el enlace.)
drop trigger if exists asignar_usuario on personas;
create trigger asignar_usuario before insert or update on personas
  for each row execute function enlazar_usuario_persona();

-- Enlaza a los usuarios que ya existían antes de esta migración.
update personas p set usuario_id = u.id
  from auth.users u
 where p.usuario_id is null and lower(trim(p.correo)) = lower(trim(u.email))
   and not exists (select 1 from personas x where x.usuario_id = u.id);

-- ─────────────────── Arranque del organismo ───────────────────
-- Roles que administran el organismo (deben coincidir con administra()).
create or replace function roles_administracion() returns rol_oec[]
language sql immutable as $$
  select array['representante_legal','gerente','responsable_sg','suplente_sg',
               'director_tecnico','director_tecnico_suplente']::rol_oec[]
$$;

-- El organismo está "en arranque" para quien lo creó (administrador de la plataforma)
-- mientras nadie tenga una designación vigente de administración.
create or replace function en_arranque(org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null
     and exists (select 1 from organismos o where o.id = org and o.creado_por = auth.uid())
     and es_admin_plataforma()
     and not exists (select 1 from designaciones d
                      where d.organismo_id = org and d.rol = any(roles_administracion())
                        and d.desde <= current_date and (d.hasta is null or d.hasta >= current_date))
$$;

create or replace function mis_organismos() returns setof uuid
language sql stable security definer set search_path = public as $$
  select v.organismo_id from vinculaciones v
  where v.persona_id = persona_actual() and v.desde <= current_date and (v.hasta is null or v.hasta >= current_date)
  union
  select o.id from organismos o where o.creado_por = auth.uid() and en_arranque(o.id)
$$;

create or replace function administra(org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select tiene_rol(org, roles_administracion()) or en_arranque(org)
$$;

-- En arranque, quien creó el organismo solo puede vincularse y designarse a sí mismo.
create or replace function validar_arranque() returns trigger
language plpgsql as $$
begin
  if en_arranque(new.organismo_id) and new.persona_id is distinct from persona_actual() then
    if persona_actual() is null then
      raise exception 'Primero regístrese usted mismo como persona (con su correo %) y desígnese en el organismo', correo_actual();
    end if;
    raise exception 'El organismo está en arranque: primero vincúlese y desígnese usted mismo en gerencia, sistema de gestión o dirección técnica; después podrá designar a las demás personas';
  end if;
  return new;
end $$;

drop trigger if exists validar_arranque on vinculaciones;
create trigger validar_arranque before insert on vinculaciones
  for each row execute function validar_arranque();
drop trigger if exists validar_arranque on designaciones;
create trigger validar_arranque before insert on designaciones
  for each row execute function validar_arranque();

-- ─────────────────── Políticas ───────────────────
-- Organismos: los crea el administrador de la plataforma.
drop policy if exists creacion_admin_plataforma on organismos;
create policy creacion_admin_plataforma on organismos for insert to authenticated
  with check (es_admin_plataforma());

drop policy if exists gestion_arranque on organismos;
create policy gestion_arranque on organismos for update to authenticated
  using (en_arranque(id)) with check (true);

-- Personas que uno registró (aún sin vincular) siguen visibles para quien las registró.
create or replace function persona_visible(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p = persona_actual()
      or exists (select 1 from personas x where x.id = p and x.creado_por = auth.uid())
      or exists (select 1 from vinculaciones v where v.persona_id = p and v.organismo_id in (select mis_organismos()))
$$;

drop policy if exists lectura_registradas on personas;
create policy lectura_registradas on personas for select to authenticated using (creado_por = auth.uid());

drop policy if exists lectura_registradas on certificados_competencia;
create policy lectura_registradas on certificados_competencia for select to authenticated using (persona_visible(persona_id));

-- La persona puede registrarse a sí misma (su correo debe ser el de su usuario).
-- (La política "gestion" de 0002 ya permite insertar personas; esta regla se impone
--  con el disparador enlazar_usuario.)

-- ─────────────────── Verificación de soportes ───────────────────
-- La verificación queda a nombre de quien inició sesión y nunca de la misma persona.
create or replace function validar_verificacion() returns trigger
language plpgsql as $$
begin
  if new.verificada and (tg_op = 'INSERT' or not old.verificada) then
    if auth.uid() is not null then
      if persona_actual() is null then
        raise exception 'Para verificar soportes, su usuario (%) debe estar registrado como persona', correo_actual();
      end if;
      if new.verificada_por is distinct from persona_actual() then
        raise exception 'La verificación queda a nombre de quien inició sesión';
      end if;
    end if;
    if new.verificada_por is null or new.verificada_por = new.persona_id then
      raise exception 'El soporte debe verificarlo otra persona del organismo (no se permite la autoverificación)';
    end if;
  end if;
  if not new.verificada then
    new.verificada_por := null;
  end if;
  return new;
end $$;

-- ─────────────────── Bitácora con el usuario real ───────────────────
create or replace function registrar_bitacora() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'No se permite eliminar registros de %; ciérrelos o anúlelos con justificación (17020 §8.4)', tg_table_name;
  end if;
  insert into bitacora(tabla, registro, operacion, usuario, antes, despues)
  values (tg_table_name, coalesce(to_jsonb(new)->>'id', ''), tg_op, auth.uid(),
          case when tg_op = 'UPDATE' then to_jsonb(old) end, to_jsonb(new));
  return new;
end $$;

create or replace function registrar_bitacora_relacion() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into bitacora(tabla, registro, operacion, usuario, antes, despues)
  values (tg_table_name, '', tg_op, auth.uid(),
          case when tg_op <> 'INSERT' then to_jsonb(old) end,
          case when tg_op <> 'DELETE' then to_jsonb(new) end);
  return coalesce(new, old);
end $$;

-- ─────────────────── Vistas con la seguridad de quien consulta ───────────────────
alter view v_personal_onac set (security_invoker = true);
alter view v_equipos_estado set (security_invoker = true);

select 'Migración 0003 aplicada. Administradores de la plataforma: '
       || (select string_agg(correo, ', ') from administradores_plataforma) as resultado;


-- >>>>>>>>>> supabase/migrations/0004_logos.sql
-- ============================================================================
-- Delta RETIE — 0004 Logos del organismo
--
-- * Logo del organismo: aparece arriba del panel y en los documentos.
-- * Símbolo de acreditado ONAC: solo en la entrega de resultados (informe de no
--   conformidades y dictamen).
-- Las imágenes se guardan en el almacenamiento de Supabase (carpeta "logos"), una
-- subcarpeta por organismo. Las ve cualquiera que tenga el enlace (son logos, no
-- datos reservados); las carga quien puede modificar los datos del organismo:
-- representante legal, gerente, responsable del SG (0002) o su creador en el arranque (0003).
-- Nada se borra: cada carga es un archivo nuevo y el organismo apunta al vigente.
--
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

alter table organismos add column if not exists logo_ruta text;
alter table organismos add column if not exists simbolo_onac_ruta text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('logos', 'logos', true, 2097152, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- ¿El usuario puede modificar el organismo de la carpeta? (logos/<organismo>/archivo)
create or replace function gestiona_carpeta_organismo(nombre text) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare org uuid;
begin
  begin
    org := ((storage.foldername(nombre))[1])::uuid;
  exception when others then
    return false;
  end;
  return tiene_rol(org, array['representante_legal','gerente','responsable_sg']::rol_oec[]) or en_arranque(org);
end $$;

drop policy if exists logos_carga on storage.objects;
create policy logos_carga on storage.objects for insert to authenticated
  with check (bucket_id = 'logos' and gestiona_carpeta_organismo(name));

-- La ruta guardada en el organismo debe ser de su propia carpeta.
create or replace function validar_rutas_logo() returns trigger
language plpgsql as $$
begin
  if new.logo_ruta is not null and new.logo_ruta not like new.id::text || '/%' then
    raise exception 'El logo debe estar en la carpeta del organismo';
  end if;
  if new.simbolo_onac_ruta is not null and new.simbolo_onac_ruta not like new.id::text || '/%' then
    raise exception 'El símbolo de ONAC debe estar en la carpeta del organismo';
  end if;
  return new;
end $$;

drop trigger if exists validar_rutas_logo on organismos;
create trigger validar_rutas_logo before insert or update of logo_ruta, simbolo_onac_ruta on organismos
  for each row execute function validar_rutas_logo();

select 'Migración 0004 aplicada: logos del organismo' as resultado;


-- >>>>>>>>>> supabase/migrations/0005_acceso_por_rol.sql
-- ============================================================================
-- Delta RETIE — 0005 Acceso por rol y archivos privados
--
-- Tabla de acceso aprobada (docs/DECISIONES.md). En esta migración:
-- * Hoja de vida (formación, experiencia, certificados) y sus soportes: la ve la
--   persona misma y la gerencia, el responsable del SG y la dirección técnica de
--   los organismos donde está vinculada. Los demás inspectores no.
--   (Corrige 0002: la gerencia de cualquier organismo podía leer la hoja de vida
--   de personas de otros organismos.)
-- * Soportes en PDF o imagen en una carpeta privada ("soportes").
-- * Logos en carpeta privada: los ve solo el personal del organismo.
-- Los archivos se abren con enlaces que vencen en pocos minutos.
--
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

-- ─────────────────── ¿Quién ve y quién gestiona una hoja de vida? ───────────────────
create or replace function roles_hoja_de_vida() returns rol_oec[]
language sql immutable as $$
  select array['representante_legal','gerente','miembro_gerencia','responsable_sg','suplente_sg',
               'director_tecnico','director_tecnico_suplente']::rol_oec[]
$$;

-- Organismos donde la persona tiene vinculación vigente.
create or replace function organismos_de(p uuid) returns setof uuid
language sql stable security definer set search_path = public as $$
  select v.organismo_id from vinculaciones v
   where v.persona_id = p and v.desde <= current_date and (v.hasta is null or v.hasta >= current_date)
$$;

-- Persona registrada por el usuario y aún sin vincular a ningún organismo (en proceso de designación).
create or replace function registrada_por_mi_sin_vincular(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from personas x where x.id = p and x.creado_por = auth.uid())
     and not exists (select 1 from vinculaciones v where v.persona_id = p)
$$;

create or replace function ve_hoja_de_vida(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
       p = persona_actual()
    or exists (select 1 from organismos_de(p) o(id) where tiene_rol(o.id, roles_hoja_de_vida()) or en_arranque(o.id))
    or registrada_por_mi_sin_vincular(p))
$$;

create or replace function gestiona_hoja_de_vida(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
       p = persona_actual()
    or exists (select 1 from organismos_de(p) o(id) where administra(o.id))
    or registrada_por_mi_sin_vincular(p))
$$;

-- ─────────────────── Políticas de la hoja de vida ───────────────────
-- Personas: el directorio (nombres) sigue como en 0002/0003; modificar, solo quien gestiona.
drop policy if exists gestion on personas;
drop policy if exists registro on personas;
drop policy if exists modificacion on personas;
create policy registro on personas for insert to authenticated with check (true);
create policy modificacion on personas for update to authenticated
  using (gestiona_hoja_de_vida(id)) with check (gestiona_hoja_de_vida(id));

-- Certificados de competencias
drop policy if exists lectura on certificados_competencia;
drop policy if exists lectura_registradas on certificados_competencia;
drop policy if exists gestion on certificados_competencia;
drop policy if exists hoja_lectura on certificados_competencia;
drop policy if exists hoja_registro on certificados_competencia;
drop policy if exists hoja_modificacion on certificados_competencia;
create policy hoja_lectura on certificados_competencia for select to authenticated using (ve_hoja_de_vida(persona_id));
create policy hoja_registro on certificados_competencia for insert to authenticated with check (gestiona_hoja_de_vida(persona_id));
create policy hoja_modificacion on certificados_competencia for update to authenticated
  using (gestiona_hoja_de_vida(persona_id)) with check (gestiona_hoja_de_vida(persona_id));

-- Categorías de cada certificado
drop policy if exists lectura on certificado_categorias;
drop policy if exists gestion on certificado_categorias;
drop policy if exists hoja_lectura on certificado_categorias;
drop policy if exists hoja_registro on certificado_categorias;
drop policy if exists hoja_retiro on certificado_categorias;
create policy hoja_lectura on certificado_categorias for select to authenticated using (
  exists (select 1 from certificados_competencia c where c.id = certificado_id and ve_hoja_de_vida(c.persona_id)));
create policy hoja_registro on certificado_categorias for insert to authenticated with check (
  exists (select 1 from certificados_competencia c where c.id = certificado_id and gestiona_hoja_de_vida(c.persona_id)));
create policy hoja_retiro on certificado_categorias for delete to authenticated using (
  exists (select 1 from certificados_competencia c where c.id = certificado_id and gestiona_hoja_de_vida(c.persona_id)));

-- Experiencia y formación
do $$
declare t text;
begin
  foreach t in array array['experiencias', 'formacion'] loop
    execute format('drop policy if exists propia on %I', t);
    execute format('drop policy if exists hoja_lectura on %I', t);
    execute format('drop policy if exists hoja_registro on %I', t);
    execute format('drop policy if exists hoja_modificacion on %I', t);
    execute format('create policy hoja_lectura on %I for select to authenticated using (ve_hoja_de_vida(persona_id))', t);
    execute format('create policy hoja_registro on %I for insert to authenticated with check (gestiona_hoja_de_vida(persona_id))', t);
    execute format('create policy hoja_modificacion on %I for update to authenticated using (gestiona_hoja_de_vida(persona_id)) with check (gestiona_hoja_de_vida(persona_id))', t);
  end loop;
end $$;

-- ─────────────────── Archivos de soporte (privados) ───────────────────
-- Ruta: soportes/<persona>/<archivo>. Máximo 10 MB; PDF, JPG o PNG.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('soportes', 'soportes', false, 10485760, array['application/pdf', 'image/png', 'image/jpeg'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create or replace function persona_de_carpeta(nombre text) returns uuid
language plpgsql immutable as $$
begin
  return ((storage.foldername(nombre))[1])::uuid;
exception when others then
  return null;
end $$;

drop policy if exists soportes_lectura on storage.objects;
create policy soportes_lectura on storage.objects for select to authenticated
  using (bucket_id = 'soportes' and ve_hoja_de_vida(persona_de_carpeta(name)));
drop policy if exists soportes_carga on storage.objects;
create policy soportes_carga on storage.objects for insert to authenticated
  with check (bucket_id = 'soportes' and gestiona_hoja_de_vida(persona_de_carpeta(name)));

-- El soporte registrado debe estar en la carpeta de la persona.
create or replace function validar_ruta_soporte() returns trigger
language plpgsql as $$
begin
  if new.soporte_ruta is not null and new.soporte_ruta not like new.persona_id::text || '/%' then
    raise exception 'El soporte debe estar en la carpeta de la persona';
  end if;
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['certificados_competencia', 'experiencias', 'formacion'] loop
    execute format('drop trigger if exists validar_ruta_soporte on %I', t);
    execute format('create trigger validar_ruta_soporte before insert or update of soporte_ruta on %I for each row execute function validar_ruta_soporte()', t);
  end loop;
end $$;

-- ─────────────────── Logos privados ───────────────────
update storage.buckets set public = false where id = 'logos';

drop policy if exists logos_lectura on storage.objects;
create policy logos_lectura on storage.objects for select to authenticated
  using (bucket_id = 'logos' and persona_de_carpeta(name) in (select mis_organismos()));

select 'Migración 0005 aplicada: acceso por rol y archivos privados' as resultado;


-- >>>>>>>>>> supabase/migrations/0006_acceso_revision.sql
-- ============================================================================
-- Delta RETIE — 0006 Acceso de revisión temporal
--
-- Permite que una persona vea TODO un organismo (solo lectura) durante un tiempo
-- limitado, sin cambiar sus roles reales ni crear designaciones falsas (17020 §8.4).
-- * Lo otorga solo el administrador de la plataforma, por correo y con fecha y hora
--   de vencimiento; al vencer se apaga solo.
-- * Solo lectura: para registrar o modificar siguen mandando los roles reales.
-- * Queda registrado quién lo otorgó, a quién, desde y hasta cuándo, y por qué.
--
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

create table if not exists accesos_revision (
  id           uuid primary key default gen_random_uuid(),
  organismo_id uuid not null references organismos(id),
  correo       text not null check (correo = lower(trim(correo))),
  desde        timestamptz not null default now(),
  hasta        timestamptz not null,
  motivo       text not null,
  otorgado_por uuid default auth.uid(),
  creado       timestamptz not null default now(),
  check (hasta > desde)
);
alter table accesos_revision enable row level security;

drop policy if exists admin_plataforma on accesos_revision;
create policy admin_plataforma on accesos_revision for all to authenticated
  using (es_admin_plataforma()) with check (es_admin_plataforma());
drop policy if exists propios on accesos_revision;
create policy propios on accesos_revision for select to authenticated using (correo = correo_actual());

drop trigger if exists bitacora_accesos_revision on accesos_revision;
create trigger bitacora_accesos_revision before insert or update or delete on accesos_revision
  for each row execute function registrar_bitacora();

-- ¿El usuario tiene acceso de revisión vigente al organismo?
create or replace function en_revision(org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from accesos_revision a
                  where a.organismo_id = org and a.correo = correo_actual() and now() between a.desde and a.hasta)
$$;

-- La aplicación lo consulta para mostrar todo el menú y el aviso de "solo lectura".
create or replace function mis_accesos_revision() returns table (organismo_id uuid, hasta timestamptz)
language sql stable security definer set search_path = public as $$
  select a.organismo_id, max(a.hasta) from accesos_revision a
   where a.correo = correo_actual() and now() between a.desde and a.hasta
   group by a.organismo_id
$$;

-- Lectura: los organismos en revisión cuentan como "mis organismos" (todas las tablas
-- con organismo_id, logos y personas vinculadas) …
create or replace function mis_organismos() returns setof uuid
language sql stable security definer set search_path = public as $$
  select v.organismo_id from vinculaciones v
  where v.persona_id = persona_actual() and v.desde <= current_date and (v.hasta is null or v.hasta >= current_date)
  union
  select o.id from organismos o where o.creado_por = auth.uid() and en_arranque(o.id)
  union
  select a.organismo_id from accesos_revision a
   where a.correo = correo_actual() and now() between a.desde and a.hasta
$$;

-- … y también se ven las hojas de vida y sus soportes del personal del organismo.
create or replace function ve_hoja_de_vida(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
       p = persona_actual()
    or exists (select 1 from organismos_de(p) o(id) where tiene_rol(o.id, roles_hoja_de_vida()) or en_arranque(o.id) or en_revision(o.id))
    or registrada_por_mi_sin_vincular(p))
$$;

select 'Migración 0006 aplicada: acceso de revisión temporal' as resultado;


-- >>>>>>>>>> supabase/migrations/0007_quitar_por_error.sql
-- ============================================================================
-- Delta RETIE — 0007 Quitar registros hechos por error
--
-- La regla general sigue: nada se borra (17020 §8.4). La excepción es corregir un
-- error de digitación que nunca se usó:
-- * una actividad del alcance de un organismo (nadie la tiene autorizada y no hay
--   órdenes de servicio con ella);
-- * una actividad autorizada a un director técnico o inspector (no hay órdenes de
--   servicio de esa persona con esa actividad).
-- Solo quien administra el organismo; con motivo obligatorio. La bitácora guarda
-- el registro quitado, quién, cuándo y el motivo.
--
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

-- La bitácora permite el borrado solo dentro de estas funciones (que marcan el motivo).
create or replace function registrar_bitacora() returns trigger
language plpgsql security definer set search_path = public as $$
declare motivo text := nullif(current_setting('delta.correccion', true), '');
begin
  if tg_op = 'DELETE' then
    if motivo is null then
      raise exception 'No se permite eliminar registros de %; ciérrelos o anúlelos con justificación (17020 §8.4)', tg_table_name;
    end if;
    insert into bitacora(tabla, registro, operacion, usuario, antes, despues)
    values (tg_table_name, coalesce(to_jsonb(old)->>'id', to_jsonb(old)->>'actividad_codigo', ''), 'DELETE (registrada por error)',
            auth.uid(), to_jsonb(old), jsonb_build_object('motivo', motivo));
    return old;
  end if;
  insert into bitacora(tabla, registro, operacion, usuario, antes, despues)
  values (tg_table_name, coalesce(to_jsonb(new)->>'id', ''), tg_op, auth.uid(),
          case when tg_op = 'UPDATE' then to_jsonb(old) end, to_jsonb(new));
  return new;
end $$;

create or replace function registrar_bitacora_relacion() returns trigger
language plpgsql security definer set search_path = public as $$
declare motivo text := nullif(current_setting('delta.correccion', true), '');
begin
  insert into bitacora(tabla, registro, operacion, usuario, antes, despues)
  values (tg_table_name, '', case when tg_op = 'DELETE' and motivo is not null then 'DELETE (registrada por error)' else tg_op end,
          auth.uid(),
          case when tg_op <> 'INSERT' then to_jsonb(old) end,
          case when tg_op <> 'DELETE' then to_jsonb(new) when motivo is not null then jsonb_build_object('motivo', motivo) end);
  return coalesce(new, old);
end $$;

-- Las actividades autorizadas ya no se quitan directamente: solo con la función de abajo.
drop policy if exists gestion on designacion_actividades;
drop policy if exists autorizacion on designacion_actividades;
create policy autorizacion on designacion_actividades for insert to authenticated
  with check (exists (select 1 from designaciones d where d.id = designacion_id and administra(d.organismo_id)));

-- ─────────────────── Quitar del alcance una actividad registrada por error ───────────────────
create or replace function quitar_alcance_por_error(p_organismo uuid, p_actividad text, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or not administra(p_organismo) then
    raise exception 'Solo quien administra el organismo puede corregir su alcance';
  end if;
  if coalesce(trim(p_motivo), '') = '' then
    raise exception 'Indique el motivo de la corrección';
  end if;
  if not exists (select 1 from alcance_acreditado where organismo_id = p_organismo and actividad_codigo = p_actividad) then
    raise exception 'La actividad no está en el alcance del organismo';
  end if;
  if exists (select 1 from designacion_actividades da join designaciones d on d.id = da.designacion_id
             where d.organismo_id = p_organismo and da.actividad_codigo = p_actividad) then
    raise exception 'La actividad ya está autorizada a alguien: no se puede quitar. Si dejó de estar acreditada, cámbiela a "retirada"';
  end if;
  if exists (select 1 from ordenes_servicio where organismo_id = p_organismo and actividad_codigo = p_actividad) then
    raise exception 'Ya hay órdenes de servicio con esta actividad: no se puede quitar. Cámbiela a "retirada"';
  end if;
  perform set_config('delta.correccion', trim(p_motivo), true);
  delete from alcance_acreditado where organismo_id = p_organismo and actividad_codigo = p_actividad;
  perform set_config('delta.correccion', '', true);
end $$;

-- ─────────────────── Quitar una actividad autorizada por error ───────────────────
create or replace function quitar_autorizacion_por_error(p_designacion uuid, p_actividad text, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
declare d designaciones;
begin
  select * into d from designaciones where id = p_designacion;
  if d.id is null or auth.uid() is null or not administra(d.organismo_id) then
    raise exception 'Solo quien administra el organismo puede corregir las actividades autorizadas';
  end if;
  if coalesce(trim(p_motivo), '') = '' then
    raise exception 'Indique el motivo de la corrección';
  end if;
  if not exists (select 1 from designacion_actividades where designacion_id = p_designacion and actividad_codigo = p_actividad) then
    raise exception 'La actividad no está autorizada en esta designación';
  end if;
  if exists (select 1 from ordenes_servicio o where o.organismo_id = d.organismo_id and o.actividad_codigo = p_actividad
               and d.persona_id in (o.inspector_id, o.director_tecnico_id)) then
    raise exception 'La persona ya tiene órdenes de servicio con esta actividad: no se puede quitar. Finalice la designación o retire la actividad del alcance';
  end if;
  perform set_config('delta.correccion', trim(p_motivo), true);
  delete from designacion_actividades where designacion_id = p_designacion and actividad_codigo = p_actividad;
  perform set_config('delta.correccion', '', true);
end $$;

revoke execute on function quitar_alcance_por_error(uuid, text, text) from public, anon;
revoke execute on function quitar_autorizacion_por_error(uuid, text, text) from public, anon;
grant execute on function quitar_alcance_por_error(uuid, text, text) to authenticated;
grant execute on function quitar_autorizacion_por_error(uuid, text, text) to authenticated;

select 'Migración 0007 aplicada: quitar registros hechos por error' as resultado;


-- >>>>>>>>>> supabase/migrations/0008_documentos_organismo.sql
-- ============================================================================
-- Delta RETIE — 0008 Documentos del organismo con historial
--
-- * Certificado de acreditación ONAC (con su anexo de alcance)
-- * Póliza de responsabilidad civil
-- * Declaración de independencia del organismo tipo A (17020 Anexo A.1)
--
-- Cada carga es una versión nueva con su PDF; la anterior queda como "reemplazada"
-- (nada se borra ni se modifica, 17020 §8.4). La versión vigente actualiza sola los
-- datos del organismo (fechas de acreditación, póliza, declaración) para el tablero.
-- Los cargan la gerencia y el responsable del SG (o el creador en el arranque).
-- El certificado lo ve todo el personal; la póliza y la declaración, la gerencia,
-- el SG y la dirección técnica. Los PDF van en una carpeta privada.
--
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

alter table organismos add column if not exists acreditacion_renovada date;
alter table organismos add column if not exists acreditacion_actualizada date;

create table if not exists documentos_organismo (
  id            uuid primary key default gen_random_uuid(),
  organismo_id  uuid not null references organismos(id),
  tipo          text not null check (tipo in ('acreditacion', 'poliza_rc', 'independencia')),
  archivo_ruta  text not null,
  numero        text,            -- código de acreditación o número de póliza
  emisor        text,            -- ONAC o aseguradora
  valor         numeric(16,2),   -- valor asegurado (póliza)
  fecha         date,            -- otorgamiento (acreditación) o firma (declaración)
  renovacion    date,            -- acreditación
  actualizacion date,            -- acreditación (última actualización publicada por ONAC)
  desde         date,            -- vigencia de la póliza
  hasta         date,            -- vencimiento de la acreditación o de la póliza
  firmado_por   text,            -- declaración de independencia
  observacion   text,
  cargado_por   uuid default auth.uid(),
  cargado       timestamptz not null default now(),
  reemplazado_en timestamptz,
  check (hasta is null or desde is null or hasta > desde),
  check (hasta is null or fecha is null or hasta > fecha),
  check (tipo <> 'acreditacion' or (numero is not null and hasta is not null)),
  check (tipo <> 'poliza_rc' or (numero is not null and desde is not null and hasta is not null)),
  check (tipo <> 'independencia' or fecha is not null)
);
create index if not exists documentos_organismo_tipo on documentos_organismo (organismo_id, tipo, cargado desc);

drop trigger if exists bitacora_documentos_organismo on documentos_organismo;
create trigger bitacora_documentos_organismo before insert or update or delete on documentos_organismo
  for each row execute function registrar_bitacora();

-- ─────────────────── ¿Quién carga y quién ve? ───────────────────
-- Cargar: lo mismo que modificar los datos del organismo (0002 / 0003).
create or replace function gestiona_organismo(org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null
     and (tiene_rol(org, array['representante_legal','gerente','responsable_sg']::rol_oec[]) or en_arranque(org))
$$;

-- Ver: el certificado de acreditación, todo el personal del organismo; lo demás, la
-- gerencia, el SG y la dirección técnica (y el acceso de revisión temporal).
create or replace function ve_documento_organismo(org uuid, p_tipo text) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and org in (select mis_organismos()) and (
       p_tipo = 'acreditacion'
    or tiene_rol(org, roles_hoja_de_vida()) or en_arranque(org) or en_revision(org))
$$;

alter table documentos_organismo enable row level security;
drop policy if exists lectura on documentos_organismo;
create policy lectura on documentos_organismo for select to authenticated using (ve_documento_organismo(organismo_id, tipo));
drop policy if exists carga on documentos_organismo;
create policy carga on documentos_organismo for insert to authenticated with check (gestiona_organismo(organismo_id));
-- Sin políticas de modificación ni borrado: cada versión queda como se cargó.

-- ─────────────────── Al cargar una versión nueva ───────────────────
create or replace function aplicar_documento_organismo() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.archivo_ruta not like new.organismo_id::text || '/' || new.tipo || '/%' then
    raise exception 'El archivo debe estar en la carpeta del organismo';
  end if;
  new.cargado_por := auth.uid();
  new.cargado := now();
  new.reemplazado_en := null;
  -- La versión anterior queda reemplazada (se conserva con su archivo).
  update documentos_organismo set reemplazado_en = now()
   where organismo_id = new.organismo_id and tipo = new.tipo and reemplazado_en is null;
  -- Los datos del organismo siguen a la versión vigente.
  if new.tipo = 'acreditacion' then
    update organismos set codigo_acreditacion = new.numero, acreditacion_otorgada = coalesce(new.fecha, acreditacion_otorgada),
           acreditacion_renovada = new.renovacion, acreditacion_actualizada = new.actualizacion, acreditacion_vence = new.hasta
     where id = new.organismo_id;
  elsif new.tipo = 'poliza_rc' then
    update organismos set poliza_rc_numero = new.numero, poliza_rc_vence = new.hasta where id = new.organismo_id;
  else
    update organismos set declaracion_independencia = new.fecha where id = new.organismo_id;
  end if;
  return new;
end $$;

-- "a_" para que corra antes de la bitácora y esta registre los valores finales.
drop trigger if exists a_aplicar_documento on documentos_organismo;
create trigger a_aplicar_documento before insert on documentos_organismo
  for each row execute function aplicar_documento_organismo();

-- ─────────────────── Carpeta privada de documentos ───────────────────
-- Ruta: documentos/<organismo>/<tipo>/<archivo>. PDF, máximo 15 MB.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('documentos', 'documentos', false, 15728640, array['application/pdf'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create or replace function segunda_carpeta(nombre text) returns text
language sql immutable as $$ select (storage.foldername(nombre))[2] $$;

drop policy if exists documentos_lectura on storage.objects;
create policy documentos_lectura on storage.objects for select to authenticated
  using (bucket_id = 'documentos' and ve_documento_organismo(persona_de_carpeta(name), segunda_carpeta(name)));
drop policy if exists documentos_carga on storage.objects;
create policy documentos_carga on storage.objects for insert to authenticated
  with check (bucket_id = 'documentos' and segunda_carpeta(name) in ('acreditacion', 'poliza_rc', 'independencia')
              and gestiona_organismo(persona_de_carpeta(name)));

select 'Migración 0008 aplicada: documentos del organismo con historial' as resultado;


-- >>>>>>>>>> supabase/migrations/0009_permisos_alcance.sql
-- ============================================================================
-- Delta RETIE — 0009 Permisos del alcance y del organismo; actuación de suplentes
--
-- Reglas de GC&I (docs/DECISIONES.md):
-- * Mientras nadie esté designado, el creador del organismo puede ajustar todo (arranque).
-- * Cambiar el estado de una actividad del alcance: solo la gerencia.
-- * Agregar actividades (en trámite) y quitarlas por error: la gerencia y el SG.
-- * Datos, logos y documentos del organismo: la gerencia y el SG.
-- * Los suplentes pueden lo mismo que el titular y queda indicado que actuó el suplente:
--   la bitácora guarda en qué calidad actuó cada persona.
-- * La bitácora de un organismo la lee solo quien lo administra (antes, cualquiera
--   que administrara algún organismo).
--
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

-- ─────────────────── Grupos de roles ───────────────────
create or replace function roles_gerencia() returns rol_oec[]
language sql immutable as $$ select array['representante_legal','gerente','miembro_gerencia']::rol_oec[] $$;

create or replace function roles_gestion_organismo() returns rol_oec[]
language sql immutable as $$ select roles_gerencia() || array['responsable_sg','suplente_sg']::rol_oec[] $$;

-- Datos, logos y documentos del organismo; agregar y quitar actividades del alcance.
create or replace function gestiona_organismo(org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (tiene_rol(org, roles_gestion_organismo()) or en_arranque(org))
$$;

-- Estado de las actividades del alcance.
create or replace function decide_estado_alcance(org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (tiene_rol(org, roles_gerencia()) or en_arranque(org))
$$;

-- Los logos siguen la misma regla que los datos del organismo.
create or replace function gestiona_carpeta_organismo(nombre text) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  return gestiona_organismo(persona_de_carpeta(nombre));
end $$;

-- Datos del organismo
drop policy if exists gestion_gerencia on organismos;
drop policy if exists gestion_arranque on organismos;
drop policy if exists gestion_organismo on organismos;
create policy gestion_organismo on organismos for update to authenticated
  using (gestiona_organismo(id)) with check (gestiona_organismo(id));

-- ─────────────────── Alcance acreditado ───────────────────
alter table alcance_acreditado add column if not exists estado_por uuid;   -- persona que fijó el estado
alter table alcance_acreditado add column if not exists estado_en_calidad text;

drop policy if exists gestion_administradores on alcance_acreditado;
drop policy if exists alcance_agregar on alcance_acreditado;
drop policy if exists alcance_estado on alcance_acreditado;
-- Agregar: la gerencia y el SG, y la actividad nueva queda en trámite (en el arranque, cualquier estado).
create policy alcance_agregar on alcance_acreditado for insert to authenticated
  with check (en_arranque(organismo_id) or (gestiona_organismo(organismo_id) and estado = 'en_tramite'));
-- Cambiar el estado: solo la gerencia.
create policy alcance_estado on alcance_acreditado for update to authenticated
  using (decide_estado_alcance(organismo_id)) with check (decide_estado_alcance(organismo_id));

-- Nombre del rol con el que actúa la persona en el organismo (para la bitácora y el alcance).
create or replace function calidad_actuante(org uuid) returns text[]
language sql stable security definer set search_path = public as $$
  select case
    when auth.uid() is null then null
    when en_arranque(org) then array['creador del organismo (arranque)']
    else (select array_agg(distinct d.rol::text order by d.rol::text) from designaciones d
           where d.organismo_id = org and d.persona_id = persona_actual()
             and d.desde <= current_date and (d.hasta is null or d.hasta >= current_date))
  end
$$;

create or replace function registrar_estado_alcance() returns trigger
language plpgsql security definer set search_path = public as $$
declare c text[] := calidad_actuante(new.organismo_id);
begin
  if tg_op = 'INSERT' or new.estado is distinct from old.estado then
    new.estado_por := persona_actual();
    new.estado_en_calidad := array_to_string(c, ', ');
    if tg_op = 'UPDATE' then new.fecha_estado := current_date; end if;
  end if;
  return new;
end $$;

drop trigger if exists a_registrar_estado on alcance_acreditado;
create trigger a_registrar_estado before insert or update on alcance_acreditado
  for each row execute function registrar_estado_alcance();

-- Quitar por error: la gerencia y el SG (antes: quien administrara el organismo).
create or replace function quitar_alcance_por_error(p_organismo uuid, p_actividad text, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not gestiona_organismo(p_organismo) then
    raise exception 'Solo la gerencia o el responsable del SG pueden quitar actividades del alcance';
  end if;
  if coalesce(trim(p_motivo), '') = '' then
    raise exception 'Indique el motivo de la corrección';
  end if;
  if not exists (select 1 from alcance_acreditado where organismo_id = p_organismo and actividad_codigo = p_actividad) then
    raise exception 'La actividad no está en el alcance del organismo';
  end if;
  if exists (select 1 from designacion_actividades da join designaciones d on d.id = da.designacion_id
             where d.organismo_id = p_organismo and da.actividad_codigo = p_actividad) then
    raise exception 'La actividad ya está autorizada a alguien: no se puede quitar. Si dejó de estar acreditada, cámbiela a "retirada"';
  end if;
  if exists (select 1 from ordenes_servicio where organismo_id = p_organismo and actividad_codigo = p_actividad) then
    raise exception 'Ya hay órdenes de servicio con esta actividad: no se puede quitar. Cámbiela a "retirada"';
  end if;
  perform set_config('delta.correccion', trim(p_motivo), true);
  delete from alcance_acreditado where organismo_id = p_organismo and actividad_codigo = p_actividad;
  perform set_config('delta.correccion', '', true);
end $$;

-- ─────────────────── Bitácora: organismo y en qué calidad actuó ───────────────────
alter table bitacora add column if not exists organismo_id uuid;
alter table bitacora add column if not exists en_calidad_de text[];

create or replace function organismo_de_fila(tabla text, fila jsonb) returns uuid
language plpgsql stable security definer set search_path = public as $$
declare org uuid;
begin
  if tabla = 'organismos' then return (fila->>'id')::uuid; end if;
  if fila ? 'organismo_id' then return (fila->>'organismo_id')::uuid; end if;
  if tabla = 'designacion_actividades' then
    select d.organismo_id into org from designaciones d where d.id = (fila->>'designacion_id')::uuid;
  end if;
  return org;
exception when others then
  return null;
end $$;

create or replace function registrar_bitacora() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  motivo text := nullif(current_setting('delta.correccion', true), '');
  fila jsonb := to_jsonb(coalesce(new, old));
  org uuid := organismo_de_fila(tg_table_name, fila);
begin
  if tg_op = 'DELETE' then
    if motivo is null then
      raise exception 'No se permite eliminar registros de %; ciérrelos o anúlelos con justificación (17020 §8.4)', tg_table_name;
    end if;
    insert into bitacora(tabla, registro, operacion, usuario, antes, despues, organismo_id, en_calidad_de)
    values (tg_table_name, coalesce(fila->>'id', fila->>'actividad_codigo', ''), 'DELETE (registrada por error)',
            auth.uid(), to_jsonb(old), jsonb_build_object('motivo', motivo), org, calidad_actuante(org));
    return old;
  end if;
  insert into bitacora(tabla, registro, operacion, usuario, antes, despues, organismo_id, en_calidad_de)
  values (tg_table_name, coalesce(to_jsonb(new)->>'id', ''), tg_op, auth.uid(),
          case when tg_op = 'UPDATE' then to_jsonb(old) end, to_jsonb(new), org, calidad_actuante(org));
  return new;
end $$;

create or replace function registrar_bitacora_relacion() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  motivo text := nullif(current_setting('delta.correccion', true), '');
  org uuid := organismo_de_fila(tg_table_name, to_jsonb(coalesce(new, old)));
begin
  insert into bitacora(tabla, registro, operacion, usuario, antes, despues, organismo_id, en_calidad_de)
  values (tg_table_name, '', case when tg_op = 'DELETE' and motivo is not null then 'DELETE (registrada por error)' else tg_op end,
          auth.uid(),
          case when tg_op <> 'INSERT' then to_jsonb(old) end,
          case when tg_op <> 'DELETE' then to_jsonb(new) when motivo is not null then jsonb_build_object('motivo', motivo) end,
          org, calidad_actuante(org));
  return coalesce(new, old);
end $$;

drop policy if exists lectura on bitacora;
create policy lectura on bitacora for select to authenticated
  using (organismo_id is not null and (administra(organismo_id) or en_revision(organismo_id)));

select 'Migración 0009 aplicada: permisos del alcance y actuación de suplentes' as resultado;


-- >>>>>>>>>> supabase/migrations/0010_matricula_ingeniero.sql
-- ============================================================================
-- Delta RETIE — 0010 Matrícula profesional de ingeniero
--
-- Para director técnico e inspector se requiere matrícula de INGENIERO:
--   CPNIEMPA — Consejo Profesional Nacional de Ingenierías Eléctrica, Mecánica y
--              Profesiones Afines (Ley 51 de 1986)
--   COPNIA   — Consejo Profesional Nacional de Ingeniería (Ley 842 de 2003)
-- Otra entidad (por ejemplo un consejo poco común) solo cuenta si la gerencia la
-- acepta a mano, con motivo; nadie acepta la suya. Si cambian la entidad o el
-- número de la matrícula, la aceptación se pierde.
-- Los consejos de técnicos y tecnólogos no cuentan ni se pueden aceptar:
--   CONTE    — Consejo Nacional de Técnicos Electricistas
--   CONALTEL — Consejo Profesional Nacional de Tecnólogos en Electricidad,
--              Electromecánica, Electrónica y Afines (Ley 1264 de 2008)
--
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

alter table personas add column if not exists matricula_aceptada_por uuid;   -- persona de la gerencia
alter table personas add column if not exists matricula_aceptada_en timestamptz;
alter table personas add column if not exists matricula_aceptada_motivo text;

-- Normaliza la entidad: CPNIEMPA, COPNIA o el texto escrito.
create or replace function entidad_matricula(e text) returns text
language sql immutable as $$
  select case
    when e is null or trim(e) = '' then null
    when upper(e) like '%CPNIEMPA%' or upper(e) like '%ELÉCTRICA, MECÁNICA%' or upper(e) like '%ELECTRICA, MECANICA%' then 'CPNIEMPA'
    when upper(e) like '%COPNIA%' then 'COPNIA'
    else trim(e) end
$$;

-- ¿Es un consejo de técnicos o tecnólogos (no de ingenieros)?
create or replace function consejo_no_ingenieros(e text) returns boolean
language sql immutable as $$
  select upper(coalesce(e, '')) ~ '(CONTE|CONALTEL|T[ÉE]CNICOS ELECTRICISTAS|TECN[ÓO]LOGOS)'
$$;

-- ¿La matrícula sirve para director técnico o inspector?
create or replace function matricula_de_ingeniero(p personas) returns boolean
language sql stable as $$
  select coalesce(trim(p.matricula_numero), '') <> ''
     and (coalesce(entidad_matricula(p.matricula_entidad), '') in ('CPNIEMPA', 'COPNIA')
          or (p.matricula_aceptada_en is not null and not consejo_no_ingenieros(p.matricula_entidad)))
$$;

-- La aceptación no se escribe a mano: solo con la función de abajo. Y se pierde si cambia la matrícula.
create or replace function proteger_aceptacion_matricula() returns trigger
language plpgsql as $$
begin
  if coalesce(current_setting('delta.aceptacion', true), '') <> 'on' then
    if tg_op = 'INSERT' then
      new.matricula_aceptada_por := null; new.matricula_aceptada_en := null; new.matricula_aceptada_motivo := null;
    elsif new.matricula_entidad is distinct from old.matricula_entidad or new.matricula_numero is distinct from old.matricula_numero then
      new.matricula_aceptada_por := null; new.matricula_aceptada_en := null; new.matricula_aceptada_motivo := null;
    elsif (new.matricula_aceptada_por, new.matricula_aceptada_en, new.matricula_aceptada_motivo)
          is distinct from (old.matricula_aceptada_por, old.matricula_aceptada_en, old.matricula_aceptada_motivo) then
      raise exception 'La aceptación de la matrícula la registra la gerencia con el botón "Aceptar matrícula"';
    end if;
  end if;
  new.matricula_entidad := coalesce(entidad_matricula(new.matricula_entidad), new.matricula_entidad);
  return new;
end $$;

drop trigger if exists a_proteger_matricula on personas;
create trigger a_proteger_matricula before insert or update on personas
  for each row execute function proteger_aceptacion_matricula();

-- La gerencia de un organismo donde la persona está vinculada acepta una matrícula de otra entidad.
create or replace function aceptar_matricula(p_persona uuid, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
declare p personas;
begin
  select * into p from personas where id = p_persona;
  if p.id is null then raise exception 'La persona no existe'; end if;
  if not exists (select 1 from organismos_de(p_persona) o(id) where tiene_rol(o.id, roles_gerencia()) or en_arranque(o.id)) then
    raise exception 'Solo la gerencia de un organismo donde la persona está vinculada puede aceptar su matrícula';
  end if;
  if p_persona = persona_actual() then
    raise exception 'Nadie puede aceptar su propia matrícula';
  end if;
  if coalesce(trim(p_motivo), '') = '' then raise exception 'Indique el motivo de la aceptación'; end if;
  if coalesce(trim(p.matricula_numero), '') = '' then raise exception 'La persona no tiene número de matrícula'; end if;
  if coalesce(entidad_matricula(p.matricula_entidad), '') in ('CPNIEMPA', 'COPNIA') then
    raise exception 'Las matrículas del CPNIEMPA y del COPNIA no necesitan aceptación';
  end if;
  if consejo_no_ingenieros(p.matricula_entidad) then
    raise exception 'El CONTE y el CONALTEL matriculan técnicos y tecnólogos: no sirven para director técnico ni inspector';
  end if;
  perform set_config('delta.aceptacion', 'on', true);
  update personas set matricula_aceptada_por = persona_actual(), matricula_aceptada_en = now(), matricula_aceptada_motivo = trim(p_motivo)
   where id = p_persona;
  perform set_config('delta.aceptacion', '', true);
end $$;

revoke execute on function aceptar_matricula(uuid, text) from public, anon;
grant execute on function aceptar_matricula(uuid, text) to authenticated;

-- Requisitos de competencia: igual que en 0001, con la matrícula de ingeniero.
create or replace function motivo_competencia(p_persona uuid, p_actividad text, p_rol text, p_fecha date default current_date)
returns text language plpgsql stable as $$
declare
  a actividades; r reglamentos; k categorias_competencia; p personas;
  cat_exp text; anios numeric; dir numeric;
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

  cat_exp := case when r.experiencia_por_categoria then k.codigo end;
  anios := anios_experiencia(p_persona, r.id, cat_exp, r.tipos_experiencia_tecnica, p_fecha);
  if anios < k.experiencia_inspector_anios then
    return format('Experiencia verificada insuficiente: %s de %s años', round(anios, 1), k.experiencia_inspector_anios);
  end if;

  if p_rol = 'director_tecnico' then
    cat_exp := case when r.dt_por_categoria then k.codigo end;
    anios := anios_experiencia(p_persona, r.id, cat_exp, r.tipos_experiencia_tecnica || r.dt_tipos_direccion, p_fecha);
    dir := anios_experiencia(p_persona, r.id, cat_exp, r.dt_tipos_direccion, p_fecha);
    if (r.dt_total_estricta and anios <= r.dt_experiencia_total) or (not r.dt_total_estricta and anios < r.dt_experiencia_total) then
      return format('Experiencia de director técnico insuficiente: %s años (%s %s)', round(anios, 1),
                    case when r.dt_total_estricta then 'más de' else 'mínimo' end, r.dt_experiencia_total);
    end if;
    if dir < r.dt_experiencia_direccion then
      return format('Experiencia en gerencia/dirección insuficiente: %s de %s años', round(dir, 1), r.dt_experiencia_direccion);
    end if;
  end if;

  if r.exige_certificado and not exists (
    select 1 from certificados_competencia c join certificado_categorias cc on cc.certificado_id = c.id
    where c.persona_id = p_persona and cc.reglamento_id = r.id and cc.categoria = k.codigo and certificado_vigente(c, p_fecha)) then
    return format('Sin certificado de competencias vigente (con seguimiento) en la categoría %s', k.codigo);
  end if;
  return null;
end $$;

-- Normaliza las entidades ya registradas.
update personas set matricula_entidad = entidad_matricula(matricula_entidad)
 where matricula_entidad is not null and matricula_entidad is distinct from entidad_matricula(matricula_entidad);

select 'Migración 0010 aplicada: matrícula profesional de ingeniero' as resultado;


-- >>>>>>>>>> supabase/migrations/0011_seguimiento_y_asistente.sql
-- ============================================================================
-- Ultra RETIE — 0011 Seguimiento del mes 30 y asistente de dirección técnica
--
-- 1. Seguimiento del mes 30 del certificado de competencias:
--    - Después de la fecha límite, sin seguimiento registrado, el certificado no cuenta
--      y la persona no puede ejercer (ya era así).
--    - NUEVO: si el seguimiento se registra tarde, el certificado vuelve a contar solo
--      desde la fecha en que se registró en la plataforma (o la del seguimiento, la que
--      sea posterior). El periodo intermedio queda como NO habilitado, para siempre.
--    - La fecha de registro la pone la base de datos; no se escribe a mano.
--    - El seguimiento no puede tener fecha futura ni anterior a la emisión.
-- 2. Rol nuevo: asistente de dirección técnica (se usa a partir de 0013).
--
-- Ejecute este archivo solo (no junto con 0012 o 0013) y después los otros, en orden.
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

alter type rol_oec add value if not exists 'asistente_direccion_tecnica';

alter table certificados_competencia add column if not exists seguimiento_registrado_en timestamptz;

-- Los seguimientos ya registrados se toman como registrados a tiempo (en su fecha).
update certificados_competencia set seguimiento_registrado_en = seguimiento_fecha::timestamptz
 where seguimiento_fecha is not null and seguimiento_registrado_en is null;

-- Fecha límite del seguimiento: mes 30 contado desde el día siguiente a la emisión.
create or replace function limite_seguimiento(c certificados_competencia) returns date
language sql stable as $$
  select (c.fecha_emision + 1 + make_interval(months => (select r.seguimiento_mes from reglamentos r where r.id = c.reglamento_id)))::date
$$;

-- Desde cuándo vuelve a contar el certificado después del seguimiento.
create or replace function seguimiento_efectivo(c certificados_competencia) returns date
language sql stable as $$
  select case when c.seguimiento_fecha is null then null
    else greatest(c.seguimiento_fecha, coalesce((c.seguimiento_registrado_en at time zone 'America/Bogota')::date, c.seguimiento_fecha)) end
$$;

-- Vigencia: dentro de sus fechas, no anulado, sin seguimiento no conforme y
--   · hasta la fecha límite del seguimiento, o
--   · desde la fecha efectiva del seguimiento (si se registró tarde, hay un periodo sin habilitación).
create or replace function certificado_vigente(c certificados_competencia, p_fecha date)
returns boolean language sql stable as $$
  select not c.anulado
     and c.fecha_emision <= p_fecha and c.fecha_vencimiento >= p_fecha
     and coalesce(c.seguimiento_resultado, '') <> 'no_conforme'
     and (p_fecha <= limite_seguimiento(c)
          or (c.seguimiento_fecha is not null and p_fecha >= seguimiento_efectivo(c)))
$$;

-- Periodo en que la persona no pudo ejercer con este certificado por registrar tarde el seguimiento.
create or replace function periodo_sin_seguimiento(c certificados_competencia) returns daterange
language sql stable as $$
  select case
    when c.anulado or coalesce(c.seguimiento_resultado, '') = 'no_conforme' then null
    when c.seguimiento_fecha is null and current_date > limite_seguimiento(c)
      then daterange(limite_seguimiento(c) + 1, null)
    when c.seguimiento_fecha is not null and seguimiento_efectivo(c) > limite_seguimiento(c) + 1
      then daterange(limite_seguimiento(c) + 1, seguimiento_efectivo(c))
  end
$$;

-- La fecha de registro la pone la base de datos, y el seguimiento no puede ser futuro.
create or replace function proteger_seguimiento() returns trigger
language plpgsql as $$
begin
  if new.seguimiento_fecha is not null
     and (tg_op = 'INSERT' or new.seguimiento_fecha is distinct from old.seguimiento_fecha) then
    if new.seguimiento_fecha > (now() at time zone 'America/Bogota')::date then
      raise exception 'La fecha del seguimiento no puede ser futura';
    end if;
    if new.seguimiento_fecha < new.fecha_emision then
      raise exception 'La fecha del seguimiento no puede ser anterior a la emisión del certificado';
    end if;
    new.seguimiento_registrado_en := now();
  elsif new.seguimiento_fecha is null then
    new.seguimiento_registrado_en := null;
  else
    new.seguimiento_registrado_en := old.seguimiento_registrado_en;
  end if;
  return new;
end $$;

-- "a_" para que corra antes de la bitácora y esta registre la fecha de registro.
drop trigger if exists a_proteger_seguimiento on certificados_competencia;
create trigger a_proteger_seguimiento before insert or update on certificados_competencia
  for each row execute function proteger_seguimiento();

select 'Migración 0011 aplicada: seguimiento del mes 30 (periodo no habilitado) y rol de asistente de dirección técnica' as resultado;


-- >>>>>>>>>> supabase/migrations/0012_generacion_por_tension.sql
-- ============================================================================
-- Ultra RETIE — 0012 Generación: competencia según la tensión de la instalación
--
-- Para las actividades de generación con FNCE, AGPE y GD y de generación con varias
-- fuentes (RETIE 2024):
--   · Más de 1.000 V AC o más de 1.500 V DC → personal con categoría a (generación).
--   · Hasta 1.000 V AC y hasta 1.500 V DC (exactamente 1.000 / 1.500 incluido)
--     → personal con categoría g (uso final).
-- Cómo se inspecciona la instalación:
--   · Conectada a la red → como generación (la actividad de generación), con a o g según la tensión.
--   · No conectada a la red → como uso final (autogeneración), con g;
--     salvo si supera 1.000 V AC o 1.500 V DC: como generación, con a.
--
-- Cada actividad de generación tiene una "variante de baja tensión" (código -BT) que
-- se autoriza al personal con categoría g. La variante no se acredita por separado:
-- la cubre la misma línea del alcance.
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

alter table actividades add column if not exists variante_de text references actividades(codigo);
alter table actividades add column if not exists tension text
  check (tension in ('hasta_1000ac_1500dc', 'mayor_1000ac_1500dc'));

insert into actividades (codigo, reglamento_id, grupo, nombre, referencias, categoria, variante_de, tension)
select a.codigo || '-BT', a.reglamento_id, a.grupo,
       a.nombre || ' — hasta 1.000 V AC y 1.500 V DC', a.referencias, 'g', a.codigo, 'hasta_1000ac_1500dc'
  from actividades a
 where a.codigo in ('RETIE24-GEN-FNCE', 'RETIE24-GEN-VARIAS')
on conflict (codigo) do nothing;

update actividades set tension = 'mayor_1000ac_1500dc'
 where codigo in ('RETIE24-GEN-FNCE', 'RETIE24-GEN-VARIAS') and tension is distinct from 'mayor_1000ac_1500dc';

-- Línea del alcance que cubre una actividad (la variante la cubre su actividad de generación).
create or replace function linea_de(p_actividad text) returns text
language sql stable as $$
  select coalesce((select a.variante_de from actividades a where a.codigo = p_actividad), p_actividad)
$$;

-- La variante no se agrega al alcance: se acredita la actividad de generación.
create or replace function validar_linea_alcance() returns trigger
language plpgsql as $$
begin
  if linea_de(new.actividad_codigo) <> new.actividad_codigo then
    raise exception 'La variante por tensión no se acredita por separado: agregue la actividad %', linea_de(new.actividad_codigo);
  end if;
  return new;
end $$;

drop trigger if exists a_validar_linea_alcance on alcance_acreditado;
create trigger a_validar_linea_alcance before insert or update of actividad_codigo on alcance_acreditado
  for each row execute function validar_linea_alcance();

-- ¿Puede ejercer? Igual que en 0001, con la línea del alcance de la variante.
create or replace function puede_ejercer(p_org uuid, p_persona uuid, p_actividad text, p_fecha date default current_date, p_rol text default 'inspector')
returns text language plpgsql stable as $$
begin
  if not exists (select 1 from alcance_acreditado a
                 where a.organismo_id = p_org and a.actividad_codigo = linea_de(p_actividad) and a.estado = 'acreditada') then
    return 'La actividad ' || linea_de(p_actividad) || ' no está en el alcance acreditado vigente del organismo (17020 §5.1 / RAC-3.0-01)';
  end if;
  if not exists (select 1 from vinculaciones v
                 where v.organismo_id = p_org and v.persona_id = p_persona
                   and v.desde <= p_fecha and (v.hasta is null or v.hasta >= p_fecha)) then
    return 'La persona no tiene vinculación vigente con el organismo (17020 §6.1)';
  end if;
  return motivo_competencia(p_persona, p_actividad, p_rol, p_fecha);
end $$;

-- Quitar por error: igual que en 0009, contando también las autorizaciones de la variante.
create or replace function quitar_alcance_por_error(p_organismo uuid, p_actividad text, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not gestiona_organismo(p_organismo) then
    raise exception 'Solo la gerencia o el responsable del SG pueden quitar actividades del alcance';
  end if;
  if coalesce(trim(p_motivo), '') = '' then
    raise exception 'Indique el motivo de la corrección';
  end if;
  if not exists (select 1 from alcance_acreditado where organismo_id = p_organismo and actividad_codigo = p_actividad) then
    raise exception 'La actividad no está en el alcance del organismo';
  end if;
  if exists (select 1 from designacion_actividades da join designaciones d on d.id = da.designacion_id
             where d.organismo_id = p_organismo and linea_de(da.actividad_codigo) = p_actividad) then
    raise exception 'La actividad ya está autorizada a alguien: no se puede quitar. Si dejó de estar acreditada, cámbiela a "retirada"';
  end if;
  if exists (select 1 from ordenes_servicio where organismo_id = p_organismo and linea_de(actividad_codigo) = p_actividad) then
    raise exception 'Ya hay órdenes de servicio con esta actividad: no se puede quitar. Cámbiela a "retirada"';
  end if;
  perform set_config('delta.correccion', trim(p_motivo), true);
  delete from alcance_acreditado where organismo_id = p_organismo and actividad_codigo = p_actividad;
  perform set_config('delta.correccion', '', true);
end $$;

-- Actividad con la que se atiende una instalación de generación (para asignar personal, fase 2).
--   p_actividad: actividad de generación (FNCE/AGPE/GD o varias fuentes)
--   p_conectada_red: ¿la instalación está conectada a la red?
--   p_vac, p_vdc: tensión máxima AC y DC de la instalación (V)
create or replace function actividad_segun_instalacion(p_actividad text, p_conectada_red boolean, p_vac numeric, p_vdc numeric)
returns text language plpgsql stable as $$
declare bt text;
begin
  select a.codigo into bt from actividades a where a.variante_de = p_actividad and a.tension = 'hasta_1000ac_1500dc';
  if bt is null then return p_actividad; end if;               -- actividad sin regla por tensión
  if p_conectada_red is null then raise exception 'Indique si la instalación está conectada a la red'; end if;
  if coalesce(p_vac, 0) > 1000 or coalesce(p_vdc, 0) > 1500 then
    return p_actividad;                                         -- generación, categoría a
  elsif p_conectada_red then
    return bt;                                                  -- generación, categoría g
  else
    return 'RETIE24-UF-AUTOGEN';                                -- uso final (autogeneración), categoría g
  end if;
end $$;

select 'Migración 0012 aplicada: generación según tensión y conexión a la red' as resultado;


-- >>>>>>>>>> supabase/migrations/0013_documentos_personal.sql
-- ============================================================================
-- Ultra RETIE — 0013 Documentos de designación y autorización del personal, con firma
--
-- Documentos (los genera la aplicación con los datos de la designación):
--   designacion_gerente                     firma: el gerente designado (autodesignación;
--                                           si lo designó una junta, se carga el acta firmada a mano)
--   designacion_responsable_sg              firma: el gerente
--   autorizacion_director_tecnico           firma: el gerente
--   autorizacion_director_tecnico_suplente  firman: el gerente y el director técnico principal
--   autorizacion_inspector                  firman: el gerente y el director técnico (principal o
--                                           suplente) que evaluó al inspector
--   designacion_asistente_direccion_tecnica firma: el gerente
--
-- Firma electrónica (Ley 527 de 1999; Decreto 2364 de 2012, compilado en el Decreto 1074 de 2015):
-- cada firmante entra con su usuario, confirma su contraseña (vale 10 minutos) y firma el texto
-- exacto que vio: se guarda la huella SHA-256 del documento, la fecha y hora, el usuario, el
-- correo, el navegador y la dirección IP. Respaldo: imprimir, firmar a mano y cargar el PDF.
--
-- Sin el documento firmado, el director técnico o el inspector no puede ejercer las
-- actividades (no se le asignan órdenes de servicio). Un documento nuevo para la misma
-- designación (por ejemplo, con más actividades) reemplaza al pendiente; los firmados se
-- conservan y siguen valiendo para las actividades que incluyen.
--
-- Requiere 0011 ejecutada antes (rol de asistente de dirección técnica).
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

create table if not exists documentos_personal (
  id               uuid primary key default gen_random_uuid(),
  organismo_id     uuid not null references organismos(id),
  designacion_id   uuid not null references designaciones(id),
  tipo             text not null check (tipo in ('designacion_gerente', 'designacion_responsable_sg',
                     'autorizacion_director_tecnico', 'autorizacion_director_tecnico_suplente',
                     'autorizacion_inspector', 'designacion_asistente_direccion_tecnica')),
  titulo           text not null,
  contenido        text not null,                 -- texto completo que se firma
  huella           text not null,                 -- SHA-256 del contenido (la calcula la base de datos)
  actividades      text[] not null default '{}',  -- actividades autorizadas que incluye
  evaluador_id     uuid references personas(id),  -- director técnico que evaluó al inspector
  creado_por       uuid default auth.uid(),
  creado_en        timestamptz not null default now(),
  reemplazado_en   timestamptz,
  firmado_a_mano_ruta text,                       -- PDF firmado a mano (respaldo)
  firmado_a_mano_por  uuid references personas(id),
  firmado_a_mano_en   timestamptz
);
create index if not exists documentos_personal_designacion on documentos_personal (designacion_id, creado_en desc);

create table if not exists firmas_documento (
  id             uuid primary key default gen_random_uuid(),
  documento_id   uuid not null references documentos_personal(id),
  organismo_id   uuid not null references organismos(id),
  persona_id     uuid not null references personas(id),
  en_calidad     text not null check (en_calidad in ('designado', 'gerente', 'director_tecnico', 'evaluador')),
  huella         text not null,
  firmado_en     timestamptz not null default now(),
  usuario_id     uuid,
  correo         text,
  autenticado_en timestamptz,                     -- cuándo confirmó su contraseña
  agente         text,                            -- navegador
  ip             text,
  unique (documento_id, en_calidad)
);

drop trigger if exists bitacora_documentos_personal on documentos_personal;
create trigger bitacora_documentos_personal before insert or update or delete on documentos_personal
  for each row execute function registrar_bitacora();
drop trigger if exists bitacora_firmas_documento on firmas_documento;
create trigger bitacora_firmas_documento before insert or update or delete on firmas_documento
  for each row execute function registrar_bitacora();

-- ─────────────────── Qué documento lleva cada rol y quién lo firma ───────────────────
create or replace function tipo_documento_de_rol(p_rol text) returns text
language sql immutable as $$
  select case p_rol
    when 'gerente' then 'designacion_gerente'
    when 'responsable_sg' then 'designacion_responsable_sg'
    when 'director_tecnico' then 'autorizacion_director_tecnico'
    when 'director_tecnico_suplente' then 'autorizacion_director_tecnico_suplente'
    when 'inspector' then 'autorizacion_inspector'
    when 'asistente_direccion_tecnica' then 'designacion_asistente_direccion_tecnica'
  end
$$;

create or replace function firmas_requeridas(p_tipo text) returns text[]
language sql immutable as $$
  select case p_tipo
    when 'designacion_gerente' then array['designado']
    when 'autorizacion_director_tecnico_suplente' then array['gerente', 'director_tecnico']
    when 'autorizacion_inspector' then array['gerente', 'evaluador']
    else array['gerente']
  end
$$;

create or replace function documento_firmado(p_documento uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from documentos_personal x
     where x.id = p_documento
       and (x.firmado_a_mano_ruta is not null
            or firmas_requeridas(x.tipo) <@ coalesce((select array_agg(f.en_calidad) from firmas_documento f where f.documento_id = x.id), '{}')))
$$;

-- ¿La designación tiene su documento firmado? (los roles sin documento, siempre sí)
create or replace function designacion_firmada(p_designacion uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(tipo_documento_de_rol((select d.rol::text from designaciones d where d.id = p_designacion)) is null, true)
      or exists (select 1 from documentos_personal x where x.designacion_id = p_designacion and documento_firmado(x.id))
$$;

-- ¿La actividad está en un documento de autorización firmado de esa designación?
create or replace function actividad_firmada(p_designacion uuid, p_actividad text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from documentos_personal x
                  where x.designacion_id = p_designacion and p_actividad = any(x.actividades) and documento_firmado(x.id))
$$;

-- Designación vigente (y firmada) de la persona actual con uno de los roles.
create or replace function tengo_rol_firmado(org uuid, roles text[]) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from designaciones d
                  where d.organismo_id = org and d.persona_id = persona_actual() and d.rol::text = any(roles)
                    and d.desde <= current_date and (d.hasta is null or d.hasta >= current_date)
                    and designacion_firmada(d.id))
$$;

-- ─────────────────── Quién ve los documentos ───────────────────
create or replace function ve_documento_personal(p_documento uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and exists (
    select 1 from documentos_personal x join designaciones d on d.id = x.designacion_id
     where x.id = p_documento
       and (tiene_rol(x.organismo_id, roles_hoja_de_vida()) or en_arranque(x.organismo_id) or en_revision(x.organismo_id)
            or d.persona_id = persona_actual() or x.evaluador_id = persona_actual()))
$$;

-- ─────────────────── Al generar un documento ───────────────────
create or replace function preparar_documento_personal() returns trigger
language plpgsql security definer set search_path = public as $$
declare d designaciones;
begin
  select * into d from designaciones where id = new.designacion_id;
  if d.id is null then raise exception 'La designación no existe'; end if;
  new.organismo_id := d.organismo_id;
  new.tipo := tipo_documento_de_rol(d.rol::text);
  if new.tipo is null then raise exception 'Este rol no lleva documento de designación o autorización'; end if;
  if d.hasta is not null and d.hasta < current_date then raise exception 'La designación ya terminó'; end if;
  new.actividades := coalesce((select array_agg(da.actividad_codigo order by da.actividad_codigo)
                                 from designacion_actividades da where da.designacion_id = d.id), '{}');
  if new.tipo like 'autorizacion_%' and cardinality(new.actividades) = 0 then
    raise exception 'Primero autorice las actividades: el documento de autorización las incluye';
  end if;
  if new.tipo = 'autorizacion_inspector' then
    if new.evaluador_id is null then raise exception 'Indique el director técnico que evaluó al inspector'; end if;
    if new.evaluador_id = d.persona_id then raise exception 'El inspector no puede evaluarse a sí mismo'; end if;
    if not exists (select 1 from designaciones x
                    where x.organismo_id = d.organismo_id and x.persona_id = new.evaluador_id
                      and x.rol in ('director_tecnico', 'director_tecnico_suplente')
                      and x.desde <= current_date and (x.hasta is null or x.hasta >= current_date)) then
      raise exception 'Quien evaluó al inspector debe ser director técnico o director técnico suplente vigente del organismo';
    end if;
  else
    new.evaluador_id := null;
  end if;
  if coalesce(trim(new.contenido), '') = '' then raise exception 'El documento no tiene texto'; end if;
  new.huella := encode(sha256(convert_to(new.contenido, 'UTF8')), 'hex');
  new.creado_por := auth.uid();
  new.creado_en := now();
  new.reemplazado_en := null;
  new.firmado_a_mano_ruta := null; new.firmado_a_mano_por := null; new.firmado_a_mano_en := null;
  -- El pendiente de firma anterior queda reemplazado (los firmados se conservan).
  update documentos_personal x set reemplazado_en = now()
   where x.designacion_id = d.id and x.reemplazado_en is null and not documento_firmado(x.id);
  return new;
end $$;

drop trigger if exists a_preparar_documento_personal on documentos_personal;
create trigger a_preparar_documento_personal before insert on documentos_personal
  for each row execute function preparar_documento_personal();

alter table documentos_personal enable row level security;
alter table firmas_documento enable row level security;
drop policy if exists lectura on documentos_personal;
create policy lectura on documentos_personal for select to authenticated using (ve_documento_personal(id));
drop policy if exists generacion on documentos_personal;
create policy generacion on documentos_personal for insert to authenticated
  with check (gestiona_organismo(organismo_id)
              or tiene_rol(organismo_id, array['director_tecnico', 'director_tecnico_suplente']::rol_oec[]));
drop policy if exists lectura on firmas_documento;
create policy lectura on firmas_documento for select to authenticated using (ve_documento_personal(documento_id));
-- Sin más políticas: las firmas solo se registran con firmar_documento() y nada se modifica ni se borra.

-- ─────────────────── Firmar ───────────────────
create or replace function firmar_documento(p_documento uuid, p_en_calidad text, p_huella text)
returns void language plpgsql security definer set search_path = public as $$
declare
  x documentos_personal; d designaciones; yo uuid := persona_actual();
  claims jsonb := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  cabeceras jsonb;
  autenticado timestamptz;
begin
  select * into x from documentos_personal where id = p_documento;
  if x.id is null or not ve_documento_personal(x.id) then raise exception 'El documento no existe'; end if;
  if x.reemplazado_en is not null then raise exception 'Este documento fue reemplazado por uno más reciente'; end if;
  if documento_firmado(x.id) then raise exception 'El documento ya está firmado'; end if;
  if not p_en_calidad = any(firmas_requeridas(x.tipo)) then raise exception 'Este documento no lleva esa firma'; end if;
  if exists (select 1 from firmas_documento f where f.documento_id = x.id and f.en_calidad = p_en_calidad) then
    raise exception 'Esa firma ya está registrada';
  end if;
  if p_huella is distinct from x.huella then
    raise exception 'El documento cambió desde que lo abrió: vuelva a abrirlo y léalo antes de firmar';
  end if;
  if yo is null then raise exception 'Su usuario no está enlazado a una persona'; end if;
  select * into d from designaciones where id = x.designacion_id;

  if p_en_calidad = 'designado' and yo is distinct from d.persona_id then
    raise exception 'Solo la persona designada firma este documento';
  elsif p_en_calidad = 'gerente' and not tengo_rol_firmado(x.organismo_id, array['gerente']) then
    raise exception 'Firma el gerente del organismo, con su designación vigente y firmada';
  elsif p_en_calidad = 'director_tecnico' then
    if yo = d.persona_id then raise exception 'Nadie firma su propia autorización como director técnico'; end if;
    if not tengo_rol_firmado(x.organismo_id, array['director_tecnico']) then
      raise exception 'Firma el director técnico principal, con su autorización vigente y firmada';
    end if;
  elsif p_en_calidad = 'evaluador' then
    if yo is distinct from x.evaluador_id then raise exception 'Firma el director técnico que evaluó al inspector'; end if;
    if not tengo_rol_firmado(x.organismo_id, array['director_tecnico', 'director_tecnico_suplente']) then
      raise exception 'Quien evaluó debe tener su autorización de director técnico vigente y firmada';
    end if;
  end if;

  -- Confirmación de la contraseña (o código) en los últimos 10 minutos.
  select to_timestamp(max((e->>'timestamp')::bigint)) into autenticado
    from jsonb_array_elements(coalesce(claims->'amr', '[]'::jsonb)) e;
  if autenticado is null or autenticado < now() - interval '10 minutes' then
    raise exception 'Para firmar, confirme su contraseña (la confirmación vale 10 minutos)';
  end if;

  cabeceras := nullif(current_setting('request.headers', true), '')::jsonb;
  insert into firmas_documento (documento_id, organismo_id, persona_id, en_calidad, huella, usuario_id, correo,
                                autenticado_en, agente, ip)
  values (x.id, x.organismo_id, yo, p_en_calidad, x.huella, auth.uid(), correo_actual(), autenticado,
          cabeceras->>'user-agent',
          coalesce(cabeceras->>'cf-connecting-ip', split_part(cabeceras->>'x-forwarded-for', ',', 1), cabeceras->>'x-real-ip'));
end $$;

-- Respaldo: documento impreso, firmado a mano y escaneado. Lo carga la gerencia o el SG.
create or replace function registrar_firmado_a_mano(p_documento uuid, p_ruta text)
returns void language plpgsql security definer set search_path = public as $$
declare x documentos_personal;
begin
  select * into x from documentos_personal where id = p_documento;
  if x.id is null or not ve_documento_personal(x.id) then raise exception 'El documento no existe'; end if;
  if not gestiona_organismo(x.organismo_id) then
    raise exception 'El documento firmado a mano lo carga la gerencia o el responsable del SG';
  end if;
  if x.reemplazado_en is not null then raise exception 'Este documento fue reemplazado por uno más reciente'; end if;
  if documento_firmado(x.id) then raise exception 'El documento ya está firmado'; end if;
  if p_ruta not like x.organismo_id::text || '/personal/' || x.id::text || '/%' then
    raise exception 'El archivo debe estar en la carpeta del documento';
  end if;
  update documentos_personal set firmado_a_mano_ruta = p_ruta, firmado_a_mano_por = persona_actual(), firmado_a_mano_en = now()
   where id = x.id;
end $$;

revoke execute on function firmar_documento(uuid, text, text) from public, anon;
revoke execute on function registrar_firmado_a_mano(uuid, text) from public, anon;
grant execute on function firmar_documento(uuid, text, text) to authenticated;
grant execute on function registrar_firmado_a_mano(uuid, text) to authenticated;

-- ─────────────────── Carpeta de los documentos firmados a mano ───────────────────
-- Ruta: documentos/<organismo>/personal/<documento>/<archivo>.pdf
create or replace function documento_de_carpeta(nombre text) returns uuid
language plpgsql immutable as $$
begin
  return ((storage.foldername(nombre))[3])::uuid;
exception when others then
  return null;
end $$;

drop policy if exists personal_lectura on storage.objects;
create policy personal_lectura on storage.objects for select to authenticated
  using (bucket_id = 'documentos' and segunda_carpeta(name) = 'personal' and ve_documento_personal(documento_de_carpeta(name)));
drop policy if exists personal_carga on storage.objects;
create policy personal_carga on storage.objects for insert to authenticated
  with check (bucket_id = 'documentos' and segunda_carpeta(name) = 'personal'
              and gestiona_organismo(persona_de_carpeta(name)) and ve_documento_personal(documento_de_carpeta(name)));

-- ─────────────────── Ejercer exige la autorización firmada ───────────────────
-- Asignación de una orden: igual que en 0001, y además la actividad debe estar en una
-- autorización firmada del inspector.
create or replace function validar_asignacion() returns trigger
language plpgsql as $$
declare motivo text;
begin
  if new.inspector_id is null then return new; end if;
  if tg_op = 'UPDATE' and new.inspector_id is not distinct from old.inspector_id then return new; end if;

  if new.solicitud_revisada_en is null then
    raise exception 'La solicitud % no ha sido revisada (17020 §7.1.6)', new.consecutivo;
  end if;
  if not exists (
    select 1 from designaciones d join designacion_actividades da on da.designacion_id = d.id
    where d.organismo_id = new.organismo_id and d.persona_id = new.inspector_id and d.rol = 'inspector'
      and da.actividad_codigo = new.actividad_codigo
      and d.desde <= current_date and (d.hasta is null or d.hasta >= current_date)
  ) then
    raise exception 'El inspector no está autorizado para la actividad % en este organismo (17020 §6.1.6)', new.actividad_codigo;
  end if;
  if not exists (
    select 1 from designaciones d
    where d.organismo_id = new.organismo_id and d.persona_id = new.inspector_id and d.rol = 'inspector'
      and d.desde <= current_date and (d.hasta is null or d.hasta >= current_date)
      and actividad_firmada(d.id, new.actividad_codigo)
  ) then
    raise exception 'La autorización del inspector para la actividad % no está firmada (gerente y director técnico)', new.actividad_codigo;
  end if;
  motivo := puede_ejercer(new.organismo_id, new.inspector_id, new.actividad_codigo);
  if motivo is not null then raise exception '%', motivo; end if;
  if exists (
    select 1 from conflictos_interes c
    where c.persona_id = new.inspector_id and c.cliente_id = new.cliente_id and c.vigente
  ) then
    raise exception 'El inspector declaró conflicto de interés con este cliente (17020 §4.1)';
  end if;
  return new;
end $$;

select 'Migración 0013 aplicada: documentos de designación y autorización con firma electrónica' as resultado;


-- >>>>>>>>>> supabase/migrations/0014_verificacion_soportes.sql
-- ============================================================================
-- Ultra RETIE — 0014 Verificación de los soportes de competencia y formación
--
-- Todo lo que tiene que ver con la competencia y la formación de una persona
-- (experiencia, formación académica y certificados de competencias) cuenta solo si
-- lo verificó alguien de:
--   · la gerencia (representante legal, gerente, miembro de la gerencia),
--   · el sistema de gestión (responsable del SG o su suplente),
--   · la dirección técnica (director técnico o su suplente),
-- de un organismo donde la persona está vinculada. Nunca la misma persona.
-- Queda quién verificó y cuándo (lo pone la base de datos).
-- Si después cambian los datos o el soporte de algo verificado, la verificación se
-- pierde y hay que verificarlo de nuevo. El seguimiento del mes 30 no la quita.
-- Los certificados de competencias ya registrados quedan SIN verificar.
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

alter table experiencias add column if not exists verificada_en timestamptz;
alter table formacion add column if not exists verificada_en timestamptz;
alter table certificados_competencia add column if not exists verificada boolean not null default false;
alter table certificados_competencia add column if not exists verificada_por uuid references personas(id);
alter table certificados_competencia add column if not exists verificada_en timestamptz;

create or replace function roles_verificacion() returns rol_oec[]
language sql immutable as $$
  select roles_gerencia() || array['responsable_sg', 'suplente_sg', 'director_tecnico', 'director_tecnico_suplente']::rol_oec[]
$$;

-- ¿Quien inició sesión puede verificar los soportes de esta persona?
create or replace function puede_verificar(p_persona uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and persona_actual() is not null and persona_actual() <> p_persona
     and exists (select 1 from organismos o
                  where tiene_rol(o.id, roles_verificacion())
                    and (o.id in (select organismos_de(p_persona)) or registrada_por_mi_sin_vincular(p_persona)))
$$;

-- Quienes verifican también pueden marcar la verificación en la hoja de vida.
create or replace function gestiona_hoja_de_vida(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
       p = persona_actual()
    or exists (select 1 from organismos_de(p) o(id) where administra(o.id) or tiene_rol(o.id, roles_verificacion()))
    or registrada_por_mi_sin_vincular(p))
$$;

-- Control de la verificación en experiencias, formación y certificados.
create or replace function controlar_verificacion() returns trigger
language plpgsql as $$
declare
  ignorar text[] := array['verificada', 'verificada_por', 'verificada_en', 'seguimiento_fecha', 'seguimiento_resultado',
                          'seguimiento_observacion', 'seguimiento_registrado_en', 'anulado'];
  cambio boolean := false;
begin
  -- Si cambian los datos o el soporte de algo verificado, la verificación se pierde.
  if tg_op = 'UPDATE' and old.verificada and new.verificada then
    cambio := (to_jsonb(new) - ignorar) is distinct from (to_jsonb(old) - ignorar);
    if cambio then new.verificada := false; end if;
  end if;

  if new.verificada and (tg_op = 'INSERT' or not old.verificada) then
    if auth.uid() is not null then
      if persona_actual() is null then
        raise exception 'Para verificar soportes, su usuario (%) debe estar registrado como persona', correo_actual();
      end if;
      if new.verificada_por is distinct from persona_actual() then
        raise exception 'La verificación queda a nombre de quien inició sesión';
      end if;
      if new.persona_id = persona_actual() then
        raise exception 'El soporte debe verificarlo otra persona del organismo (no se permite la autoverificación)';
      end if;
      if not puede_verificar(new.persona_id) then
        raise exception 'Verifican los soportes la gerencia, el responsable del SG (o su suplente) o un director técnico (o su suplente) del organismo';
      end if;
    end if;
    if new.verificada_por is null or new.verificada_por = new.persona_id then
      raise exception 'El soporte debe verificarlo otra persona del organismo (no se permite la autoverificación)';
    end if;
    new.verificada_en := now();
  elsif tg_op = 'UPDATE' and old.verificada and not new.verificada and not cambio then
    if auth.uid() is not null and not puede_verificar(new.persona_id) then
      raise exception 'Quitan la verificación la gerencia, el responsable del SG (o su suplente) o un director técnico (o su suplente)';
    end if;
    new.verificada_por := null; new.verificada_en := null;
  elsif not new.verificada then
    new.verificada_por := null; new.verificada_en := null;
  else
    new.verificada_por := old.verificada_por; new.verificada_en := old.verificada_en;
  end if;
  return new;
end $$;

drop trigger if exists validar_verificacion on experiencias;
drop trigger if exists validar_verificacion on formacion;
drop trigger if exists a_controlar_verificacion on experiencias;
drop trigger if exists a_controlar_verificacion on formacion;
drop trigger if exists a_controlar_verificacion on certificados_competencia;
create trigger a_controlar_verificacion before insert or update on experiencias
  for each row execute function controlar_verificacion();
create trigger a_controlar_verificacion before insert or update on formacion
  for each row execute function controlar_verificacion();
-- Los campos del seguimiento del mes 30 no cuentan como cambio (los maneja a_proteger_seguimiento, 0011).
create trigger a_controlar_verificacion before insert or update on certificados_competencia
  for each row execute function controlar_verificacion();

-- Requisitos de competencia: igual que en 0010; el certificado, además, verificado.
create or replace function motivo_competencia(p_persona uuid, p_actividad text, p_rol text, p_fecha date default current_date)
returns text language plpgsql stable as $$
declare
  a actividades; r reglamentos; k categorias_competencia; p personas;
  cat_exp text; anios numeric; dir numeric;
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

  cat_exp := case when r.experiencia_por_categoria then k.codigo end;
  anios := anios_experiencia(p_persona, r.id, cat_exp, r.tipos_experiencia_tecnica, p_fecha);
  if anios < k.experiencia_inspector_anios then
    return format('Experiencia verificada insuficiente: %s de %s años', round(anios, 1), k.experiencia_inspector_anios);
  end if;

  if p_rol = 'director_tecnico' then
    cat_exp := case when r.dt_por_categoria then k.codigo end;
    anios := anios_experiencia(p_persona, r.id, cat_exp, r.tipos_experiencia_tecnica || r.dt_tipos_direccion, p_fecha);
    dir := anios_experiencia(p_persona, r.id, cat_exp, r.dt_tipos_direccion, p_fecha);
    if (r.dt_total_estricta and anios <= r.dt_experiencia_total) or (not r.dt_total_estricta and anios < r.dt_experiencia_total) then
      return format('Experiencia de director técnico insuficiente: %s años (%s %s)', round(anios, 1),
                    case when r.dt_total_estricta then 'más de' else 'mínimo' end, r.dt_experiencia_total);
    end if;
    if dir < r.dt_experiencia_direccion then
      return format('Experiencia en gerencia/dirección insuficiente: %s de %s años', round(dir, 1), r.dt_experiencia_direccion);
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

select 'Migración 0014 aplicada: verificación de los soportes de competencia y formación' as resultado;


-- >>>>>>>>>> supabase/migrations/0015_experiencia_por_tipo_generacion.sql
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
