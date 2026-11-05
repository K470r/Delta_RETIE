"use client";
/**
 * Documentos del organismo con historial (0008): certificado de acreditación ONAC,
 * póliza de responsabilidad civil y declaración de independencia (tipo A, Anexo A.1).
 * Cada carga es una versión nueva; la anterior queda reemplazada y se conserva.
 */
import { useState } from "react";
import { Boton, Campo, Entrada, Errores, claseBoton } from "@/components/Formulario";
import { Icono, type NombreIcono } from "@/components/Icono";
import { abrirArchivo, cargarArchivo, REGLAS_DOCUMENTO } from "@/lib/archivos";
import { actualizar, mostrarError, nuevoId } from "@/lib/organismo/almacen";
import { designacionesVigentes, hoyISO, nombrePersona } from "@/lib/organismo/reglas";
import type { BaseOrganismos, DocumentoOrganismo, Organismo, TipoDocumentoOrganismo } from "@/lib/organismo/tipos";
import { CON_SUPABASE } from "@/lib/supabase";
import { usePermisosOrganismo } from "@/lib/organismo/permisos";

const TIPOS: { tipo: TipoDocumentoOrganismo; titulo: string; icono: NombreIcono; ayuda: string }[] = [
  { tipo: "acreditacion", titulo: "Certificado de acreditación ONAC", icono: "dictamenes", ayuda: "Con su anexo de alcance. Cargue una versión nueva cuando ONAC renueve, amplíe, reduzca o actualice la acreditación. Lo ve todo el personal." },
  { tipo: "poliza_rc", titulo: "Póliza de responsabilidad civil", icono: "imparcialidad", ayuda: "Cargue la nueva cuando se renueve. La ven la gerencia, el SG y la dirección técnica." },
  { tipo: "independencia", titulo: "Declaración de independencia (tipo A)", icono: "organismo", ayuda: "17020 Anexo A.1. Cargue una versión nueva cuando se actualice o se vuelva a firmar. La ven la gerencia, el SG y la dirección técnica." },
];

const fecha = (iso?: string) => (iso ? new Date(iso).toLocaleDateString("es-CO", { dateStyle: "medium" }) : "—");

export function DocumentosOrganismo({ base, o }: { base: BaseOrganismos; o: Organismo }) {
  const docs = (base.documentos ?? []).filter((d) => d.organismoId === o.id);
  const { gestion } = usePermisosOrganismo(base, o.id);
  return (
    <div className="space-y-4">
      {!gestion && <p className="tarjeta p-3 text-sm">Los documentos del organismo los cargan la gerencia y el responsable del SG.</p>}
      <p className="suave text-sm">
        Cada documento conserva su historial: al cargar una versión nueva, la anterior queda <b>reemplazada</b> con su PDF, quién la cargó y cuándo.
        Las fechas de la versión vigente actualizan los datos del organismo y el tablero avisa antes de que venzan.
      </p>
      {TIPOS.map((t) => (
        <Tarjeta key={t.tipo} base={base} o={o} t={t}
          versiones={docs.filter((d) => d.tipo === t.tipo).sort((a, b) => b.cargado.localeCompare(a.cargado))} puede={gestion} />
      ))}
    </div>
  );
}

function Tarjeta({ base, o, t, versiones, puede }: {
  base: BaseOrganismos; o: Organismo; t: (typeof TIPOS)[number]; versiones: DocumentoOrganismo[]; puede: boolean;
}) {
  const [cargando, setCargando] = useState(false);
  const [historial, setHistorial] = useState(false);
  const vigente = versiones[0];
  const anteriores = versiones.slice(1);
  const vence = vigente?.hasta;
  const vencido = vence && vence < hoyISO();
  return (
    <section className="tarjeta space-y-3 p-4">
      <div className="flex flex-wrap items-start gap-3">
        <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl" style={{ background: "color-mix(in srgb, var(--marca) 14%, transparent)" }}>
          <Icono nombre={t.icono} color="var(--marca)" tamano={22} />
        </span>
        <div className="min-w-0 flex-1">
          <h3 className="font-titulo text-base font-extrabold">{t.titulo}</h3>
          <p className="suave text-xs">{t.ayuda}</p>
        </div>
        {puede && !cargando && <Boton variante="contorno" onClick={() => setCargando(true)}><Icono nombre="subir" tamano={16} /> {vigente ? "Cargar nueva versión" : "Cargar"}</Boton>}
      </div>

      {vigente ? (
        <div className="flex flex-wrap items-center justify-between gap-3 rounded-lg border p-3 text-sm" style={{ borderColor: "var(--borde)" }}>
          <div className="space-y-0.5">
            <div className="flex flex-wrap items-center gap-2">
              <span className="rounded-full px-2 py-0.5 text-xs font-bold" style={vencido ? { background: "#FBE2E0", color: "#B42318" } : { background: "#DCF2E9", color: "#16795A" }}>
                {vencido ? "Vencido" : "Vigente"}
              </span>
              <b>{resumen(vigente)}</b>
            </div>
            <div className="suave text-xs">{detalle(vigente)}</div>
            <div className="suave text-xs">Cargado el {fecha(vigente.cargado)}</div>
          </div>
          <VerPdf ruta={vigente.archivoRuta} />
        </div>
      ) : !cargando && <p className="suave text-sm">Aún no se ha cargado.</p>}

      {cargando && <FormularioVersion base={base} o={o} tipo={t.tipo} anterior={vigente} onTerminar={() => setCargando(false)} />}

      {anteriores.length > 0 && (
        <div>
          <button className="suave text-sm underline" onClick={() => setHistorial(!historial)}>
            {historial ? "Ocultar" : "Ver"} historial ({anteriores.length})
          </button>
          {historial && (
            <ul className="mt-2 space-y-2">
              {anteriores.map((d) => (
                <li key={d.id} className="flex flex-wrap items-center justify-between gap-2 rounded-lg border p-2 text-xs opacity-80" style={{ borderColor: "var(--borde)" }}>
                  <span><b>{resumen(d)}</b> · {detalle(d)} · cargado el {fecha(d.cargado)} · reemplazado el {fecha(d.reemplazadoEn ?? versiones[versiones.indexOf(d) - 1]?.cargado)}</span>
                  <VerPdf ruta={d.archivoRuta} />
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </section>
  );
}

function resumen(d: DocumentoOrganismo) {
  if (d.tipo === "acreditacion") return `${d.numero} · vence ${d.hasta}`;
  if (d.tipo === "poliza_rc") return `Póliza ${d.numero}${d.emisor ? ` · ${d.emisor}` : ""} · vence ${d.hasta}`;
  return `Firmada el ${d.fecha}${d.firmadoPor ? ` por ${d.firmadoPor}` : ""}`;
}

function detalle(d: DocumentoOrganismo) {
  if (d.tipo === "acreditacion")
    return [d.fecha && `Otorgada ${d.fecha}`, d.renovacion && `renovada ${d.renovacion}`, d.actualizacion && `actualizada ${d.actualizacion}`].filter(Boolean).join(" · ");
  if (d.tipo === "poliza_rc")
    return [`Vigencia ${d.desde} a ${d.hasta}`, d.valor ? `valor asegurado $${d.valor.toLocaleString("es-CO")}` : ""].filter(Boolean).join(" · ");
  return d.observacion ?? "";
}

function VerPdf({ ruta }: { ruta: string }) {
  return (
    <button className={claseBoton("contorno", "pequeno")}
      onClick={async () => { const e = await abrirArchivo("documentos", ruta); if (e) mostrarError(e); }}>
      <Icono nombre="ojo" tamano={16} /> Ver PDF
    </button>
  );
}

function FormularioVersion({ base, o, tipo, anterior, onTerminar }: {
  base: BaseOrganismos; o: Organismo; tipo: TipoDocumentoOrganismo; anterior?: DocumentoOrganismo; onTerminar: () => void;
}) {
  const repLegal = designacionesVigentes(base, o.id, ["representante_legal"])[0];
  const [d, setD] = useState<Partial<DocumentoOrganismo>>(() => tipo === "acreditacion"
    ? { numero: anterior?.numero ?? o.codigoAcreditacion, emisor: "ONAC", fecha: anterior?.fecha ?? o.acreditacionOtorgada, hasta: anterior?.hasta ?? o.acreditacionVence,
        renovacion: anterior?.renovacion ?? o.acreditacionRenovada, actualizacion: anterior?.actualizacion ?? o.acreditacionActualizada }
    : tipo === "poliza_rc" ? { emisor: anterior?.emisor }
    : { fecha: hoyISO(), firmadoPor: repLegal ? nombrePersona(base.personas.find((p) => p.id === repLegal.personaId)) : undefined });
  const [archivo, setArchivo] = useState<File>();
  const [errores, setErrores] = useState<string[]>([]);
  const [guardando, setGuardando] = useState(false);
  const set = (k: keyof DocumentoOrganismo) => (e: { target: { value: string } }) => setD({ ...d, [k]: e.target.value || undefined });

  const guardar = async () => {
    const e: string[] = [];
    if (!archivo) e.push("Adjunte el PDF");
    if (tipo === "acreditacion" && (!d.numero || !d.hasta)) e.push("El código de acreditación y la fecha de vencimiento son obligatorios");
    if (tipo === "poliza_rc" && (!d.numero || !d.desde || !d.hasta)) e.push("El número de la póliza y su vigencia son obligatorios");
    if (tipo === "independencia" && !d.fecha) e.push("La fecha de firma es obligatoria");
    if (d.desde && d.hasta && d.hasta <= d.desde) e.push("La vigencia debe terminar después de iniciar");
    if (d.fecha && d.hasta && d.hasta <= d.fecha) e.push("El vencimiento debe ser posterior al otorgamiento");
    setErrores(e);
    if (e.length || !archivo) return;
    setGuardando(true);
    const id = nuevoId();
    const subida = await cargarArchivo("documentos", `${o.id}/${tipo}/${id}.pdf`, archivo, REGLAS_DOCUMENTO);
    if (subida.error || !subida.ruta) { setGuardando(false); return setErrores([subida.error ?? "No se pudo cargar el PDF"]); }
    const ahora = new Date().toISOString();
    const nuevo: DocumentoOrganismo = { ...d, id, organismoId: o.id, tipo, archivoRuta: subida.ruta, cargado: ahora } as DocumentoOrganismo;
    const error = await actualizar((b) => ({
      ...b,
      documentos: [...(b.documentos ?? []).map((x) => (!CON_SUPABASE && x.organismoId === o.id && x.tipo === tipo && !x.reemplazadoEn ? { ...x, reemplazadoEn: ahora } : x)), nuevo],
      // En Supabase la base de datos actualiza el organismo; en modo local se hace aquí.
      organismos: CON_SUPABASE ? b.organismos : b.organismos.map((x) => (x.id !== o.id ? x
        : tipo === "acreditacion" ? { ...x, codigoAcreditacion: d.numero, acreditacionOtorgada: d.fecha ?? x.acreditacionOtorgada, acreditacionRenovada: d.renovacion, acreditacionActualizada: d.actualizacion, acreditacionVence: d.hasta }
        : tipo === "poliza_rc" ? { ...x, polizaRCNumero: d.numero, polizaRCVence: d.hasta }
        : { ...x, declaracionIndependencia: d.fecha })),
    }), { mostrarError: false });
    setGuardando(false);
    if (error) return setErrores([error]);
    onTerminar();
  };

  return (
    <div className="space-y-3 rounded-lg border p-3" style={{ borderColor: "var(--marca)" }}>
      <div className="grid gap-3 sm:grid-cols-3">
        {tipo === "acreditacion" && (<>
          <Campo etiqueta="Código de acreditación"><Entrada value={d.numero ?? ""} onChange={set("numero")} placeholder="17-OIN-032" /></Campo>
          <Campo etiqueta="Fecha de otorgamiento"><Entrada type="date" value={d.fecha ?? ""} onChange={set("fecha")} /></Campo>
          <Campo etiqueta="Fecha de vencimiento"><Entrada type="date" value={d.hasta ?? ""} onChange={set("hasta")} /></Campo>
          <Campo etiqueta="Fecha de renovación"><Entrada type="date" value={d.renovacion ?? ""} onChange={set("renovacion")} /></Campo>
          <Campo etiqueta="Última actualización publicada"><Entrada type="date" value={d.actualizacion ?? ""} onChange={set("actualizacion")} /></Campo>
        </>)}
        {tipo === "poliza_rc" && (<>
          <Campo etiqueta="Aseguradora"><Entrada value={d.emisor ?? ""} onChange={set("emisor")} /></Campo>
          <Campo etiqueta="Número de la póliza"><Entrada value={d.numero ?? ""} onChange={set("numero")} /></Campo>
          <Campo etiqueta="Valor asegurado (pesos)"><Entrada type="number" min={0} value={d.valor ?? ""} onChange={(e) => setD({ ...d, valor: e.target.value ? Number(e.target.value) : undefined })} /></Campo>
          <Campo etiqueta="Vigente desde"><Entrada type="date" value={d.desde ?? ""} onChange={set("desde")} /></Campo>
          <Campo etiqueta="Vigente hasta"><Entrada type="date" value={d.hasta ?? ""} onChange={set("hasta")} /></Campo>
        </>)}
        {tipo === "independencia" && (<>
          <Campo etiqueta="Fecha de firma"><Entrada type="date" value={d.fecha ?? ""} onChange={set("fecha")} /></Campo>
          <Campo etiqueta="Firmada por"><Entrada value={d.firmadoPor ?? ""} onChange={set("firmadoPor")} placeholder="Representante legal" /></Campo>
        </>)}
        <Campo etiqueta="Observación (opcional)"><Entrada value={d.observacion ?? ""} onChange={set("observacion")} /></Campo>
      </div>
      <label className="flex cursor-pointer items-center gap-2 rounded-lg border-2 border-dashed p-3 text-sm" style={{ borderColor: "var(--borde)" }}>
        <Icono nombre="subir" color="var(--marca)" />
        <span className="flex-1">{archivo ? archivo.name : "Adjuntar el PDF (máximo 15 MB)"}</span>
        <input type="file" accept="application/pdf" className="sr-only" onChange={(e) => setArchivo(e.target.files?.[0])} />
      </label>
      {anterior && <p className="suave text-xs">La versión vigente quedará como <b>reemplazada</b> y se conservará en el historial.</p>}
      <Errores errores={errores} />
      <div className="flex gap-2">
        <Boton onClick={guardar} disabled={guardando}>{guardando ? "Guardando…" : "Guardar versión"}</Boton>
        <Boton variante="secundario" onClick={onTerminar}>Cancelar</Boton>
      </div>
    </div>
  );
}
