/**
 * Cliente de Supabase (solo navegador). Si no hay variables de entorno, la
 * aplicación trabaja en modo local (datos solo en este navegador).
 */
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const CLAVE = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export const CON_SUPABASE = !!(URL && CLAVE);

let cliente: SupabaseClient | null = null;

export function supabase(): SupabaseClient {
  if (!CON_SUPABASE) throw new Error("Supabase no está configurado");
  cliente ??= createClient(URL!, CLAVE!, {
    // "implicit": el enlace del correo funciona aunque se abra en otro navegador o dispositivo.
    auth: { flowType: "implicit", persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
  });
  return cliente;
}
