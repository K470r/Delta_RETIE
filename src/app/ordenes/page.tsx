import Link from "next/link";
import { obtenerDatos } from "@/lib/datos";
import { NOMBRE_ALCANCE, type EstadoOrden } from "@/lib/tipos";

export const dynamic = "force-dynamic";

const ETAPAS: { estado: EstadoOrden; texto: string }[] = [
  { estado: "cotizada", texto: "Cotizada" },
  { estado: "aprobada", texto: "Aprobada" },
  { estado: "asignada", texto: "Asignada" },
  { estado: "en_inspeccion", texto: "En inspección" },
  { estado: "en_revision", texto: "En revisión" },
  { estado: "emitida", texto: "Dictamen emitido" },
  { estado: "entregada", texto: "Entregada" },
];

export default async function Ordenes() {
  const d = await obtenerDatos();
  const nombre = (id?: string) => d.personas.find((p) => p.id === id)?.nombre ?? "—";

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">Órdenes de servicio</h1>
      <div className="grid gap-3">
        {d.ordenes.map((o) => {
          const etapa = ETAPAS.findIndex((e) => e.estado === o.estado);
          const cliente = d.clientes.find((c) => c.id === o.clienteId);
          const puedeInspeccionar = ["asignada", "en_inspeccion"].includes(o.estado);
          return (
            <article key={o.id} className="tarjeta p-4">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div>
                  <div className="font-mono text-xs suave">{o.consecutivo}</div>
                  <h2 className="font-semibold">{o.instalacion}</h2>
                  <div className="suave text-sm">{cliente?.nombre} · {NOMBRE_ALCANCE[o.alcance]}</div>
                </div>
                {puedeInspeccionar && (
                  <Link href={`/inspeccion/${o.id}`} className="rounded-lg bg-[var(--marca)] px-3 py-1.5 text-sm font-semibold text-white">
                    Abrir inspección
                  </Link>
                )}
              </div>
              <ol className="mt-3 flex flex-wrap gap-1 text-xs">
                {ETAPAS.map((e, i) => (
                  <li key={e.estado}
                    className={`rounded px-2 py-0.5 ${i <= etapa ? "bg-[var(--marca)] text-white" : "border suave"}`}
                    style={i > etapa ? { borderColor: "var(--borde)" } : undefined}>
                    {e.texto}
                  </li>
                ))}
              </ol>
              <div className="suave mt-2 text-xs">
                Inspector: {nombre(o.inspectorId)} · Revisor: {nombre(o.revisorId)} · Formato {o.formato.codigo} v{o.formato.version}
              </div>
            </article>
          );
        })}
      </div>
    </div>
  );
}
