"use client";
import Link from "next/link";
import { useParams } from "next/navigation";
import { Icono } from "@/components/Icono";
import { SECCIONES } from "@/lib/navegacion";

/** Secciones del menú que aún no se han construido. */
export default function SeccionEnConstruccion() {
  const { id } = useParams<{ id: string }>();
  const s = SECCIONES.find((x) => x.id === id);
  if (!s) return <p>Sección no encontrada.</p>;
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
