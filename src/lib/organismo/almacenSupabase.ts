/**
 * Adaptador Supabase del almacén de organismos.
 * Lee todo lo que la seguridad por filas (RLS) le permite ver al usuario y,
 * al guardar, compara la base anterior con la nueva y envía solo los cambios,
 * en orden de dependencias. Si la base de datos rechaza algo (reglas 17020),
 * devuelve el mensaje en español y recarga para mostrar el estado real.
 */
import { supabase } from "../supabase";
import { mensajeError } from "../errores";
import type {
  BaseOrganismos, CertificadoCompetencia, Declaracion, Designacion, DocumentoOrganismo, DocumentoPersonal, Experiencia, Formacion,
  LineaAlcance, Organismo, Persona, RevisionSG, Sede, Vinculacion,
} from "./tipos";

type Fila = Record<string, unknown>;
const u = <T,>(v: T | null | undefined) => (v === null ? undefined : v) as T | undefined;
const n = (v: unknown) => (v === undefined || v === "" ? null : v);

// ───────────────────────── Lectura ─────────────────────────

export async function cargarBase(): Promise<BaseOrganismos> {
  const sb = supabase();
  const [org, sed, alc, per, cer, form, exp, vin, des, dec, rev] = await Promise.all([
    sb.from("organismos").select("*").order("creado"),
    sb.from("sedes").select("*"),
    sb.from("alcance_acreditado").select("*"),
    sb.from("personas").select("*").order("apellidos"),
    sb.from("certificados_competencia").select("*, certificado_categorias(categoria)"),
    sb.from("formacion").select("*").order("fecha"),
    sb.from("experiencias").select("*").order("desde"),
    sb.from("vinculaciones").select("*"),
    sb.from("designaciones").select("*, designacion_actividades(actividad_codigo)"),
    sb.from("declaraciones").select("*"),
    sb.from("revisiones_sg").select("*"),
  ]);
  const err = [org, sed, alc, per, cer, form, exp, vin, des, dec, rev].find((r) => r.error)?.error;
  if (err) throw err;
  // Documentos del organismo (0008): si la migración aún no está, se sigue sin ellos.
  const docs = await sb.from("documentos_organismo").select("*").order("cargado");
  const documentos: DocumentoOrganismo[] = (docs.error ? [] : docs.data ?? []).map((d: Fila) => ({
    id: d.id as string, organismoId: d.organismo_id as string, tipo: d.tipo as DocumentoOrganismo["tipo"],
    archivoRuta: d.archivo_ruta as string, numero: u(d.numero as string), emisor: u(d.emisor as string),
    valor: d.valor === null || d.valor === undefined ? undefined : Number(d.valor),
    fecha: u(d.fecha as string), renovacion: u(d.renovacion as string), actualizacion: u(d.actualizacion as string),
    desde: u(d.desde as string), hasta: u(d.hasta as string), firmadoPor: u(d.firmado_por as string),
    observacion: u(d.observacion as string), cargado: d.cargado as string, reemplazadoEn: u(d.reemplazado_en as string),
  }));

  // Documentos del personal con firma (0013): si la migración aún no está, se sigue sin ellos.
  const [dp, fd] = await Promise.all([
    sb.from("documentos_personal").select("*").order("creado_en"),
    sb.from("firmas_documento").select("*").order("firmado_en"),
  ]);
  const firmas = (fd.error ? [] : fd.data ?? []) as Fila[];
  const documentosPersonal: DocumentoPersonal[] = (dp.error ? [] : dp.data ?? []).map((d: Fila) => ({
    id: d.id as string, organismoId: d.organismo_id as string, designacionId: d.designacion_id as string,
    tipo: d.tipo as DocumentoPersonal["tipo"], titulo: d.titulo as string, contenido: d.contenido as string, huella: d.huella as string,
    actividades: (d.actividades ?? []) as string[], evaluadorId: u(d.evaluador_id as string), creadoEn: d.creado_en as string,
    reemplazadoEn: u(d.reemplazado_en as string), firmadoAManoRuta: u(d.firmado_a_mano_ruta as string),
    firmadoAManoPor: u(d.firmado_a_mano_por as string), firmadoAManoEn: u(d.firmado_a_mano_en as string),
    firmas: firmas.filter((f) => f.documento_id === d.id).map((f) => ({
      enCalidad: f.en_calidad as DocumentoPersonal["firmas"][number]["enCalidad"], personaId: f.persona_id as string,
      firmadoEn: f.firmado_en as string, correo: u(f.correo as string), autenticadoEn: u(f.autenticado_en as string),
      agente: u(f.agente as string), ip: u(f.ip as string), huella: f.huella as string,
    })),
  }));

  const sedes = (sed.data ?? []) as Fila[];
  const alcance = (alc.data ?? []) as Fila[];
  const organismos: Organismo[] = (org.data ?? []).map((o: Fila) => ({
    id: o.id as string,
    razonSocial: o.razon_social as string,
    sigla: u(o.sigla as string),
    nit: o.nit as string,
    tipo: "A",
    codigoAcreditacion: u(o.codigo_acreditacion as string),
    acreditacionOtorgada: u(o.acreditacion_otorgada as string),
    acreditacionRenovada: u(o.acreditacion_renovada as string),
    acreditacionActualizada: u(o.acreditacion_actualizada as string),
    acreditacionVence: u(o.acreditacion_vence as string),
    direccion: u(o.direccion as string),
    ciudad: u(o.ciudad as string),
    telefono: u(o.telefono as string),
    correo: u(o.correo as string),
    declaracionIndependencia: u(o.declaracion_independencia as string),
    polizaRCNumero: u(o.poliza_rc_numero as string),
    polizaRCVence: u(o.poliza_rc_vence as string),
    creado: o.creado as string,
    creadoPor: u(o.creado_por as string),
    logoRuta: u(o.logo_ruta as string),
    simboloOnacRuta: u(o.simbolo_onac_ruta as string),
    sedes: sedes.filter((s) => s.organismo_id === o.id).map((s): Sede => ({
      id: s.id as string, nombre: s.nombre as string, direccion: u(s.direccion as string), ciudad: u(s.ciudad as string), principal: !!s.principal,
    })),
    alcance: alcance.filter((a) => a.organismo_id === o.id).map((a): LineaAlcance => ({
      actividad: a.actividad_codigo as string, estado: a.estado as LineaAlcance["estado"],
      fechaEstado: a.fecha_estado as string, observacion: u(a.observacion as string),
      estadoPor: u(a.estado_por as string), estadoEnCalidad: u(a.estado_en_calidad as string),
    })),
  }));

  const certs = (cer.data ?? []) as Fila[];
  const forms = (form.data ?? []) as Fila[];
  const exps = (exp.data ?? []) as Fila[];
  const personas: Persona[] = (per.data ?? []).map((p: Fila) => ({
    id: p.id as string,
    usuarioId: u(p.usuario_id as string),
    tipoDocumento: p.tipo_documento as Persona["tipoDocumento"],
    documento: p.documento as string,
    nombres: p.nombres as string,
    apellidos: p.apellidos as string,
    correo: u(p.correo as string),
    telefono: u(p.telefono as string),
    profesion: u(p.profesion as string),
    matriculaNumero: u(p.matricula_numero as string),
    matriculaEntidad: u(p.matricula_entidad as string),
    matriculaEspecialidad: u(p.matricula_especialidad as string),
    matriculaAceptadaPor: u(p.matricula_aceptada_por as string),
    matriculaAceptadaEn: u(p.matricula_aceptada_en as string),
    matriculaAceptadaMotivo: u(p.matricula_aceptada_motivo as string),
    creado: p.creado as string,
    certificados: certs.filter((c) => c.persona_id === p.id).map((c): CertificadoCompetencia => ({
      id: c.id as string,
      numero: c.numero as string,
      certificador: c.certificador as string,
      reglamento: c.reglamento_id as string,
      categorias: ((c.certificado_categorias ?? []) as Fila[]).map((k) => k.categoria as string).sort(),
      fechaEmision: c.fecha_emision as string,
      fechaVencimiento: c.fecha_vencimiento as string,
      seguimiento: c.seguimiento_fecha ? {
        fecha: c.seguimiento_fecha as string,
        resultado: c.seguimiento_resultado as "conforme" | "no_conforme",
        observacion: u(c.seguimiento_observacion as string),
        registradoEn: u(c.seguimiento_registrado_en as string),
      } : undefined,
      anulado: !!c.anulado,
      soporteRuta: u(c.soporte_ruta as string),
      verificada: !!c.verificada,
      verificadaPor: u(c.verificada_por as string),
      verificadaEn: u(c.verificada_en as string),
    })),
    formacion: forms.filter((f) => f.persona_id === p.id).map((f): Formacion => ({
      id: f.id as string,
      tipo: f.tipo as Formacion["tipo"],
      titulo: f.titulo as string,
      institucion: f.institucion as string,
      fecha: f.fecha as string,
      enIluminacion: !!f.en_iluminacion,
      areasIluminacion: (f.areas_iluminacion ?? []) as string[],
      verificada: !!f.verificada,
      verificadaPor: u(f.verificada_por as string),
      verificadaEn: u(f.verificada_en as string),
      soporteRuta: u(f.soporte_ruta as string),
    })),
    experiencias: exps.filter((e) => e.persona_id === p.id).map((e): Experiencia => ({
      id: e.id as string,
      empresa: e.empresa as string,
      cargo: e.cargo as string,
      desde: e.desde as string,
      hasta: u(e.hasta as string),
      reglamento: e.reglamento_id as string,
      categorias: (e.categorias ?? []) as string[],
      tipos: (e.tipos ?? []) as string[],
      descripcion: u(e.descripcion as string),
      verificada: !!e.verificada,
      verificadaPor: u(e.verificada_por as string),
      verificadaEn: u(e.verificada_en as string),
      soporteRuta: u(e.soporte_ruta as string),
    })),
  }));

  return {
    organismos,
    personas,
    documentos,
    documentosPersonal,
    vinculaciones: (vin.data ?? []).map((v: Fila): Vinculacion => ({
      id: v.id as string, organismoId: v.organismo_id as string, personaId: v.persona_id as string,
      sedeId: u(v.sede_id as string), tipo: v.tipo as Vinculacion["tipo"], cargo: v.cargo as string,
      desde: v.desde as string, hasta: u(v.hasta as string),
    })),
    designaciones: (des.data ?? []).map((d: Fila): Designacion => ({
      id: d.id as string, organismoId: d.organismo_id as string, personaId: d.persona_id as string,
      rol: d.rol as Designacion["rol"], desde: d.desde as string, hasta: u(d.hasta as string), acto: u(d.acto as string),
      actividades: ((d.designacion_actividades ?? []) as Fila[]).map((a) => a.actividad_codigo as string).sort(),
    })),
    declaraciones: (dec.data ?? []).map((d: Fila): Declaracion => ({
      id: d.id as string, organismoId: d.organismo_id as string, personaId: d.persona_id as string,
      tipo: d.tipo as Declaracion["tipo"], fecha: d.fecha as string,
    })),
    revisionesSG: (rev.data ?? []).map((r: Fila): RevisionSG => ({
      id: r.id as string, organismoId: r.organismo_id as string, personaId: r.persona_id as string, fecha: r.fecha as string,
      aspectos: (r.aspectos ?? []) as string[], observaciones: (r.observaciones ?? "") as string, requiereAccion: !!r.requiere_accion,
    })),
  };
}

// ───────────────────────── Escritura ─────────────────────────

const filaOrganismo = (o: Organismo): Fila => ({
  id: o.id, razon_social: o.razonSocial, sigla: n(o.sigla), nit: o.nit.trim(), tipo: o.tipo,
  codigo_acreditacion: n(o.codigoAcreditacion), acreditacion_otorgada: n(o.acreditacionOtorgada), acreditacion_vence: n(o.acreditacionVence),
  ...(o.acreditacionRenovada !== undefined ? { acreditacion_renovada: o.acreditacionRenovada } : {}),
  ...(o.acreditacionActualizada !== undefined ? { acreditacion_actualizada: o.acreditacionActualizada } : {}),
  direccion: n(o.direccion), ciudad: n(o.ciudad), telefono: n(o.telefono), correo: n(o.correo),
  declaracion_independencia: n(o.declaracionIndependencia), poliza_rc_numero: n(o.polizaRCNumero), poliza_rc_vence: n(o.polizaRCVence),
  logo_ruta: n(o.logoRuta), simbolo_onac_ruta: n(o.simboloOnacRuta),
});
const filaSede = (org: string, s: Sede): Fila => ({
  id: s.id, organismo_id: org, nombre: s.nombre, direccion: n(s.direccion), ciudad: n(s.ciudad), principal: s.principal,
});
const filaAlcance = (org: string, l: LineaAlcance): Fila => ({
  organismo_id: org, actividad_codigo: l.actividad, estado: l.estado, fecha_estado: l.fechaEstado, observacion: n(l.observacion),
});
const filaPersona = (p: Persona): Fila => ({
  id: p.id, tipo_documento: p.tipoDocumento, documento: p.documento.trim(), nombres: p.nombres.trim(), apellidos: p.apellidos.trim(),
  correo: n(p.correo?.trim().toLowerCase()), telefono: n(p.telefono), profesion: n(p.profesion),
  matricula_numero: n(p.matriculaNumero?.trim()), matricula_entidad: n(p.matriculaEntidad), matricula_especialidad: n(p.matriculaEspecialidad),
});
const filaCertificado = (persona: string, c: CertificadoCompetencia): Fila => ({
  id: c.id, persona_id: persona, reglamento_id: c.reglamento, numero: c.numero, certificador: c.certificador,
  fecha_emision: c.fechaEmision, fecha_vencimiento: c.fechaVencimiento,
  seguimiento_fecha: n(c.seguimiento?.fecha), seguimiento_resultado: n(c.seguimiento?.resultado),
  seguimiento_observacion: n(c.seguimiento?.observacion), anulado: c.anulado, soporte_ruta: n(c.soporteRuta),
  verificada: !!c.verificada, verificada_por: c.verificada ? n(c.verificadaPor) : null,
});
const filaFormacion = (persona: string, f: Formacion): Fila => ({
  id: f.id, persona_id: persona, tipo: f.tipo, titulo: f.titulo, institucion: f.institucion, fecha: f.fecha,
  en_iluminacion: f.enIluminacion, areas_iluminacion: f.areasIluminacion, verificada: f.verificada,
  verificada_por: f.verificada ? n(f.verificadaPor) : null, soporte_ruta: n(f.soporteRuta),
});
const filaExperiencia = (persona: string, e: Experiencia): Fila => ({
  id: e.id, persona_id: persona, empresa: e.empresa, cargo: e.cargo, desde: e.desde, hasta: n(e.hasta),
  reglamento_id: e.reglamento, categorias: e.categorias, tipos: e.tipos, descripcion: n(e.descripcion),
  verificada: e.verificada, verificada_por: e.verificada ? n(e.verificadaPor) : null, soporte_ruta: n(e.soporteRuta),
});
const filaVinculacion = (v: Vinculacion): Fila => ({
  id: v.id, organismo_id: v.organismoId, persona_id: v.personaId, sede_id: n(v.sedeId), tipo: v.tipo, cargo: v.cargo, desde: v.desde, hasta: n(v.hasta),
});
const filaDesignacion = (d: Designacion): Fila => ({
  id: d.id, organismo_id: d.organismoId, persona_id: d.personaId, rol: d.rol, desde: d.desde, hasta: n(d.hasta), acto: n(d.acto),
});
const filaDeclaracion = (d: Declaracion): Fila => ({
  id: d.id, organismo_id: d.organismoId, persona_id: d.personaId, tipo: d.tipo, fecha: d.fecha,
});
const filaDocumento = (d: DocumentoOrganismo): Fila => ({
  id: d.id, organismo_id: d.organismoId, tipo: d.tipo, archivo_ruta: d.archivoRuta, numero: n(d.numero), emisor: n(d.emisor),
  valor: d.valor ?? null, fecha: n(d.fecha), renovacion: n(d.renovacion), actualizacion: n(d.actualizacion),
  desde: n(d.desde), hasta: n(d.hasta), firmado_por: n(d.firmadoPor), observacion: n(d.observacion),
});
// Solo lo que escribe el usuario: tipo, huella, actividades y fechas los pone la base de datos.
const filaDocumentoPersonal = (d: DocumentoPersonal): Fila => ({
  id: d.id, organismo_id: d.organismoId, designacion_id: d.designacionId, tipo: d.tipo, titulo: d.titulo,
  contenido: d.contenido, evaluador_id: n(d.evaluadorId),
});
const filaRevision = (r: RevisionSG): Fila => ({
  id: r.id, organismo_id: r.organismoId, persona_id: r.personaId, fecha: r.fecha, aspectos: r.aspectos,
  observaciones: n(r.observaciones), requiere_accion: r.requiereAccion,
});

type Operacion =
  | { tipo: "insertar"; tabla: string; fila: Fila }
  | { tipo: "modificar"; tabla: string; clave: Fila; cambios: Fila }
  | { tipo: "eliminar"; tabla: string; clave: Fila };

/** Columnas que cambiaron entre dos filas. */
function cambios(antes: Fila, despues: Fila): Fila | null {
  const c: Fila = {};
  for (const k of Object.keys(despues)) {
    if (JSON.stringify(antes[k] ?? null) !== JSON.stringify(despues[k] ?? null)) c[k] = despues[k];
  }
  return Object.keys(c).length ? c : null;
}

/** Compara dos colecciones por clave y produce inserciones y modificaciones (nada se borra). */
function comparar<T>(tabla: string, antes: T[], despues: T[], fila: (x: T) => Fila, claveDe: (f: Fila) => Fila): Operacion[] {
  const id = (f: Fila) => JSON.stringify(claveDe(f));
  const previas = new Map(antes.map((x) => { const f = fila(x); return [id(f), f]; }));
  const ops: Operacion[] = [];
  for (const x of despues) {
    const f = fila(x);
    const prev = previas.get(id(f));
    // Al insertar se omiten los campos vacíos: la base pone sus valores por defecto.
    if (!prev) ops.push({ tipo: "insertar", tabla, fila: Object.fromEntries(Object.entries(f).filter(([, v]) => v !== null)) });
    else {
      const c = cambios(prev, f);
      if (c) ops.push({ tipo: "modificar", tabla, clave: claveDe(f), cambios: c });
    }
  }
  return ops;
}

/** Relaciones (categorías de certificado, actividades autorizadas): se agregan y se quitan. */
function compararRelacion(tabla: string, antes: Fila[], despues: Fila[]): Operacion[] {
  const k = (f: Fila) => JSON.stringify(f);
  const a = new Set(antes.map(k));
  const d = new Set(despues.map(k));
  return [
    ...despues.filter((f) => !a.has(k(f))).map((fila): Operacion => ({ tipo: "insertar", tabla, fila })),
    ...antes.filter((f) => !d.has(k(f))).map((clave): Operacion => ({ tipo: "eliminar", tabla, clave })),
  ];
}

const porId = (f: Fila) => ({ id: f.id });

export function operaciones(a: BaseOrganismos, d: BaseOrganismos): Operacion[] {
  const sedes = (b: BaseOrganismos) => b.organismos.flatMap((o) => o.sedes.map((s) => filaSede(o.id, s)));
  const alcance = (b: BaseOrganismos) => b.organismos.flatMap((o) => o.alcance.map((l) => filaAlcance(o.id, l)));
  const certs = (b: BaseOrganismos) => b.personas.flatMap((p) => p.certificados.map((c) => filaCertificado(p.id, c)));
  const cats = (b: BaseOrganismos) => b.personas.flatMap((p) => p.certificados.flatMap((c) =>
    c.categorias.map((categoria) => ({ certificado_id: c.id, reglamento_id: c.reglamento, categoria }))));
  const forms = (b: BaseOrganismos) => b.personas.flatMap((p) => p.formacion.map((f) => filaFormacion(p.id, f)));
  const exps = (b: BaseOrganismos) => b.personas.flatMap((p) => p.experiencias.map((e) => filaExperiencia(p.id, e)));
  const acts = (b: BaseOrganismos) => b.designaciones.flatMap((x) => x.actividades.map((actividad_codigo) => ({ designacion_id: x.id, actividad_codigo })));
  const ident = (f: Fila) => f;

  return [
    ...comparar("organismos", a.organismos, d.organismos, filaOrganismo, porId),
    ...comparar("sedes", sedes(a), sedes(d), ident, porId),
    ...comparar("alcance_acreditado", alcance(a), alcance(d), ident, (f) => ({ organismo_id: f.organismo_id, actividad_codigo: f.actividad_codigo })),
    ...comparar("personas", a.personas, d.personas, filaPersona, porId),
    ...comparar("certificados_competencia", certs(a), certs(d), ident, porId),
    ...compararRelacion("certificado_categorias", cats(a), cats(d)),
    ...comparar("formacion", forms(a), forms(d), ident, porId),
    ...comparar("experiencias", exps(a), exps(d), ident, porId),
    ...comparar("vinculaciones", a.vinculaciones, d.vinculaciones, filaVinculacion, porId),
    ...comparar("designaciones", a.designaciones, d.designaciones, filaDesignacion, porId),
    ...compararRelacion("designacion_actividades", acts(a), acts(d)),
    ...comparar("declaraciones", a.declaraciones, d.declaraciones, filaDeclaracion, porId),
    ...comparar("revisiones_sg", a.revisionesSG, d.revisionesSG, filaRevision, porId),
    // Documentos: solo se agregan versiones nuevas (la base reemplaza la anterior y actualiza el organismo).
    ...comparar("documentos_organismo", (a.documentos ?? []).filter((x) => d.documentos?.some((y) => y.id === x.id)),
      d.documentos ?? [], filaDocumento, porId).filter((op) => op.tipo === "insertar"),
    // Documentos del personal: solo se generan (las firmas van por firmar_documento()).
    ...comparar("documentos_personal", (a.documentosPersonal ?? []).filter((x) => d.documentosPersonal?.some((y) => y.id === x.id)),
      d.documentosPersonal ?? [], filaDocumentoPersonal, porId).filter((op) => op.tipo === "insertar"),
  ];
}

/** Envía los cambios en orden. Devuelve el mensaje de error (en español) o null. */
export async function guardarCambios(a: BaseOrganismos, d: BaseOrganismos): Promise<string | null> {
  const sb = supabase();
  for (const op of operaciones(a, d)) {
    const t = sb.from(op.tabla);
    const { error, count } =
      op.tipo === "insertar" ? await t.insert(op.fila)
      : op.tipo === "modificar" ? await t.update(op.cambios, { count: "exact" }).match(op.clave)
      : await t.delete({ count: "exact" }).match(op.clave);
    if (error) return mensajeError(error);
    // La seguridad por filas no da error al modificar: simplemente no toca nada.
    if (op.tipo !== "insertar" && count === 0) return mensajeError({ code: "42501", message: `table "${op.tabla}"` });
  }
  return null;
}
