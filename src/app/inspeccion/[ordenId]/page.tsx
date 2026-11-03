import { notFound } from "next/navigation";
import { obtenerDatos } from "@/lib/datos";
import { obtenerFormato } from "@/lib/formatos";
import { NOMBRE_ALCANCE } from "@/lib/tipos";
import { ListaInspeccion } from "./ListaInspeccion";

export const dynamic = "force-dynamic";

export default async function Inspeccion({ params }: { params: Promise<{ ordenId: string }> }) {
  const { ordenId } = await params;
  const d = await obtenerDatos();
  const orden = d.ordenes.find((o) => o.id === ordenId);
  if (!orden) notFound();
  const formato = obtenerFormato(orden.formato.codigo);
  if (!formato) notFound();
  const inspector = d.personas.find((p) => p.id === orden.inspectorId);
  const cliente = d.clientes.find((c) => c.id === orden.clienteId);

  // Controles 17020 aplicados ANTES de permitir iniciar la inspección.
  const bloqueos: string[] = [];
  if (!inspector) bloqueos.push("La orden no tiene inspector asignado.");
  else {
    if (!inspector.alcancesAutorizados.includes(orden.alcance))
      bloqueos.push(`${inspector.nombre} no tiene autorización para el alcance "${NOMBRE_ALCANCE[orden.alcance]}" (17020 §6.1).`);
    if (inspector.conflictosConClientes.includes(orden.clienteId))
      bloqueos.push(`${inspector.nombre} declaró conflicto de interés con este cliente (17020 §4.1).`);
  }
  if (!orden.solicitudRevisada) bloqueos.push("La solicitud no ha sido revisada (17020 §7.1).");
  if (d.config.formatosVigentes[formato.codigo_formato] !== formato.version)
    bloqueos.push(`El formato ${formato.codigo_formato} v${formato.version} no es la versión vigente (17020 §8.3).`);

  return (
    <div className="space-y-4">
      <div>
        <div className="font-mono text-xs suave">{orden.consecutivo} · {formato.codigo_formato} v{formato.version} · {formato.reglamento}</div>
        <h1 className="text-xl font-bold">{orden.instalacion}</h1>
        <div className="suave text-sm">{cliente?.nombre} · {NOMBRE_ALCANCE[orden.alcance]} · Inspector: {inspector?.nombre ?? "—"}</div>
      </div>
      {bloqueos.length > 0 ? (
        <div className="rounded-xl border border-red-300 bg-red-50 p-4 text-sm text-red-900 dark:border-red-800 dark:bg-red-950 dark:text-red-200">
          <p className="mb-2 font-semibold">No se puede iniciar la inspección:</p>
          <ul className="list-disc pl-5">{bloqueos.map((b) => <li key={b}>{b}</li>)}</ul>
          <p className="mt-2">El director técnico debe reasignar o corregir la orden.</p>
        </div>
      ) : (
        <ListaInspeccion ordenId={orden.id} formato={formato} equipos={d.equipos} />
      )}
    </div>
  );
}
