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

export type LineaAlcance = {
  actividad: string; estado: EstadoLinea; fechaEstado: string; observacion?: string;
  /** Quién fijó el estado y en calidad de qué (lo registra la base de datos, 0009). */
  estadoPor?: string; estadoEnCalidad?: string;
};

export type Sede = { id: string; nombre: string; direccion?: string; ciudad?: string; principal: boolean };

export type Organismo = {
  id: string;
  razonSocial: string;
  sigla?: string;
  nit: string;
  tipo: "A";
  codigoAcreditacion?: string;
  acreditacionOtorgada?: string;
  /** Última renovación y última actualización publicada por ONAC (del certificado vigente). */
  acreditacionRenovada?: string;
  acreditacionActualizada?: string;
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
  /** Usuario que lo creó (Supabase). Lo asigna la base de datos. */
  creadoPor?: string;
  /** Logo del organismo: ruta en el almacenamiento (Supabase) o imagen en línea (modo local). */
  logoRuta?: string;
  /** Símbolo de acreditado ONAC: solo en el informe de no conformidades y en el dictamen. */
  simboloOnacRuta?: string;
};

/** Certificado de competencias (ISO/IEC 17024) por categorías del reglamento. */
export type CertificadoCompetencia = {
  id: string;
  numero: string;
  certificador: string;
  reglamento: string;          // "RETIE-2024" | "RETILAP-2024"
  categorias: string[];        // RETIE: "a".."g"; RETILAP: "1".."5"
  fechaEmision: string;
  fechaVencimiento: string;    // por defecto emisión + 5 años
  /** Seguimiento obligatorio al mes 30 (RETIE §4.4.2.6 / RETILAP §4.5.2.6). */
  seguimiento?: { fecha: string; resultado: "conforme" | "no_conforme"; observacion?: string };
  anulado: boolean;
  /** Archivo de soporte (PDF o imagen) en la carpeta privada de la persona. */
  soporteRuta?: string;
};

export type Formacion = {
  id: string;
  tipo: "pregrado" | "especializacion" | "maestria" | "doctorado" | "curso_profundizacion" | "otro";
  titulo: string;
  institucion: string;
  fecha: string;
  /** Áreas de iluminación que incluye (plan de estudios del posgrado o tema del curso). */
  areasIluminacion: string[];
  /** Posgrado/curso en iluminación o alumbrado público (RETILAP §4.5.2.5-2). */
  enIluminacion: boolean;
  verificada: boolean;
  /** Persona que verificó el soporte (quien inició sesión; nunca la misma persona). */
  verificadaPor?: string;
  /** Archivo de soporte (PDF o imagen) en la carpeta privada de la persona. */
  soporteRuta?: string;
};

export type Experiencia = {
  id: string;
  empresa: string;
  cargo: string;
  desde: string;
  hasta?: string;              // vacío = actual
  reglamento: string;          // a qué tipo de instalaciones corresponde
  categorias: string[];        // RETIE: categorías de instalación; RETILAP: opcional
  tipos: string[];             // TipoExperiencia
  descripcion?: string;
  /** El soporte (certificación laboral) fue revisado por el OI. Solo cuenta la experiencia verificada. */
  verificada: boolean;
  /** Persona que verificó el soporte (quien inició sesión; nunca la misma persona). */
  verificadaPor?: string;
  /** Archivo de soporte (PDF o imagen) en la carpeta privada de la persona. */
  soporteRuta?: string;
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
  /** Especialidad de ingeniería que figura en la matrícula (Ley 842 de 2003 / Ley 51 de 1986). */
  matriculaEspecialidad?: string;
  /** Matrícula de otra entidad aceptada por la gerencia (0010). Lo registra la base de datos. */
  matriculaAceptadaPor?: string;
  matriculaAceptadaEn?: string;
  matriculaAceptadaMotivo?: string;
  formacion: Formacion[];
  experiencias: Experiencia[];
  certificados: CertificadoCompetencia[];
  creado: string;
  /** Usuario de acceso enlazado (Supabase Auth). Lo asigna la base de datos por el correo. */
  usuarioId?: string;
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

/** Documento del organismo con historial: cada carga es una versión; la anterior queda reemplazada. */
export type TipoDocumentoOrganismo = "acreditacion" | "poliza_rc" | "independencia";
export type DocumentoOrganismo = {
  id: string;
  organismoId: string;
  tipo: TipoDocumentoOrganismo;
  archivoRuta: string;
  numero?: string;        // código de acreditación o número de póliza
  emisor?: string;        // ONAC o aseguradora
  valor?: number;         // valor asegurado
  fecha?: string;         // otorgamiento o firma
  renovacion?: string;
  actualizacion?: string;
  desde?: string;
  hasta?: string;         // vencimiento
  firmadoPor?: string;
  observacion?: string;
  cargado: string;
  reemplazadoEn?: string;
};

export type BaseOrganismos = {
  organismos: Organismo[];
  personas: Persona[];
  vinculaciones: Vinculacion[];
  designaciones: Designacion[];
  declaraciones: Declaracion[];
  revisionesSG: RevisionSG[];
  /** Documentos del organismo (0008). Opcional para datos guardados antes. */
  documentos?: DocumentoOrganismo[];
};

export type Plazos = { vigenciaDeclaraciones: number; revisionResponsableSG: number; alertaAnticipada: number; alertaAcreditacion: number };
export const PLAZOS_POR_DEFECTO: Plazos = { vigenciaDeclaraciones: 365, revisionResponsableSG: 30, alertaAnticipada: 60, alertaAcreditacion: 90 };

/** Rol técnico para efectos de requisitos de competencia. */
export type RolTecnico = "inspector" | "director_tecnico";
export const rolTecnico = (r: RolOEC): RolTecnico => (r === "inspector" ? "inspector" : "director_tecnico");
