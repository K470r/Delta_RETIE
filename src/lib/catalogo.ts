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
/** Actividades acreditables (las del catálogo ONAC; sin las variantes por tensión). */
export const ACTIVIDADES: Actividad[] = REGLAMENTOS.flatMap((r) => r.actividades);

// ───────────── Generación según la tensión (0012, docs/DECISIONES.md) ─────────────
// Más de 1.000 V AC o más de 1.500 V DC: categoría a. Hasta 1.000 V AC y 1.500 V DC: categoría g.
// La variante de baja tensión ("-BT") se autoriza al personal; no se acredita por separado.
export const LIMITE_AC = 1000;
export const LIMITE_DC = 1500;
export const ACTIVIDADES_POR_TENSION = ["RETIE24-GEN-FNCE", "RETIE24-GEN-VARIAS"];
export const varianteBT = (codigo: string) => (ACTIVIDADES_POR_TENSION.includes(codigo) ? `${codigo}-BT` : undefined);
/** Línea del alcance que cubre la actividad (la variante la cubre su actividad de generación). */
export const lineaDe = (codigo: string) => (codigo.endsWith("-BT") && ACTIVIDADES_POR_TENSION.includes(codigo.slice(0, -3)) ? codigo.slice(0, -3) : codigo);
export const esVarianteBT = (codigo: string) => lineaDe(codigo) !== codigo;
export const TEXTO_ALTA = "más de 1.000 V AC o más de 1.500 V DC";
export const TEXTO_BAJA = "hasta 1.000 V AC y 1.500 V DC";

const VARIANTES: Actividad[] = ACTIVIDADES.filter((a) => ACTIVIDADES_POR_TENSION.includes(a.codigo))
  .map((a) => ({ ...a, codigo: `${a.codigo}-BT`, nombre: `${a.nombre} — ${TEXTO_BAJA}` }));

/** Actividades que se autorizan al personal: las acreditadas y, para generación, también su variante de baja tensión. */
export function actividadesAutorizables(lineas: string[]): Actividad[] {
  return lineas.flatMap((c) => {
    const a = actividad(c);
    if (!a) return [];
    const bt = varianteBT(c);
    return bt ? [{ ...a, nombre: `${a.nombre} — ${TEXTO_ALTA}` }, actividad(bt)!] : [a];
  });
}

/**
 * Actividad con la que se atiende una instalación de generación (igual que la base de datos):
 * conectada a la red → generación (a o g según la tensión); no conectada → uso final
 * (autogeneración, g), salvo si supera 1.000 V AC o 1.500 V DC → generación con a.
 */
export function actividadSegunInstalacion(codigo: string, conectadaRed: boolean, vac: number, vdc: number): string {
  const bt = varianteBT(codigo);
  if (!bt) return codigo;
  if (vac > LIMITE_AC || vdc > LIMITE_DC) return codigo;
  return conectadaRed ? bt : "RETIE24-UF-AUTOGEN";
}

const POR_CODIGO = new Map([...ACTIVIDADES, ...VARIANTES].map((a) => [a.codigo, a]));

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

/** Nombre corto para autorizaciones: a la actividad de generación se le agrega su rango de tensión. */
export const nombreAutorizacion = (codigo: string) => (varianteBT(codigo) ? `${nombreCorto(codigo)} — ${TEXTO_ALTA}` : nombreCorto(codigo));

export function agrupar(actividades: Actividad[]): { reglamento: Reglamento; grupos: [string, Actividad[]][] }[] {
  return REGLAMENTOS.map((r) => {
    const grupos = new Map<string, Actividad[]>();
    for (const a of actividades.filter((x) => x.reglamento === r.id)) grupos.set(a.grupo, [...(grupos.get(a.grupo) ?? []), a]);
    return { reglamento: r, grupos: [...grupos.entries()] };
  }).filter((x) => x.grupos.length);
}
