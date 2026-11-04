"use client";
/**
 * Protege las rutas (con Supabase, todo exige sesión salvo /ingresar),
 * muestra el usuario y el aviso de errores de la base de datos.
 */
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, type ReactNode } from "react";
import { mostrarError, useErrorGlobal } from "@/lib/organismo/almacen";
import { cerrarSesion, useSesion } from "@/lib/sesion";

const PUBLICAS = ["/ingresar"];

export function MarcoSesion({ children }: { children: ReactNode }) {
  const sesion = useSesion();
  const ruta = usePathname();
  const router = useRouter();
  const publica = PUBLICAS.some((p) => ruta.startsWith(p));

  useEffect(() => {
    if (sesion.estado === "sin_sesion" && !publica)
      router.replace(`/ingresar?volver=${encodeURIComponent(ruta + window.location.search)}`);
  }, [sesion.estado, publica, ruta, router]);

  if (!publica && (sesion.estado === "cargando" || sesion.estado === "sin_sesion")) return <p className="suave">Cargando…</p>;
  return (
    <>
      <AvisoError />
      {sesion.estado === "con_sesion" && sesion.aviso && (
        <p className="mb-4 rounded-lg border border-amber-300 bg-amber-50 p-3 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-200">{sesion.aviso}</p>
      )}
      {children}
    </>
  );
}

export function BarraUsuario() {
  const sesion = useSesion();
  const router = useRouter();
  if (sesion.estado !== "con_sesion") return null;
  return (
    <div className="ml-auto flex items-center gap-3 text-sm">
      <span className="suave hidden sm:inline" title={sesion.esAdminPlataforma ? "Administrador de la plataforma" : undefined}>
        {sesion.correo}{sesion.esAdminPlataforma && " · admin"}
      </span>
      <Link href="/cuenta" className="underline">Mi cuenta</Link>
      <button className="underline" onClick={async () => { await cerrarSesion(); router.replace("/ingresar"); }}>Salir</button>
    </div>
  );
}

function AvisoError() {
  const error = useErrorGlobal();
  if (!error) return null;
  return (
    <div role="alert" className="sticky top-2 z-10 mb-4 flex items-start justify-between gap-3 rounded-lg border border-red-300 bg-red-50 p-3 text-sm text-red-900 shadow dark:border-red-800 dark:bg-red-950 dark:text-red-200">
      <span><b>No se guardó:</b> {error}</span>
      <button className="font-semibold" aria-label="Cerrar" onClick={() => mostrarError(null)}>✕</button>
    </div>
  );
}
