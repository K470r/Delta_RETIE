"use client";
/**
 * Hoja de vida técnica: formación, experiencia verificada y certificados de
 * competencias con su seguimiento. Alimenta la habilitación por categoría.
 */
import { useState } from "react";
import { actualizar, nuevoId, useBase, usePersonaActual } from "@/lib/organismo/almacen";
import {
  aniosExperiencia, estadoCertificado, estadoSeguimiento, evaluarCompetencia, fechaSeguimiento, sumarAnios,
} from "@/lib/organismo/competencia";
import { hoyISO, nombrePersona, puedeVerificar } from "@/lib/organismo/reglas";
import { CON_SUPABASE } from "@/lib/supabase";
import type { CertificadoCompetencia, Experiencia, Formacion, Persona, RolTecnico } from "@/lib/organismo/tipos";
import {
  AREAS_ILUMINACION, NOMBRE_TIPO_EXPERIENCIA, REQUISITOS, etiquetaCategoria, requisitosDe, type TipoExperiencia,
} from "@/lib/requisitos";
import { Boton, Campo, Entrada, Errores, Grupo, Selector, claseBoton } from "../Formulario";
import { Icono } from "../Icono";
import { EnlaceMotivo, seccionDeMotivo } from "./EnlaceMotivo";
import { ACTIVIDADES, ACTIVIDADES_POR_TENSION, TEXTO_BAJA, nombreCorto } from "@/lib/catalogo";

const GENERACION = ACTIVIDADES.filter((a) => a.reglamento === "RETIE-2024" && a.grupo === "Generación");
import { abrirArchivo, cargarArchivo, extension, REGLAS_SOPORTE } from "@/lib/archivos";
import { aceptarMatricula, mostrarError } from "@/lib/organismo/almacen";
import { entidadMatricula, estadoMatricula } from "@/lib/organismo/matricula";
import { useOrganismoActual } from "@/lib/organismo/actual";
import { usePermisosOrganismo } from "@/lib/organismo/permisos";

const modificarPersona = (id: string, f: (p: Persona) => Persona, mostrarError = true) =>
  actualizar((b) => ({ ...b, personas: b.personas.map((p) => (p.id === id ? f(p) : p)) }), { mostrarError });

/**
 * Quién verifica soportes: la persona que inició sesión, si es de la gerencia, del SG o de la
 * dirección técnica de un organismo donde la persona está vinculada; nunca ella misma (0014).
 */
function useVerificador(persona?: Persona) {
  const base = useBase();
  const yo = usePersonaActual(base);
  return {
    yo: yo?.id,
    puede: !CON_SUPABASE || (!!base && !!persona && puedeVerificar(base, yo?.id, persona.id)),
    nombre: (id?: string) => (id ? nombrePersona(base?.personas.find((p) => p.id === id)) : ""),
  };
}

const AYUDA_VERIFICAR = "Verifican los soportes la gerencia, el responsable del SG (o su suplente) o un director técnico (o su suplente); nunca la misma persona.";

type ItemVerificable = { id: string; verificada?: boolean; verificadaPor?: string; verificadaEn?: string };

/** Casilla "Soporte verificado" con quién verificó y cuándo. */
function Verificacion({ persona, lista, item }: { persona: Persona; lista: Lista; item: ItemVerificable }) {
  const { yo, puede, nombre } = useVerificador(persona);
  const alternar = () => modificarPersona(persona.id, (p) => ({
    ...p, [lista]: (p[lista] as ItemVerificable[]).map((x) => (x.id === item.id
      ? { ...x, verificada: !x.verificada, verificadaPor: x.verificada ? undefined : yo, verificadaEn: x.verificada ? undefined : new Date().toISOString() } : x)),
  }));
  return (
    <div className="text-right text-xs">
      <label className={`flex items-center justify-end gap-1 font-semibold ${puede ? "cursor-pointer" : "opacity-70"}`} title={puede ? undefined : AYUDA_VERIFICAR}>
        <input type="checkbox" checked={!!item.verificada} disabled={!puede} onChange={alternar} />
        <span className={item.verificada ? "text-emerald-600" : ""}>{item.verificada ? "Soporte verificado" : "Sin verificar"}</span>
      </label>
      {item.verificada && item.verificadaPor && (
        <span className="suave block">Verificó: {nombre(item.verificadaPor)}{item.verificadaEn && ` · ${new Date(item.verificadaEn).toLocaleDateString("es-CO", { timeZone: "America/Bogota" })}`}</span>
      )}
      {!item.verificada && !puede && <span className="suave block max-w-56">Lo verifica la gerencia, el SG o un director técnico</span>}
    </div>
  );
}

type Lista = "certificados" | "experiencias" | "formacion";

/** Ver o cargar el archivo de soporte (PDF o imagen) de un ítem de la hoja de vida. */
function Soporte({ persona, lista, id, ruta }: { persona: Persona; lista: Lista; id: string; ruta?: string }) {
  const [ocupado, setOcupado] = useState(false);
  const cargar = async (archivo?: File) => {
    if (!archivo) return;
    setOcupado(true);
    const r = await cargarArchivo("soportes", `${persona.id}/${lista}-${id}-${Date.now()}.${extension(archivo)}`, archivo, REGLAS_SOPORTE);
    if (r.error || !r.ruta) { setOcupado(false); return mostrarError(r.error ?? "No se pudo cargar el soporte"); }
    await modificarPersona(persona.id, (p) => ({ ...p, [lista]: (p[lista] as { id: string }[]).map((x) => (x.id === id ? { ...x, soporteRuta: r.ruta, ...(CON_SUPABASE ? {} : { verificada: false, verificadaPor: undefined, verificadaEn: undefined }) } : x)) }));
    setOcupado(false);
  };
  return (
    <span className="flex flex-wrap items-center gap-2">
      {ruta && (
        <button type="button" className={claseBoton("contorno", "pequeno")}
          onClick={async () => { const e = await abrirArchivo("soportes", ruta); if (e) mostrarError(e); }}>
          <Icono nombre="ojo" tamano={15} /> Ver soporte
        </button>
      )}
      <label className={`cursor-pointer ${claseBoton(ruta ? "contorno" : "primario", "pequeno")}`}>
        <Icono nombre="subir" tamano={15} /> {ocupado ? "Cargando…" : ruta ? "Cambiar soporte" : "Cargar soporte (PDF)"}
        <input type="file" accept="application/pdf,image/png,image/jpeg" className="sr-only" disabled={ocupado}
          onChange={(e) => { cargar(e.target.files?.[0]); e.target.value = ""; }} />
      </label>
    </span>
  );
}

const NOMBRE_REG = (r: string) => (r.startsWith("RETILAP") ? "RETILAP 2024" : "RETIE 2024");

export function HojaDeVida({ persona }: { persona: Persona }) {
  return (
    <div className="space-y-5">
      <Matricula persona={persona} />
      <Certificados persona={persona} />
      <Experiencias persona={persona} />
      <Formaciones persona={persona} />
      <MatrizHabilitacion persona={persona} />
    </div>
  );
}

// ───────────────────────────── Matrícula profesional ─────────────────────────────
/** Matrícula de ingeniero (CPNIEMPA o COPNIA); otra entidad requiere aceptación de la gerencia (0010). */
function Matricula({ persona }: { persona: Persona }) {
  const base = useBase();
  const organismo = useOrganismoActual(base);
  const { gerencia } = usePermisosOrganismo(base, organismo?.id);
  const { yo, nombre } = useVerificador();
  const e = estadoMatricula(persona);
  const datos = [persona.matriculaNumero, entidadMatricula(persona.matriculaEntidad), persona.matriculaEspecialidad].filter(Boolean).join(" · ");
  const [texto, color, fondo] = {
    sin_matricula: ["Sin matrícula registrada", "#B42318", "#FBE2E0"],
    ingeniero: ["Matrícula de ingeniero", "#16795A", "#DCF2E9"],
    aceptada: ["Otra entidad, aceptada por la gerencia", "#16795A", "#DCF2E9"],
    conte: ["Consejo de técnicos o tecnólogos (CONTE, CONALTEL): no sirve para director técnico ni inspector", "#B42318", "#FBE2E0"],
    por_aceptar: ["Otra entidad: requiere aceptación de la gerencia", "#8A4209", "#FBE9D8"],
  }[e];
  const puedeAceptar = e === "por_aceptar" && gerencia && persona.id !== yo;
  return (
    <section id="matricula" className="scroll-mt-24 rounded-xl transition-shadow space-y-1">
      <h3 className="text-sm font-semibold">Matrícula profesional</h3>
      <div className="flex flex-wrap items-center gap-2 text-sm">
        <span>{datos || "—"}</span>
        <span className="rounded-full px-2 py-0.5 text-xs font-bold" style={{ color, background: fondo }}>{texto}</span>
        {puedeAceptar && (
          <button className={claseBoton("contorno", "pequeno")} onClick={() => {
            const m = prompt(`Aceptar la matrícula de ${persona.nombres} ${persona.apellidos} expedida por "${persona.matriculaEntidad}".\n\nQueda registrado con su nombre y la fecha.\nMotivo (obligatorio; por ejemplo, la ley que faculta a ese consejo):`);
            if (m === null) return;
            if (!m.trim()) return alert("Debe escribir el motivo.");
            aceptarMatricula(persona.id, m.trim());
          }}>Aceptar matrícula</button>
        )}
      </div>
      {e === "aceptada" && (
        <p className="suave text-xs">
          Aceptada{persona.matriculaAceptadaPor && ` por ${nombre(persona.matriculaAceptadaPor)}`}
          {persona.matriculaAceptadaEn && ` el ${new Date(persona.matriculaAceptadaEn).toLocaleDateString("es-CO")}`}
          {persona.matriculaAceptadaMotivo && `: ${persona.matriculaAceptadaMotivo}`}
        </p>
      )}
      {e === "por_aceptar" && !puedeAceptar && <p className="suave text-xs">La acepta la gerencia del organismo (nadie acepta la suya).</p>}
    </section>
  );
}

// ───────────────────────────── Certificados ─────────────────────────────
function Certificados({ persona }: { persona: Persona }) {
  const [nuevo, setNuevo] = useState(false);
  const [seguimiento, setSeguimiento] = useState<string | null>(null);
  const hoy = hoyISO();
  return (
    <section id="certificados" className="scroll-mt-24 rounded-xl transition-shadow space-y-2">
      <h3 className="text-sm font-semibold">Certificados de competencias</h3>
      {persona.certificados.length === 0 && <p className="suave text-sm">Sin certificados registrados.</p>}
      {[...persona.certificados].sort((x, y) => x.reglamento.localeCompare(y.reglamento) || (x.categorias[0] ?? "").localeCompare(y.categorias[0] ?? "")
        || x.fechaEmision.localeCompare(y.fechaEmision) || x.id.localeCompare(y.id)).map((c) => {
        const e = estadoCertificado(c, hoy);
        return (
          <div key={c.id} className={`rounded-lg border p-3 text-sm ${c.anulado ? "opacity-50" : ""}`} style={{ borderColor: "var(--borde)" }}>
            <div className="flex flex-wrap items-start justify-between gap-2">
              <div>
                <b>N.° {c.numero}</b> · {c.certificador} · {NOMBRE_REG(c.reglamento)}
                <div className="text-xs">Categorías: <b>{c.categorias.map((k) => etiquetaCategoria(c.reglamento, k)).join(", ")}</b></div>
                <div className="suave text-xs">Emitido {c.fechaEmision} · vence {c.fechaVencimiento}</div>
                <div className={`text-xs font-semibold ${e.vigente ? "text-emerald-600" : "text-red-600"}`}>
                  {e.vigente ? "Vigente" : e.motivo}{e.alertas.length > 0 && <span className="text-amber-600"> · {e.alertas.join(" · ")}</span>}
                </div>
                <div className="mt-2"><Soporte persona={persona} lista="certificados" id={c.id} ruta={c.soporteRuta} /></div>
              </div>
              {!c.anulado && (
                <div className="flex flex-col items-end gap-2">
                <Verificacion persona={persona} lista="certificados" item={c} />
                <Boton variante="discreto" onClick={() => {
                  if (confirm(`¿Anular el certificado ${c.numero}? Quedará en el historial.`))
                    modificarPersona(persona.id, (p) => ({ ...p, certificados: p.certificados.map((x) => (x.id === c.id ? { ...x, anulado: true } : x)) }));
                }}>Anular</Boton>
                </div>
              )}
            </div>
            {!c.anulado && <AvisoSeguimiento cert={c} abierto={seguimiento === c.id} onRegistrar={() => setSeguimiento(c.id)} />}
            {seguimiento === c.id && <FormularioSeguimiento persona={persona} cert={c} onTerminar={() => setSeguimiento(null)} />}
          </div>
        );
      })}
      {nuevo ? <FormularioCertificado persona={persona} onTerminar={() => setNuevo(false)} />
        : <Boton onClick={() => setNuevo(true)}><Icono nombre="mas" tamano={16} /> Agregar certificado</Boton>}
    </section>
  );
}

/** Seguimiento del mes 30: aviso según lo que falta, con el botón para registrarlo (0011). */
function AvisoSeguimiento({ cert, abierto, onRegistrar }: { cert: CertificadoCompetencia; abierto: boolean; onRegistrar: () => void }) {
  const { nivel, limite, dias, periodo } = estadoSeguimiento(cert, hoyISO());
  const boton = (estilo?: React.CSSProperties) => !abierto && (
    <Boton onClick={onRegistrar} style={estilo} className={estilo ? "!shadow-none" : ""}><Icono nombre="calendario" tamano={16} /> Registrar seguimiento</Boton>
  );
  if (nivel === "hecho") {
    return (
      <div className="mt-2 space-y-1 text-xs">
        <div>Seguimiento del mes 30: <b className={cert.seguimiento!.resultado === "conforme" ? "text-emerald-600" : "text-red-600"}>
          {cert.seguimiento!.resultado === "conforme" ? "conforme" : "no conforme"} el {cert.seguimiento!.fecha}</b> (límite {limite})</div>
        {periodo && (
          <div className="alerta-naranja rounded-lg px-3 py-2 font-semibold">
            Registrado tarde: del {periodo.desde} al {periodo.hasta} no pudo ejercer con este certificado. Queda así en el registro.
          </div>
        )}
      </div>
    );
  }
  if (nivel === "pendiente") {
    return (
      <div className="mt-2 flex flex-wrap items-center justify-between gap-2 text-sm">
        <span>Seguimiento del mes 30: a más tardar el <b>{limite}</b></span>
        {!abierto && <Boton variante="contorno" tamano="pequeno" onClick={onRegistrar}><Icono nombre="calendario" tamano={15} /> Registrar seguimiento</Boton>}
      </div>
    );
  }
  const vencido = nivel === "vencido";
  return (
    <div className={`mt-3 flex flex-wrap items-center justify-between gap-3 rounded-xl px-4 py-3 ${vencido ? "alerta-roja" : "alerta-naranja"}`}>
      <div className="flex items-start gap-3">
        <Icono nombre="alerta" tamano={26} />
        <div>
          <div className="text-base font-extrabold">
            {vencido ? `Seguimiento del mes 30 vencido desde el ${periodo?.desde}` : `Faltan ${dias} ${dias === 1 ? "día" : "días"} para el seguimiento del mes 30`}
          </div>
          <div className="text-sm">
            {vencido
              ? "NO puede ejercer las actividades de este certificado hasta registrarlo. Puede registrarlo ahora, pero el periodo sin seguimiento quedará como no habilitado."
              : `Fecha máxima: ${limite}. Si no lo registra a tiempo, no podrá ejercer desde el día siguiente.`}
          </div>
        </div>
      </div>
      {boton({ background: vencido ? "#d92d20" : "#e8772e" })}
    </div>
  );
}

function FormularioCertificado({ persona, onTerminar }: { persona: Persona; onTerminar: () => void }) {
  const [c, setC] = useState<Omit<CertificadoCompetencia, "id" | "anulado">>({
    numero: "", certificador: "", reglamento: "RETIE-2024", categorias: [], fechaEmision: "", fechaVencimiento: "",
  });
  const [venceManual, setVenceManual] = useState(false);
  const [errores, setErrores] = useState<string[]>([]);
  const req = requisitosDe(c.reglamento)!;

  const emision = (f: string) => setC({ ...c, fechaEmision: f, fechaVencimiento: venceManual || !f ? c.fechaVencimiento : sumarAnios(f, req.vigenciaCertificadoAnios) });

  const guardar = async () => {
    const e: string[] = [];
    if (!c.numero.trim()) e.push("El número del certificado es obligatorio");
    if (persona.certificados.some((x) => x.numero === c.numero.trim() && x.certificador === c.certificador.trim())) e.push("Ese certificado ya está registrado");
    if (!c.certificador.trim()) e.push("Indique el organismo de certificación de personas (ISO/IEC 17024)");
    if (!c.fechaEmision || !c.fechaVencimiento) e.push("Fechas de emisión y vencimiento obligatorias");
    else if (c.fechaVencimiento <= c.fechaEmision) e.push("El vencimiento debe ser posterior a la emisión");
    else if (c.fechaVencimiento > sumarAnios(c.fechaEmision, req.vigenciaCertificadoAnios))
      e.push(`La vigencia no puede superar ${req.vigenciaCertificadoAnios} años (vence a más tardar ${sumarAnios(c.fechaEmision, req.vigenciaCertificadoAnios)})`);
    if (!c.categorias.length) e.push("Marque las categorías que certifica");
    setErrores(e);
    if (e.length) return;
    const error = await modificarPersona(persona.id, (p) => ({ ...p, certificados: [...p.certificados, { ...c, numero: c.numero.trim(), certificador: c.certificador.trim(), id: nuevoId(), anulado: false }] }), false);
    if (error) return setErrores([error]);
    onTerminar();
  };

  return (
    <div className="space-y-3 rounded-lg border p-3" style={{ borderColor: "var(--marca)" }}>
      <div className="grid gap-3 sm:grid-cols-2">
        <Campo etiqueta="Reglamento">
          <Selector value={c.reglamento} onChange={(e) => setC({ ...c, reglamento: e.target.value, categorias: [] })}>
            {REQUISITOS.map((r) => <option key={r.reglamento} value={r.reglamento}>{NOMBRE_REG(r.reglamento)}</option>)}
          </Selector>
        </Campo>
        <Campo etiqueta="Número del certificado"><Entrada value={c.numero} onChange={(e) => setC({ ...c, numero: e.target.value })} /></Campo>
        <Campo etiqueta="Organismo certificador (ISO/IEC 17024)"><Entrada value={c.certificador} onChange={(e) => setC({ ...c, certificador: e.target.value })} /></Campo>
        <div className="grid grid-cols-2 gap-3">
          <Campo etiqueta="Emisión"><Entrada type="date" value={c.fechaEmision} onChange={(e) => emision(e.target.value)} /></Campo>
          <Campo etiqueta="Vencimiento" ayuda={`${req.vigenciaCertificadoAnios} años por defecto`}>
            <Entrada type="date" value={c.fechaVencimiento} onChange={(e) => { setVenceManual(true); setC({ ...c, fechaVencimiento: e.target.value }); }} />
          </Campo>
        </div>
      </div>
      {!req.exigeCertificado && <p className="text-xs text-amber-700 dark:text-amber-400">{req.notaCertificado}</p>}
      <Grupo etiqueta="Categorías certificadas">
        <div className="space-y-1">
          {req.categorias.map((k) => (
            <label key={k.codigo} className="flex items-start gap-2 text-sm">
              <input type="checkbox" className="mt-1" checked={c.categorias.includes(k.codigo)}
                onChange={() => setC({ ...c, categorias: c.categorias.includes(k.codigo) ? c.categorias.filter((x) => x !== k.codigo) : [...c.categorias, k.codigo] })} />
              <span><b>{k.codigo}.</b> {k.nombre}</span>
            </label>
          ))}
        </div>
      </Grupo>
      {c.fechaEmision && <p className="suave text-xs">Seguimiento obligatorio al mes {req.seguimientoMes}: a más tardar el {fechaSeguimiento(c)}.</p>}
      <Errores errores={errores} />
      <div className="flex gap-2"><Boton onClick={guardar}>Guardar certificado</Boton><Boton variante="secundario" onClick={onTerminar}>Cancelar</Boton></div>
    </div>
  );
}

function FormularioSeguimiento({ persona, cert, onTerminar }: { persona: Persona; cert: CertificadoCompetencia; onTerminar: () => void }) {
  const [fecha, setFecha] = useState(hoyISO());
  const [resultado, setResultado] = useState<"conforme" | "no_conforme">("conforme");
  const [obs, setObs] = useState("");
  const [errores, setErrores] = useState<string[]>([]);
  const limite = fechaSeguimiento(cert);
  const tarde = hoyISO() > limite;
  const guardar = async () => {
    if (!fecha || fecha > hoyISO()) return setErrores(["La fecha del seguimiento no puede ser futura"]);
    if (fecha < cert.fechaEmision) return setErrores(["La fecha del seguimiento no puede ser anterior a la emisión"]);
    // En Supabase la fecha de registro la pone la base de datos; en modo local, el navegador.
    const registradoEn = new Date().toISOString();
    const error = await modificarPersona(persona.id, (p) => ({ ...p, certificados: p.certificados.map((x) => (x.id === cert.id ? { ...x, seguimiento: { fecha, resultado, observacion: obs || undefined, registradoEn } } : x)) }), false);
    if (error) return setErrores([error]);
    onTerminar();
  };
  return (
    <div className="mt-2 space-y-3 rounded-lg border-2 p-3" style={{ borderColor: "var(--marca)" }}>
      {tarde && (
        <p className="alerta-naranja rounded-lg px-3 py-2 text-sm font-semibold">
          Se registra después de la fecha máxima ({limite}): el certificado vuelve a contar desde hoy y el periodo
          del día siguiente al límite hasta ayer queda como no habilitado.
        </p>
      )}
      <div className="grid gap-3 sm:grid-cols-3">
        <Campo etiqueta="Fecha del seguimiento"><Entrada type="date" value={fecha} max={hoyISO()} min={cert.fechaEmision} onChange={(e) => setFecha(e.target.value)} /></Campo>
        <Campo etiqueta="Resultado">
          <Selector value={resultado} onChange={(e) => setResultado(e.target.value as "conforme" | "no_conforme")}>
            <option value="conforme">Conforme</option><option value="no_conforme">No conforme</option>
          </Selector>
        </Campo>
        <Campo etiqueta="Observación / soporte"><Entrada value={obs} onChange={(e) => setObs(e.target.value)} /></Campo>
      </div>
      <Errores errores={errores} />
      <div className="flex gap-2">
        <Boton onClick={guardar}>Guardar seguimiento</Boton>
        <Boton variante="secundario" onClick={onTerminar}>Cancelar</Boton>
      </div>
    </div>
  );
}

// ───────────────────────────── Experiencia ─────────────────────────────
function Experiencias({ persona }: { persona: Persona }) {
  const [nueva, setNueva] = useState(false);
  const hoy = hoyISO();
  const resumen = REQUISITOS.map((r) => ({
    r, total: aniosExperiencia(persona, { reglamento: r.reglamento, tipos: [...r.tiposExperienciaTecnica, ...r.directorTecnico.tiposExperienciaDireccion] }, hoy),
  })).filter((x) => x.total > 0);
  return (
    <section id="experiencias" className="scroll-mt-24 rounded-xl transition-shadow space-y-2">
      <h3 className="text-sm font-semibold">Experiencia laboral del ejercicio profesional</h3>
      <p className="suave text-xs">Solo cuenta la experiencia con soporte <b>verificado</b> por el organismo. Los periodos que se traslapan no se suman dos veces.</p>
      {resumen.length > 0 && (
        <p className="text-xs">{resumen.map((x) => `${NOMBRE_REG(x.r.reglamento)}: ${x.total.toFixed(1).replace(".", ",")} años verificados`).join(" · ")}</p>
      )}
      {persona.experiencias.map((e) => (
        <div key={e.id} className="flex flex-wrap items-start justify-between gap-2 rounded-lg border p-3 text-sm" style={{ borderColor: "var(--borde)" }}>
          <div>
            <b>{e.cargo}</b> · {e.empresa}
            <div className="suave text-xs">{e.desde} a {e.hasta ?? "la fecha"} · {NOMBRE_REG(e.reglamento)}
              {e.categorias.length > 0 && ` · categorías ${e.categorias.join(", ")}`}</div>
            {(e.actividades ?? []).length > 0 && <div className="text-xs">Generación: {(e.actividades ?? []).map((c) => nombreCorto(c)).join("; ")}</div>}
            <div className="suave text-xs">{e.tipos.map((t) => NOMBRE_TIPO_EXPERIENCIA[t as TipoExperiencia] ?? t).join(", ")}</div>
            <div className="mt-1"><Soporte persona={persona} lista="experiencias" id={e.id} ruta={e.soporteRuta} /></div>
          </div>
          <Verificacion persona={persona} lista="experiencias" item={e} />
        </div>
      ))}
      {nueva ? <FormularioExperiencia persona={persona} onTerminar={() => setNueva(false)} />
        : <Boton onClick={() => setNueva(true)}><Icono nombre="mas" tamano={16} /> Agregar experiencia</Boton>}
    </section>
  );
}

function FormularioExperiencia({ persona, onTerminar }: { persona: Persona; onTerminar: () => void }) {
  const [e, setE] = useState<Omit<Experiencia, "id">>({ empresa: "", cargo: "", desde: "", reglamento: "RETIE-2024", categorias: [], tipos: [], verificada: false });
  const [errores, setErrores] = useState<string[]>([]);
  const { yo, puede } = useVerificador(persona);
  const req = requisitosDe(e.reglamento)!;
  const tipos = [...req.tiposExperienciaTecnica, ...req.directorTecnico.tiposExperienciaDireccion];
  const alternar = (k: "categorias" | "tipos", v: string) => setE({ ...e, [k]: e[k].includes(v) ? e[k].filter((x) => x !== v) : [...e[k], v] });

  const guardar = async () => {
    const err: string[] = [];
    if (!e.empresa.trim() || !e.cargo.trim()) err.push("Empresa y cargo son obligatorios");
    if (!e.desde) err.push("Fecha de inicio obligatoria");
    if (e.hasta && e.hasta < e.desde) err.push("La fecha final es anterior a la inicial");
    if (e.desde > hoyISO()) err.push("La experiencia no puede iniciar en el futuro");
    if (!e.tipos.length) err.push("Marque el tipo de actividad desarrollada");
    if (req.experienciaPorCategoria && !e.categorias.length) err.push("Marque la(s) categoría(s) de instalación en que se obtuvo la experiencia");
    if (e.categorias.includes("a") && e.reglamento === "RETIE-2024" && !(e.actividades ?? []).length) err.push("Indique el tipo de instalación de generación");
    setErrores(err);
    if (err.length) return;
    const actividades = e.categorias.includes("a") ? e.actividades ?? [] : [];
    const error = await modificarPersona(persona.id, (p) => ({ ...p, experiencias: [...p.experiencias, { ...e, actividades, id: nuevoId(), hasta: e.hasta || undefined, verificadaPor: e.verificada ? yo : undefined }] }), false);
    if (error) return setErrores([error]);
    onTerminar();
  };

  return (
    <div className="space-y-3 rounded-lg border p-3" style={{ borderColor: "var(--marca)" }}>
      <div className="grid gap-3 sm:grid-cols-2">
        <Campo etiqueta="Empresa / contratante"><Entrada value={e.empresa} onChange={(x) => setE({ ...e, empresa: x.target.value })} /></Campo>
        <Campo etiqueta="Cargo"><Entrada value={e.cargo} onChange={(x) => setE({ ...e, cargo: x.target.value })} /></Campo>
        <div className="grid grid-cols-2 gap-3">
          <Campo etiqueta="Desde"><Entrada type="date" value={e.desde} onChange={(x) => setE({ ...e, desde: x.target.value })} /></Campo>
          <Campo etiqueta="Hasta" ayuda="Vacío si es actual"><Entrada type="date" value={e.hasta ?? ""} onChange={(x) => setE({ ...e, hasta: x.target.value || undefined })} /></Campo>
        </div>
        <Campo etiqueta="Tipo de instalaciones">
          <Selector value={e.reglamento} onChange={(x) => setE({ ...e, reglamento: x.target.value, categorias: [], tipos: [] })}>
            <option value="RETIE-2024">Instalaciones eléctricas (RETIE)</option>
            <option value="RETILAP-2024">Iluminación y alumbrado público (RETILAP)</option>
          </Selector>
        </Campo>
      </div>
      <Grupo etiqueta="Actividades desarrolladas">
        <div className="flex flex-wrap gap-x-4 gap-y-1">
          {tipos.map((t) => (
            <label key={t} className="flex items-center gap-1 text-sm">
              <input type="checkbox" checked={e.tipos.includes(t)} onChange={() => alternar("tipos", t)} /> {NOMBRE_TIPO_EXPERIENCIA[t]}
            </label>
          ))}
        </div>
      </Grupo>
      <Grupo etiqueta={req.experienciaPorCategoria ? "Categorías de instalación (misma o similar)" : "Categorías relacionadas (opcional)"}>
        <div className="space-y-1">
          {req.categorias.map((k) => (
            <label key={k.codigo} className="flex items-start gap-2 text-sm">
              <input type="checkbox" className="mt-1" checked={e.categorias.includes(k.codigo)} onChange={() => alternar("categorias", k.codigo)} />
              <span><b>{k.codigo}.</b> {k.nombre}</span>
            </label>
          ))}
        </div>
      </Grupo>
        {e.reglamento === "RETIE-2024" && e.categorias.includes("a") && (
        <Grupo etiqueta="Tipo de instalación de generación (para la generación hasta 1.000 V AC y 1.500 V DC se exige experiencia en ese tipo)">
          <div className="space-y-1">
            {GENERACION.map((a) => (
              <label key={a.codigo} className="flex items-start gap-2 text-sm">
                <input type="checkbox" className="mt-1" checked={(e.actividades ?? []).includes(a.codigo)}
                  onChange={() => setE({ ...e, actividades: (e.actividades ?? []).includes(a.codigo) ? (e.actividades ?? []).filter((x) => x !== a.codigo) : [...(e.actividades ?? []), a.codigo] })} />
                <span>{nombreCorto(a.codigo)}</span>
              </label>
            ))}
          </div>
        </Grupo>
      )}
      {puede ? (
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={e.verificada} onChange={() => setE({ ...e, verificada: !e.verificada })} />
          Revisé la certificación laboral que soporta esta experiencia
        </label>
      ) : <p className="suave text-xs">{AYUDA_VERIFICAR}</p>}
      <Errores errores={errores} />
      <div className="flex gap-2"><Boton onClick={guardar}>Guardar experiencia</Boton><Boton variante="secundario" onClick={onTerminar}>Cancelar</Boton></div>
    </div>
  );
}

// ───────────────────────────── Formación ─────────────────────────────
const NOMBRE_FORMACION: Record<Formacion["tipo"], string> = {
  pregrado: "Pregrado", especializacion: "Especialización", maestria: "Maestría", doctorado: "Doctorado",
  curso_profundizacion: "Curso de profundización", otro: "Otro",
};

function Formaciones({ persona }: { persona: Persona }) {
  const [nueva, setNueva] = useState(false);
  const { yo } = useVerificador();
  return (
    <section id="formacion" className="scroll-mt-24 rounded-xl transition-shadow space-y-2">
      <h3 className="text-sm font-semibold">Formación académica</h3>
      {persona.formacion.map((f) => (
        <div key={f.id} className="flex flex-wrap items-start justify-between gap-2 rounded-lg border p-3 text-sm" style={{ borderColor: "var(--borde)" }}>
          <div>
            <b>{NOMBRE_FORMACION[f.tipo]}</b>: {f.titulo} · {f.institucion} · {f.fecha}
            {f.enIluminacion && <div className="text-xs">En iluminación / alumbrado público{f.areasIluminacion.length > 0 && `: ${f.areasIluminacion.map((a) => AREAS_ILUMINACION[a]).join("; ")}`}</div>}
            <div className="mt-1"><Soporte persona={persona} lista="formacion" id={f.id} ruta={f.soporteRuta} /></div>
          </div>
          <Verificacion persona={persona} lista="formacion" item={f} />
        </div>
      ))}
      {nueva ? <FormularioFormacion persona={persona} onTerminar={() => setNueva(false)} />
        : <Boton onClick={() => setNueva(true)}><Icono nombre="mas" tamano={16} /> Agregar formación</Boton>}
    </section>
  );
}

function FormularioFormacion({ persona, onTerminar }: { persona: Persona; onTerminar: () => void }) {
  const [f, setF] = useState<Omit<Formacion, "id">>({ tipo: "especializacion", titulo: "", institucion: "", fecha: "", areasIluminacion: [], enIluminacion: false, verificada: false });
  const [errores, setErrores] = useState<string[]>([]);
  const { yo, puede } = useVerificador(persona);
  const guardar = async () => {
    const e: string[] = [];
    if (!f.titulo.trim() || !f.institucion.trim() || !f.fecha) e.push("Título, institución y fecha son obligatorios");
    if (f.tipo === "curso_profundizacion" && !f.areasIluminacion.length) e.push("Indique el área de profundización del curso");
    setErrores(e);
    if (e.length) return;
    const error = await modificarPersona(persona.id, (p) => ({ ...p, formacion: [...p.formacion, { ...f, id: nuevoId(), enIluminacion: f.enIluminacion || f.tipo === "curso_profundizacion", verificadaPor: f.verificada ? yo : undefined }] }), false);
    if (error) return setErrores([error]);
    onTerminar();
  };
  return (
    <div className="space-y-3 rounded-lg border p-3" style={{ borderColor: "var(--marca)" }}>
      <div className="grid gap-3 sm:grid-cols-2">
        <Campo etiqueta="Tipo">
          <Selector value={f.tipo} onChange={(e) => setF({ ...f, tipo: e.target.value as Formacion["tipo"] })}>
            {Object.entries(NOMBRE_FORMACION).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </Selector>
        </Campo>
        <Campo etiqueta="Título"><Entrada value={f.titulo} onChange={(e) => setF({ ...f, titulo: e.target.value })} /></Campo>
        <Campo etiqueta="Institución" ayuda="Reconocida por el Ministerio de Educación Nacional"><Entrada value={f.institucion} onChange={(e) => setF({ ...f, institucion: e.target.value })} /></Campo>
        <Campo etiqueta="Fecha de grado / certificación"><Entrada type="date" value={f.fecha} onChange={(e) => setF({ ...f, fecha: e.target.value })} /></Campo>
      </div>
      {f.tipo !== "curso_profundizacion" && f.tipo !== "pregrado" && (
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={f.enIluminacion} onChange={() => setF({ ...f, enIluminacion: !f.enIluminacion })} />
          Es un posgrado en iluminación y/o alumbrado público (RETILAP)
        </label>
      )}
      {(f.enIluminacion || f.tipo === "curso_profundizacion") && (
        <Grupo etiqueta={f.tipo === "curso_profundizacion" ? "Área del curso" : "Áreas específicas incluidas en el plan de estudios"}>
          <div className="space-y-1">
            {Object.entries(AREAS_ILUMINACION).map(([k, v]) => (
              <label key={k} className="flex items-center gap-2 text-sm">
                <input type="checkbox" checked={f.areasIluminacion.includes(k)}
                  onChange={() => setF({ ...f, areasIluminacion: f.areasIluminacion.includes(k) ? f.areasIluminacion.filter((x) => x !== k) : [...f.areasIluminacion, k] })} />
                {v}
              </label>
            ))}
          </div>
        </Grupo>
      )}
      {puede ? (
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={f.verificada} onChange={() => setF({ ...f, verificada: !f.verificada })} />
          Revisé el diploma o certificado
        </label>
      ) : <p className="suave text-xs">{AYUDA_VERIFICAR}</p>}
      <Errores errores={errores} />
      <div className="flex gap-2"><Boton onClick={guardar}>Guardar formación</Boton><Boton variante="secundario" onClick={onTerminar}>Cancelar</Boton></div>
    </div>
  );
}

// ───────────────────────────── Habilitación ─────────────────────────────
/** Matriz: para cada categoría, ¿cumple como inspector y como director técnico? */
export function MatrizHabilitacion({ persona }: { persona: Persona }) {
  const [detalle, setDetalle] = useState<string | null>(null);
  const hoy = hoyISO();
  const celda = (actividad: string, rol: RolTecnico, clave: string) => {
    const h = evaluarCompetencia(persona, actividad, rol, hoy);
    return (
      <button onClick={() => setDetalle(detalle === clave ? null : clave)}
        className={`rounded px-2 py-0.5 text-xs font-semibold ${h.cumple ? "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-300" : "bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-400"}`}>
        {h.cumple ? "Cumple" : "No"}
      </button>
    );
  };
  return (
    <section id="habilitacion" className="scroll-mt-24 rounded-xl transition-shadow space-y-2">
      <h3 className="text-sm font-semibold">Habilitación por categoría (calculada)</h3>
      <div className="overflow-x-auto">
        <table className="w-full text-left text-sm">
          <thead className="suave text-xs uppercase"><tr><th className="py-1 pr-2">Categoría</th><th className="px-2">Inspector</th><th className="px-2">Director técnico</th></tr></thead>
          <tbody>
            {REQUISITOS.flatMap((r) => [
              ...r.categorias.map((k) => ({ act: k.actividades[0], clave: `${r.reglamento}-${k.codigo}`, etiqueta: etiquetaCategoria(r.reglamento, k.codigo), nombre: k.nombre })),
              // Generación hasta 1.000 V AC y 1.500 V DC: certificado g, experiencia en ese tipo de instalación (0015).
              ...(r.reglamento === "RETIE-2024" ? ACTIVIDADES_POR_TENSION.map((c) => ({
                act: `${c}-BT`, clave: `${c}-BT`, etiqueta: "RETIE g",
                nombre: `${nombreCorto(c)} — ${TEXTO_BAJA} (certificado g, 3 años de experiencia en ese tipo de instalación)`,
              })) : []),
            ].map(({ act, clave, etiqueta, nombre }) => {
              return [
                <tr key={clave} className="border-t" style={{ borderColor: "var(--borde)" }}>
                  <td className="py-1 pr-2"><b>{etiqueta}</b> <span className="suave text-xs">{nombre}</span></td>
                  <td className="px-2">{celda(act, "inspector", clave + "-i")}</td>
                  <td className="px-2">{celda(act, "director_tecnico", clave + "-d")}</td>
                </tr>,
                ...(["i", "d"] as const).filter((x) => detalle === `${clave}-${x}`).map((x) => (
                  <tr key={clave + x}><td colSpan={3} className="pb-2">
                    <ListaRequisitos persona={persona} actividad={act} rol={x === "i" ? "inspector" : "director_tecnico"} />
                  </td></tr>
                )),
              ];
            }))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

export function ListaRequisitos({ persona, actividad, rol }: { persona: Persona; actividad: string; rol: RolTecnico }) {
  const h = evaluarCompetencia(persona, actividad, rol, hoyISO());
  return (
    <ul className="space-y-0.5 rounded-lg border p-2 text-xs" style={{ borderColor: "var(--borde)" }}>
      {h.items.map((i) => (
        <li key={i.requisito} className="flex gap-2">
          <span className={i.cumple ? "text-emerald-600" : i.bloquea ? "text-red-600" : "text-amber-600"}>{i.cumple ? "✓" : i.bloquea ? "✕" : "!"}</span>
          <span><b>{i.requisito}:</b> {i.cumple ? i.detalle : <EnlaceMotivo personaId={persona.id} texto={i.detalle} seccion={seccionDeMotivo(i.requisito)} />}</span>
        </li>
      ))}
      {h.alertas.map((a) => <li key={a} className="text-amber-600">! {a}</li>)}
    </ul>
  );
}
