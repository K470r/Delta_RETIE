/** Catálogo de actividades acreditables (notas técnicas ONAC NTE-3.3-88 y NTE-3.3-89). */
import retie from "@datos/alcances/retie_2024.json";
import retilap from "@datos/alcances/retilap_2024.json";

export type Actividad = { codigo: string; grupo: string; nombre: string; referencias: string[]; reglamento: string };
export type Reglamento = { id: string; nombre: string; acto: string; fuente: string; actividades: Actividad[] };

const cargar = (d: typeof retie): Reglamento => ({
  id: d.reglamento,
  nombre: d.nombre,
  acto: d.acto,
  fuente: d.fuente,
  actividades: d.actividades.map((a) => ({ ...a, reglamento: d.reglamento })),
});

export const REGLAMENTOS: Reglamento[] = [cargar(retie), cargar(retilap)];
export const ACTIVIDADES: Actividad[] = REGLAMENTOS.flatMap((r) => r.actividades);
const POR_CODIGO = new Map(ACTIVIDADES.map((a) => [a.codigo, a]));

export function actividad(codigo: string): Actividad | undefined {
  return POR_CODIGO.get(codigo);
}

/** Nombre corto para listas: quita el prefijo repetido "Inspección de instalaciones eléctricas de". */
export function nombreCorto(codigo: string): string {
  const n = actividad(codigo)?.nombre ?? codigo;
  return n
    .replace(/^Inspección de instalaciones (eléctricas )?(de )?/i, "")
    .replace(/^Instalaciones eléctricas de /i, "")
    .replace(/^./, (c) => c.toUpperCase());
}

export function agrupar(actividades: Actividad[]): { reglamento: Reglamento; grupos: [string, Actividad[]][] }[] {
  return REGLAMENTOS.map((r) => {
    const grupos = new Map<string, Actividad[]>();
    for (const a of actividades.filter((x) => x.reglamento === r.id)) grupos.set(a.grupo, [...(grupos.get(a.grupo) ?? []), a]);
    return { reglamento: r, grupos: [...grupos.entries()] };
  }).filter((x) => x.grupos.length);
}
