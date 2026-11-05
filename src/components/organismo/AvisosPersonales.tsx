"use client";
/**
 * Avisos de la persona que inició sesión, arriba de cada página: documentos que debe
 * firmar y seguimiento del mes 30 de sus certificados (próximo o vencido).
 */
import Link from "next/link";
import { usePathname } from "next/navigation";
import { claseBoton } from "@/components/Formulario";
import { Icono } from "@/components/Icono";
import { useBase, usePersonaActual } from "@/lib/organismo/almacen";
import { estadoSeguimiento } from "@/lib/organismo/competencia";
import { NOMBRE_CALIDAD, pendientesDeFirma } from "@/lib/organismo/documentos";
import { hoyISO } from "@/lib/organismo/reglas";

export function AvisosPersonales() {
  const base = useBase();
  const yo = usePersonaActual(base);
  const ruta = usePathname();
  if (!base || !yo || ruta.startsWith("/documento")) return null;
  const porFirmar = pendientesDeFirma(base, yo.id);
  const seguimientos = yo.certificados
    .filter((c) => !c.anulado && c.fechaVencimiento >= hoyISO())
    .map((c) => ({ c, s: estadoSeguimiento(c, hoyISO()) }))
    .filter((x) => x.s.nivel === "proximo" || x.s.nivel === "vencido");
  if (!porFirmar.length && !seguimientos.length) return null;
  return (
    <div className="no-imprimir mb-4 space-y-2">
      {porFirmar.length > 0 && (
        <div className="alerta-naranja flex flex-wrap items-center justify-between gap-3 rounded-xl px-4 py-3">
          <div className="flex items-center gap-3">
            <Icono nombre="firma" tamano={24} />
            <div>
              <div className="font-extrabold">Tiene {porFirmar.length} {porFirmar.length === 1 ? "documento" : "documentos"} por firmar</div>
              <div className="text-sm">{porFirmar.map((x) => `${x.doc.titulo} (como ${x.calidades.map((c) => NOMBRE_CALIDAD[c].toLowerCase()).join(" y ")})`).join(" · ")}</div>
            </div>
          </div>
          <Link href={`/documento?id=${porFirmar[0].doc.id}`} className={claseBoton("primario")} style={{ background: "#e8772e" }}>
            <Icono nombre="firma" tamano={16} /> Firmar ahora
          </Link>
        </div>
      )}
      {seguimientos.map(({ c, s }) => (
        <div key={c.id} className={`flex flex-wrap items-center justify-between gap-3 rounded-xl px-4 py-3 ${s.nivel === "vencido" ? "alerta-roja" : "alerta-naranja"}`}>
          <div className="flex items-center gap-3">
            <Icono nombre="alerta" tamano={24} />
            <div>
              <div className="font-extrabold">
                {s.nivel === "vencido"
                  ? `Su certificado N.° ${c.numero}: seguimiento del mes 30 vencido desde el ${s.periodo?.desde}`
                  : `Su certificado N.° ${c.numero}: faltan ${s.dias} ${s.dias === 1 ? "día" : "días"} para el seguimiento del mes 30`}
              </div>
              <div className="text-sm">
                {s.nivel === "vencido" ? "No puede ejercer las actividades de este certificado hasta registrarlo." : `Fecha máxima: ${s.limite}.`}
              </div>
            </div>
          </div>
          <Link href="/mi-hoja-de-vida" className={claseBoton("primario")} style={{ background: s.nivel === "vencido" ? "#d92d20" : "#e8772e" }}>
            <Icono nombre="calendario" tamano={16} /> Registrar seguimiento
          </Link>
        </div>
      ))}
    </div>
  );
}
