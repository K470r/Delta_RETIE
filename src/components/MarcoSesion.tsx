"use client";
/**
 * Marco de la aplicación: panel lateral fijo (la sección actual queda iluminada),
 * barra superior y menú inferior en el celular. Con Supabase, todo exige sesión
 * salvo /ingresar. Muestra el aviso de errores de la base de datos.
 */
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useState, type ReactNode } from "react";
import { Icono } from "@/components/Icono";
import { GRUPOS, rolesMenu, rutaSeccion, seccionActual, visible, type Seccion } from "@/lib/navegacion";
import { mostrarError, useBase, useErrorGlobal, usePersonaActual } from "@/lib/organismo/almacen";
import { useOrganismoActual } from "@/lib/organismo/actual";
import { urlLogo } from "@/lib/organismo/logos";
import { NOMBRE_PRODUCTO } from "@/lib/producto";
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

  if (publica) return <main className="mx-auto max-w-6xl px-4 py-10">{children}</main>;
  if (sesion.estado === "cargando" || sesion.estado === "sin_sesion") return <p className="suave p-8">Cargando…</p>;
  return <Suspense fallback={<p className="suave p-8">Cargando…</p>}><Marco>{children}</Marco></Suspense>;
}

function Marco({ children }: { children: ReactNode }) {
  const sesion = useSesion();
  const base = useBase();
  const ruta = usePathname();
  const pestana = useSearchParams().get("p");
  const idEnRuta = /^\/organismos\/([0-9a-f-]{36})$/.exec(ruta)?.[1];
  const organismo = useOrganismoActual(base, idEnRuta);
  const yo = usePersonaActual(base);
  const [menuAbierto, setMenuAbierto] = useState(false);
  useEffect(() => setMenuAbierto(false), [ruta, pestana]);

  const roles = rolesMenu({
    local: sesion.estado === "local",
    esAdminPlataforma: sesion.estado === "con_sesion" && sesion.esAdminPlataforma,
    usuarioId: sesion.estado === "con_sesion" ? sesion.usuarioId : undefined,
    base, personaId: yo?.id, organismoId: organismo?.id,
  });
  const actual = seccionActual(ruta, pestana);
  const grupos = GRUPOS.map((g) => ({ ...g, secciones: g.secciones.filter((s) => visible(s, roles)) })).filter((g) => g.secciones.length);
  const inferior = ["inicio", "inspecciones", "ia", "personal"]
    .map((id) => grupos.flatMap((g) => g.secciones).find((s) => s.id === id)).filter(Boolean) as Seccion[];

  const panel = (
    <nav aria-label="Menú principal" className="flex h-full flex-col overflow-y-auto">
      <Link href={organismo ? rutaSeccion(GRUPOS[0].secciones[0], organismo.id) : "/organismos"} className="flex items-center gap-3 px-5 pb-4 pt-5">
        {organismo?.logoRuta ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={urlLogo(organismo.logoRuta)} alt="" className="h-11 w-11 shrink-0 rounded-lg bg-white object-contain p-1" />
        ) : (
          <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg" style={{ background: "var(--ambar)" }}>
            <Icono nombre="rayo" color="var(--panel)" grosor={2.2} tamano={22} />
          </span>
        )}
        <span className="min-w-0">
          <span className="block truncate font-titulo text-[15px] font-extrabold leading-tight text-white">{organismo?.razonSocial ?? NOMBRE_PRODUCTO}</span>
          {organismo?.codigoAcreditacion && <span className="block truncate text-xs" style={{ color: "var(--panel-suave)" }}>Acreditación {organismo.codigoAcreditacion}</span>}
        </span>
      </Link>
      {base && base.organismos.length > 1 && (
        <Link href="/organismos" className="mx-5 mb-2 text-xs underline" style={{ color: "var(--panel-suave)" }}>Cambiar de organismo</Link>
      )}

      {grupos.map((g) => (
        <div key={g.titulo || "inicio"} className="px-3 pb-2">
          {g.titulo && <div className="px-3 pb-1.5 pt-3 text-[11px] font-semibold uppercase tracking-[0.12em]" style={{ color: "var(--panel-suave)" }}>{g.titulo}</div>}
          {g.secciones.map((s) => {
            const activa = actual?.id === s.id;
            return (
              <Link key={s.id} href={rutaSeccion(s, organismo?.id)} aria-current={activa ? "page" : undefined}
                className={`elemento-panel ${activa ? "activo" : ""}`}>
                <Icono nombre={s.icono} color={activa ? "var(--ambar)" : "var(--panel-suave)"} />
                <span className="flex-1">{s.nombre}</span>
              </Link>
            );
          })}
        </div>
      ))}

      <div className="mt-auto space-y-2 border-t px-5 py-4 text-sm" style={{ borderColor: "rgba(255,255,255,0.08)" }}>
        {sesion.estado === "con_sesion" && (
          <>
            <div className="truncate" style={{ color: "var(--panel-suave)" }} title={sesion.correo}>{yo ? `${yo.nombres} ${yo.apellidos}` : sesion.correo}</div>
            <div className="flex gap-4">
              <Link href="/cuenta" className="flex items-center gap-1.5 text-white hover:underline"><Icono nombre="usuario" tamano={16} />Mi cuenta</Link>
              <SalirBoton />
            </div>
          </>
        )}
        <div className="pt-1 text-[11px]" style={{ color: "var(--panel-suave)" }}>{NOMBRE_PRODUCTO}</div>
      </div>
    </nav>
  );

  return (
    <div className="lg:flex lg:h-screen">
      {/* Escritorio: panel fijo */}
      <aside className="panel hidden w-[272px] shrink-0 lg:block">{panel}</aside>

      {/* Celular y tableta: menú desplegable */}
      {menuAbierto && (
        <div className="fixed inset-0 z-40 lg:hidden">
          <button aria-label="Cerrar menú" className="absolute inset-0 bg-black/40" onClick={() => setMenuAbierto(false)} />
          <aside className="panel absolute inset-y-0 left-0 w-[280px] max-w-[85vw]">{panel}</aside>
        </div>
      )}

      <div className="min-w-0 flex-1 lg:overflow-y-auto">
        <header className="sticky top-0 z-30 flex items-center gap-3 border-b px-4 py-3 backdrop-blur lg:px-8" style={{ borderColor: "var(--borde)", background: "color-mix(in srgb, var(--fondo) 92%, transparent)" }}>
          <button className="flex h-11 w-11 items-center justify-center rounded-xl border lg:hidden" style={{ borderColor: "var(--borde)", background: "var(--tarjeta)" }}
            aria-label="Abrir menú" onClick={() => setMenuAbierto(true)}>
            <Icono nombre="menu" />
          </button>
          <div className="min-w-0 flex-1">
            {actual?.grupo && <div className="suave text-xs">{actual.grupo}</div>}
            <div className="flex flex-wrap items-center gap-2">
              <span className="truncate font-titulo text-lg font-extrabold lg:text-xl">{actual?.nombre ?? NOMBRE_PRODUCTO}</span>
              {actual?.numeral && <span className="chip-numeral">ISO/IEC 17020 {actual.numeral}</span>}
            </div>
          </div>
        </header>
        <main className="mx-auto max-w-6xl px-4 pb-28 pt-6 lg:px-8 lg:pb-12">
          <AvisoError />
          {sesion.estado === "con_sesion" && sesion.aviso && (
            <p className="mb-4 rounded-lg border border-amber-300 bg-amber-50 p-3 text-sm text-amber-900">{sesion.aviso}</p>
          )}
          {children}
        </main>
      </div>

      {/* Celular: menú inferior */}
      <nav aria-label="Menú rápido" className="fixed inset-x-0 bottom-0 z-30 grid border-t px-1 pb-[max(env(safe-area-inset-bottom),8px)] pt-1 lg:hidden"
        style={{ borderColor: "var(--borde)", background: "var(--tarjeta)", gridTemplateColumns: `repeat(${inferior.length + 1}, minmax(0, 1fr))` }}>
        {inferior.map((s) => {
          const activa = actual?.id === s.id;
          return (
            <Link key={s.id} href={rutaSeccion(s, organismo?.id)} aria-current={activa ? "page" : undefined}
              className={`elemento-inferior ${activa ? "activo" : ""}`}>
              <Icono nombre={s.icono} tamano={22} grosor={activa ? 2.1 : 1.9} />
              <span className="truncate">{s.id === "ia" ? "IA" : s.nombre.split(" ")[0]}</span>
            </Link>
          );
        })}
        <button className="elemento-inferior" onClick={() => setMenuAbierto(true)}>
          <Icono nombre="menu" tamano={22} />
          <span>Más</span>
        </button>
      </nav>
    </div>
  );
}

function SalirBoton() {
  const router = useRouter();
  return (
    <button className="flex items-center gap-1.5 text-white hover:underline" onClick={async () => { await cerrarSesion(); router.replace("/ingresar"); }}>
      <Icono nombre="salir" tamano={16} />Salir
    </button>
  );
}

function AvisoError() {
  const error = useErrorGlobal();
  if (!error) return null;
  return (
    <div role="alert" className="sticky top-20 z-20 mb-4 flex items-start justify-between gap-3 rounded-lg border border-red-300 bg-red-50 p-3 text-sm text-red-900 shadow">
      <span><b>No se guardó:</b> {error}</span>
      <button className="font-semibold" aria-label="Cerrar" onClick={() => mostrarError(null)}>✕</button>
    </div>
  );
}
