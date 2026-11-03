/**
 * Almacén de organismos y personal.
 * Modo local (sin Supabase): guarda en el navegador (localStorage) para poder
 * probar el flujo completo. Al conectar Supabase se reemplaza por el
 * adaptador remoto con la misma interfaz.
 */
import { useSyncExternalStore } from "react";
import { categoriaDeActividad } from "../requisitos";
import type { BaseOrganismos } from "./tipos";

const CLAVE = "delta-retie:organismos:v1";
const VACIA: BaseOrganismos = { organismos: [], personas: [], vinculaciones: [], designaciones: [], declaraciones: [], revisionesSG: [] };

let cache: BaseOrganismos | null = null;
const oyentes = new Set<() => void>();

function leer(): BaseOrganismos {
  if (cache) return cache;
  try {
    const crudo = localStorage.getItem(CLAVE);
    cache = crudo ? normalizar({ ...VACIA, ...JSON.parse(crudo) }) : VACIA;
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

/** Adapta datos guardados con versiones anteriores del modelo. */
function normalizar(b: BaseOrganismos): BaseOrganismos {
  return {
    ...b,
    personas: b.personas.map((p) => ({
      ...p,
      formacion: p.formacion ?? [],
      experiencias: p.experiencias ?? [],
      // v1 guardaba actividades ONAC en el certificado; ahora son categorías del reglamento.
      certificados: p.certificados.map((c) => {
        const viejo = c as typeof c & { actividades?: string[] };
        if (c.categorias) return c;
        const acts = viejo.actividades ?? [];
        const m = acts.map(categoriaDeActividad).filter(Boolean);
        return { ...c, reglamento: m[0]?.req.reglamento ?? "RETIE-2024", categorias: [...new Set(m.map((x) => x!.cat.codigo))] };
      }),
    })),
  };
}
