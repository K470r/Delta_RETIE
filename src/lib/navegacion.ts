/**
 * Menú lateral (opción B, docs/DECISIONES.md): trabajo diario arriba, sistema 17020 abajo.
 * Cada persona ve las secciones de su rol.
 */
import type { NombreIcono } from "@/components/Icono";
import type { BaseOrganismos, RolOEC } from "./organismo/tipos";
import { vigenteEn, hoyISO } from "./organismo/reglas";

export type RolMenu = "inspector" | "revisor" | "gerencia" | "admin";
const TODOS: RolMenu[] = ["inspector", "revisor", "gerencia", "admin"];

export type Seccion = {
  id: string;
  nombre: string;
  icono: NombreIcono;
  numeral?: string;
  roles: RolMenu[];
  /** Pestañas de la página del organismo que pertenecen a esta sección. */
  pestanas?: string[];
  /** Otras rutas que pertenecen a esta sección. */
  rutas?: string[];
  /** Descripción para la página "en construcción". */
  pendiente?: string;
};

export const GRUPOS: { titulo: string; secciones: Seccion[] }[] = [
  { titulo: "", secciones: [
    { id: "inicio", nombre: "Inicio", icono: "inicio", roles: TODOS, pestanas: ["resumen"] },
  ] },
  { titulo: "Operación", secciones: [
    { id: "cotizaciones", nombre: "Cotizaciones y solicitudes", icono: "cotizaciones", numeral: "§7.1", roles: ["gerencia", "admin"],
      pendiente: "Cotización, aprobación del cliente y revisión de la solicitud antes de aceptar el servicio." },
    { id: "ordenes", nombre: "Órdenes y asignación", icono: "ordenes", numeral: "§7.1 · §6.1.6", roles: ["gerencia", "admin"], rutas: ["/ordenes"] },
    { id: "inspecciones", nombre: "Inspecciones", icono: "inspecciones", numeral: "§7.2 · §7.3", roles: TODOS, rutas: ["/inspeccion"],
      pendiente: "Inspección en sitio sin conexión con la lista de verificación de cada actividad y la carga de evidencias (fotos, PDF y video corto)." },
    { id: "ia", nombre: "Revisión IA", icono: "ia", numeral: "apoyo a §7.4", roles: TODOS,
      pendiente: "Informe automático de evidencias completas o faltantes para el inspector, y alarmas para el revisor humano." },
    { id: "dictamenes", nombre: "Revisión técnica y dictámenes", icono: "dictamenes", numeral: "§7.4", roles: ["revisor", "gerencia", "admin"],
      pendiente: "Revisión por una persona distinta al inspector, decisión y emisión del dictamen con el símbolo de acreditado." },
    { id: "quejas", nombre: "Quejas y apelaciones", icono: "quejas", numeral: "§7.5 · §7.6", roles: ["gerencia", "admin"],
      pendiente: "Recepción, investigación y decisión por personal no involucrado." },
  ] },
  { titulo: "Sistema 17020", secciones: [
    { id: "imparcialidad", nombre: "Imparcialidad y confidencialidad", icono: "imparcialidad", numeral: "§4", roles: TODOS,
      pendiente: "Análisis de riesgos a la imparcialidad, declaraciones del personal y conflictos de interés. Hoy las declaraciones se registran al designar a cada persona." },
    { id: "organismo", nombre: "Organismo y alcance acreditado", icono: "organismo", numeral: "§5", roles: ["gerencia", "admin"], pestanas: ["alcance", "documentos", "gerencia"] },
    { id: "personal", nombre: "Personal y competencia", icono: "personal", numeral: "§6.1", roles: TODOS, pestanas: ["dt", "inspectores", "onac"], rutas: ["/personas"] },
    { id: "equipos", nombre: "Equipos y calibraciones", icono: "equipos", numeral: "§6.2", roles: ["inspector", "gerencia", "admin"],
      pendiente: "Inventario de equipos de medición, calibraciones y verificaciones intermedias." },
    { id: "gestion", nombre: "Sistema de gestión", icono: "gestion", numeral: "§8", roles: ["gerencia", "admin"], pestanas: ["sg"] },
    { id: "configuracion", nombre: "Configuración", icono: "configuracion", roles: ["gerencia", "admin"],
      pendiente: "Plazos del organismo, listas de verificación y criterios de la revisión IA." },
    { id: "plataforma", nombre: "Plataforma", icono: "rayo", roles: ["admin"], rutas: ["/organismos"] },
  ] },
];

export const SECCIONES = GRUPOS.flatMap((g) => g.secciones.map((s) => ({ ...s, grupo: g.titulo })));

/** Nombres de las pestañas de la página del organismo. */
export const NOMBRE_PESTANA: Record<string, string> = {
  resumen: "Cumplimiento", alcance: "Datos, logos y alcance", documentos: "Documentos", gerencia: "Gerencia", sg: "Responsable del SG",
  dt: "Directores técnicos", inspectores: "Inspectores", onac: "Personal (formato ONAC)",
};

/** Ruta de una sección para el organismo actual. */
export function rutaSeccion(s: Seccion, organismoId?: string): string {
  // Sin organismo todavía, la sección muestra cómo empezar (y se ilumina ella, no Plataforma).
  if (s.pestanas) return organismoId ? `/organismos/${organismoId}?p=${s.pestanas[0]}` : `/seccion/${s.id}`;
  if (s.pendiente) return `/seccion/${s.id}`;   // aún en construcción (sus "rutas" solo marcan la sección activa)
  if (s.rutas) return s.rutas[0];
  return `/seccion/${s.id}`;
}

/** Sección a la que pertenece la ruta actual. */
export function seccionActual(ruta: string, pestana: string | null): (Seccion & { grupo: string }) | undefined {
  if (/^\/organismos\/[^/]+$/.test(ruta) && ruta !== "/organismos/nuevo") {
    const p = pestana ?? "resumen";
    return SECCIONES.find((s) => s.pestanas?.includes(p));
  }
  const m = /^\/seccion\/([^/]+)/.exec(ruta);
  if (m) return SECCIONES.find((s) => s.id === m[1]);
  return SECCIONES.find((s) => s.rutas?.some((r) => ruta === r || ruta.startsWith(r + "/")));
}

const ADMINISTRACION: RolOEC[] = ["representante_legal", "gerente", "miembro_gerencia", "responsable_sg", "suplente_sg", "director_tecnico", "director_tecnico_suplente"];

/** Roles del menú para la persona en el organismo actual. */
export function rolesMenu(opciones: {
  local: boolean; esAdminPlataforma: boolean; usuarioId?: string;
  base: BaseOrganismos | null; personaId?: string; organismoId?: string;
  /** Organismos con acceso de revisión temporal vigente (ve todo, solo lectura). */
  enRevision?: string[];
}): Set<RolMenu> {
  if (opciones.local) return new Set(TODOS);
  const r = new Set<RolMenu>();
  if (opciones.esAdminPlataforma) r.add("admin");
  if (opciones.organismoId && opciones.enRevision?.includes(opciones.organismoId)) {
    r.add("inspector"); r.add("revisor"); r.add("gerencia");
  }
  const { base, personaId, organismoId } = opciones;
  if (!base || !organismoId) return r;
  const hoy = hoyISO();
  const mias = base.designaciones.filter((d) => d.organismoId === organismoId && d.personaId === personaId && vigenteEn(d, hoy));
  for (const d of mias) {
    if (d.rol === "inspector") r.add("inspector");
    if (ADMINISTRACION.includes(d.rol)) r.add("gerencia");
    if (d.rol === "director_tecnico" || d.rol === "director_tecnico_suplente") r.add("revisor");
  }
  // Arranque: quien creó el organismo lo administra mientras nadie de la administración esté designado.
  const org = base.organismos.find((o) => o.id === organismoId);
  const sinAdministracion = !base.designaciones.some((d) => d.organismoId === organismoId && ADMINISTRACION.includes(d.rol) && vigenteEn(d, hoy));
  if (org && org.creadoPor === opciones.usuarioId && sinAdministracion) r.add("gerencia");
  return r;
}

export const visible = (s: Seccion, roles: Set<RolMenu>) => s.id === "inicio" || s.roles.some((x) => roles.has(x));

/**
 * Permisos sobre el organismo (los mismos de 0009_permisos_alcance.sql; la base los exige igual):
 * - gerencia: cambiar el estado de las actividades del alcance.
 * - gestion (gerencia y SG, con suplentes): datos, logos, documentos; agregar y quitar actividades.
 * En el arranque (nadie de la administración designado) el creador puede todo.
 */
export function permisosOrganismo(op: { local: boolean; usuarioId?: string; base: BaseOrganismos | null; personaId?: string; organismoId?: string }) {
  if (op.local) return { gerencia: true, gestion: true, arranque: false };
  const { base, personaId, organismoId } = op;
  if (!base || !organismoId) return { gerencia: false, gestion: false, arranque: false };
  const hoy = hoyISO();
  const org = base.organismos.find((o) => o.id === organismoId);
  const arranque = !!org && org.creadoPor === op.usuarioId &&
    !base.designaciones.some((d) => d.organismoId === organismoId && ADMINISTRACION.includes(d.rol) && vigenteEn(d, hoy));
  const mios = base.designaciones.filter((d) => d.organismoId === organismoId && d.personaId === personaId && vigenteEn(d, hoy)).map((d) => d.rol);
  const gerencia = arranque || mios.some((r) => ["representante_legal", "gerente", "miembro_gerencia"].includes(r));
  const gestion = gerencia || mios.some((r) => ["responsable_sg", "suplente_sg"].includes(r));
  return { gerencia, gestion, arranque };
}
