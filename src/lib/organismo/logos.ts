/** Logos del organismo (carpeta privada: solo el personal del organismo los ve). */
import { cargarArchivo, extension } from "../archivos";

export const TIPOS_LOGO = ["image/png", "image/jpeg", "image/webp"];
export const MAXIMO_LOGO = 2 * 1024 * 1024;

/** Carga la imagen y devuelve la ruta a guardar en el organismo (o un error en español). */
export async function cargarLogo(organismoId: string, tipo: "logo" | "simbolo-onac", archivo: File): Promise<{ ruta?: string; error?: string }> {
  const r = await cargarArchivo("logos", `${organismoId}/${tipo}-${Date.now()}.${extension(archivo)}`, archivo,
    { tipos: TIPOS_LOGO, maximo: MAXIMO_LOGO, nombreTipos: "PNG, JPG o WEBP" });
  if (r.error === "No tiene permiso para cargar este archivo")
    return { error: "Solo la gerencia o el responsable del SG pueden cambiar los logos del organismo" };
  return r;
}
