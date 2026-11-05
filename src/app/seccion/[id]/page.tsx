"use client";
import Link from "next/link";
import { useParams } from "next/navigation";
import { Icono } from "@/components/Icono";
import { SECCIONES, rutaSeccion } from "@/lib/navegacion";
import { useBase } from "@/lib/organismo/almacen";
import { useOrganismoActual } from "@/lib/organismo/actual";
import { useSesion } from "@/lib/sesion";

/** Secciones del menú que aún no se han construido. */
export default function SeccionEnConstruccion() {
  const { id } = useParams<{ id: string }>();
  const s = SECCIONES.find((x) => x.id === id);
  const base = useBase();
  const organismo = useOrganismoActual(base);
  const sesion = useSesion();
  if (!s) return <p>Sección no encontrada.</p>;
  if (s.pestanas) return <SinOrganismo nombre={s.nombre} icono={s.icono} hay={organismo ? rutaSeccion(s, organismo.id) : undefined}
    puedeCrear={sesion.estado === "local" || (sesion.estado === "con_sesion" && sesion.esAdminPlataforma)}
    correo={sesion.estado === "con_sesion" ? sesion.correo : undefined} />;
  return (
    <section className="tarjeta flex flex-col items-center gap-3 p-10 text-center">
      <span className="flex h-14 w-14 items-center justify-center rounded-2xl" style={{ background: "color-mix(in srgb, var(--marca) 14%, transparent)" }}>
        <Icono nombre={s.icono} tamano={28} color="var(--marca)" />
      </span>
      <h1 className="text-xl font-extrabold">{s.nombre}</h1>
      {s.pendiente && <p className="suave max-w-lg text-sm">{s.pendiente}</p>}
      <span className="flex items-center gap-2 rounded-full px-3 py-1 text-xs font-semibold" style={{ background: "#FBE9D8", color: "#8A4209" }}>
        <Icono nombre="construccion" tamano={14} /> En construcción
      </span>
      {s.id === "inspecciones" && (
        <Link href="/ordenes" className="text-sm underline marca">Ver la demostración de la lista F-229 sin conexión</Link>
      )}
    </section>
  );
}

/** Secciones que dependen de un organismo, cuando aún no hay ninguno. */
function SinOrganismo({ nombre, icono, hay, puedeCrear, correo }: {
  nombre: string; icono: Parameters<typeof Icono>[0]["nombre"]; hay?: string; puedeCrear: boolean; correo?: string;
}) {
  if (hay) return <p className="suave">Cargando… <Link href={hay} className="underline">abrir {nombre}</Link></p>;
  return (
    <section className="tarjeta flex flex-col items-center gap-3 p-10 text-center">
      <span className="flex h-14 w-14 items-center justify-center rounded-2xl" style={{ background: "color-mix(in srgb, var(--marca) 14%, transparent)" }}>
        <Icono nombre={icono} tamano={28} color="var(--marca)" />
      </span>
      <h1 className="text-xl font-extrabold">Aún no hay un organismo</h1>
      {puedeCrear ? (
        <>
          <p className="suave max-w-lg text-sm">Cree su organismo de inspección con sus datos, su logo y su alcance acreditado. Después aquí verá {nombre.toLowerCase()}.</p>
          <Link href="/organismos/nuevo" className="flex min-h-11 items-center gap-2 rounded-lg px-4 text-sm font-semibold text-white" style={{ background: "var(--marca)" }}>
            <Icono nombre="organismo" tamano={18} /> Crear el organismo
          </Link>
        </>
      ) : (
        <p className="suave max-w-lg text-sm">
          Su usuario aún no está vinculado a ningún organismo. Pida a la gerencia o al responsable del SG que lo registre como persona
          {correo && <> con el correo <b>{correo}</b></>} y lo vincule.
        </p>
      )}
    </section>
  );
}
