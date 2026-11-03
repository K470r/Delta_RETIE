/**
 * Almacén de organismos y personal.
 * Modo local (sin Supabase): guarda en el navegador (localStorage) para poder
 * probar el flujo completo. Al conectar Supabase se reemplaza por el
 * adaptador remoto con la misma interfaz.
 */
import { useSyncExternalStore } from "react";
import type { BaseOrganismos } from "./tipos";

const CLAVE = "delta-retie:organismos:v1";
const VACIA: BaseOrganismos = { organismos: [], personas: [], vinculaciones: [], designaciones: [], declaraciones: [], revisionesSG: [] };

let cache: BaseOrganismos | null = null;
const oyentes = new Set<() => void>();

function leer(): BaseOrganismos {
  if (cache) return cache;
  try {
    const crudo = localStorage.getItem(CLAVE);
    cache = crudo ? { ...VACIA, ...JSON.parse(crudo) } : VACIA;
  } catch {
    cache = VACIA;
  }
  return cache!;
}

export function actualizar(cambio: (b: BaseOrganismos) => BaseOrganismos) {
  cache = cambio(leer());
  try {
    localStorage.setItem(CLAVE, JSON.stringify(cache));
  } catch {
    /* almacenamiento no disponible: se conserva en memoria */
  }
  oyentes.forEach((f) => f());
}

export function useBase(): BaseOrganismos | null {
  return useSyncExternalStore(
    (f) => {
      oyentes.add(f);
      const enOtraPestana = (e: StorageEvent) => {
        if (e.key === CLAVE) { cache = null; f(); }
      };
      window.addEventListener("storage", enOtraPestana);
      return () => { oyentes.delete(f); window.removeEventListener("storage", enOtraPestana); };
    },
    leer,
    () => null,
  );
}

export const nuevoId = () => crypto.randomUUID();
