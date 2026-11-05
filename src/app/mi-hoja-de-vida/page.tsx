"use client";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense, useEffect } from "react";
import { claseBoton } from "@/components/Formulario";
import { HojaDeVida } from "@/components/organismo/HojaDeVida";
import { useBase, usePersonaActual } from "@/lib/organismo/almacen";
import { nombrePersona } from "@/lib/organismo/reglas";

export default function Pagina() {
  return <Suspense><HojaDeVidaPagina /></Suspense>;
}

/**
 * Hoja de vida de quien inició sesión, o de otra persona (?persona=id). A esta página llevan
 * los avisos y los motivos de "no cumple": baja a la parte que falta (#experiencias, …) y la resalta.
 */
function HojaDeVidaPagina() {
  const params = useSearchParams();
  const base = useBase();
  const yo = usePersonaActual(base);
  const id = params.get("persona");
  const volver = params.get("volver");
  const persona = id ? base?.personas.find((p) => p.id === id) : yo;

  useEffect(() => {
    if (!persona) return;
    const seccion = window.location.hash.slice(1);
    const el = seccion ? document.getElementById(seccion) : null;
    if (!el) return;
    const t = setTimeout(() => {
      el.scrollIntoView({ behavior: "smooth", block: "start" });
      el.style.boxShadow = "0 0 0 3px var(--naranja)";
      el.style.padding = "12px";
      setTimeout(() => { el.style.boxShadow = ""; }, 4000);
    }, 200);
    return () => clearTimeout(t);
  }, [persona]);

  if (!base) return <p className="suave">Cargando…</p>;
  if (!persona) return <p className="tarjeta p-4 text-sm">{id ? "La persona no existe o no tiene permiso para ver su hoja de vida." : "Su usuario aún no está enlazado a una persona."}</p>;
  return (
    <div className="space-y-4">
      {volver && <Link href={volver} className={claseBoton("secundario", "pequeno")}>← Volver</Link>}
      <h1 className="text-2xl font-bold">{persona.id === yo?.id ? "Mi hoja de vida" : `Hoja de vida de ${nombrePersona(persona)}`}</h1>
      <p className="suave text-sm">{nombrePersona(persona)} · {persona.tipoDocumento} {persona.documento}</p>
      <section className="tarjeta p-4"><HojaDeVida persona={persona} /></section>
    </div>
  );
}
