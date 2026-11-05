/** Logos del organismo: carga y dirección para mostrarlos. */
import { CON_SUPABASE, supabase } from "../supabase";

const URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
export const TIPOS_LOGO = ["image/png", "image/jpeg", "image/webp"];
export const MAXIMO_LOGO = 2 * 1024 * 1024;

/** Dirección para mostrar un logo guardado. */
export function urlLogo(ruta?: string): string | undefined {
  if (!ruta) return undefined;
  if (ruta.startsWith("data:")) return ruta;
  return `${URL}/storage/v1/object/public/logos/${ruta}`;
}

/** Carga la imagen y devuelve la ruta a guardar en el organismo (o un error en español). */
export async function cargarLogo(organismoId: string, tipo: "logo" | "simbolo-onac", archivo: File): Promise<{ ruta?: string; error?: string }> {
  if (!TIPOS_LOGO.includes(archivo.type)) return { error: "Use una imagen PNG, JPG o WEBP" };
  if (archivo.size > MAXIMO_LOGO) return { error: "La imagen pesa más de 2 MB. Redúzcala e intente de nuevo" };
  if (!CON_SUPABASE) {
    if (archivo.size > 400 * 1024) return { error: "En modo local la imagen debe pesar menos de 400 KB" };
    const ruta = await new Promise<string>((ok) => { const r = new FileReader(); r.onload = () => ok(String(r.result)); r.readAsDataURL(archivo); });
    return { ruta };
  }
  const ext = archivo.type.split("/")[1].replace("jpeg", "jpg");
  const ruta = `${organismoId}/${tipo}-${Date.now()}.${ext}`;
  const { error } = await supabase().storage.from("logos").upload(ruta, archivo, { contentType: archivo.type, upsert: false });
  if (!error) return { ruta };
  const m = error.message;
  if (/bucket not found/i.test(m)) return { error: "Falta ejecutar la migración 0004_logos.sql en el SQL Editor de Supabase" };
  if (/row-level security|unauthorized|403/i.test(m)) return { error: "Solo la gerencia o el responsable del SG pueden cambiar los logos del organismo" };
  if (/size|too large/i.test(m)) return { error: "La imagen pesa más de 2 MB. Redúzcala e intente de nuevo" };
  if (/mime/i.test(m)) return { error: "Use una imagen PNG, JPG o WEBP" };
  return { error: m };
}
