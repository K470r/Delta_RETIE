import type { EstadoControl } from "@/lib/controles";

const ESTILOS: Record<EstadoControl | "sin_controles", { texto: string; clase: string }> = {
  cumple: { texto: "Cumple", clase: "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-300" },
  alerta: { texto: "Alerta", clase: "bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300" },
  incumple: { texto: "Incumple", clase: "bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-300" },
  no_aplica: { texto: "No aplica", clase: "bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-400" },
  sin_controles: { texto: "Control manual", clase: "bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-400" },
};

export function EtiquetaEstado({ estado }: { estado: EstadoControl | "sin_controles" }) {
  const e = ESTILOS[estado];
  return <span className={`inline-block whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-semibold ${e.clase}`}>{e.texto}</span>;
}
