/**
 * Punto único de acceso a datos. Hoy sirve los datos de demostración;
 * al configurar Supabase (ver .env.example) se conectará el adaptador real
 * sin cambiar las pantallas.
 */
import { datosDemo } from "./demo";
import type { DatosOEC } from "./tipos";

export const MODO_DEMO = !process.env.NEXT_PUBLIC_SUPABASE_URL;

export async function obtenerDatos(): Promise<DatosOEC> {
  return datosDemo();
}
