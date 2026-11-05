/**
 * Matrícula profesional de ingeniero (0010_matricula_ingeniero.sql; la base de datos aplica la misma regla).
 * CPNIEMPA (Ley 51 de 1986) o COPNIA (Ley 842 de 2003). Otra entidad solo cuenta si la gerencia la acepta.
 * El CONTE matricula técnicos electricistas: no sirve para director técnico ni inspector.
 */
import type { Persona } from "./tipos";

export const ENTIDADES_MATRICULA = [
  { codigo: "CPNIEMPA", nombre: "CPNIEMPA – Consejo Profesional Nacional de Ingenierías Eléctrica, Mecánica y Profesiones Afines (Ley 51 de 1986)" },
  { codigo: "COPNIA", nombre: "COPNIA – Consejo Profesional Nacional de Ingeniería (Ley 842 de 2003)" },
];

export function entidadMatricula(e?: string): string | undefined {
  if (!e?.trim()) return undefined;
  const u = e.toUpperCase();
  if (u.includes("CPNIEMPA") || u.includes("ELÉCTRICA, MECÁNICA") || u.includes("ELECTRICA, MECANICA")) return "CPNIEMPA";
  if (u.includes("COPNIA")) return "COPNIA";
  return e.trim();
}

export const esConte = (e?: string) => !!e && /CONTE|T[ÉE]CNICOS ELECTRICISTAS/i.test(e);

export type EstadoMatricula = "sin_matricula" | "ingeniero" | "aceptada" | "conte" | "por_aceptar";

export function estadoMatricula(p: Persona): EstadoMatricula {
  if (!p.matriculaNumero?.trim()) return "sin_matricula";
  const e = entidadMatricula(p.matriculaEntidad);
  if (e === "CPNIEMPA" || e === "COPNIA") return "ingeniero";
  if (p.matriculaAceptadaEn) return "aceptada";
  if (esConte(e)) return "conte";
  return "por_aceptar";
}
