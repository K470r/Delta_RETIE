/** Modelo de dominio del OEC. Refleja las tablas de supabase/migrations. */

export type Rol =
  | "vendedor"
  | "inspector"
  | "revisor"
  | "director_tecnico"
  | "director_tecnico_suplente"
  | "calidad"
  | "administrativo";

/** Alcances de inspección RETIE (se ajustan al alcance acreditado ante ONAC). */
export type Alcance =
  | "USO_FINAL_RESIDENCIAL"
  | "USO_FINAL_NO_RESIDENCIAL"
  | "DISTRIBUCION"
  | "TRANSFORMACION"
  | "GENERACION"
  | "TRANSMISION";

export const NOMBRE_ALCANCE: Record<Alcance, string> = {
  USO_FINAL_RESIDENCIAL: "Uso final residencial",
  USO_FINAL_NO_RESIDENCIAL: "Uso final no residencial",
  DISTRIBUCION: "Distribución",
  TRANSFORMACION: "Transformación",
  GENERACION: "Generación",
  TRANSMISION: "Transmisión",
};

export type Persona = {
  id: string;
  nombre: string;
  roles: Rol[];
  matriculaProfesional?: { numero: string; vence?: string };
  /** Fecha de la última declaración de imparcialidad y conflictos de interés firmada. */
  declaracionImparcialidad?: string;
  /** Fecha de firma del acuerdo de confidencialidad. */
  acuerdoConfidencialidad?: string;
  alcancesAutorizados: Alcance[];
  ultimaSupervisionEnSitio?: string;
  /** Clientes con los que la persona declaró conflicto de interés. */
  conflictosConClientes: string[];
  activo: boolean;
};

export type Equipo = {
  id: string;
  codigo: string;
  nombre: string;
  marcaModelo: string;
  serie: string;
  ultimaCalibracion: string;
  vencimientoCalibracion: string;
  proximaVerificacionIntermedia?: string;
  estado: "operativo" | "fuera_de_servicio";
};

export type Cliente = { id: string; nombre: string; nit: string };

export type EstadoOrden =
  | "cotizada"
  | "aprobada"
  | "asignada"
  | "en_inspeccion"
  | "en_revision"
  | "emitida"
  | "entregada"
  | "cancelada";

export type OrdenServicio = {
  id: string;
  consecutivo: string;
  clienteId: string;
  instalacion: string;
  alcance: Alcance;
  estado: EstadoOrden;
  /** Revisión de la solicitud (capacidad, alcance, imparcialidad) antes de aceptar. */
  solicitudRevisada: boolean;
  inspectorId?: string;
  revisorId?: string;
  fechaInspeccion?: string;
  equiposUsados: string[];
  formato: { codigo: string; version: string };
  itemsTotales: number;
  itemsEvaluados: number;
  ncSinEvidencia: number;
  fechaEmision?: string;
};

export type QuejaApelacion = {
  id: string;
  tipo: "queja" | "apelacion";
  descripcion: string;
  fechaRecepcion: string;
  fechaAcuse?: string;
  estado: "abierta" | "cerrada";
  decisorId?: string;
  involucradosIds: string[];
};

export type AccionCorrectiva = {
  id: string;
  origen: string;
  descripcion: string;
  fechaLimite: string;
  estado: "abierta" | "implementada" | "cerrada";
  eficaciaVerificada: boolean;
};

export type DocumentoControlado = {
  codigo: string;
  titulo: string;
  version: string;
  fechaRevision: string;
  estado: "vigente" | "obsoleto";
};

export type Subcontratista = { nombre: string; evaluacionVence: string };

export type ConfiguracionOEC = {
  nombre: string;
  /** Tipo de organismo según el anexo A de ISO/IEC 17020. */
  tipoOrganismo: "A" | "B" | "C";
  polizaRCVence?: string;
  directorTecnicoId?: string;
  directorTecnicoSuplenteId?: string;
  /** Versiones vigentes de los formatos de inspección. */
  formatosVigentes: Record<string, string>;
  /** Plazos configurables (días) — deben coincidir con los procedimientos del OEC. */
  plazos: {
    vigenciaDeclaracionImparcialidad: number;
    vigenciaSupervisionEnSitio: number;
    revisionDocumentos: number;
    auditoriaInterna: number;
    revisionDireccion: number;
    analisisRiesgosImparcialidad: number;
    acuseQueja: number;
    resolucionQueja: number;
    emisionDictamen: number;
    alertaAnticipada: number;
  };
};

export type DatosOEC = {
  config: ConfiguracionOEC;
  personas: Persona[];
  equipos: Equipo[];
  clientes: Cliente[];
  ordenes: OrdenServicio[];
  quejas: QuejaApelacion[];
  acciones: AccionCorrectiva[];
  documentos: DocumentoControlado[];
  subcontratistas: Subcontratista[];
  auditoriasInternas: { fecha: string; numeralesCubiertos: string[] }[];
  revisionesDireccion: { fecha: string }[];
  analisisRiesgosImparcialidad: { fecha: string }[];
};
