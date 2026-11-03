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
