"use client";
import { useMemo, useState } from "react";
import { actividad, nombreCorto } from "@/lib/catalogo";
import { actualizar, nuevoId } from "@/lib/organismo/almacen";
import {
  hoyISO, lineasAcreditadas, motivoNoPuedeEjercer, nombrePersona,
  validarDesignacion, vigenteEn, vinculacionVigente,
} from "@/lib/organismo/reglas";
import { evaluarCompetencia } from "@/lib/organismo/competencia";
import {
  NOMBRE_ROL, ROLES_CON_ACTIVIDADES, rolTecnico,
  type BaseOrganismos, type Designacion, type Organismo, type RolOEC, type Vinculacion,
} from "@/lib/organismo/tipos";
import { Boton, Campo, Entrada, Errores, Selector } from "../Formulario";
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
  const [agregando, setAgregando] = useState(false);
  const [verHistorial, setVerHistorial] = useState(false);
  const hoy = hoyISO();
  const todas = base.designaciones
    .filter((d) => d.organismoId === organismo.id && roles.includes(d.rol))
    .sort((a, b) => roles.indexOf(a.rol) - roles.indexOf(b.rol) || b.desde.localeCompare(a.desde));
  const vigentes = todas.filter((d) => vigenteEn(d, hoy) || d.desde > hoy);
  const historicas = todas.filter((d) => !vigentes.includes(d));

  const finalizar = (d: Designacion) => {
    const motivo = prompt(`Finalizar la designación de ${nombrePersona(base.personas.find((p) => p.id === d.personaId))} como ${NOMBRE_ROL[d.rol].toLowerCase()}.\n\nMotivo (queda en el registro):`);
    if (motivo === null) return;
    actualizar((b) => ({
      ...b,
      designaciones: b.designaciones.map((x) => (x.id === d.id
        ? { ...x, hasta: hoy, acto: [x.acto, `Finalizada ${hoy}: ${motivo || "sin motivo"}`].filter(Boolean).join(" · ") } : x)),
    }));
  };

  return (
    <section className="space-y-4">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <h2 className="text-lg font-semibold">{titulo}</h2>
          <p className="suave max-w-3xl text-sm">{descripcion}</p>
        </div>
        {!agregando && <Boton onClick={() => setAgregando(true)}>+ Designar persona</Boton>}
      </div>

      {agregando && (
        <FormularioDesignacion base={base} organismo={organismo} roles={roles}
          onTerminar={() => setAgregando(false)} />
      )}

      {vigentes.length === 0 && !agregando && (
        <p className="tarjeta suave p-4 text-sm">Aún no hay personas designadas.</p>
      )}
      <div className="grid gap-3">
        {vigentes.map((d) => <TarjetaDesignacion key={d.id} base={base} organismo={organismo} d={d} onFinalizar={() => finalizar(d)} />)}
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
          <div className="text-xs font-semibold uppercase tracking-wide marca">{NOMBRE_ROL[d.rol]}</div>
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
        {onFinalizar && <Boton variante="peligro" onClick={onFinalizar}>Finalizar</Boton>}
      </div>
      <div className="flex flex-wrap gap-2 text-xs">
        <Indicador ok={!!decl("imparcialidad")} texto={`Imparcialidad ${decl("imparcialidad") ?? "sin firmar"}`} />
        <Indicador ok={!!decl("confidencialidad")} texto={`Confidencialidad ${decl("confidencialidad") ?? "sin firmar"}`} />
      </div>
      {d.actividades.length > 0 && (
        <ul className="space-y-1 text-sm">
          {d.actividades.map((a) => <FilaActividad key={a} base={base} organismo={organismo} d={d} actividad={a} />)}
        </ul>
      )}
    </article>
  );
}

function FilaActividad({ base, organismo, d, actividad: a }: { base: BaseOrganismos; organismo: Organismo; d: Designacion; actividad: string }) {
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
          {nombreCorto(a)} <span className="suave text-xs">({h.categoria})</span>
          <span className={`block text-xs ${motivo ? "text-red-600" : "suave"}`}>
            {motivo ?? (cert ? `Certificado ${cert.detalle}` : "Cumple los requisitos")}
            {h.alertas.length > 0 && <span className="text-amber-600"> · {h.alertas.join(" · ")}</span>}
          </span>
        </span>
      </button>
      {abierta && <div className="ml-6 mt-1"><ListaRequisitos persona={p} actividad={a} rol={rol} /></div>}
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

// ───────────────────────── Formulario de designación ─────────────────────────

function FormularioDesignacion({ base, organismo, roles, onTerminar }: {
  base: BaseOrganismos; organismo: Organismo; roles: RolOEC[]; onTerminar: () => void;
}) {
  const hoy = hoyISO();
  const [personaId, setPersonaId] = useState("");
  const [creandoPersona, setCreandoPersona] = useState(false);
  const [verHoja, setVerHoja] = useState(false);
  const [filtro, setFiltro] = useState("");
  const [rol, setRol] = useState<RolOEC>(roles[0]);
  const [desde, setDesde] = useState(hoy);
  const [acto, setActo] = useState("");
  const [acts, setActs] = useState<string[]>([]);
  const [vinc, setVinc] = useState<Omit<Vinculacion, "id" | "organismoId" | "personaId">>({
    tipo: "laboral", cargo: NOMBRE_ROL[roles[0]], desde: hoy, sedeId: organismo.sedes.find((s) => s.principal)?.id,
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

  const lineas = lineasAcreditadas(organismo).map((c) => actividad(c)!).filter(Boolean);
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
            <Boton variante="secundario" onClick={() => setCreandoPersona(true)}>+ Registrar persona nueva</Boton>
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
                <button className="ml-1 underline marca" onClick={() => setVerHoja(!verHoja)}>
                  {verHoja ? "ocultar hoja de vida" : "completar hoja de vida (certificados, experiencia, formación)"}
                </button>
              </div>
              {verHoja && <div className="rounded-lg border p-3" style={{ borderColor: "var(--borde)" }}><HojaDeVida persona={persona} /></div>}
              <SelectorActividades actividades={lineas} seleccion={acts} onCambio={setActs}
                bloqueo={(c) => motivoNoPuedeEjercer(baseTentativa, organismo, persona, c, fechaEval, rolTecnico(rol))} />
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
