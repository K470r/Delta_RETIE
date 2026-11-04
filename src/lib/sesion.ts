/**
 * Sesión de Supabase Auth (enlace mágico o código por correo, sin contraseña).
 */
import { useSyncExternalStore } from "react";
import { CON_SUPABASE, supabase } from "./supabase";
import { mensajeError } from "./errores";

export type Sesion =
  | { estado: "local" }                       // sin Supabase: no se exige inicio de sesión
  | { estado: "cargando" }
  | { estado: "sin_sesion" }
  | { estado: "con_sesion"; usuarioId: string; correo: string; esAdminPlataforma: boolean; aviso?: string };

let actual: Sesion = CON_SUPABASE ? { estado: "cargando" } : { estado: "local" };
let iniciada = false;
const oyentes = new Set<(s: Sesion) => void>();

function publicar(s: Sesion) {
  actual = s;
  oyentes.forEach((f) => f(s));
}

async function desdeUsuario(u: { id: string; email?: string } | null | undefined) {
  if (!u) return publicar({ estado: "sin_sesion" });
  const base = { estado: "con_sesion" as const, usuarioId: u.id, correo: (u.email ?? "").toLowerCase() };
  // Publicar ya la sesión y luego completar si es administrador de la plataforma.
  if (actual.estado !== "con_sesion" || actual.usuarioId !== u.id) publicar({ ...base, esAdminPlataforma: false });
  const { data, error } = await supabase().rpc("soy_admin_plataforma");
  publicar({ ...base, esAdminPlataforma: data === true, aviso: error ? mensajeError(error) : undefined });
}

function iniciar() {
  if (iniciada || !CON_SUPABASE || typeof window === "undefined") return;
  iniciada = true;
  const sb = supabase();
  sb.auth.getSession().then(({ data }) => desdeUsuario(data.session?.user));
  sb.auth.onAuthStateChange((evento, s) => {
    if (evento === "SIGNED_OUT") return publicar({ estado: "sin_sesion" });
    if (evento === "SIGNED_IN" || evento === "USER_UPDATED" || evento === "INITIAL_SESSION") {
      // Diferido: no llamar a Supabase dentro del callback (recomendación de supabase-js).
      setTimeout(() => desdeUsuario(s?.user), 0);
    }
  });
}

export function sesionActual(): Sesion {
  iniciar();
  return actual;
}

export function suscribirSesion(f: (s: Sesion) => void) {
  iniciar();
  oyentes.add(f);
  return () => { oyentes.delete(f); };
}

const EN_SERVIDOR: Sesion = CON_SUPABASE ? { estado: "cargando" } : { estado: "local" };

export function useSesion(): Sesion {
  return useSyncExternalStore((f) => suscribirSesion(() => f()), sesionActual, () => EN_SERVIDOR);
}

export async function cerrarSesion() {
  if (CON_SUPABASE) await supabase().auth.signOut();
}
