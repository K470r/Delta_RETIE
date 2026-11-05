/** Permisos de quien inició sesión sobre un organismo (ver navegacion.ts → permisosOrganismo). */
import { permisosOrganismo } from "../navegacion";
import { useSesion } from "../sesion";
import { usePersonaActual } from "./almacen";
import type { BaseOrganismos } from "./tipos";

export function usePermisosOrganismo(base: BaseOrganismos | null, organismoId?: string) {
  const sesion = useSesion();
  const yo = usePersonaActual(base);
  return permisosOrganismo({
    local: sesion.estado === "local",
    usuarioId: sesion.estado === "con_sesion" ? sesion.usuarioId : undefined,
    base, personaId: yo?.id, organismoId,
  });
}
