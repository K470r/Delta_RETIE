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

/**
 * Botones (docs/DECISIONES.md, "Botones"):
 *  - primario: relleno con el color de la aplicación (agregar, registrar, guardar, firmar)
 *  - contorno: borde de color y fondo claro (ver, cargar o cambiar soportes, aceptar, historial)
 *  - secundario: neutro (cancelar)
 *  - peligro / discreto: pequeños, en rojo (finalizar, anular, quitar por error)
 */
export type VarianteBoton = "primario" | "contorno" | "secundario" | "peligro" | "discreto";

export function claseBoton(variante: VarianteBoton = "primario", tamano: "normal" | "pequeno" = "normal") {
  const base = "inline-flex items-center justify-center gap-1.5 rounded-lg font-semibold transition disabled:opacity-50 disabled:cursor-not-allowed";
  const medida = tamano === "pequeno" ? "min-h-8 px-3 py-1 text-xs" : "min-h-10 px-4 py-2 text-sm";
  return `${base} ${variante === "discreto" ? "text-xs" : medida} ${{
    primario: "boton-primario",
    contorno: "boton-contorno",
    secundario: "border boton-neutro",
    peligro: "border text-red-600 boton-neutro",
    discreto: "text-red-600 underline",
  }[variante]}`;
}

export function Boton({ variante = "primario", tamano = "normal", ...props }: React.ButtonHTMLAttributes<HTMLButtonElement> & { variante?: VarianteBoton; tamano?: "normal" | "pequeno" }) {
  return <button {...props} type={props.type ?? "button"} className={`${claseBoton(variante, tamano)} ${props.className ?? ""}`} />;
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
