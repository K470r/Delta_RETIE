/**
 * Requisitos de competencia del personal técnico por reglamento (versionados).
 * Fuente: datos/requisitos/*.json — RETIE 2024 §4.4.2.x y RETILAP 2024 §4.5.2.x.
 */
import retie from "@datos/requisitos/retie_2024.json";
import retilap from "@datos/requisitos/retilap_2024.json";

export type TipoExperiencia =
  | "diseno" | "construccion" | "operacion" | "mantenimiento" | "interventoria" | "inspeccion"
  | "direccion_tecnica_oi" | "gerencia_direccion" | "coordinacion_proyectos";

export const NOMBRE_TIPO_EXPERIENCIA: Record<TipoExperiencia, string> = {
  diseno: "Diseño", construccion: "Construcción", operacion: "Operación", mantenimiento: "Mantenimiento",
  interventoria: "Interventoría", inspeccion: "Inspección", direccion_tecnica_oi: "Dirección técnica de OI",
  gerencia_direccion: "Gerencia o dirección", coordinacion_proyectos: "Coordinación de proyectos",
};

export type Categoria = {
  codigo: string;
  nombre: string;
  actividades: string[];
  experienciaInspectorAnios: number;
  requiereCategoriaVigente?: string | null;
  notaExperiencia?: string;
};

export type RequisitosReglamento = {
  reglamento: string;
  fuente: string;
  exigeCertificado: boolean;
  notaCertificado: string;
  vigenciaCertificadoAnios: number;
  seguimientoMes: number;
  matriculaRequerida: boolean;
  formacionEspecializada: { texto: string; tipos: string[] } | null;
  areasProfundizacion?: Record<string, string>;
  profundizacionPorActividad?: Record<string, string>;
  categorias: Categoria[];
  experienciaPorCategoria: boolean;
  tiposExperienciaTecnica: TipoExperiencia[];
  directorTecnico: {
    experienciaTotalAnios: number;
    experienciaTotalEstricta: boolean;
    experienciaDireccionAnios: number;
    tiposExperienciaDireccion: TipoExperiencia[];
    porCategoria: boolean;
    texto: string;
  };
};

export const REQUISITOS: RequisitosReglamento[] = [retie as RequisitosReglamento, retilap as RequisitosReglamento];

export const requisitosDe = (reglamento: string) => REQUISITOS.find((r) => r.reglamento === reglamento);

export function categoriaDeActividad(actividad: string): { req: RequisitosReglamento; cat: Categoria } | undefined {
  for (const req of REQUISITOS) {
    const cat = req.categorias.find((c) => c.actividades.includes(actividad));
    if (cat) return { req, cat };
  }
}

export const etiquetaCategoria = (reglamento: string, codigo: string) =>
  `${reglamento.startsWith("RETILAP") ? "RETILAP" : "RETIE"} ${codigo}`;

/** Áreas de iluminación (RETILAP) que exigen curso de profundización si la especialización no las incluye. */
export const AREAS_ILUMINACION: Record<string, string> = (retilap as RequisitosReglamento).areasProfundizacion ?? {};
