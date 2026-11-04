/** Controles de formulario reutilizables con estilo uniforme. */
import type { InputHTMLAttributes, ReactNode, SelectHTMLAttributes, TextareaHTMLAttributes } from "react";

export const claseCampo = "w-full rounded-lg border bg-transparent px-3 py-2 text-sm";
const borde = { borderColor: "var(--borde)" };

export function Campo({ etiqueta, ayuda, children }: { etiqueta: string; ayuda?: string; children: ReactNode }) {
  return (
    <label className="block space-y-1">
      <span className="text-sm font-medium">{etiqueta}</span>
      {children}
      {ayuda && <span className="suave block text-xs">{ayuda}</span>}
    </label>
  );
}

export function Entrada(props: InputHTMLAttributes<HTMLInputElement>) {
  return <input {...props} className={`${claseCampo} ${props.className ?? ""}`} style={borde} />;
}

export function Selector(props: SelectHTMLAttributes<HTMLSelectElement>) {
  return <select {...props} className={`${claseCampo} ${props.className ?? ""}`} style={{ ...borde, background: "var(--tarjeta)" }} />;
}

export function Texto(props: TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return <textarea {...props} className={`${claseCampo} ${props.className ?? ""}`} style={borde} />;
}

export function Boton({ variante = "primario", ...props }: React.ButtonHTMLAttributes<HTMLButtonElement> & { variante?: "primario" | "secundario" | "peligro" }) {
  const clases = {
    primario: "bg-[var(--marca)] text-white border-transparent",
    secundario: "",
    peligro: "text-red-600",
  }[variante];
  return (
    <button {...props} type={props.type ?? "button"}
      className={`rounded-lg border px-3 py-2 text-sm font-semibold disabled:opacity-50 ${clases} ${props.className ?? ""}`}
      style={variante === "primario" ? undefined : borde} />
  );
}

export function Errores({ errores }: { errores: string[] }) {
  if (!errores.length) return null;
  return (
    <ul className="list-disc space-y-1 rounded-lg border border-red-300 bg-red-50 p-3 pl-7 text-sm text-red-900 dark:border-red-800 dark:bg-red-950 dark:text-red-200">
      {errores.map((e) => <li key={e}>{e}</li>)}
    </ul>
  );
}

/** Como Campo, pero para grupos de casillas (no anida etiquetas). */
export function Grupo({ etiqueta, children }: { etiqueta: string; children: ReactNode }) {
  return (
    <div role="group" aria-label={etiqueta} className="space-y-1">
      <span className="text-sm font-medium">{etiqueta}</span>
      {children}
    </div>
  );
}
