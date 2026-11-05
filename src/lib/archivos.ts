/**
 * Archivos privados (logos y soportes). Nada es público: para verlos se pide un
 * enlace que vence en pocos minutos, y Supabase solo lo entrega si el rol lo permite.
 * En modo local, el archivo se guarda en línea (data:) y se muestra tal cual.
 */
import { useEffect, useState } from "react";
import { CON_SUPABASE, supabase } from "./supabase";

export type Carpeta = "logos" | "soportes" | "documentos";
const DURACION = 300; // segundos que dura un enlace
const cache = new Map<string, { url: string; vence: number }>();

export async function enlaceTemporal(carpeta: Carpeta, ruta: string): Promise<string | null> {
  if (ruta.startsWith("data:")) return ruta;
  if (!CON_SUPABASE) return null;
  const clave = `${carpeta}/${ruta}`;
  const c = cache.get(clave);
  if (c && c.vence > Date.now() + 30_000) return c.url;
  const { data, error } = await supabase().storage.from(carpeta).createSignedUrl(ruta, DURACION);
  if (error || !data) return null;
  cache.set(clave, { url: data.signedUrl, vence: Date.now() + DURACION * 1000 });
  return data.signedUrl;
}

/** Dirección temporal para mostrar una imagen (se renueva al volver a montar). */
export function useEnlace(carpeta: Carpeta, ruta?: string): string | undefined {
  const [url, setUrl] = useState<string>();
  useEffect(() => {
    let vivo = true;
    setUrl(undefined);
    if (ruta) enlaceTemporal(carpeta, ruta).then((u) => { if (vivo && u) setUrl(u); });
    return () => { vivo = false; };
  }, [carpeta, ruta]);
  return url;
}

/** Abre un archivo en otra pestaña con un enlace temporal. */
export async function abrirArchivo(carpeta: Carpeta, ruta: string): Promise<string | null> {
  const ventana = window.open("", "_blank");   // se abre antes para que el navegador no la bloquee
  const url = await enlaceTemporal(carpeta, ruta);
  if (!url) { ventana?.close(); return "No tiene permiso para ver este archivo, o ya no existe"; }
  if (ventana) ventana.location.href = url; else window.location.href = url;
  return null;
}

type Reglas = { tipos: string[]; maximo: number; nombreTipos: string; maximoLocal?: number };

/** Carga un archivo en la carpeta indicada y devuelve su ruta (o un error en español). */
export async function cargarArchivo(carpeta: Carpeta, ruta: string, archivo: File, r: Reglas): Promise<{ ruta?: string; error?: string }> {
  if (!r.tipos.includes(archivo.type)) return { error: `Use un archivo ${r.nombreTipos}` };
  if (archivo.size > r.maximo) return { error: `El archivo pesa más de ${r.maximo / 1024 / 1024} MB. Redúzcalo e intente de nuevo` };
  if (!CON_SUPABASE) {
    const maximoLocal = r.maximoLocal ?? 400 * 1024;
    if (archivo.size > maximoLocal) return { error: `En modo local el archivo debe pesar menos de ${Math.round(maximoLocal / 1024)} KB` };
    const enLinea = await new Promise<string>((ok) => { const f = new FileReader(); f.onload = () => ok(String(f.result)); f.readAsDataURL(archivo); });
    return { ruta: enLinea };
  }
  const { error } = await supabase().storage.from(carpeta).upload(ruta, archivo, { contentType: archivo.type, upsert: false });
  if (!error) return { ruta };
  const m = error.message;
  if (/bucket not found/i.test(m)) return { error: "Falta ejecutar una migración (0004 o 0005) en el SQL Editor de Supabase" };
  if (/row-level security|unauthorized|403/i.test(m)) return { error: "No tiene permiso para cargar este archivo" };
  if (/size|too large/i.test(m)) return { error: `El archivo pesa más de ${r.maximo / 1024 / 1024} MB` };
  if (/mime/i.test(m)) return { error: `Use un archivo ${r.nombreTipos}` };
  return { error: m };
}

export const extension = (archivo: File) => (archivo.type.split("/")[1] ?? "bin").replace("jpeg", "jpg");

export const REGLAS_DOCUMENTO: Reglas = { tipos: ["application/pdf"], maximo: 15 * 1024 * 1024, nombreTipos: "PDF", maximoLocal: 2 * 1024 * 1024 };

export const REGLAS_SOPORTE: Reglas = { tipos: ["application/pdf", "image/png", "image/jpeg"], maximo: 10 * 1024 * 1024, nombreTipos: "PDF, JPG o PNG" };
