/** Modelo del organismo y su personal. Refleja supabase/migrations/0001_esquema_base.sql. */

export type RolOEC =
  | "representante_legal"
  | "gerente"
  | "miembro_gerencia"
  | "responsable_sg"
  | "suplente_sg"
  | "director_tecnico"
  | "director_tecnico_suplente"
  | "inspector";

export const NOMBRE_ROL: Record<RolOEC, string> = {
  representante_legal: "Representante legal",
  gerente: "Gerente",
  miembro_gerencia: "Miembro de la gerencia",
  responsable_sg: "Responsable del sistema de gestión",
  suplente_sg: "Suplente del responsable del SG",
  director_tecnico: "Director técnico",
  director_tecnico_suplente: "Director técnico suplente",
  inspector: "Inspector",
};

/** Roles que llevan actividades autorizadas (17020 §6.1.6). */
export const ROLES_CON_ACTIVIDADES: RolOEC[] = ["director_tecnico", "director_tecnico_suplente", "inspector"];
/** Roles de los que solo puede haber una persona vigente a la vez. */
export const ROLES_UNICOS: RolOEC[] = ["representante_legal", "responsable_sg"];

export type EstadoLinea = "en_tramite" | "acreditada" | "suspendida" | "retirada";

export type LineaAlcance = { actividad: string; estado: EstadoLinea; fechaEstado: string; observacion?: string };

export type Sede = { id: string; nombre: string; direccion?: string; ciudad?: string; principal: boolean };

export type Organismo = {
  id: string;
  razonSocial: string;
  sigla?: string;
  nit: string;
  tipo: "A";
  codigoAcreditacion?: string;
  acreditacionOtorgada?: string;
  acreditacionVence?: string;
  direccion?: string;
  ciudad?: string;
  telefono?: string;
  correo?: string;
  /** Declaración de independencia del organismo tipo A (17020 Anexo A.1). */
  declaracionIndependencia?: string;
  polizaRCNumero?: string;
  polizaRCVence?: string;
  sedes: Sede[];
  alcance: LineaAlcance[];
  creado: string;
};

export type CertificadoCompetencia = {
  id: string;
  numero: string;
  certificador: string;
  fechaEmision: string;
  fechaVencimiento: string;
  actividades: string[];
  anulado: boolean;
};

export type Persona = {
  id: string;
  tipoDocumento: "CC" | "CE" | "PA" | "PPT";
  documento: string;
  nombres: string;
  apellidos: string;
  correo?: string;
  telefono?: string;
  profesion?: string;
  matriculaNumero?: string;
  matriculaEntidad?: string;
  certificados: CertificadoCompetencia[];
  creado: string;
};

export type Vinculacion = {
  id: string;
  organismoId: string;
  personaId: string;
  sedeId?: string;
  tipo: "laboral" | "prestacion_servicios" | "otro";
  cargo: string;
  desde: string;
  hasta?: string;
};

export type Designacion = {
  id: string;
  organismoId: string;
  personaId: string;
  rol: RolOEC;
  desde: string;
  hasta?: string;
  acto?: string;
  actividades: string[];
};

export type Declaracion = {
  id: string;
  organismoId: string;
  personaId: string;
  tipo: "imparcialidad" | "confidencialidad";
  fecha: string;
};

export type RevisionSG = {
  id: string;
  organismoId: string;
  personaId: string;
  fecha: string;
  aspectos: string[];
  observaciones: string;
  requiereAccion: boolean;
};

export type BaseOrganismos = {
  organismos: Organismo[];
  personas: Persona[];
  vinculaciones: Vinculacion[];
  designaciones: Designacion[];
  declaraciones: Declaracion[];
  revisionesSG: RevisionSG[];
};

export type Plazos = { vigenciaDeclaraciones: number; revisionResponsableSG: number; alertaAnticipada: number; alertaAcreditacion: number };
export const PLAZOS_POR_DEFECTO: Plazos = { vigenciaDeclaraciones: 365, revisionResponsableSG: 30, alertaAnticipada: 60, alertaAcreditacion: 90 };
