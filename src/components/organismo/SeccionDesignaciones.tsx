"use client";
import { useMemo, useState } from "react";
import { actividadesAutorizables, nombreAutorizacion } from "@/lib/catalogo";
import Link from "next/link";
import { actualizar, nuevoId, pedirMotivo, quitarAutorizacionPorError, usePersonaActual } from "@/lib/organismo/almacen";
import { CON_SUPABASE } from "@/lib/supabase";
import {
  NOMBRE_CALIDAD, NOMBRE_TIPO, TIPO_DE_ROL, documentoFirmado, documentosDe, estadoDocumentacion, evaluadoresPosibles, generarDocumento, huella, puedeFirmarComo,
} from "@/lib/organismo/documentos";
import { usePermisosOrganismo } from "@/lib/organismo/permisos";
import {
  hoyISO, lineasAcreditadas, motivoNoPuedeEjercer, nombrePersona,
  validarDesignacion, vigenteEn, vinculacionVigente,
} from "@/lib/organismo/reglas";
import { evaluarCompetencia } from "@/lib/organismo/competencia";
import {
  NOMBRE_ROL, ROLES_CON_ACTIVIDADES, rolTecnico,
  type BaseOrganismos, type Designacion, type Organismo, type RolOEC, type Vinculacion,
} from "@/lib/organismo/tipos";
import { Boton, Campo, Entrada, Errores, Selector, claseBoton } from "../Formulario";
import { Icono } from "../Icono";
import { EnlaceMotivo } from "./EnlaceMotivo";
import { SelectorActividades } from "../SelectorActividades";
import { FormularioPersona } from "./FormularioPersona";
import { HojaDeVida, ListaRequisitos } from "./HojaDeVida";

type Props = {
  base: BaseOrganismos;
  organismo: Organismo;
  roles: RolOEC[];
  titulo: string;
  descripcion: string;
};

export function SeccionDesignaciones({ base, organismo, roles, titulo, descripcion }: Props) {
  const [agregando, setAgregando] = useState<RolOEC | null>(null);
  const [verHistorial, setVerHistorial] = useState(false);
  const hoy = hoyISO();
  const hace30 = new Date(Date.now() - 30 * 86_400_000).toLocaleDateString("en-CA", { timeZone: "America/Bogota" });
  const todas = base.designaciones
    .filter((d) => d.organismoId === organismo.id && roles.includes(d.rol))
    .sort((a, b) => roles.indexOf(a.rol) - roles.indexOf(b.rol) || b.desde.localeCompare(a.desde));
  // Activas: sin fecha final, o que terminan después de hoy. Las desvinculadas hace poco van al
  // fondo, en gris y sin botón; las más antiguas, en el historial.
  const activas = todas.filter((d) => !d.hasta || d.hasta > hoy);
  const recientes = todas.filter((d) => d.hasta && d.hasta <= hoy && d.hasta >= hace30);
  const historicas = todas.filter((d) => d.hasta && d.hasta < hace30);

  const finalizar = (d: Designacion) => {
    const motivo = prompt(`DESVINCULAR DEL OEC a ${nombrePersona(base.personas.find((p) => p.id === d.personaId))} como ${NOMBRE_ROL[d.rol].toLowerCase()}.\n\nDeja de tener este rol desde hoy y ya no puede ejercerlo. No se puede deshacer (habría que designarla de nuevo).\nSi solo quiere terminar de cargar documentos, haga clic en Cancelar: todo se guarda solo.\n\nMotivo (obligatorio, queda en el registro):`);
    if (motivo === null) return;
    if (!motivo.trim()) return alert("Debe escribir el motivo.");
    // Deja de tener el rol desde hoy: su último día es ayer (así otra persona puede tomar hoy un
    // rol único). Si la designación empezó hoy, termina hoy y el reemplazo empieza mañana.
    const ayer = new Date(Date.now() - 86_400_000).toLocaleDateString("en-CA", { timeZone: "America/Bogota" });
    const hasta = d.desde < hoy ? ayer : hoy;
    actualizar((b) => ({
      ...b,
      designaciones: b.designaciones.map((x) => (x.id === d.id
        ? { ...x, hasta, acto: [x.acto, `Desvinculada del OEC ${hoy}: ${motivo.trim()}`].filter(Boolean).join(" · ") } : x)),
    }));
  };

  return (
    <section className="space-y-4">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <h2 className="text-lg font-semibold">{titulo}</h2>
          <p className="suave max-w-3xl text-sm">{descripcion}</p>
        </div>
        {!agregando && (
          <div className="flex flex-wrap justify-end gap-2">
            {roles.map((r, i) => (
              <Boton key={r} variante={i === 0 ? "primario" : "contorno"} onClick={() => setAgregando(r)}>
                <Icono nombre="mas" tamano={16} /> Designar {NOMBRE_ROL[r].toLowerCase()}
              </Boton>
            ))}
          </div>
        )}
      </div>

      {agregando && (
        <FormularioDesignacion key={agregando} base={base} organismo={organismo} roles={roles} rolInicial={agregando}
          onTerminar={() => setAgregando(null)} />
      )}

      {activas.length === 0 && !agregando && (
        <p className="tarjeta suave p-4 text-sm">{recientes.length ? "No hay personas vigentes en estos roles." : "Aún no hay personas designadas."}</p>
      )}
      <div className="grid gap-3">
        {activas.map((d) => <TarjetaDesignacion key={d.id} base={base} organismo={organismo} d={d} onFinalizar={() => finalizar(d)} />)}
        {recientes.map((d) => (
          <div key={d.id} className="opacity-60 grayscale">
            <TarjetaDesignacion base={base} organismo={organismo} d={d} />
          </div>
        ))}
      </div>

      {historicas.length > 0 && (
        <div>
          <button className="suave text-sm underline" onClick={() => setVerHistorial(!verHistorial)}>
            {verHistorial ? "Ocultar" : "Ver"} historial ({historicas.length})
          </button>
          {verHistorial && (
            <div className="mt-2 grid gap-2 opacity-75">
              {historicas.map((d) => <TarjetaDesignacion key={d.id} base={base} organismo={organismo} d={d} />)}
            </div>
          )}
        </div>
      )}
    </section>
  );
}

function TarjetaDesignacion({ base, organismo, d, onFinalizar }: {
  base: BaseOrganismos; organismo: Organismo; d: Designacion; onFinalizar?: () => void;
}) {
  const p = base.personas.find((x) => x.id === d.personaId)!;
  const v = base.vinculaciones.find((x) => x.organismoId === organismo.id && x.personaId === p.id && vigenteEn(x, d.desde));
  const hoy = hoyISO();
  const decl = (tipo: string) =>
    base.declaraciones.filter((x) => x.organismoId === organismo.id && x.personaId === p.id && x.tipo === tipo).map((x) => x.fecha).sort().at(-1);

  return (
    <article className="tarjeta space-y-2 p-4">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-xs font-semibold uppercase tracking-wide marca">{NOMBRE_ROL[d.rol]}</span>
            {d.hasta && d.hasta <= hoy && (
              <span className="rounded-full px-2 py-0.5 text-xs font-bold" style={{ background: "var(--borde)" }}>
                Desvinculado del OEC · último día {d.hasta}
              </span>
            )}
          </div>
          <div className="font-semibold">{nombrePersona(p)}</div>
          <div className="suave text-xs">
            {p.tipoDocumento} {p.documento}
            {p.matriculaNumero && <> · Matrícula {p.matriculaNumero} {p.matriculaEntidad}</>}
            {v && <> · {v.cargo} ({v.tipo.replace("_", " ")})</>}
          </div>
          <div className="suave text-xs">
            Desde {d.desde}{d.hasta ? ` hasta ${d.hasta}` : ""}{d.acto ? ` · ${d.acto}` : ""}
          </div>
        </div>
        {onFinalizar && <Boton variante="peligro" tamano="pequeno" onClick={onFinalizar}>DESVINCULAR DEL OEC</Boton>}
      </div>
      <div className="flex flex-wrap gap-2 text-xs">
        <Indicador ok={!!decl("imparcialidad")} texto={`Imparcialidad ${decl("imparcialidad") ?? "sin firmar"}`} />
        <Indicador ok={!!decl("confidencialidad")} texto={`Confidencialidad ${decl("confidencialidad") ?? "sin firmar"}`} />
      </div>
      {ROLES_CON_ACTIVIDADES.includes(d.rol) && d.actividades.length === 0 && (
        <p className="rounded-lg px-3 py-2 text-sm font-semibold" style={{ background: "#FBE9D8", color: "#8A4209" }}>
          Actividades pendientes de autorizar: aún no puede ejercer (17020 §6.1.6)
        </p>
      )}
      {onFinalizar && ROLES_CON_ACTIVIDADES.includes(d.rol) && <AutorizarActividades base={base} organismo={organismo} d={d} />}
      {d.actividades.length > 0 && (
        <ul className="space-y-1 text-sm">
          {d.actividades.map((a) => <FilaActividad key={a} base={base} organismo={organismo} d={d} actividad={a} corregible={!!onFinalizar} />)}
        </ul>
      )}
      {TIPO_DE_ROL[d.rol] && <BloqueDocumento base={base} organismo={organismo} d={d} vigente={!!onFinalizar} />}
    </article>
  );
}

function FilaActividad({ base, organismo, d, actividad: a, corregible }: { base: BaseOrganismos; organismo: Organismo; d: Designacion; actividad: string; corregible?: boolean }) {
  const [abierta, setAbierta] = useState(false);
  const p = base.personas.find((x) => x.id === d.personaId)!;
  const rol = rolTecnico(d.rol);
  const motivo = motivoNoPuedeEjercer(base, organismo, p, a, hoyISO(), rol);
  const h = evaluarCompetencia(p, a, rol, hoyISO());
  const cert = h.items.find((i) => i.requisito.startsWith("Certificado de competencias") && i.cumple);
  return (
    <li>
      <button className="flex w-full items-start gap-2 text-left" onClick={() => setAbierta(!abierta)}>
        <span className={motivo ? "text-red-600" : "text-emerald-600"}>{motivo ? "✕" : "✓"}</span>
        <span>
          {nombreAutorizacion(a)} <span className="suave text-xs">({h.categoria})</span>
          <span className={`block text-xs ${motivo ? "text-red-600" : "suave"}`}>
            {motivo ? <EnlaceMotivo personaId={p.id} texto={motivo} /> : (cert ? `Certificado ${cert.detalle}` : "Cumple los requisitos")}
            {h.alertas.length > 0 && <span className="text-amber-600"> · {h.alertas.join(" · ")}</span>}
          </span>
        </span>
      </button>
      {abierta && (
        <div className="ml-6 mt-1 space-y-1">
          <ListaRequisitos persona={p} actividad={a} rol={rol} />
          {corregible && (
            <button className="text-xs text-red-700 underline" onClick={() => {
              const m = pedirMotivo(`${nombreAutorizacion(a)} — ${nombrePersona(p)}`); if (m) quitarAutorizacionPorError(d.id, a, m);
            }}>Quitar esta actividad (autorizada por error)</button>
          )}
        </div>
      )}
    </li>
  );
}

function Indicador({ ok, texto }: { ok: boolean; texto: string }) {
  return (
    <span className={`rounded-full px-2 py-0.5 ${ok
      ? "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-300"
      : "bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-300"}`}>{texto}</span>
  );
}

/** Autoriza actividades a una designación ya hecha (cuando se verifican los soportes). */
function AutorizarActividades({ base, organismo, d }: { base: BaseOrganismos; organismo: Organismo; d: Designacion }) {
  const [abierto, setAbierto] = useState(false);
  const [acts, setActs] = useState<string[]>([]);
  const [errores, setErrores] = useState<string[]>([]);
  const [guardando, setGuardando] = useState(false);
  const p = base.personas.find((x) => x.id === d.personaId)!;
  const disponibles = actividadesAutorizables(lineasAcreditadas(organismo)).filter((a) => !d.actividades.includes(a.codigo));
  if (!disponibles.length) return null;
  if (!abierto) {
    return <Boton onClick={() => setAbierto(true)}><Icono nombre="mas" tamano={16} /> Autorizar actividades</Boton>;
  }
  const guardar = async () => {
    if (!acts.length) return setErrores(["Marque las actividades que va a autorizar"]);
    setGuardando(true);
    const error = await actualizar((b) => ({
      ...b, designaciones: b.designaciones.map((x) => (x.id === d.id ? { ...x, actividades: [...x.actividades, ...acts] } : x)),
    }), { mostrarError: false });
    setGuardando(false);
    if (error) return setErrores([error]);
    setActs([]); setErrores([]); setAbierto(false);
  };
  return (
    <div className="space-y-3 rounded-lg border p-3" style={{ borderColor: "var(--marca)" }}>
      <p className="suave text-sm">
        Solo se pueden autorizar actividades del alcance acreditado para las que {nombrePersona(p)} cumple los requisitos
        del reglamento como {rolTecnico(d.rol) === "inspector" ? "inspector" : "director técnico"}, con su experiencia verificada por otra persona.
      </p>
      <SelectorActividades actividades={disponibles} seleccion={acts} onCambio={setActs}
        bloqueo={(c) => motivoNoPuedeEjercer(base, organismo, p, c, hoyISO(), rolTecnico(d.rol))} personaId={p.id} />
      <Errores errores={errores} />
      <div className="flex gap-2">
        <Boton onClick={guardar} disabled={guardando}>{guardando ? "Guardando…" : "Autorizar"}</Boton>
        <Boton variante="secundario" onClick={() => { setAbierto(false); setActs([]); setErrores([]); }}>Cancelar</Boton>
      </div>
    </div>
  );
}

// ───────────────────────── Formulario de designación ─────────────────────────

function FormularioDesignacion({ base, organismo, roles, rolInicial, onTerminar }: {
  base: BaseOrganismos; organismo: Organismo; roles: RolOEC[]; rolInicial: RolOEC; onTerminar: () => void;
}) {
  const hoy = hoyISO();
  const [personaId, setPersonaId] = useState("");
  const [creandoPersona, setCreandoPersona] = useState(false);
  const [verHoja, setVerHoja] = useState(false);
  const [filtro, setFiltro] = useState("");
  const [rol, setRol] = useState<RolOEC>(rolInicial);
  const [desde, setDesde] = useState(hoy);
  const [acto, setActo] = useState("");
  const [acts, setActs] = useState<string[]>([]);
  const [vinc, setVinc] = useState<Omit<Vinculacion, "id" | "organismoId" | "personaId">>({
    tipo: "laboral", cargo: NOMBRE_ROL[rolInicial], desde: hoy, sedeId: organismo.sedes.find((s) => s.principal)?.id,
  });
  const [declImp, setDeclImp] = useState(hoy);
  const [declConf, setDeclConf] = useState(hoy);
  const [errores, setErrores] = useState<string[]>([]);
  const [guardando, setGuardando] = useState(false);

  const persona = base.personas.find((p) => p.id === personaId);
  const vinculoExistente = persona ? vinculacionVigente(base, organismo.id, persona.id, desde) : undefined;
  const conActividades = ROLES_CON_ACTIVIDADES.includes(rol);

  // Base hipotética con la vinculación nueva, para evaluar reglas antes de guardar.
  const baseTentativa = useMemo<BaseOrganismos>(() => {
    if (!persona || vinculoExistente) return base;
    return { ...base, vinculaciones: [...base.vinculaciones, { ...vinc, id: "tmp", organismoId: organismo.id, personaId: persona.id }] };
  }, [base, persona, vinculoExistente, vinc, organismo.id]);

  const candidatas = base.personas
    .filter((p) => `${p.nombres} ${p.apellidos} ${p.documento}`.toLowerCase().includes(filtro.toLowerCase()))
    .slice(0, 50);

  const lineas = actividadesAutorizables(lineasAcreditadas(organismo));
  const fechaEval = desde > hoy ? desde : hoy;

  const guardar = async () => {
    if (!persona) return setErrores(["Seleccione o cree una persona"]);
    const e: string[] = [];
    if (!vinculoExistente) {
      if (!vinc.cargo.trim()) e.push("Indique el cargo de la vinculación");
      if (vinc.desde > desde) e.push("La vinculación debe iniciar en o antes de la fecha de designación");
    }
    if (!declImp) e.push("Registre la fecha de la declaración de imparcialidad y conflicto de interés (17020 §4.1)");
    if (!declConf) e.push("Registre la fecha del acuerdo de confidencialidad (17020 §4.2)");
    const nueva = { organismoId: organismo.id, personaId: persona.id, rol, desde, acto: acto || undefined, actividades: conActividades ? acts : [] };
    e.push(...validarDesignacion(baseTentativa, nueva));
    setErrores(e);
    if (e.length) return;

    setGuardando(true);
    const error = await actualizar((b) => ({
      ...b,
      vinculaciones: vinculoExistente ? b.vinculaciones
        : [...b.vinculaciones, { ...vinc, id: nuevoId(), organismoId: organismo.id, personaId: persona.id }],
      designaciones: [...b.designaciones, { ...nueva, id: nuevoId() }],
      declaraciones: [
        ...b.declaraciones,
        ...(["imparcialidad", "confidencialidad"] as const)
          .map((tipo) => ({ tipo, fecha: tipo === "imparcialidad" ? declImp : declConf }))
          .filter(({ tipo, fecha }) => !b.declaraciones.some((x) => x.organismoId === organismo.id && x.personaId === persona.id && x.tipo === tipo && x.fecha === fecha))
          .map(({ tipo, fecha }) => ({ id: nuevoId(), organismoId: organismo.id, personaId: persona.id, tipo, fecha })),
      ],
    }), { mostrarError: false });
    setGuardando(false);
    if (error) return setErrores([error]);
    onTerminar();
  };

  return (
    <div className="tarjeta space-y-5 border-2 p-4" style={{ borderColor: "var(--marca)" }}>
      {/* 1. Persona */}
      <div className="space-y-2">
        <h3 className="font-semibold">1. Persona</h3>
        {creandoPersona ? (
          <FormularioPersona base={base} onCancelar={() => setCreandoPersona(false)}
            onGuardado={(id) => { setPersonaId(id); setCreandoPersona(false); }} />
        ) : persona ? (
          <div className="flex flex-wrap items-center gap-2 text-sm">
            <b>{nombrePersona(persona)}</b> <span className="suave">{persona.tipoDocumento} {persona.documento}</span>
            <button className="underline suave" onClick={() => { setPersonaId(""); setActs([]); }}>cambiar</button>
          </div>
        ) : (
          <div className="space-y-2">
            <Entrada placeholder="Buscar por nombre o documento…" value={filtro} onChange={(e) => setFiltro(e.target.value)} />
            {candidatas.length > 0 && (
              <ul className="max-h-48 divide-y overflow-y-auto rounded-lg border text-sm" style={{ borderColor: "var(--borde)" }}>
                {candidatas.map((p) => (
                  <li key={p.id}>
                    <button className="w-full px-3 py-2 text-left hover:bg-black/5 dark:hover:bg-white/5" onClick={() => setPersonaId(p.id)}>
                      {nombrePersona(p)} <span className="suave">· {p.documento}</span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
            <Boton variante="contorno" onClick={() => setCreandoPersona(true)}><Icono nombre="mas" tamano={16} /> Registrar persona nueva</Boton>
          </div>
        )}
      </div>

      {persona && (
        <>
          {/* 2. Rol */}
          <div className="space-y-2">
            <h3 className="font-semibold">2. Designación</h3>
            <div className="grid gap-3 sm:grid-cols-3">
              {roles.length > 1 && (
                <Campo etiqueta="Rol">
                  <Selector value={rol} onChange={(e) => { setRol(e.target.value as RolOEC); setVinc({ ...vinc, cargo: NOMBRE_ROL[e.target.value as RolOEC] }); }}>
                    {roles.map((r) => <option key={r} value={r}>{NOMBRE_ROL[r]}</option>)}
                  </Selector>
                </Campo>
              )}
              <Campo etiqueta="Desde"><Entrada type="date" value={desde} onChange={(e) => setDesde(e.target.value)} /></Campo>
              <Campo etiqueta="Acto de designación" ayuda="Acta, resolución o documento interno">
                <Entrada value={acto} onChange={(e) => setActo(e.target.value)} placeholder="Acta de gerencia No. …" />
              </Campo>
            </div>
          </div>

          {/* 3. Vinculación */}
          <div className="space-y-2">
            <h3 className="font-semibold">3. Vinculación con el organismo</h3>
            {vinculoExistente ? (
              <p className="text-sm">Ya vinculada: <b>{vinculoExistente.cargo}</b> ({vinculoExistente.tipo.replace("_", " ")}) desde {vinculoExistente.desde}.</p>
            ) : (
              <div className="grid gap-3 sm:grid-cols-4">
                <Campo etiqueta="Tipo">
                  <Selector value={vinc.tipo} onChange={(e) => setVinc({ ...vinc, tipo: e.target.value as Vinculacion["tipo"] })}>
                    <option value="laboral">Contrato laboral</option>
                    <option value="prestacion_servicios">Prestación de servicios</option>
                    <option value="otro">Otro</option>
                  </Selector>
                </Campo>
                <Campo etiqueta="Cargo"><Entrada value={vinc.cargo} onChange={(e) => setVinc({ ...vinc, cargo: e.target.value })} /></Campo>
                <Campo etiqueta="Desde"><Entrada type="date" value={vinc.desde} onChange={(e) => setVinc({ ...vinc, desde: e.target.value })} /></Campo>
                <Campo etiqueta="Sede">
                  <Selector value={vinc.sedeId ?? ""} onChange={(e) => setVinc({ ...vinc, sedeId: e.target.value || undefined })}>
                    {organismo.sedes.map((s) => <option key={s.id} value={s.id}>{s.nombre}</option>)}
                  </Selector>
                </Campo>
              </div>
            )}
          </div>

          {/* 4. Actividades */}
          {conActividades && (
            <div className="space-y-2">
              <h3 className="font-semibold">4. Actividades autorizadas (17020 §6.1.6)</h3>
              <p className="text-sm">
                Puede dejarlas <b>pendientes</b> y autorizarlas después con <b>+ Autorizar actividades</b>, cuando otra persona del organismo
                haya verificado los soportes. Mientras tanto la persona no puede ejercer.
              </p>
              <p className="suave text-sm">
                Solo se pueden autorizar actividades del alcance acreditado para las que la persona cumple los requisitos del reglamento
                como {rol === "inspector" ? "inspector" : "director técnico"}: matrícula, formación, experiencia verificada y certificado de competencias vigente con seguimiento.
              </p>
              <div className="text-sm">
                <b>Certificados:</b>{" "}
                {persona.certificados.filter((c) => !c.anulado).length === 0 ? <span className="text-red-600">ninguno registrado</span>
                  : persona.certificados.filter((c) => !c.anulado).map((c) => (
                    <span key={c.id} className="mr-2">N.° {c.numero} (cat. {c.categorias.join(", ")}, vence {c.fechaVencimiento})</span>
                  ))}
                <button className={`ml-2 ${claseBoton("contorno", "pequeno")}`} onClick={() => setVerHoja(!verHoja)}>
                  {verHoja ? "ocultar hoja de vida" : "completar hoja de vida (certificados, experiencia, formación)"}
                </button>
              </div>
              {verHoja && <div className="rounded-lg border p-3" style={{ borderColor: "var(--borde)" }}><HojaDeVida persona={persona} /></div>}
              <SelectorActividades actividades={lineas} seleccion={acts} onCambio={setActs}
                bloqueo={(c) => motivoNoPuedeEjercer(baseTentativa, organismo, persona, c, fechaEval, rolTecnico(rol))} personaId={persona.id} />
            </div>
          )}

          {/* 5. Declaraciones */}
          <div className="space-y-2">
            <h3 className="font-semibold">{conActividades ? "5" : "4"}. Compromisos firmados</h3>
            <div className="grid gap-3 sm:grid-cols-2">
              <Campo etiqueta="Declaración de imparcialidad y conflicto de interés (§4.1)">
                <Entrada type="date" value={declImp} onChange={(e) => setDeclImp(e.target.value)} />
              </Campo>
              <Campo etiqueta="Acuerdo de confidencialidad (§4.2)">
                <Entrada type="date" value={declConf} onChange={(e) => setDeclConf(e.target.value)} />
              </Campo>
            </div>
          </div>
        </>
      )}

      <Errores errores={errores} />
      <div className="flex gap-2">
        <Boton onClick={guardar} disabled={!persona || guardando}>{guardando ? "Guardando…" : "Guardar designación"}</Boton>
        <Boton variante="secundario" onClick={onTerminar}>Cancelar</Boton>
      </div>
    </div>
  );
}

// ───────────────────────── Documento de designación o autorización (0013) ─────────────────────────

function BloqueDocumento({ base, organismo, d, vigente }: { base: BaseOrganismos; organismo: Organismo; d: Designacion; vigente: boolean }) {
  const yo = usePersonaActual(base);
  const { gestion } = usePermisosOrganismo(base, organismo.id);
  const [generando, setGenerando] = useState(false);
  const [evaluador, setEvaluador] = useState("");
  const [errores, setErrores] = useState<string[]>([]);
  const tipo = TIPO_DE_ROL[d.rol]!;
  const e = estadoDocumentacion(base, d);
  const docs = documentosDe(base, d.id);
  const esDT = base.designaciones.some((x) => x.organismoId === organismo.id && x.personaId === yo?.id && ["director_tecnico", "director_tecnico_suplente"].includes(x.rol) && vigenteEn(x, hoyISO()));
  const puedeGenerar = vigente && (gestion || esDT || !CON_SUPABASE);
  const esInspector = tipo === "autorizacion_inspector";
  const sinActividades = tipo.startsWith("autorizacion_") && d.actividades.length === 0;
  const necesitaNuevo = !e.pendiente && (!e.firmado || e.sinFirmar.length > 0);
  const evaluadores = evaluadoresPosibles(base, d);
  const yoFirmo = e.pendiente ? puedeFirmarComo(base, e.pendiente, yo?.id) : [];

  const generar = async () => {
    if (esInspector && !evaluador) return setErrores(["Indique el director técnico que evaluó al inspector"]);
    const borrador = generarDocumento(base, d, evaluador || undefined);
    if (!borrador) return setErrores(["No se pudo generar el documento"]);
    const id = nuevoId();
    const error = await actualizar((b) => ({
      ...b,
      documentosPersonal: [
        ...(b.documentosPersonal ?? []).map((x) => (x.designacionId === d.id && !x.reemplazadoEn && !documentoFirmado(x) ? { ...x, reemplazadoEn: new Date().toISOString() } : x)),
        { id, organismoId: organismo.id, designacionId: d.id, tipo, titulo: borrador.titulo, contenido: borrador.contenido, huella: "",
          actividades: d.actividades, evaluadorId: evaluador || undefined, creadoEn: new Date().toISOString(), firmas: [] },
      ],
    }), { mostrarError: false });
    if (error) return setErrores([error]);
    if (!CON_SUPABASE) {
      const h = await huella(borrador.contenido);
      await actualizar((b) => ({ ...b, documentosPersonal: (b.documentosPersonal ?? []).map((x) => (x.id === id ? { ...x, huella: h } : x)) }));
    }
    setGenerando(false); setErrores([]);
    window.location.href = `/documento?id=${id}&volver=${encodeURIComponent(window.location.pathname + window.location.search)}`;
  };

  const estado = e.firmado && !e.sinFirmar.length
    ? { clase: "alerta-verde", texto: `Firmado${docs.find((x) => x.firmadoAManoRuta) ? " (a mano)" : ""}` }
    : e.pendiente ? { clase: "alerta-naranja", texto: `Pendiente de firma: falta ${e.faltan.join(" y ")}` }
    : e.firmado ? { clase: "alerta-naranja", texto: "Hay actividades autorizadas que no están en un documento firmado" }
    : { clase: "alerta-roja", texto: "Sin documento firmado: no puede ejercer (17020 §6.1.6)" };

  return (
    <div className="space-y-2 rounded-xl border p-3" style={{ borderColor: "var(--borde)" }}>
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <Icono nombre="documento" tamano={20} color="var(--marca)" />
          <span className="text-sm font-semibold">{NOMBRE_TIPO[tipo]}</span>
        </div>
        <span className={`rounded-lg px-3 py-1 text-xs font-bold ${estado.clase}`}>{estado.texto}</span>
      </div>
      {e.sinFirmar.length > 0 && e.firmado && (
        <p className="text-xs">Sin documento firmado: {e.sinFirmar.map(nombreAutorizacion).join("; ")}. Genere un documento actualizado.</p>
      )}
      <div className="flex flex-wrap items-center gap-2">
        {e.pendiente && (
          <Link href={`/documento?id=${e.pendiente.id}`} className={claseBoton(yoFirmo.length ? "primario" : "contorno", "pequeno")}>
            <Icono nombre={yoFirmo.length ? "firma" : "ojo"} tamano={15} />
            {yoFirmo.length ? `Ver y firmar como ${yoFirmo.map((c) => NOMBRE_CALIDAD[c].toLowerCase()).join(" y ")}` : "Ver documento"}
          </Link>
        )}
        {docs.filter((x) => !x.reemplazadoEn && x.id !== e.pendiente?.id).map((x) => (
          <Link key={x.id} href={`/documento?id=${x.id}`} className={claseBoton("contorno", "pequeno")}>
            <Icono nombre="ojo" tamano={15} /> Ver documento firmado ({x.creadoEn.slice(0, 10)})
          </Link>
        ))}
        {puedeGenerar && (necesitaNuevo || e.pendiente) && !generando && !sinActividades && (
          <Boton variante={necesitaNuevo ? "primario" : "secundario"} tamano="pequeno" onClick={() => setGenerando(true)}>
            <Icono nombre="documento" tamano={15} /> {e.pendiente ? "Volver a generar" : e.firmado ? "Generar documento actualizado" : "Generar documento"}
          </Boton>
        )}
        {sinActividades && <span className="suave text-xs">El documento se genera después de autorizar las actividades.</span>}
      </div>
      {generando && (
        <div className="space-y-2 rounded-lg border-2 p-3" style={{ borderColor: "var(--marca)" }}>
          <p className="text-sm">
            Se genera con los datos de la designación{tipo.startsWith("autorizacion_") ? " y las actividades autorizadas" : ""}.
            {e.pendiente && " Reemplaza al documento pendiente de firma."} Texto provisional, hasta adecuarlo a los formatos del organismo.
          </p>
          {esInspector && (
            <Campo etiqueta="Director técnico que evaluó al inspector (firma la autorización)">
              <Selector value={evaluador} onChange={(x) => setEvaluador(x.target.value)}>
                <option value="">Seleccione…</option>
                {evaluadores.map((p) => <option key={p.id} value={p.id}>{nombrePersona(p)}</option>)}
              </Selector>
            </Campo>
          )}
          {esInspector && !evaluadores.length && <p className="text-xs text-red-600">No hay director técnico vigente que pueda figurar como evaluador.</p>}
          <Errores errores={errores} />
          <div className="flex gap-2">
            <Boton onClick={generar}>Generar y abrir</Boton>
            <Boton variante="secundario" onClick={() => { setGenerando(false); setErrores([]); }}>Cancelar</Boton>
          </div>
        </div>
      )}
    </div>
  );
}
