"use client";
import Link from "next/link";
import { useParams, useRouter, useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";
import { Boton, Campo, Entrada, Errores, Grupo, Selector, Texto } from "@/components/Formulario";
import { FormularioOrganismo } from "@/components/organismo/FormularioOrganismo";
import { FormularioPersona } from "@/components/organismo/FormularioPersona";
import { SeccionDesignaciones } from "@/components/organismo/SeccionDesignaciones";
import { SelectorActividades } from "@/components/SelectorActividades";
import { EtiquetaEstado } from "@/components/Estado";
import { ACTIVIDADES, actividad, agrupar, nombreCorto } from "@/lib/catalogo";
import { NUMERALES_17020 } from "@/lib/iso17020";
import { actualizar, nuevoId, pedirMotivo, quitarAlcancePorError, useBase, usePersonaActual } from "@/lib/organismo/almacen";
import { useSesion } from "@/lib/sesion";
import { designacionesVigentes, evaluarOrganismo, hoyISO, nombrePersona, vigenteEn } from "@/lib/organismo/reglas";
import type { BaseOrganismos, EstadoLinea, Organismo, RolOEC } from "@/lib/organismo/tipos";
import { Icono, type NombreIcono } from "@/components/Icono";
import { LogosOrganismo } from "@/components/organismo/LogosOrganismo";
import { DocumentosOrganismo } from "@/components/organismo/DocumentosOrganismo";
import { usePermisosOrganismo } from "@/lib/organismo/permisos";
import { NOMBRE_PESTANA, rolesMenu, seccionActual } from "@/lib/navegacion";
import { HojaDeVida, MatrizHabilitacion } from "@/components/organismo/HojaDeVida";
import { NOMBRE_ROL } from "@/lib/organismo/tipos";


export default function PaginaOrganismo() {
  return <Suspense><Contenido /></Suspense>;
}

function Contenido() {
  const { id } = useParams<{ id: string }>();
  const params = useSearchParams();
  const router = useRouter();
  const base = useBase();
  const sesion = useSesion();
  const yo = usePersonaActual(base);
  const pestana = params.get("p") ?? "resumen";
  if (!base) return <p className="suave">Cargando…</p>;
  const o = base.organismos.find((x) => x.id === id);
  if (!o) return <p>Organismo no encontrado. <Link href="/organismos" className="underline">Volver</Link></p>;

  // Tabla de acceso (docs/DECISIONES.md): quien no es de la gerencia, el SG o la dirección técnica
  // solo ve lo suyo. La base de datos lo exige igual; esto evita mostrar datos incompletos.
  const roles = rolesMenu({
    local: sesion.estado === "local",
    esAdminPlataforma: sesion.estado === "con_sesion" && sesion.esAdminPlataforma,
    usuarioId: sesion.estado === "con_sesion" ? sesion.usuarioId : undefined,
    base, personaId: yo?.id, organismoId: o.id,
    enRevision: sesion.estado === "con_sesion" ? sesion.revision.map((x) => x.organismoId) : [],
  });
  if (!roles.has("gerencia")) return <VistaPersonal base={base} o={o} pestana={pestana} />;

  // Pestañas de la sección del menú en la que se está (el menú lateral elige la sección).
  const pestanas = seccionActual(`/organismos/${o.id}`, pestana)?.pestanas ?? [];

  return (
    <div className="space-y-5">
      <p className="suave text-sm">
        {o.razonSocial} · NIT {o.nit} · Organismo de inspección tipo A{o.codigoAcreditacion && ` · Acreditación ${o.codigoAcreditacion}`}
        {o.acreditacionVence && ` · vence ${o.acreditacionVence}`}
      </p>
      {pestanas.length > 1 && (
        <nav className="flex gap-1 overflow-x-auto rounded-xl border p-1" style={{ borderColor: "var(--borde)", background: "var(--tarjeta)" }}>
          {pestanas.map((p) => (
            <button key={p} onClick={() => router.replace(`/organismos/${o.id}?p=${p}`, { scroll: false })}
              aria-current={pestana === p ? "page" : undefined}
              className={`min-h-10 whitespace-nowrap rounded-lg px-4 text-sm ${pestana === p ? "font-semibold text-white" : "suave"}`}
              style={pestana === p ? { background: "var(--marca)" } : undefined}>
              {NOMBRE_PESTANA[p]}
            </button>
          ))}
          {pestanas.includes("dt") && (
            <Link href="/personas" className="suave flex min-h-10 items-center whitespace-nowrap rounded-lg px-4 text-sm">Directorio de personas</Link>
          )}
        </nav>
      )}

      <Arranque base={base} o={o} irA={(p) => router.replace(`/organismos/${o.id}?p=${p}`, { scroll: false })} />
      {pestana === "resumen" && <Resumen base={base} o={o} />}
      {pestana === "alcance" && <Alcance base={base} o={o} />}
      {pestana === "documentos" && <DocumentosOrganismo base={base} o={o} />}
      {pestana === "gerencia" && (
        <SeccionDesignaciones base={base} organismo={o} roles={["representante_legal", "gerente", "miembro_gerencia"]}
          titulo="Gerencia del organismo"
          descripcion="Personas con responsabilidad general sobre el organismo (17020 §5.2.1). Debe haber un único representante legal vigente. La gerencia firma la declaración de independencia del organismo tipo A y responde por la imparcialidad (§4.1.2)." />
      )}
      {pestana === "sg" && (
        <div className="space-y-8">
          <SeccionDesignaciones base={base} organismo={o} roles={["responsable_sg", "suplente_sg"]}
            titulo="Responsable del sistema de gestión"
            descripcion="Debe existir siempre un único responsable vigente del sistema de gestión (opción A, 17020 §8). Para relevarlo, finalice la designación actual y designe a la nueva persona. Se recomienda un suplente." />
          <RevisionesSG base={base} o={o} />
        </div>
      )}
      {pestana === "dt" && (
        <SeccionDesignaciones base={base} organismo={o} roles={["director_tecnico", "director_tecnico_suplente"]}
          titulo="Directores técnicos"
          descripcion="Responsables técnicos de las actividades de inspección (17020 §5.2.5) y sus suplentes (§5.2.6). Solo se autorizan actividades del alcance acreditado cubiertas por un certificado de competencias vigente." />
      )}
      {pestana === "inspectores" && (
        <SeccionDesignaciones base={base} organismo={o} roles={["inspector"]}
          titulo="Inspectores"
          descripcion="Inspectores autorizados formalmente por actividad (17020 §6.1.6). La autorización queda limitada a las actividades acreditadas del organismo que estén cubiertas por un certificado de competencias vigente; si el certificado vence o la línea se retira, el tablero lo marca de inmediato." />
      )}
      {pestana === "onac" && <PersonalONAC base={base} o={o} />}
    </div>
  );
}

// ───────────────────────── Vista de quien no administra ─────────────────────────
/** Inspectores y demás personal: su habilitación y su hoja de vida, nada de los demás. */
function VistaPersonal({ base, o, pestana }: { base: BaseOrganismos; o: Organismo; pestana: string }) {
  const yo = usePersonaActual(base);
  if (!yo) return <p className="tarjeta p-4 text-sm">Su usuario aún no está enlazado a una persona de este organismo.</p>;
  const mias = designacionesVigentes(base, o.id, Object.keys(NOMBRE_ROL) as RolOEC[]).filter((d) => d.personaId === yo.id);
  const enPersonal = ["dt", "inspectores", "onac"].includes(pestana);
  const deGerencia = ["alcance", "documentos", "gerencia", "sg"].includes(pestana);
  if (deGerencia) return <p className="tarjeta p-4 text-sm">Esta sección la administran la gerencia y el responsable del sistema de gestión.</p>;
  return (
    <div className="space-y-5">
      <section className="tarjeta space-y-2 p-4">
        <h2 className="font-semibold">{enPersonal ? "Mi hoja de vida" : `Hola, ${yo.nombres}`}</h2>
        <p className="suave text-sm">
          {o.razonSocial}{mias.length ? ` · ${mias.map((d) => NOMBRE_ROL[d.rol]).join(", ")}` : " · sin designación vigente"}
        </p>
        {!enPersonal && mias.some((d) => d.actividades.length) && (
          <ul className="list-disc pl-5 text-sm">
            {mias.flatMap((d) => d.actividades).map((a) => <li key={a}>{actividad(a)?.nombre ?? a}</li>)}
          </ul>
        )}
      </section>
      {enPersonal ? <HojaDeVida persona={yo} /> : <section className="tarjeta p-4"><MatrizHabilitacion persona={yo} /></section>}
    </div>
  );
}

// ───────────────────────── Arranque del organismo ─────────────────────────
const ROLES_ADMINISTRACION: RolOEC[] = ["representante_legal", "gerente", "responsable_sg", "suplente_sg", "director_tecnico", "director_tecnico_suplente"];

/** Guía para quien creó el organismo: mientras nadie lo administre, debe registrarse y designarse él mismo. */
function Arranque({ base, o, irA }: { base: BaseOrganismos; o: Organismo; irA: (pestana: string) => void }) {
  const sesion = useSesion();
  const yo = usePersonaActual(base);
  if (sesion.estado !== "con_sesion" || o.creadoPor !== sesion.usuarioId) return null;
  if (designacionesVigentes(base, o.id, ROLES_ADMINISTRACION).length) return null;
  return (
    <section className="tarjeta space-y-3 border-2 p-4" style={{ borderColor: "var(--marca)" }}>
      <h2 className="font-semibold">Arranque del organismo</h2>
      <p className="text-sm">
        Usted creó este organismo. Mientras nadie esté designado en la gerencia, el sistema de gestión o la dirección técnica,
        solo usted puede administrarlo y <b>solo puede vincularse y designarse a sí mismo</b>. Después podrá designar a las demás personas.
      </p>
      <ol className="list-decimal space-y-2 pl-5 text-sm">
        <li>
          <b>Antes de designarse</b>, complete los datos del organismo: logo, símbolo ONAC, póliza RC y declaración de independencia
          (en <b>Datos, logos y alcance</b>). Después de designarse, esos datos solo los modifican la gerencia o el responsable del SG.
        </li>
        <li className={yo ? "suave line-through" : ""}>
          Regístrese como persona con su cédula y su correo de ingreso ({sesion.correo}).
          {yo && <span className="no-underline"> ✓ {nombrePersona(yo)}</span>}
        </li>
        <li>
          Desígnese en su rol real: director técnico, gerencia o responsable del SG. La vinculación y las declaraciones se registran
          en el mismo formulario.
          <span className="suave block text-xs">
            Como director técnico puede dejar las actividades <b>pendientes</b>: se autorizan después, cuando <b>otra persona</b> del
            organismo haya verificado sus soportes (no se permite la autoverificación).
          </span>
        </li>
      </ol>
      {!yo ? (
        <div className="rounded-lg border p-3" style={{ borderColor: "var(--borde)" }}>
          <FormularioPersona base={base} correoFijo={sesion.correo} onGuardado={() => {}} />
        </div>
      ) : (
        <div className="flex flex-wrap gap-2">
          <Boton onClick={() => irA("alcance")}>Completar datos y logos</Boton>
          <Boton variante="secundario" onClick={() => irA("dt")}>Designarme director técnico</Boton>
          <Boton variante="secundario" onClick={() => irA("gerencia")}>Designarme en la gerencia</Boton>
          <Boton variante="secundario" onClick={() => irA("sg")}>Designarme responsable del SG</Boton>
        </div>
      )}
    </section>
  );
}

// ───────────────────────── Resumen de cumplimiento ─────────────────────────
function Resumen({ base, o }: { base: BaseOrganismos; o: Organismo }) {
  const controles = evaluarOrganismo(base, o);
  const cuenta = (e: string) => controles.filter((c) => c.estado === e).length;
  return (
    <div className="space-y-4">
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        {([
          ["Controles que cumplen", cuenta("cumple"), "dictamenes", "#16795A", "#DCF2E9"],
          ["En alerta", cuenta("alerta"), "alerta", "#B4590F", "#FBE9D8"],
          ["Incumplen", cuenta("incumple"), "alerta", "#B42318", "#FBE2E0"],
        ] as [string, number, NombreIcono, string, string][]).map(([t, v, ic, color, fondo]) => (
          <div key={t} className="tarjeta flex items-center gap-4 p-4">
            <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl" style={{ background: fondo }}>
              <Icono nombre={ic} color={color} tamano={24} grosor={2} />
            </span>
            <div>
              <div className="font-titulo text-3xl font-extrabold tabular-nums" style={{ color }}>{v}</div>
              <div className="suave text-sm">{t}</div>
            </div>
          </div>
        ))}
      </div>
      <ul className="grid gap-2">
        {controles.map((c) => (
          <li key={c.id} className="tarjeta p-3 text-sm">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <span><span className="suave font-mono text-xs">§{c.numeral}</span> {c.titulo}</span>
              <EtiquetaEstado estado={c.estado} />
            </div>
            {c.hallazgos.length > 0 && <ul className="suave mt-1 list-disc pl-6">{c.hallazgos.map((h) => <li key={h}>{h}</li>)}</ul>}
          </li>
        ))}
      </ul>
    </div>
  );
}

// ───────────────────────── Datos y alcance ─────────────────────────
const ESTADOS: Record<EstadoLinea, string> = { acreditada: "Acreditada", en_tramite: "En trámite", suspendida: "Suspendida", retirada: "Retirada" };

function Alcance({ base, o }: { base: BaseOrganismos; o: Organismo }) {
  const [editando, setEditando] = useState(false);
  const [agregando, setAgregando] = useState(false);
  const [nuevas, setNuevas] = useState<string[]>([]);
  const permisos = usePermisosOrganismo(base, o.id);
  const disponibles = ACTIVIDADES.filter((a) => !o.alcance.some((l) => l.actividad === a.codigo));

  const cambiarEstado = (codigo: string, estado: EstadoLinea) => {
    const obs = estado === "acreditada" ? "" : prompt(`Motivo / soporte del cambio a "${ESTADOS[estado]}":`) ?? null;
    if (obs === null) return;
    actualizar((b) => ({ ...b, organismos: b.organismos.map((x) => x.id === o.id
      ? { ...x, alcance: x.alcance.map((l) => (l.actividad === codigo ? { ...l, estado, fechaEstado: hoyISO(), observacion: obs || undefined } : l)) } : x) }));
  };
  const agregar = () => {
    actualizar((b) => ({ ...b, organismos: b.organismos.map((x) => x.id === o.id
      ? { ...x, alcance: [...x.alcance, ...nuevas.map((a) => ({ actividad: a, estado: "en_tramite" as const, fechaEstado: hoyISO() }))] } : x) }));
    setNuevas([]); setAgregando(false);
  };

  if (editando) return <FormularioOrganismo base={base} organismo={o} onGuardado={() => setEditando(false)} onCancelar={() => setEditando(false)} />;

  return (
    <div className="space-y-6">
      <LogosOrganismo o={o} puedeCargar={permisos.gestion} />
      <section className="tarjeta space-y-2 p-4 text-sm">
        <div className="flex items-center justify-between">
          <h2 className="font-semibold">Datos generales</h2>
          {permisos.gestion && <Boton variante="secundario" onClick={() => setEditando(true)}>Editar</Boton>}
        </div>
        <dl className="grid gap-x-6 gap-y-1 sm:grid-cols-2">
          {[
            ["Dirección", [o.direccion, o.ciudad].filter(Boolean).join(", ")],
            ["Contacto", [o.telefono, o.correo].filter(Boolean).join(" · ")],
            ["Acreditación", [o.codigoAcreditacion, o.acreditacionOtorgada && `otorgada ${o.acreditacionOtorgada}`, o.acreditacionRenovada && `renovada ${o.acreditacionRenovada}`,
              o.acreditacionActualizada && `actualizada ${o.acreditacionActualizada}`, o.acreditacionVence && `vence ${o.acreditacionVence}`].filter(Boolean).join(" · ")],
            ["Póliza RC", [o.polizaRCNumero, o.polizaRCVence && `vence ${o.polizaRCVence}`].filter(Boolean).join(" · ")],
            ["Declaración de independencia", o.declaracionIndependencia],
            ["Sedes", o.sedes.map((s) => s.nombre).join(", ")],
          ].map(([k, v]) => (
            <div key={k} className="flex gap-2"><dt className="suave">{k}:</dt><dd>{v || "—"}</dd></div>
          ))}
        </dl>
      </section>

      <section className="space-y-3">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div>
            <h2 className="font-semibold">Alcance acreditado</h2>
            <p className="suave text-xs">Toque una actividad para ver su detalle.</p>
          </div>
          {permisos.gestion && !agregando && disponibles.length > 0 && <Boton variante="secundario" onClick={() => setAgregando(true)}>+ Agregar actividad</Boton>}
        </div>
        {agregando && (
          <div className="tarjeta space-y-3 p-4">
            <p className="suave text-sm">
              Aquí solo aparecen las actividades que aún no están en el alcance (ya tiene <b>{o.alcance.length}</b>).
              Las nuevas quedan <b>en trámite</b> hasta que ONAC otorgue la ampliación; entonces cámbielas a <b>acreditada</b>.
            </p>
            <SelectorActividades actividades={disponibles} seleccion={nuevas} onCambio={setNuevas} />
            <div className="flex gap-2"><Boton onClick={agregar} disabled={!nuevas.length}>Agregar</Boton><Boton variante="secundario" onClick={() => setAgregando(false)}>Cancelar</Boton></div>
          </div>
        )}
        <AlcanceDosColumnas base={base} o={o} cambiarEstado={cambiarEstado} permisos={permisos} />
      </section>
    </div>
  );
}

// ───────────────────────── Alcance en dos columnas (diseño aprobado) ─────────────────────────
const COLUMNAS = [
  { prefijo: "RETIE", titulo: "RETIE 2024", acto: "Resolución 40117 de 2024 · Instalaciones eléctricas", color: "#0F6E8C", icono: "rayo" as NombreIcono },
  { prefijo: "RETILAP", titulo: "RETILAP 2024", acto: "Resolución 40150 de 2024 · Iluminación y alumbrado público", color: "#B98A00", icono: "bombillo" as NombreIcono },
];
const COLOR_ESTADO: Record<EstadoLinea, [string, string]> = {
  acreditada: ["#16795A", "#DCF2E9"], en_tramite: ["#0B4F64", "#DDEFF3"], suspendida: ["#8A4209", "#FBE9D8"], retirada: ["#B42318", "#FBE2E0"],
};

function AlcanceDosColumnas({ base, o, cambiarEstado, permisos }: {
  base: BaseOrganismos; o: Organismo; cambiarEstado: (c: string, e: EstadoLinea) => void; permisos: { gerencia: boolean; gestion: boolean };
}) {
  const [abierta, setAbierta] = useState<string | null>(null);
  const acts = o.alcance.map((l) => actividad(l.actividad)!).filter(Boolean);
  if (!acts.length) return <p className="tarjeta suave p-4 text-sm">Aún no hay actividades en el alcance.</p>;
  return (
    <div className="grid items-start gap-5 lg:grid-cols-2">
      {COLUMNAS.map((c) => {
        const grupos = agrupar(acts.filter((a) => a.reglamento.startsWith(c.prefijo)))[0]?.grupos ?? [];
        const total = grupos.reduce((n, [, xs]) => n + xs.length, 0);
        return (
          <section key={c.prefijo} className="tarjeta overflow-hidden">
            <header className="flex items-center gap-3 border-b p-4" style={{ borderColor: "var(--borde)" }}>
              <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl" style={{ background: c.color }}>
                <Icono nombre={c.icono} color="#FFFFFF" tamano={22} grosor={2.1} />
              </span>
              <div className="min-w-0 flex-1">
                <div className="font-titulo text-xl font-extrabold">{c.titulo}</div>
                <div className="suave text-xs">{c.acto}</div>
              </div>
              <span className="whitespace-nowrap rounded-full border px-3 py-1 text-sm font-bold" style={{ borderColor: "var(--borde)" }}>{total} en el alcance</span>
            </header>
            <div className="px-4 pb-4">
              {!grupos.length && <p className="suave pt-4 text-sm">Sin actividades de este reglamento.</p>}
              {grupos.map(([grupo, xs]) => (
                <div key={grupo} className="pt-4">
                  <div className="suave pb-1.5 text-[11px] font-bold uppercase tracking-[0.1em]">{grupo}</div>
                  {xs.map((a) => {
                    const l = o.alcance.find((x) => x.actividad === a.codigo)!;
                    const [color, fondo] = COLOR_ESTADO[l.estado];
                    const abiertaAqui = abierta === a.codigo;
                    const autorizadas = base.designaciones.filter((d) => d.organismoId === o.id && d.actividades.includes(a.codigo) && vigenteEn(d, hoyISO()));
                    const nombres = (roles: string[]) => autorizadas.filter((d) => roles.includes(d.rol))
                      .map((d) => nombrePersona(base.personas.find((p) => p.id === d.personaId))).join(", ") || "Nadie todavía";
                    return (
                      <div key={a.codigo}>
                        <button className="flex w-full items-start gap-3 border-t py-3 text-left" style={{ borderColor: "var(--borde)" }}
                          aria-expanded={abiertaAqui} onClick={() => setAbierta(abiertaAqui ? null : a.codigo)}>
                          <span className="min-w-0 flex-1">
                            <span className="block text-base font-bold uppercase leading-snug">{nombreCorto(a.codigo)}</span>
                            <span className="suave mt-1 block text-justify text-xs" style={{ hyphens: "auto" }}>{a.nombre}</span>
                          </span>
                          <span className="shrink-0 text-right">
                            <span className="inline-block rounded-full px-2.5 py-1 text-xs font-bold" style={{ color, background: fondo }}>{ESTADOS[l.estado]}</span>
                            <span className="suave mt-1 block text-[11px]">desde {l.fechaEstado}</span>
                          </span>
                        </button>
                        {abiertaAqui && (
                          <div className="mb-3 space-y-3 rounded-xl border p-3" style={{ borderColor: "var(--borde)", background: "var(--fondo)" }}>
                            <div className="grid gap-3 sm:grid-cols-2">
                              <Dato icono="gestion" titulo="Procedimientos de inspección" texto="Se construirá con el control documental (fase 4)." />
                              <Dato icono="cotizaciones" titulo="Formatos de inspección" texto="Se construirá con la inspección en sitio (fase 2)." />
                              <Dato icono="dictamenes" titulo="Directores técnicos autorizados" texto={nombres(["director_tecnico", "director_tecnico_suplente"])} />
                              <Dato icono="personal" titulo="Inspectores autorizados" texto={nombres(["inspector"])} />
                              <Dato icono="equipos" titulo="Equipos de medición" texto="Se construirá con equipos y calibraciones (fase 2)." />
                              <Dato icono="ordenes" titulo="Referencias del reglamento" texto={`${a.referencias.length} referencias del anexo de ONAC`} />
                            </div>
                            <ul className="suave list-disc pl-5 text-xs">{a.referencias.map((r) => <li key={r}>{r}</li>)}</ul>
                            {l.observacion && <p className="text-xs"><b>Observación del estado:</b> {l.observacion}</p>}
                            {(l.estadoPor || l.estadoEnCalidad) && (
                              <p className="suave text-xs">
                                Estado fijado el {l.fechaEstado}
                                {l.estadoPor && <> por <b>{nombrePersona(base.personas.find((p) => p.id === l.estadoPor))}</b></>}
                                {l.estadoEnCalidad && <> · como {calidad(l.estadoEnCalidad)}</>}
                              </p>
                            )}
                            <div className="flex flex-wrap items-center gap-4 border-t pt-3 text-sm" style={{ borderColor: "var(--borde)" }}>
                              {permisos.gerencia ? (
                                <label className="flex items-center gap-2">
                                  <span className="suave text-xs">Cambiar estado</span>
                                  <Selector value={l.estado} onChange={(e) => cambiarEstado(a.codigo, e.target.value as EstadoLinea)} className="w-auto py-1 text-xs">
                                    {Object.entries(ESTADOS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                                  </Selector>
                                </label>
                              ) : <span className="suave text-xs">Solo la gerencia cambia el estado de la actividad.</span>}
                              {permisos.gestion && !base.designaciones.some((d) => d.organismoId === o.id && d.actividades.includes(a.codigo)) && (
                                <button className="text-xs text-red-700 underline" onClick={() => {
                                  const m = pedirMotivo(a.nombre); if (m) quitarAlcancePorError(o.id, a.codigo, m);
                                }}>Quitar (registrada por error)</button>
                              )}
                            </div>
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              ))}
            </div>
          </section>
        );
      })}
    </div>
  );
}

/** "suplente_sg, gerente" → "Suplente del responsable del SG y Gerente". */
function calidad(texto: string) {
  return texto.split(",").map((r) => r.trim()).map((r) => NOMBRE_ROL[r as RolOEC] ?? r).join(" y ");
}

function Dato({ icono, titulo, texto }: { icono: NombreIcono; titulo: string; texto: string }) {
  return (
    <div className="flex items-start gap-2.5">
      <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg border" style={{ borderColor: "var(--borde)" }}>
        <Icono nombre={icono} tamano={16} color="var(--marca)" />
      </span>
      <span>
        <span className="block text-[13px] font-bold">{titulo}</span>
        <span className="suave block text-xs">{texto}</span>
      </span>
    </div>
  );
}

// ───────────────────────── Revisión continua del SG ─────────────────────────
function RevisionesSG({ base, o }: { base: BaseOrganismos; o: Organismo }) {
  const [abierto, setAbierto] = useState(false);
  const [aspectos, setAspectos] = useState<string[]>([]);
  const [obs, setObs] = useState("");
  const [accion, setAccion] = useState(false);
  const [fecha, setFecha] = useState(hoyISO());
  const [errores, setErrores] = useState<string[]>([]);
  const responsables = designacionesVigentes(base, o.id, ["responsable_sg", "suplente_sg"]);
  const [elegido, setQuien] = useState("");
  // Si no se ha elegido (o el elegido dejó de ser responsable), se toma el responsable vigente.
  const quien = responsables.some((d) => d.personaId === elegido) ? elegido : responsables[0]?.personaId ?? "";
  const revisiones = base.revisionesSG.filter((r) => r.organismoId === o.id).sort((a, b) => b.fecha.localeCompare(a.fecha));

  const guardar = async () => {
    const e: string[] = [];
    if (!quien) e.push("Solo el responsable del SG (o su suplente) vigente puede registrar revisiones");
    if (!aspectos.length) e.push("Marque los numerales revisados");
    if (!obs.trim()) e.push("Describa lo revisado y lo encontrado");
    setErrores(e);
    if (e.length) return;
    const error = await actualizar((b) => ({ ...b, revisionesSG: [...b.revisionesSG, { id: nuevoId(), organismoId: o.id, personaId: quien, fecha, aspectos, observaciones: obs, requiereAccion: accion }] }), { mostrarError: false });
    if (error) return setErrores([error]);
    setAbierto(false); setAspectos([]); setObs(""); setAccion(false);
  };

  return (
    <section className="space-y-3">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <h2 className="text-lg font-semibold">Revisión continua del sistema de gestión</h2>
          <p className="suave max-w-3xl text-sm">
            Registro periódico (por defecto cada 30 días) de la revisión que hace el responsable del SG. Si pasa el plazo sin registro, el tablero lo marca como incumplimiento.
          </p>
        </div>
        {!abierto && <Boton onClick={() => setAbierto(true)} disabled={!responsables.length}>+ Registrar revisión</Boton>}
      </div>
      {!responsables.length && <p className="text-sm text-red-600">Designe primero un responsable del sistema de gestión.</p>}
      {abierto && (
        <div className="tarjeta space-y-3 p-4">
          <div className="grid gap-3 sm:grid-cols-2">
            <Campo etiqueta="Responsable">
              <Selector value={quien} onChange={(e) => setQuien(e.target.value)}>
                {responsables.map((d) => <option key={d.id} value={d.personaId}>{nombrePersona(base.personas.find((p) => p.id === d.personaId))}</option>)}
              </Selector>
            </Campo>
            <Campo etiqueta="Fecha"><Entrada type="date" value={fecha} max={hoyISO()} onChange={(e) => setFecha(e.target.value)} /></Campo>
          </div>
          <Grupo etiqueta="Numerales revisados">
            <div className="grid gap-1 sm:grid-cols-2 lg:grid-cols-3">
              {NUMERALES_17020.map((n) => (
                <label key={n.codigo} className="flex items-center gap-2 text-sm">
                  <input type="checkbox" checked={aspectos.includes(n.codigo)}
                    onChange={() => setAspectos(aspectos.includes(n.codigo) ? aspectos.filter((x) => x !== n.codigo) : [...aspectos, n.codigo])} />
                  {n.codigo} {n.titulo}
                </label>
              ))}
            </div>
          </Grupo>
          <Campo etiqueta="Observaciones y hallazgos"><Texto rows={3} value={obs} onChange={(e) => setObs(e.target.value)} /></Campo>
          <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={accion} onChange={(e) => setAccion(e.target.checked)} /> Requiere acción correctiva</label>
          <Errores errores={errores} />
          <div className="flex gap-2"><Boton onClick={guardar}>Guardar revisión</Boton><Boton variante="secundario" onClick={() => setAbierto(false)}>Cancelar</Boton></div>
        </div>
      )}
      <ul className="grid gap-2">
        {revisiones.map((r) => (
          <li key={r.id} className="tarjeta p-3 text-sm">
            <div className="flex flex-wrap justify-between gap-2">
              <b>{r.fecha}</b>
              <span className="suave">{nombrePersona(base.personas.find((p) => p.id === r.personaId))}</span>
            </div>
            <div className="suave text-xs">Numerales: {r.aspectos.join(", ")}{r.requiereAccion && " · requiere acción correctiva"}</div>
            <p className="mt-1 whitespace-pre-line">{r.observaciones}</p>
          </li>
        ))}
      </ul>
    </section>
  );
}

// ───────────────────────── Personal en formato ONAC ─────────────────────────
function PersonalONAC({ base, o }: { base: BaseOrganismos; o: Organismo }) {
  const hoy = hoyISO();
  const filas = base.vinculaciones
    .filter((v) => v.organismoId === o.id && vigenteEn(v, hoy))
    .map((v) => {
      const p = base.personas.find((x) => x.id === v.personaId)!;
      return {
        sede: o.sedes.find((s) => s.id === v.sedeId)?.nombre ?? "",
        nombre: nombrePersona(p),
        documento: `${p.tipoDocumento} ${p.documento}`,
        cargo: v.cargo,
        vinculacion: `${{ laboral: "Laboral", prestacion_servicios: "Prestación de servicios", otro: "Otro" }[v.tipo]} — ${v.desde}`,
        certificados: p.certificados.filter((c) => !c.anulado && c.fechaVencimiento >= hoy).map((c) => c.numero).join("; "),
      };
    });

  const descargar = () => {
    const enc = ["Sede", "Nombre completo", "N° de documento de identidad", "Cargo / Área de actividad", "Tipo y fecha de vinculación", "Certificado de competencias No."];
    const esc = (s: string) => `"${s.replace(/"/g, '""')}"`;
    const csv = [enc, ...filas.map((f) => [f.sede, f.nombre, f.documento, f.cargo, f.vinculacion, f.certificados])].map((r) => r.map(esc).join(";")).join("\r\n");
    const url = URL.createObjectURL(new Blob(["﻿" + csv], { type: "text/csv;charset=utf-8" }));
    const a = document.createElement("a");
    a.href = url; a.download = `personal_${o.nit}_${hoy}.csv`; a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <section className="space-y-3">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <h2 className="text-lg font-semibold">Personas que participan en la evaluación de la conformidad</h2>
          <p className="suave text-sm">Formato solicitado por ONAC (NTE-3.3-88 / NTE-3.3-89, numeral 4.1, ítem 2).</p>
        </div>
        <Boton variante="secundario" onClick={descargar} disabled={!filas.length}>Descargar CSV (Excel)</Boton>
      </div>
      <div className="tarjeta overflow-x-auto">
        <table className="w-full text-left text-sm">
          <thead className="suave text-xs uppercase">
            <tr>{["Sede", "Nombre completo", "Documento", "Cargo", "Tipo y fecha de vinculación", "Certificado de competencias"].map((h) => <th key={h} className="p-3">{h}</th>)}</tr>
          </thead>
          <tbody>
            {filas.map((f) => (
              <tr key={f.documento + f.cargo} className="border-t" style={{ borderColor: "var(--borde)" }}>
                <td className="p-3">{f.sede}</td><td className="p-3 font-medium">{f.nombre}</td><td className="p-3">{f.documento}</td>
                <td className="p-3">{f.cargo}</td><td className="p-3">{f.vinculacion}</td><td className="p-3">{f.certificados || "—"}</td>
              </tr>
            ))}
            {!filas.length && <tr><td colSpan={6} className="suave p-3">Sin personal vinculado.</td></tr>}
          </tbody>
        </table>
      </div>
    </section>
  );
}
