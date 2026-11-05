/** Organismo con el que se está trabajando (se recuerda en este navegador). */
import { useEffect, useSyncExternalStore } from "react";
import type { BaseOrganismos, Organismo } from "./tipos";

const CLAVE = "delta-retie:organismo-actual";
const oyentes = new Set<() => void>();
let elegido: string | null = null;

function leer(): string | null {
  if (elegido === null) {
    try { elegido = localStorage.getItem(CLAVE) ?? ""; } catch { elegido = ""; }
  }
  return elegido || null;
}

export function elegirOrganismo(id: string) {
  if (id === leer()) return;
  elegido = id;
  try { localStorage.setItem(CLAVE, id); } catch { /* sin almacenamiento: solo en memoria */ }
  oyentes.forEach((f) => f());
}

export function useOrganismoActual(base: BaseOrganismos | null, desdeRuta?: string): Organismo | undefined {
  const id = useSyncExternalStore((f) => { oyentes.add(f); return () => { oyentes.delete(f); }; }, leer, () => null);
  useEffect(() => { if (desdeRuta) elegirOrganismo(desdeRuta); }, [desdeRuta]);
  if (!base) return undefined;
  const buscado = desdeRuta ?? id;
  return base.organismos.find((o) => o.id === buscado) ?? base.organismos[0];
}
