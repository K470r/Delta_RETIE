"use client";
/**
 * Documento de designación o autorización del personal (0013): se lee, se firma
 * electrónicamente (confirmando la contraseña), se imprime o se guarda en PDF, y como
 * respaldo se carga el PDF firmado a mano.
 */
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense, useEffect, useState } from "react";
import { Boton, Campo, Entrada, Errores, Selector, claseBoton } from "@/components/Formulario";
import { Icono } from "@/components/Icono";
import { abrirArchivo, useEnlace } from "@/lib/archivos";
import {
  elegirPersonaLocal, firmarDocumento, mostrarError, registrarFirmadoAMano, useBase, usePersonaActual,
} from "@/lib/organismo/almacen";
import {
  FIRMAS_REQUERIDAS, NOMBRE_CALIDAD, documentoFirmado, firmasFaltantes, huella, puedeFirmarComo,
} from "@/lib/organismo/documentos";
import { usePermisosOrganismo } from "@/lib/organismo/permisos";
import { designacionesVigentes, nombrePersona } from "@/lib/organismo/reglas";
import type { BaseOrganismos, CalidadFirma, DocumentoPersonal } from "@/lib/organismo/tipos";
import { NOMBRE_ROL } from "@/lib/organismo/tipos";
import { CON_SUPABASE } from "@/lib/supabase";

export default function PaginaDocumento() {
  return <Suspense><Documento /></Suspense>;
}

const fechaHora = (iso: string) =>
  new Date(iso).toLocaleString("es-CO", { dateStyle: "long", timeStyle: "short", timeZone: "America/Bogota" });

function Documento() {
  const params = useSearchParams();
  const id = params.get("id");
  const volver = params.get("volver");
  const base = useBase();
  const yo = usePersonaActual(base);
  const [local, setLocal] = useState<string>("");
  const doc = base?.documentosPersonal?.find((x) => x.id === id);
  const o = base?.organismos.find((x) => x.id === doc?.organismoId);
  const d = base?.designaciones.find((x) => x.id === doc?.designacionId);
  const logo = useEnlace("logos", o?.logoRuta);
  const { gestion } = usePermisosOrganismo(base, o?.id);
  const [verificada, setVerificada] = useState<boolean | null>(null);

  useEffect(() => {
    let vivo = true;
    if (doc) huella(doc.contenido).then((h) => { if (vivo) setVerificada(h === doc.huella); });
    return () => { vivo = false; };
  }, [doc]);

  if (!base) return <p className="suave">Cargando…</p>;
  if (!doc || !o || !d) return <p className="tarjeta p-4 text-sm">El documento no existe o no tiene permiso para verlo.</p>;

  const firmante = CON_SUPABASE ? yo?.id : local || undefined;
  const calidades = puedeFirmarComo(base, doc, firmante);
  const firmado = documentoFirmado(doc);
  const designada = base.personas.find((p) => p.id === d.personaId);

  return (
    <div className="space-y-4">
      <div className="no-imprimir flex flex-wrap items-center justify-between gap-2">
        <Link href={volver ?? `/organismos/${o.id}?p=${d.rol === "inspector" ? "inspectores" : ["gerente"].includes(d.rol) ? "gerencia" : d.rol === "responsable_sg" ? "sg" : "dt"}`}
          className={claseBoton("secundario", "pequeno")}>← Volver</Link>
        <div className="flex flex-wrap items-center gap-2">
          <span className={`rounded-lg px-3 py-1 text-xs font-bold ${doc.reemplazadoEn ? "alerta-roja" : firmado ? "alerta-verde" : "alerta-naranja"}`}>
            {doc.reemplazadoEn ? "Reemplazado por un documento más reciente"
              : firmado ? (doc.firmadoAManoRuta ? "Firmado a mano" : "Firmado electrónicamente")
              : `Pendiente de firma: ${firmasFaltantes(doc).map((c) => NOMBRE_CALIDAD[c]).join(" y ")}`}
          </span>
          <Boton variante="contorno" tamano="pequeno" onClick={() => window.print()}>
            <Icono nombre="imprimir" tamano={15} /> Imprimir o guardar en PDF
          </Boton>
        </div>
      </div>

      {!CON_SUPABASE && !firmado && !doc.reemplazadoEn && (
        <div className="no-imprimir tarjeta flex flex-wrap items-end gap-3 p-3 text-sm">
          <Campo etiqueta="Modo local (pruebas): firmar como">
            <Selector value={local} onChange={(e) => { setLocal(e.target.value); elegirPersonaLocal(e.target.value || undefined); }}>
              <option value="">Seleccione…</option>
              {designacionesVigentes(base, o.id, Object.keys(NOMBRE_ROL) as (keyof typeof NOMBRE_ROL)[]).map((x) => (
                <option key={x.id} value={x.personaId}>{nombrePersona(base.personas.find((p) => p.id === x.personaId))} — {NOMBRE_ROL[x.rol]}</option>
              ))}
            </Selector>
          </Campo>
        </div>
      )}

      {calidades.length > 0 && <PanelFirma doc={doc} calidades={calidades} />}

      <article className="tarjeta solo-documento space-y-6 p-6 sm:p-10">
        {logo && <img src={logo} alt={`Logo de ${o.razonSocial}`} className="h-16 w-auto object-contain" />}
        <div className="whitespace-pre-wrap text-[15px] leading-relaxed">
          {doc.contenido.split("\n").map((linea, i) => (linea === doc.titulo.toUpperCase()
            ? <div key={i} className="py-2 text-center font-titulo text-lg font-extrabold">{linea}</div>
            : <div key={i}>{linea || "\u00a0"}</div>))}
        </div>
        <HojaDeFirmas base={base} doc={doc} />
        <p className="suave border-t pt-3 text-xs" style={{ borderColor: "var(--borde)" }}>
          Documento generado en Ultra RETIE el {fechaHora(doc.creadoEn)} para {nombrePersona(designada)} ({NOMBRE_ROL[d.rol]}).
          Firma electrónica conforme a la Ley 527 de 1999 y al Decreto 2364 de 2012 (compilado en el Decreto 1074 de 2015).
          Huella SHA-256 del texto: <span className="break-all font-mono">{doc.huella || "—"}</span>
          {verificada !== null && (verificada ? " ✓ el texto no ha cambiado." : " ✕ el texto no coincide con la huella.")}
        </p>
      </article>

      {gestion && !firmado && !doc.reemplazadoEn && <FirmadoAMano doc={doc} />}
      {doc.firmadoAManoRuta && (
        <div className="no-imprimir tarjeta flex flex-wrap items-center justify-between gap-2 p-4 text-sm">
          <span>
            PDF firmado a mano, cargado
            {doc.firmadoAManoPor && ` por ${nombrePersona(base.personas.find((p) => p.id === doc.firmadoAManoPor))}`}
            {doc.firmadoAManoEn && ` el ${fechaHora(doc.firmadoAManoEn)}`}.
          </span>
          <Boton variante="contorno" tamano="pequeno" onClick={async () => { const e = await abrirArchivo("documentos", doc.firmadoAManoRuta!); if (e) mostrarError(e); }}>
            <Icono nombre="ojo" tamano={15} /> Ver PDF firmado
          </Boton>
        </div>
      )}
    </div>
  );
}

/** Firmantes: quién firmó (con fecha, hora y datos de la firma) o la línea para firmar a mano. */
function HojaDeFirmas({ base, doc }: { base: BaseOrganismos; doc: DocumentoPersonal }) {
  const d = base.designaciones.find((x) => x.id === doc.designacionId)!;
  const persona = (id?: string) => base.personas.find((p) => p.id === id);
  const esperado = (c: CalidadFirma) => {
    if (c === "designado") return persona(d.personaId);
    if (c === "evaluador") return persona(doc.evaluadorId);
    const rol = c === "gerente" ? "gerente" : "director_tecnico";
    const v = designacionesVigentes(base, doc.organismoId, [rol])[0];
    return v ? persona(v.personaId) : undefined;
  };
  return (
    <div className="grid gap-4 sm:grid-cols-2">
      {FIRMAS_REQUERIDAS[doc.tipo].map((c) => {
        const f = doc.firmas.find((x) => x.enCalidad === c);
        const p = f ? persona(f.personaId) : esperado(c);
        return (
          <div key={c} className="space-y-1 rounded-lg border p-3 text-sm" style={{ borderColor: "var(--borde)" }}>
            {f ? (
              <div className="font-semibold" style={{ color: "var(--verde)" }}>✓ Firmado electrónicamente</div>
            ) : (
              <div className="pt-8">______________________________</div>
            )}
            <div className="font-semibold">{p ? nombrePersona(p) : "—"}</div>
            <div className="suave text-xs">{NOMBRE_CALIDAD[c]}{p && ` · ${p.tipoDocumento} ${p.documento}`}</div>
            {f && (
              <div className="suave text-xs">
                {fechaHora(f.firmadoEn)} (hora de Colombia){f.correo && ` · ${f.correo}`}
                {f.autenticadoEn && ` · confirmó su contraseña a las ${new Date(f.autenticadoEn).toLocaleTimeString("es-CO", { timeStyle: "short", timeZone: "America/Bogota" })}`}
                {f.ip && ` · IP ${f.ip}`}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

function PanelFirma({ doc, calidades }: { doc: DocumentoPersonal; calidades: CalidadFirma[] }) {
  const [calidad, setCalidad] = useState<CalidadFirma>(calidades[0]);
  const [leido, setLeido] = useState(false);
  const [contrasena, setContrasena] = useState("");
  const [errores, setErrores] = useState<string[]>([]);
  const [firmando, setFirmando] = useState(false);
  const firmar = async () => {
    if (!leido) return setErrores(["Confirme que leyó el documento completo"]);
    if (CON_SUPABASE && !contrasena) return setErrores(["Escriba su contraseña para confirmar la firma"]);
    setFirmando(true);
    const h = await huella(doc.contenido);   // la huella del texto que se está viendo
    const error = await firmarDocumento(doc.id, calidad, h, contrasena);
    setFirmando(false);
    setContrasena("");
    if (error) return setErrores([error]);
    setErrores([]); setLeido(false);
  };
  return (
    <section className="no-imprimir space-y-3 rounded-xl border-2 p-4" style={{ borderColor: "var(--marca)", background: "color-mix(in srgb, var(--marca) 6%, var(--tarjeta))" }}>
      <h2 className="flex items-center gap-2 font-semibold"><Icono nombre="firma" tamano={20} color="var(--marca)" /> Firmar electrónicamente</h2>
      <p className="text-sm">
        Lea el documento completo (abajo). Al firmar queda registrado su nombre, la fecha y la hora, su usuario y la huella del texto:
        si el texto cambiara, la firma no valdría.
      </p>
      <div className="grid gap-3 sm:grid-cols-2">
        {calidades.length > 1 && (
          <Campo etiqueta="Firma como">
            <Selector value={calidad} onChange={(e) => setCalidad(e.target.value as CalidadFirma)}>
              {calidades.map((c) => <option key={c} value={c}>{NOMBRE_CALIDAD[c]}</option>)}
            </Selector>
          </Campo>
        )}
        {CON_SUPABASE && (
          <Campo etiqueta="Su contraseña (confirma que es usted)">
            <Entrada type="password" autoComplete="current-password" value={contrasena} onChange={(e) => setContrasena(e.target.value)} />
          </Campo>
        )}
      </div>
      <label className="flex items-start gap-2 text-sm">
        <input type="checkbox" className="mt-1" checked={leido} onChange={() => setLeido(!leido)} />
        Leí el documento completo y lo firmo electrónicamente como <b>{NOMBRE_CALIDAD[calidad].toLowerCase()}</b>.
      </label>
      <Errores errores={errores} />
      <Boton onClick={firmar} disabled={firmando}><Icono nombre="firma" tamano={16} /> {firmando ? "Firmando…" : "Firmar"}</Boton>
    </section>
  );
}

function FirmadoAMano({ doc }: { doc: DocumentoPersonal }) {
  const [ocupado, setOcupado] = useState(false);
  const [errores, setErrores] = useState<string[]>([]);
  return (
    <section className="no-imprimir tarjeta space-y-2 p-4">
      <h2 className="font-semibold">Respaldo: firmado a mano</h2>
      <p className="suave text-sm">
        Si alguien no puede firmar en la aplicación: imprima el documento (botón de arriba), que lo firmen a mano todos los firmantes,
        escanéelo y cárguelo aquí en PDF. Queda registrado quién lo cargó y cuándo.
      </p>
      <Errores errores={errores} />
      <label className={`cursor-pointer ${claseBoton("contorno")}`}>
        <Icono nombre="subir" tamano={16} /> {ocupado ? "Cargando…" : "Cargar PDF firmado a mano"}
        <input type="file" accept="application/pdf" className="sr-only" disabled={ocupado}
          onChange={async (e) => {
            const f = e.target.files?.[0]; e.target.value = "";
            if (!f) return;
            if (!confirm("¿El PDF tiene las firmas de todos los firmantes? Al cargarlo, el documento queda firmado.")) return;
            setOcupado(true);
            const error = await registrarFirmadoAMano(doc, f);
            setOcupado(false);
            setErrores(error ? [error] : []);
          }} />
      </label>
    </section>
  );
}
