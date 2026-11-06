"use client";
import { agrupar, type Actividad } from "@/lib/catalogo";
import { EnlaceMotivo } from "./organismo/EnlaceMotivo";

/**
 * Lista de actividades agrupada por reglamento y grupo, con casillas.
 * `bloqueo(codigo)` devuelve un motivo cuando la actividad no se puede marcar.
 */
export function SelectorActividades({ actividades, seleccion, onCambio, bloqueo, personaId }: {
  actividades: Actividad[];
  seleccion: string[];
  onCambio: (s: string[]) => void;
  bloqueo?: (codigo: string) => string | null;
  /** Si se indica, el motivo del bloqueo lleva a la hoja de vida de la persona. */
  personaId?: string;
}) {
  const alternar = (c: string) => onCambio(seleccion.includes(c) ? seleccion.filter((x) => x !== c) : [...seleccion, c]);
  if (!actividades.length) return <p className="suave text-sm">No hay actividades disponibles.</p>;
  return (
    <div className="space-y-4">
      {agrupar(actividades).map(({ reglamento, grupos }) => (
        <div key={reglamento.id} className="space-y-2">
          <div className="text-sm font-semibold">{reglamento.nombre}</div>
          {grupos.map(([grupo, acts]) => {
            const habilitadas = acts.filter((a) => !bloqueo?.(a.codigo)).map((a) => a.codigo);
            const todas = habilitadas.length > 0 && habilitadas.every((c) => seleccion.includes(c));
            return (
              <fieldset key={grupo} className="rounded-lg border p-3" style={{ borderColor: "var(--borde)" }}>
                <legend className="flex items-center gap-2 px-1 text-xs font-semibold uppercase tracking-wide suave">
                  {grupo}
                  {habilitadas.length > 1 && (
                    <button type="button" className="normal-case underline"
                      onClick={() => onCambio(todas ? seleccion.filter((c) => !habilitadas.includes(c)) : [...new Set([...seleccion, ...habilitadas])])}>
                      {todas ? "quitar todas" : "marcar todas"}
                    </button>
                  )}
                </legend>
                <div className="space-y-2">
                  {acts.map((a) => {
                    const motivo = bloqueo?.(a.codigo) ?? null;
                    return (
                      <label key={a.codigo} className="flex items-start gap-2 text-sm">
                        <input type="checkbox" className="mt-1" disabled={!!motivo}
                          checked={seleccion.includes(a.codigo)} onChange={() => alternar(a.codigo)} />
                        <span>
                          <span className={motivo ? "opacity-60" : ""}>{a.nombre}</span>
                          {motivo && <EnlaceMotivo personaId={personaId} texto={motivo} className="block text-xs text-red-600" />}
                        </span>
                      </label>
                    );
                  })}
                </div>
              </fieldset>
            );
          })}
        </div>
      ))}
    </div>
  );
}
