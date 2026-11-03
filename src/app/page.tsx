import Link from "next/link";
import { EtiquetaEstado } from "@/components/Estado";
import { evaluarCumplimiento } from "@/lib/controles";
import { obtenerDatos } from "@/lib/datos";
import { CAPITULOS, NUMERALES_17020 } from "@/lib/iso17020";

export const dynamic = "force-dynamic";

export default async function Tablero() {
  const datos = await obtenerDatos();
  const evaluacion = evaluarCumplimiento(datos, NUMERALES_17020.map((n) => n.codigo));
  const controles = evaluacion.flatMap((e) => e.controles);
  const conteo = (estado: string) => controles.filter((c) => c.resultado.estado === estado).length;
  const hallazgos = controles.filter((c) => c.resultado.estado === "incumple" || c.resultado.estado === "alerta");

  return (
    <div className="space-y-8">
      <section>
        <h1 className="text-2xl font-bold">Cumplimiento ISO/IEC 17020</h1>
        <p className="suave text-sm">
          {datos.config.nombre} · Organismo tipo {datos.config.tipoOrganismo} · Evaluado automáticamente a partir de los registros operativos
        </p>
      </section>

      <section className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        {[
          ["Controles", controles.length, ""],
          ["Cumplen", conteo("cumple"), "text-emerald-600"],
          ["En alerta", conteo("alerta"), "text-amber-600"],
          ["Incumplen", conteo("incumple"), "text-red-600"],
        ].map(([t, v, c]) => (
          <div key={t as string} className="tarjeta p-4">
            <div className="suave text-xs uppercase tracking-wide">{t}</div>
            <div className={`text-3xl font-bold tabular-nums ${c}`}>{v}</div>
          </div>
        ))}
      </section>

      {hallazgos.length > 0 && (
        <section className="tarjeta p-4">
          <h2 className="mb-3 font-semibold">Requiere atención</h2>
          <ul className="space-y-3">
            {hallazgos
              .sort((a, b) => (a.resultado.estado === "incumple" ? -1 : 1) - (b.resultado.estado === "incumple" ? -1 : 1))
              .map((c) => (
                <li key={c.id} className="text-sm">
                  <div className="flex flex-wrap items-center gap-2">
                    <EtiquetaEstado estado={c.resultado.estado} />
                    <Link href={`/cumplimiento#${c.numeral}`} className="font-medium hover:underline">
                      {c.numeral} · {c.titulo}
                    </Link>
                  </div>
                  <ul className="suave mt-1 list-disc pl-6">
                    {c.resultado.hallazgos.map((h) => <li key={h}>{h}</li>)}
                  </ul>
                </li>
              ))}
          </ul>
        </section>
      )}

      <section className="space-y-4">
        <h2 className="font-semibold">Estado por numeral</h2>
        {Object.entries(CAPITULOS).map(([cap, titulo]) => (
          <div key={cap}>
            <h3 className="suave mb-2 text-sm font-medium">{cap}. {titulo}</h3>
            <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
              {NUMERALES_17020.filter((n) => n.capitulo === cap).map((n) => {
                const ev = evaluacion.find((e) => e.numeral === n.codigo)!;
                return (
                  <Link key={n.codigo} href={`/cumplimiento#${n.codigo}`} className="tarjeta flex items-center justify-between gap-2 p-3 hover:shadow-sm">
                    <span className="text-sm"><b>{n.codigo}</b> {n.titulo}</span>
                    <EtiquetaEstado estado={ev.estado} />
                  </Link>
                );
              })}
            </div>
          </div>
        ))}
      </section>
    </div>
  );
}
