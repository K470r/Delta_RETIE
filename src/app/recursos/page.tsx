import { obtenerDatos } from "@/lib/datos";
import { NOMBRE_ALCANCE } from "@/lib/tipos";

export const dynamic = "force-dynamic";

const hoy = () => new Date().toISOString().slice(0, 10);

export default async function Recursos() {
  const d = await obtenerDatos();
  return (
    <div className="space-y-8">
      <section>
        <h1 className="mb-3 text-2xl font-bold">Personal (6.1)</h1>
        <div className="tarjeta overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="suave text-xs uppercase">
              <tr><th className="p-3">Nombre</th><th className="p-3">Roles</th><th className="p-3">Alcances autorizados</th>
                <th className="p-3">Decl. imparcialidad</th><th className="p-3">Último monitoreo</th></tr>
            </thead>
            <tbody>
              {d.personas.map((p) => (
                <tr key={p.id} className="border-t" style={{ borderColor: "var(--borde)" }}>
                  <td className="p-3 font-medium">{p.nombre}</td>
                  <td className="p-3">{p.roles.join(", ")}</td>
                  <td className="p-3">{p.alcancesAutorizados.map((a) => NOMBRE_ALCANCE[a]).join(", ") || "—"}</td>
                  <td className="p-3 tabular-nums">{p.declaracionImparcialidad ?? "—"}</td>
                  <td className="p-3 tabular-nums">{p.ultimaSupervisionEnSitio ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
      <section>
        <h2 className="mb-3 text-2xl font-bold">Equipos de medición (6.2)</h2>
        <div className="tarjeta overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="suave text-xs uppercase">
              <tr><th className="p-3">Código</th><th className="p-3">Equipo</th><th className="p-3">Serie</th>
                <th className="p-3">Última calibración</th><th className="p-3">Vence</th></tr>
            </thead>
            <tbody>
              {d.equipos.map((e) => (
                <tr key={e.id} className="border-t" style={{ borderColor: "var(--borde)" }}>
                  <td className="p-3 font-mono">{e.codigo}</td>
                  <td className="p-3">{e.nombre}</td>
                  <td className="p-3">{e.serie}</td>
                  <td className="p-3 tabular-nums">{e.ultimaCalibracion}</td>
                  <td className={`p-3 tabular-nums ${e.vencimientoCalibracion < hoy() ? "font-semibold text-red-600" : ""}`}>
                    {e.vencimientoCalibracion}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
