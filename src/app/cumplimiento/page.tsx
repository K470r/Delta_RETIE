import { EtiquetaEstado } from "@/components/Estado";
import { evaluarCumplimiento } from "@/lib/controles";
import { obtenerDatos } from "@/lib/datos";
import { NUMERALES_17020 } from "@/lib/iso17020";

export const dynamic = "force-dynamic";

export default async function Cumplimiento() {
  const datos = await obtenerDatos();
  const evaluacion = evaluarCumplimiento(datos, NUMERALES_17020.map((n) => n.codigo));

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">Matriz de cumplimiento 17020</h1>
      <p className="suave text-sm">
        Cada numeral muestra los controles automáticos que lo soportan. Los numerales marcados como
        &quot;Control manual&quot; se gestionan con evidencia documental (módulo de control documental, fase 4).
      </p>
      {NUMERALES_17020.map((n) => {
        const ev = evaluacion.find((e) => e.numeral === n.codigo)!;
        return (
          <section key={n.codigo} id={n.codigo} className="tarjeta scroll-mt-4 p-4">
            <div className="flex flex-wrap items-start justify-between gap-2">
              <div>
                <h2 className="font-semibold">{n.codigo} {n.titulo}</h2>
                <p className="suave text-sm">{n.resumen}</p>
              </div>
              <EtiquetaEstado estado={ev.estado} />
            </div>
            {ev.controles.length > 0 && (
              <ul className="mt-3 divide-y" style={{ borderColor: "var(--borde)" }}>
                {ev.controles.map((c) => (
                  <li key={c.id} className="py-2 text-sm" style={{ borderColor: "var(--borde)" }}>
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <span><span className="suave font-mono text-xs">{c.id}</span> {c.titulo}</span>
                      <span className="flex items-center gap-2">
                        <span className="suave text-xs">{c.resultado.resumen}</span>
                        <EtiquetaEstado estado={c.resultado.estado} />
                      </span>
                    </div>
                    {c.resultado.hallazgos.length > 0 && (
                      <ul className="suave mt-1 list-disc pl-6">
                        {c.resultado.hallazgos.map((h) => <li key={h}>{h}</li>)}
                      </ul>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </section>
        );
      })}
    </div>
  );
}
