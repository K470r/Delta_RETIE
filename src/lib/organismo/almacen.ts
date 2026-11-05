/**
 * Almacén de organismos y personal, con la misma interfaz en dos modos:
 *  - Supabase (si hay NEXT_PUBLIC_SUPABASE_URL y la clave pública): lee lo que la
 *    seguridad por filas permite y guarda cada cambio en la base de datos.
 *  - Local (sin Supabase): guarda en el navegador (localStorage) para pruebas.
 *
 * `actualizar(cambio)` recibe una función que transforma la base y devuelve una
 * promesa con el mensaje de error en español (o null si se guardó).
 */
import { useSyncExternalStore } from "react";
import { categoriaDeActividad } from "../requisitos";
import { mensajeError } from "../errores";
import { CON_SUPABASE } from "../supabase";
import { sesionActual, suscribirSesion, useSesion } from "../sesion";
import { cargarBase, guardarCambios } from "./almacenSupabase";
import type { BaseOrganismos, CalidadFirma, DocumentoPersonal, Persona } from "./tipos";

const CLAVE = "delta-retie:organismos:v1";
const VACIA: BaseOrganismos = { organismos: [], personas: [], vinculaciones: [], designaciones: [], declaraciones: [], revisionesSG: [] };

let cache: BaseOrganismos | null = null;
const oyentes = new Set<() => void>();
const avisar = () => oyentes.forEach((f) => f());

// ───────────────────────── Error visible en pantalla ─────────────────────────
let errorGlobal: string | null = null;
const oyentesError = new Set<() => void>();
export function mostrarError(e: string | null) {
  errorGlobal = e;
  oyentesError.forEach((f) => f());
}
export function useErrorGlobal(): string | null {
  return useSyncExternalStore((f) => { oyentesError.add(f); return () => { oyentesError.delete(f); }; }, () => errorGlobal, () => null);
}

// ───────────────────────── Modo local ─────────────────────────
function leerLocal(): BaseOrganismos {
  if (cache) return cache;
  try {
    const crudo = localStorage.getItem(CLAVE);
    cache = crudo ? normalizar({ ...VACIA, ...JSON.parse(crudo) }) : VACIA;
  } catch {
    cache = VACIA;
  }
  return cache!;
}

function suscribirLocal(f: () => void) {
  oyentes.add(f);
  const enOtraPestana = (e: StorageEvent) => {
    if (e.key === CLAVE) { cache = null; f(); }
  };
  window.addEventListener("storage", enOtraPestana);
  return () => { oyentes.delete(f); window.removeEventListener("storage", enOtraPestana); };
}

// ───────────────────────── Modo Supabase ─────────────────────────
let usuarioCargado: string | null = null;
let cargando: Promise<void> | null = null;
let cola: Promise<unknown> = Promise.resolve();

/** Vuelve a leer la base desde Supabase. */
export function recargar(): Promise<void> {
  const s = sesionActual();
  if (s.estado !== "con_sesion") return Promise.resolve();
  cargando = cargarBase()
    .then((b) => { cache = b; usuarioCargado = s.usuarioId; })
    .catch((e) => { mostrarError(`No se pudieron leer los datos: ${mensajeError(e)}`); cache ??= VACIA; })
    .finally(() => { cargando = null; avisar(); });
  return cargando;
}

function alCambiarSesion() {
  const s = sesionActual();
  if (s.estado !== "con_sesion") {
    if (cache) { cache = null; usuarioCargado = null; avisar(); }
    return;
  }
  if (usuarioCargado !== s.usuarioId && !cargando) {
    cache = null;
    avisar();
    recargar();
  }
}

function suscribirRemoto(f: () => void) {
  oyentes.add(f);
  const quitar = suscribirSesion(alCambiarSesion);
  alCambiarSesion();
  return () => { oyentes.delete(f); quitar(); };
}

// ───────────────────────── Interfaz común ─────────────────────────

export function useBase(): BaseOrganismos | null {
  return useSyncExternalStore(
    CON_SUPABASE ? suscribirRemoto : suscribirLocal,
    CON_SUPABASE ? () => cache : leerLocal,
    () => null,
  );
}

type Opciones = {
  /** Mostrar el error en el aviso general (por defecto). Los formularios lo muestran ellos mismos. */
  mostrarError?: boolean;
};

export function actualizar(cambio: (b: BaseOrganismos) => BaseOrganismos, opciones: Opciones = {}): Promise<string | null> {
  if (!CON_SUPABASE) {
    cache = cambio(leerLocal());
    try {
      localStorage.setItem(CLAVE, JSON.stringify(cache));
    } catch {
      /* almacenamiento no disponible: se conserva en memoria */
    }
    avisar();
    return Promise.resolve(null);
  }
  // Los cambios se envían uno tras otro para que cada uno parta del estado anterior.
  const tarea = cola.then(async () => {
    if (cargando) await cargando;
    if (!cache) return "Los datos aún no se han cargado";
    const antes = cache;
    const despues = cambio(antes);
    let error: string | null;
    try {
      error = await guardarCambios(antes, despues);
    } catch (e) {
      error = mensajeError(e);
    }
    if (!error) { cache = despues; avisar(); }
    await recargar();   // estado real (valores por defecto de la base, o lo que sí se guardó)
    if (error && opciones.mostrarError !== false) mostrarError(error);
    return error;
  });
  cola = tarea.catch(() => null);
  return tarea;
}

export const nuevoId = () => crypto.randomUUID();

/**
 * Corrige un registro hecho por error (migración 0007): lo quita con motivo y queda en la
 * bitácora. La base de datos se niega si ya se usó. Devuelve el error en español o null.
 */
async function corregir(rpc: string, args: Record<string, string>, local: (b: BaseOrganismos) => BaseOrganismos): Promise<string | null> {
  if (!CON_SUPABASE) return actualizar(local);
  const { supabase } = await import("../supabase");
  const { error } = await supabase().rpc(rpc, args);
  await recargar();
  if (error) { const m = mensajeError(error); mostrarError(m); return m; }
  return null;
}

export const quitarAlcancePorError = (organismoId: string, actividad: string, motivo: string) =>
  corregir("quitar_alcance_por_error", { p_organismo: organismoId, p_actividad: actividad, p_motivo: motivo },
    (b) => ({ ...b, organismos: b.organismos.map((o) => (o.id === organismoId ? { ...o, alcance: o.alcance.filter((l) => l.actividad !== actividad) } : o)) }));

export const quitarAutorizacionPorError = (designacionId: string, actividad: string, motivo: string) =>
  corregir("quitar_autorizacion_por_error", { p_designacion: designacionId, p_actividad: actividad, p_motivo: motivo },
    (b) => ({ ...b, designaciones: b.designaciones.map((d) => (d.id === designacionId ? { ...d, actividades: d.actividades.filter((a) => a !== actividad) } : d)) }));

export const aceptarMatricula = (personaId: string, motivo: string) =>
  corregir("aceptar_matricula", { p_persona: personaId, p_motivo: motivo },
    (b) => ({ ...b, personas: b.personas.map((p) => (p.id === personaId ? { ...p, matriculaAceptadaEn: new Date().toISOString(), matriculaAceptadaMotivo: motivo } : p)) }));

/**
 * Firma electrónica de un documento del personal (0013): confirma la contraseña del usuario
 * (vale 10 minutos para la base de datos) y firma la huella del texto que se mostró.
 */
export async function firmarDocumento(documentoId: string, calidad: CalidadFirma, huellaVista: string, contrasena: string): Promise<string | null> {
  if (!CON_SUPABASE) {
    // Modo local (pruebas): firma la persona elegida en "Firmar como".
    return actualizar((b) => ({
      ...b, documentosPersonal: (b.documentosPersonal ?? []).map((x) => (x.id === documentoId
        ? { ...x, firmas: [...x.firmas, { enCalidad: calidad, personaId: personaLocal ?? "", firmadoEn: new Date().toISOString(), huella: x.huella, correo: "modo local" }] } : x)),
    }));
  }
  const s = sesionActual();
  if (s.estado !== "con_sesion") return "Inicie sesión para firmar";
  const { supabase } = await import("../supabase");
  const sb = supabase();
  const ingreso = await sb.auth.signInWithPassword({ email: s.correo, password: contrasena });
  if (ingreso.error) return "La contraseña no es correcta";
  const { error } = await sb.rpc("firmar_documento", { p_documento: documentoId, p_en_calidad: calidad, p_huella: huellaVista });
  await recargar();
  return error ? mensajeError(error) : null;
}

/** Respaldo: registra el PDF del documento impreso, firmado a mano y escaneado. */
export async function registrarFirmadoAMano(doc: DocumentoPersonal, archivo: File): Promise<string | null> {
  const { cargarArchivo, REGLAS_DOCUMENTO } = await import("../archivos");
  const r = await cargarArchivo("documentos", `${doc.organismoId}/personal/${doc.id}/firmado-${Date.now()}.pdf`, archivo, REGLAS_DOCUMENTO);
  if (r.error || !r.ruta) return r.error ?? "No se pudo cargar el archivo";
  if (!CON_SUPABASE) {
    return actualizar((b) => ({
      ...b, documentosPersonal: (b.documentosPersonal ?? []).map((x) => (x.id === doc.id
        ? { ...x, firmadoAManoRuta: r.ruta, firmadoAManoEn: new Date().toISOString(), firmadoAManoPor: personaLocal } : x)),
    }));
  }
  const { supabase } = await import("../supabase");
  const { error } = await supabase().rpc("registrar_firmado_a_mano", { p_documento: doc.id, p_ruta: r.ruta });
  await recargar();
  return error ? mensajeError(error) : null;
}

/** En modo local (sin Supabase) no hay usuario: se elige "firmar como" para probar las firmas. */
let personaLocal: string | undefined;
export const elegirPersonaLocal = (id: string | undefined) => { personaLocal = id; };

/** Pide el motivo (obligatorio) para quitar algo registrado por error. */
export function pedirMotivo(que: string): string | null {
  const m = prompt(`Quitar "${que}" porque se registró por error.\n\nQueda en la bitácora con su nombre y la fecha.\nMotivo (obligatorio):`);
  if (m === null) return null;
  if (!m.trim()) { alert("Debe escribir el motivo."); return null; }
  return m.trim();
}

/** Persona enlazada al usuario que inició sesión (por el correo). */
export function usePersonaActual(base: BaseOrganismos | null): Persona | undefined {
  const s = useSesion();
  if (!base || s.estado !== "con_sesion") return undefined;
  return base.personas.find((p) => p.usuarioId === s.usuarioId);
}

/** Adapta datos guardados con versiones anteriores del modelo. */
function normalizar(b: BaseOrganismos): BaseOrganismos {
  return {
    ...b,
    personas: b.personas.map((p) => ({
      ...p,
      formacion: p.formacion ?? [],
      experiencias: p.experiencias ?? [],
      // v1 guardaba actividades ONAC en el certificado; ahora son categorías del reglamento.
      certificados: p.certificados.map((c) => {
        const viejo = c as typeof c & { actividades?: string[] };
        if (c.categorias) return c;
        const acts = viejo.actividades ?? [];
        const m = acts.map(categoriaDeActividad).filter(Boolean);
        return { ...c, reglamento: m[0]?.req.reglamento ?? "RETIE-2024", categorias: [...new Set(m.map((x) => x!.cat.codigo))] };
      }),
    })),
  };
}
