"use client";
import { HojaDeVida } from "@/components/organismo/HojaDeVida";
import { useBase, usePersonaActual } from "@/lib/organismo/almacen";
import { nombrePersona } from "@/lib/organismo/reglas";

/** Hoja de vida de quien inició sesión (a esta página llevan los avisos del seguimiento). */
export default function MiHojaDeVida() {
  const base = useBase();
  const yo = usePersonaActual(base);
  if (!base) return <p className="suave">Cargando…</p>;
  if (!yo) return <p className="tarjeta p-4 text-sm">Su usuario aún no está enlazado a una persona.</p>;
  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">Mi hoja de vida</h1>
      <p className="suave text-sm">{nombrePersona(yo)} · {yo.tipoDocumento} {yo.documento}</p>
      <section className="tarjeta p-4"><HojaDeVida persona={yo} /></section>
    </div>
  );
}
