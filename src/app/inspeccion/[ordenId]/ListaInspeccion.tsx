"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import {
  borrarEvidencia, guardarBorrador, guardarEvidencia, leerBorrador, leerEvidencia,
  type BorradorInspeccion, type Resultado,
} from "@/lib/almacenLocal";
import type { Formato, ItemFormato } from "@/lib/formatos";
import type { Equipo } from "@/lib/tipos";

const OPCIONES: { valor: Resultado; texto: string; activo: string }[] = [
  { valor: "C", texto: "Cumple", activo: "bg-emerald-600 text-white border-emerald-600" },
  { valor: "NC", texto: "No cumple", activo: "bg-red-600 text-white border-red-600" },
  { valor: "NA", texto: "No aplica", activo: "bg-slate-600 text-white border-slate-600" },
];

type Props = { ordenId: string; formato: Formato; equipos: Equipo[] };

export function ListaInspeccion({ ordenId, formato, equipos }: Props) {
  const [b, setB] = useState<BorradorInspeccion | null>(null);
  const [filtro, setFiltro] = useState<"todos" | "pendientes" | "NC">("todos");
  const [errores, setErrores] = useState<string[]>([]);
  const hoy = new Date().toISOString().slice(0, 10);

  const items = useMemo(
    () => formato.items.filter((i): i is ItemFormato => i.tipo === "item"),
    [formato],
  );

  useEffect(() => {
    leerBorrador(ordenId).then((x) =>
      setB(x ?? { ordenId, respuestas: {}, equiposUsados: [], estado: "borrador", actualizado: new Date().toISOString() }),
    );
  }, [ordenId]);

  if (!b) return <p className="suave">Cargando…</p>;

  const actualizar = (cambio: (x: BorradorInspeccion) => BorradorInspeccion) => {
    setB((prev) => {
      const nuevo = cambio(prev!);
      void guardarBorrador(nuevo);
      return nuevo;
    });
  };

  const respuesta = (codigo: string) => b.respuestas[codigo] ?? { evidencias: [], actualizado: "" };
  const setRespuesta = (codigo: string, parcial: Partial<BorradorInspeccion["respuestas"][string]>) =>
    actualizar((x) => ({
      ...x,
      estado: "borrador",
      respuestas: {
        ...x.respuestas,
        [codigo]: { ...(x.respuestas[codigo] ?? { evidencias: [] }), ...parcial, actualizado: new Date().toISOString() },
      },
    }));

  const evaluados = items.filter((i) => b.respuestas[i.codigo]?.resultado).length;
  const nc = items.filter((i) => b.respuestas[i.codigo]?.resultado === "NC").length;

  const capturarUbicacion = () =>
    navigator.geolocation?.getCurrentPosition((p) =>
      actualizar((x) => ({
        ...x,
        ubicacion: { lat: p.coords.latitude, lon: p.coords.longitude, precision: p.coords.accuracy, fecha: new Date().toISOString() },
      })),
    );

  const validar = () => {
    const e: string[] = [];
    if (!b.equiposUsados.length) e.push("Registre al menos un equipo de medición utilizado (17020 §6.2).");
    const pendientes = items.filter((i) => !b.respuestas[i.codigo]?.resultado);
    if (pendientes.length) e.push(`${pendientes.length} ítem(s) sin evaluar: ${pendientes.map((i) => i.codigo).join(", ")} (17020 §7.3).`);
    const sinEvidencia = items.filter((i) => b.respuestas[i.codigo]?.resultado === "NC" && !b.respuestas[i.codigo].evidencias.length);
    if (sinEvidencia.length) e.push(`No conformidades sin evidencia: ${sinEvidencia.map((i) => i.codigo).join(", ")}.`);
    const sinObs = items.filter((i) => b.respuestas[i.codigo]?.resultado === "NC" && !b.respuestas[i.codigo].observacion?.trim());
    if (sinObs.length) e.push(`No conformidades sin descripción del hallazgo: ${sinObs.map((i) => i.codigo).join(", ")}.`);
    setErrores(e);
    if (!e.length) actualizar((x) => ({ ...x, estado: "lista_para_revision" }));
  };

  let seccionActual = "";
  const visibles = formato.items.filter((i) => {
    if (i.tipo === "seccion") return true;
    const r = b.respuestas[i.codigo]?.resultado;
    return filtro === "todos" || (filtro === "pendientes" && !r) || (filtro === "NC" && r === "NC");
  });

  return (
    <div className="space-y-4">
      {/* Avance */}
      <div className="tarjeta sticky top-0 z-10 space-y-2 p-3">
        <div className="flex flex-wrap items-center justify-between gap-2 text-sm">
          <span><b className="tabular-nums">{evaluados}/{items.length}</b> evaluados · <b className="tabular-nums text-red-600">{nc}</b> NC</span>
          <div className="flex gap-1">
            {(["todos", "pendientes", "NC"] as const).map((f) => (
              <button key={f} onClick={() => setFiltro(f)}
                className={`rounded border px-2 py-1 text-xs ${filtro === f ? "bg-[var(--marca)] text-white" : ""}`}
                style={{ borderColor: "var(--borde)" }}>
                {f === "todos" ? "Todos" : f === "pendientes" ? "Pendientes" : "Solo NC"}
              </button>
            ))}
          </div>
        </div>
        <div className="h-2 overflow-hidden rounded bg-slate-200 dark:bg-slate-700">
          <div className="h-full bg-[var(--marca)] transition-all" style={{ width: `${(evaluados / items.length) * 100}%` }} />
        </div>
      </div>

      {/* Datos de campo */}
      <section className="tarjeta space-y-3 p-4">
        <h2 className="font-semibold">Equipos utilizados</h2>
        <div className="grid gap-2 sm:grid-cols-2">
          {equipos.filter((e) => e.estado === "operativo").map((e) => {
            const vencido = e.vencimientoCalibracion < hoy;
            const marcado = b.equiposUsados.includes(e.id);
            return (
              <label key={e.id} className={`flex items-start gap-2 rounded-lg border p-2 text-sm ${vencido ? "opacity-60" : ""}`}
                style={{ borderColor: "var(--borde)" }}>
                <input type="checkbox" disabled={vencido} checked={marcado} className="mt-1"
                  onChange={() => actualizar((x) => ({
                    ...x,
                    equiposUsados: marcado ? x.equiposUsados.filter((id) => id !== e.id) : [...x.equiposUsados, e.id],
                  }))} />
                <span>
                  <b>{e.codigo}</b> {e.nombre} · S/N {e.serie}
                  <span className={`block text-xs ${vencido ? "font-semibold text-red-600" : "suave"}`}>
                    {vencido ? `Calibración vencida (${e.vencimientoCalibracion}) — bloqueado` : `Calibración vigente hasta ${e.vencimientoCalibracion}`}
                  </span>
                </span>
              </label>
            );
          })}
        </div>
        <div className="flex flex-wrap items-center gap-2 text-sm">
          <button onClick={capturarUbicacion} className="rounded-lg border px-3 py-1.5" style={{ borderColor: "var(--borde)" }}>
            Registrar ubicación GPS
          </button>
          {b.ubicacion && (
            <span className="suave text-xs">
              {b.ubicacion.lat.toFixed(5)}, {b.ubicacion.lon.toFixed(5)} (±{Math.round(b.ubicacion.precision)} m)
            </span>
          )}
        </div>
      </section>

      {/* Lista de verificación */}
      {visibles.map((i, idx) => {
        if (i.tipo === "seccion") {
          seccionActual = i.titulo;
          return <h2 key={`s-${idx}`} className="pt-2 text-sm font-semibold uppercase tracking-wide suave">{i.titulo}</h2>;
        }
        const r = respuesta(i.codigo);
        return (
          <article key={i.codigo} className="tarjeta space-y-3 p-4" data-seccion={seccionActual}>
            <div>
              <div className="flex flex-wrap items-center gap-2 text-xs">
                <span className="font-mono font-semibold marca">{i.codigo}</span>
                <span className="suave">{i.articulo}</span>
              </div>
              <h3 className="font-semibold">{i.aspecto}</h3>
              <p className="text-sm">{i.actividad}</p>
              <details className="mt-1 text-sm">
                <summary className="suave cursor-pointer">Requisito: {i.requisito}</summary>
                <p className="suave mt-1">{i.descripcion}</p>
              </details>
            </div>
            <div className="grid grid-cols-3 gap-2">
              {OPCIONES.map((o) => (
                <button key={o.valor} onClick={() => setRespuesta(i.codigo, { resultado: o.valor })}
                  className={`rounded-lg border py-2 text-sm font-semibold ${r.resultado === o.valor ? o.activo : ""}`}
                  style={r.resultado === o.valor ? undefined : { borderColor: "var(--borde)" }}>
                  {o.texto}
                </button>
              ))}
            </div>
            {(r.resultado === "NC" || r.observacion) && (
              <textarea value={r.observacion ?? ""} rows={2}
                placeholder={r.resultado === "NC" ? "Describa el hallazgo (obligatorio para NC)" : "Observación"}
                onChange={(e) => setRespuesta(i.codigo, { observacion: e.target.value })}
                className="w-full rounded-lg border bg-transparent p-2 text-sm" style={{ borderColor: "var(--borde)" }} />
            )}
            <Evidencias ordenId={ordenId} itemCodigo={i.codigo} ids={r.evidencias}
              onCambio={(ids) => setRespuesta(i.codigo, { evidencias: ids })} />
          </article>
        );
      })}

      {/* Cierre */}
      <section className="tarjeta space-y-2 p-4">
        {b.estado === "lista_para_revision" ? (
          <p className="font-semibold text-emerald-600">
            Inspección completa y lista para revisión técnica. Se enviará al servidor al sincronizar.
          </p>
        ) : (
          <button onClick={validar} className="w-full rounded-lg bg-[var(--marca)] py-3 font-semibold text-white">
            Validar y enviar a revisión
          </button>
        )}
        {errores.length > 0 && (
          <ul className="list-disc pl-5 text-sm text-red-600">{errores.map((e) => <li key={e}>{e}</li>)}</ul>
        )}
        <p className="suave text-xs">Los datos se guardan en este dispositivo automáticamente; puede trabajar sin señal.</p>
      </section>
    </div>
  );
}

function Evidencias({ ordenId, itemCodigo, ids, onCambio }: {
  ordenId: string; itemCodigo: string; ids: string[]; onCambio: (ids: string[]) => void;
}) {
  const entrada = useRef<HTMLInputElement>(null);
  const [vistas, setVistas] = useState<Record<string, { url: string; tipo: string; nombre: string }>>({});

  useEffect(() => {
    let vivo = true;
    const urls: string[] = [];
    Promise.all(ids.map(leerEvidencia)).then((evs) => {
      if (!vivo) return;
      const v: typeof vistas = {};
      for (const e of evs) if (e) {
        const url = URL.createObjectURL(e.datos);
        urls.push(url);
        v[e.id] = { url, tipo: e.tipo, nombre: e.nombre };
      }
      setVistas(v);
    });
    return () => { vivo = false; urls.forEach(URL.revokeObjectURL); };
  }, [ids]);

  const agregar = async (archivos: FileList | null) => {
    if (!archivos?.length) return;
    const nuevos: string[] = [];
    for (const archivo of Array.from(archivos)) {
      const id = crypto.randomUUID();
      await guardarEvidencia({ id, ordenId, itemCodigo, tipo: archivo.type, nombre: archivo.name, datos: archivo, tomada: new Date().toISOString() });
      nuevos.push(id);
    }
    onCambio([...ids, ...nuevos]);
  };

  return (
    <div className="space-y-2">
      <div className="flex flex-wrap gap-2">
        {ids.map((id) => {
          const v = vistas[id];
          if (!v) return null;
          return (
            <div key={id} className="relative">
              {v.tipo.startsWith("image/") ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={v.url} alt={v.nombre} className="h-20 w-20 rounded-lg object-cover" />
              ) : v.tipo.startsWith("video/") ? (
                <video src={v.url} className="h-20 w-28 rounded-lg object-cover" controls />
              ) : v.tipo.startsWith("audio/") ? (
                <audio src={v.url} controls className="h-10" />
              ) : (
                <span className="block rounded-lg border p-2 text-xs" style={{ borderColor: "var(--borde)" }}>{v.nombre}</span>
              )}
              <button aria-label="Quitar evidencia"
                onClick={async () => { await borrarEvidencia(id); onCambio(ids.filter((x) => x !== id)); }}
                className="absolute -right-1 -top-1 h-5 w-5 rounded-full bg-red-600 text-xs leading-5 text-white">×</button>
            </div>
          );
        })}
      </div>
      <input ref={entrada} type="file" multiple accept="image/*,video/*,audio/*,application/pdf" capture="environment"
        className="hidden" onChange={(e) => { void agregar(e.target.files); e.target.value = ""; }} />
      <button onClick={() => entrada.current?.click()} className="rounded-lg border px-3 py-1.5 text-sm" style={{ borderColor: "var(--borde)" }}>
        + Foto / video / audio
      </button>
    </div>
  );
}
