"use client";
import Link from "next/link";
import { useBase } from "@/lib/organismo/almacen";
import { evaluarOrganismo, lineasAcreditadas } from "@/lib/organismo/reglas";

export default function Organismos() {
  const base = useBase();
  if (!base) return <p className="suave">Cargando…</p>;
  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h1 className="text-2xl font-bold">Organismos de inspección</h1>
          <p className="suave text-sm">Organismos tipo A con alcance RETIE / RETILAP acreditado ante ONAC.</p>
        </div>
        <Link href="/organismos/nuevo" className="rounded-lg bg-[var(--marca)] px-3 py-2 text-sm font-semibold text-white">+ Nuevo organismo</Link>
      </div>
      {base.organismos.length === 0 && (
        <div className="tarjeta p-6 text-center">
          <p className="mb-3">Aún no hay organismos registrados.</p>
          <Link href="/organismos/nuevo" className="underline marca">Crear el primer organismo</Link>
        </div>
      )}
      <div className="grid gap-3 sm:grid-cols-2">
        {base.organismos.map((o) => {
          const controles = evaluarOrganismo(base, o);
          const inc = controles.filter((c) => c.estado === "incumple").length;
          const al = controles.filter((c) => c.estado === "alerta").length;
          return (
            <Link key={o.id} href={`/organismos/${o.id}`} className="tarjeta block space-y-2 p-4 hover:shadow-sm">
              <div className="font-semibold">{o.razonSocial}</div>
              <div className="suave text-sm">NIT {o.nit}{o.codigoAcreditacion && ` · ${o.codigoAcreditacion}`}</div>
              <div className="text-sm">{lineasAcreditadas(o).length} actividades acreditadas</div>
              <div className="flex gap-2 text-xs">
                <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-300">{controles.length - inc - al} cumplen</span>
                {al > 0 && <span className="rounded-full bg-amber-100 px-2 py-0.5 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300">{al} alertas</span>}
                {inc > 0 && <span className="rounded-full bg-red-100 px-2 py-0.5 text-red-800 dark:bg-red-900/40 dark:text-red-300">{inc} incumplen</span>}
              </div>
            </Link>
          );
        })}
      </div>
    </div>
  );
}
