"use client";
/**
 * Logo del organismo (panel y documentos) y símbolo de acreditado ONAC
 * (solo en el informe de no conformidades y en el dictamen).
 */
import { useState } from "react";
import { Icono } from "@/components/Icono";
import { Errores } from "@/components/Formulario";
import { actualizar } from "@/lib/organismo/almacen";
import { useEnlace } from "@/lib/archivos";
import { cargarLogo } from "@/lib/organismo/logos";
import type { Organismo } from "@/lib/organismo/tipos";

export function LogosOrganismo({ o }: { o: Organismo }) {
  const [errores, setErrores] = useState<string[]>([]);
  const [cargando, setCargando] = useState<string | null>(null);

  const cargar = async (tipo: "logo" | "simbolo-onac", archivo?: File) => {
    if (!archivo) return;
    setErrores([]); setCargando(tipo);
    const { ruta, error } = await cargarLogo(o.id, tipo, archivo);
    if (error || !ruta) { setCargando(null); return setErrores([error ?? "No se pudo cargar la imagen"]); }
    const campo = tipo === "logo" ? "logoRuta" : "simboloOnacRuta";
    const e = await actualizar((b) => ({ ...b, organismos: b.organismos.map((x) => (x.id === o.id ? { ...x, [campo]: ruta } : x)) }), { mostrarError: false });
    setCargando(null);
    if (e) setErrores([e]);
  };

  const logo = useEnlace("logos", o.logoRuta);
  const simbolo = useEnlace("logos", o.simboloOnacRuta);

  return (
    <section className="space-y-3">
      <div className="grid gap-3 md:grid-cols-2">
        <Carga titulo="Logo del organismo" ayuda="Aparece arriba en el panel y en los documentos. PNG, JPG o WEBP, máximo 2 MB."
          imagen={logo} ocupado={cargando === "logo"} onArchivo={(f) => cargar("logo", f)} />
        <Carga titulo="Símbolo de acreditado ONAC" ayuda="Solo aparece en el informe de no conformidades y en el dictamen. Cargue el que ONAC entregó al organismo."
          imagen={simbolo} ocupado={cargando === "simbolo-onac"} onArchivo={(f) => cargar("simbolo-onac", f)} />
      </div>
      <Errores errores={errores} />
      <div className="tarjeta space-y-2 p-4">
        <h3 className="text-sm font-semibold">Vista previa: encabezado del informe de no conformidades y del dictamen</h3>
        <div className="flex flex-wrap items-start gap-6 rounded-lg border bg-white p-4 text-slate-900" style={{ borderColor: "var(--borde)" }}>
          <EncabezadoResultados simbolo={simbolo} logo={logo} codigo={o.codigoAcreditacion} />
          <div className="min-w-48 flex-1 self-center text-center">
            <div className="font-titulo font-extrabold">DICTAMEN DE INSPECCIÓN</div>
            <div className="text-xs text-slate-600">{o.razonSocial} · Organismo de inspección tipo A</div>
          </div>
        </div>
        <p className="suave text-xs">
          Símbolo ONAC a la izquierda y logo del organismo a la derecha, alineados arriba y separados el diámetro de la "O" de ONAC.
          Solo en el informe de no conformidades y en el dictamen. Su uso debe seguir las reglas de ONAC para el uso del símbolo de acreditado.
        </p>
      </div>
    </section>
  );
}

function Carga({ titulo, ayuda, imagen, ocupado, onArchivo }: {
  titulo: string; ayuda: string; imagen?: string; ocupado: boolean; onArchivo: (f?: File) => void;
}) {
  return (
    <div className="tarjeta space-y-3 p-4">
      <h3 className="text-sm font-semibold">{titulo}</h3>
      <label className="flex cursor-pointer flex-col items-center gap-2 rounded-xl border-2 border-dashed p-5 text-center text-sm" style={{ borderColor: "var(--borde)" }}>
        {imagen
          // eslint-disable-next-line @next/next/no-img-element
          ? <img src={imagen} alt={titulo} className="h-20 max-w-full object-contain" />
          : <Icono nombre="subir" tamano={28} color="var(--marca)" />}
        <span className="font-semibold">{ocupado ? "Cargando…" : imagen ? "Cambiar imagen" : "Cargar imagen"}</span>
        <span className="suave text-xs">{ayuda}</span>
        <input type="file" accept="image/png,image/jpeg,image/webp" className="sr-only" disabled={ocupado}
          onChange={(e) => { onArchivo(e.target.files?.[0]); e.target.value = ""; }} />
      </label>
    </div>
  );
}


/**
 * Regla de GC&I (docs/DECISIONES.md): símbolo ONAC a la izquierda y logo del organismo a la
 * derecha, alineados arriba, separados el diámetro de la "O" de ONAC (11 % del ancho del
 * símbolo); el logo del organismo tiene la altura del recuadro verde (41 % del ancho del símbolo).
 */
export function EncabezadoResultados({ simbolo, logo, codigo, ancho = 200 }: { simbolo?: string; logo?: string; codigo?: string; ancho?: number }) {
  const separacion = Math.round(ancho * 84 / 759);
  const alto = Math.round(ancho * 312 / 759);
  return (
    <div className="flex items-start" style={{ gap: separacion }}>
      {simbolo
        // eslint-disable-next-line @next/next/no-img-element
        ? <img src={simbolo} alt="Símbolo de acreditado ONAC" style={{ width: ancho, height: "auto" }} />
        : <span className="flex items-center justify-center rounded-md bg-slate-100 text-center text-[11px] text-slate-500"
            style={{ width: ancho, height: Math.round(ancho * 512 / 759) }}>[Símbolo ONAC con {codigo ?? "código"}]</span>}
      {logo
        // eslint-disable-next-line @next/next/no-img-element
        ? <img src={logo} alt="Logo del organismo" style={{ height: alto, width: "auto" }} />
        : <span className="flex items-center justify-center rounded-md bg-slate-100 text-center text-[11px] text-slate-500"
            style={{ height: alto, width: Math.round(alto * 476 / 310) }}>[Logo del organismo]</span>}
    </div>
  );
}
