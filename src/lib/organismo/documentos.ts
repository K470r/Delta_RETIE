/**
 * Documentos de designación y autorización del personal (0013): qué documento lleva cada
 * rol, quién lo firma, su estado y el texto del modelo (provisional, hasta adecuarlo a los
 * formatos del organismo). Las mismas reglas las aplica la base de datos.
 */
import { actividad } from "../catalogo";
import { categoriaDeActividad, etiquetaCategoria } from "../requisitos";
import { entidadMatricula } from "./matricula";
import type {
  BaseOrganismos, CalidadFirma, Designacion, DocumentoPersonal, Organismo, Persona, RolOEC, TipoDocumentoPersonal,
} from "./tipos";

const vigente = (d: { desde: string; hasta?: string }, fecha: string) => d.desde <= fecha && (!d.hasta || d.hasta >= fecha);
const hoy = () => new Date().toLocaleDateString("en-CA", { timeZone: "America/Bogota" });
const nombre = (p?: Persona) => (p ? `${p.nombres} ${p.apellidos}` : "(desconocida)");

export const TIPO_DE_ROL: Partial<Record<RolOEC, TipoDocumentoPersonal>> = {
  gerente: "designacion_gerente",
  responsable_sg: "designacion_responsable_sg",
  director_tecnico: "autorizacion_director_tecnico",
  director_tecnico_suplente: "autorizacion_director_tecnico_suplente",
  inspector: "autorizacion_inspector",
  asistente_direccion_tecnica: "designacion_asistente_direccion_tecnica",
};

export const NOMBRE_TIPO: Record<TipoDocumentoPersonal, string> = {
  designacion_gerente: "Documento de designación de gerente",
  designacion_responsable_sg: "Documento de designación de responsable del sistema de gestión",
  autorizacion_director_tecnico: "Autorización del director técnico",
  autorizacion_director_tecnico_suplente: "Autorización del director técnico suplente",
  autorizacion_inspector: "Autorización de inspector",
  designacion_asistente_direccion_tecnica: "Documento de designación de asistente de dirección técnica",
};

export const FIRMAS_REQUERIDAS: Record<TipoDocumentoPersonal, CalidadFirma[]> = {
  designacion_gerente: ["designado"],
  designacion_responsable_sg: ["gerente"],
  autorizacion_director_tecnico: ["gerente"],
  autorizacion_director_tecnico_suplente: ["gerente", "director_tecnico"],
  autorizacion_inspector: ["gerente", "evaluador"],
  designacion_asistente_direccion_tecnica: ["gerente"],
};

export const NOMBRE_CALIDAD: Record<CalidadFirma, string> = {
  designado: "Gerente designado",
  gerente: "Gerente",
  director_tecnico: "Director técnico principal",
  evaluador: "Director técnico que evaluó",
};

export const esAutorizacion = (t: TipoDocumentoPersonal) => t.startsWith("autorizacion_");

export function documentosDe(b: BaseOrganismos, designacionId: string): DocumentoPersonal[] {
  return (b.documentosPersonal ?? []).filter((x) => x.designacionId === designacionId).sort((x, y) => y.creadoEn.localeCompare(x.creadoEn));
}

export const firmasFaltantes = (doc: DocumentoPersonal): CalidadFirma[] =>
  doc.firmadoAManoRuta ? [] : FIRMAS_REQUERIDAS[doc.tipo].filter((c) => !doc.firmas.some((f) => f.enCalidad === c));
export const documentoFirmado = (doc: DocumentoPersonal) => firmasFaltantes(doc).length === 0;

/** ¿La designación tiene su documento firmado? (los roles que no llevan documento, siempre sí) */
export function designacionFirmada(b: BaseOrganismos, d: Designacion): boolean {
  return !TIPO_DE_ROL[d.rol] || documentosDe(b, d.id).some(documentoFirmado);
}

export type EstadoDocumentacion = {
  requiere: boolean;
  firmado: boolean;
  /** Documento pendiente de firma (el más reciente sin reemplazar). */
  pendiente?: DocumentoPersonal;
  /** Firmas que le faltan al pendiente (nombres). */
  faltan: string[];
  /** Actividades autorizadas que no están en ningún documento firmado. */
  sinFirmar: string[];
};

export function estadoDocumentacion(b: BaseOrganismos, d: Designacion): EstadoDocumentacion {
  const tipo = TIPO_DE_ROL[d.rol];
  if (!tipo) return { requiere: false, firmado: true, faltan: [], sinFirmar: [] };
  const docs = documentosDe(b, d.id);
  const firmados = docs.filter(documentoFirmado);
  const pendiente = docs.find((x) => !x.reemplazadoEn && !documentoFirmado(x));
  return {
    requiere: true,
    firmado: firmados.length > 0,
    pendiente,
    faltan: pendiente ? firmasFaltantes(pendiente).map((c) => NOMBRE_CALIDAD[c]) : [],
    sinFirmar: esAutorizacion(tipo) ? d.actividades.filter((a) => !firmados.some((x) => x.actividades.includes(a))) : [],
  };
}

/** Designación vigente y firmada de la persona con uno de los roles. */
function tieneRolFirmado(b: BaseOrganismos, organismoId: string, personaId: string, roles: RolOEC[], fecha: string) {
  return b.designaciones.some((x) => x.organismoId === organismoId && x.personaId === personaId && roles.includes(x.rol)
    && vigente(x, fecha) && designacionFirmada(b, x));
}

/** En qué calidad puede firmar la persona este documento ahora (lo mismo que exige la base de datos). */
export function puedeFirmarComo(b: BaseOrganismos, doc: DocumentoPersonal, personaId: string | undefined, fecha = hoy()): CalidadFirma[] {
  if (!personaId || doc.reemplazadoEn || documentoFirmado(doc)) return [];
  const d = b.designaciones.find((x) => x.id === doc.designacionId);
  if (!d) return [];
  return firmasFaltantes(doc).filter((c) => {
    if (c === "designado") return personaId === d.personaId;
    if (c === "gerente") return tieneRolFirmado(b, doc.organismoId, personaId, ["gerente"], fecha);
    if (c === "director_tecnico") return personaId !== d.personaId && tieneRolFirmado(b, doc.organismoId, personaId, ["director_tecnico"], fecha);
    return personaId === doc.evaluadorId && tieneRolFirmado(b, doc.organismoId, personaId, ["director_tecnico", "director_tecnico_suplente"], fecha);
  });
}

/** Documentos que la persona puede firmar ahora (para el aviso de Inicio). */
export function pendientesDeFirma(b: BaseOrganismos, personaId: string | undefined) {
  if (!personaId) return [];
  return (b.documentosPersonal ?? [])
    .map((doc) => ({ doc, calidades: puedeFirmarComo(b, doc, personaId) }))
    .filter((x) => x.calidades.length > 0);
}

/** Directores técnicos (principal o suplente) que pueden figurar como evaluadores de un inspector. */
export function evaluadoresPosibles(b: BaseOrganismos, d: Designacion, fecha = hoy()): Persona[] {
  const ids = new Set(b.designaciones
    .filter((x) => x.organismoId === d.organismoId && ["director_tecnico", "director_tecnico_suplente"].includes(x.rol) && vigente(x, fecha) && x.personaId !== d.personaId)
    .map((x) => x.personaId));
  return b.personas.filter((p) => ids.has(p.id));
}

/** Huella SHA-256 (hexadecimal) del texto, igual a la que calcula la base de datos. */
export async function huella(texto: string): Promise<string> {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(texto));
  return [...new Uint8Array(bytes)].map((x) => x.toString(16).padStart(2, "0")).join("");
}

// ───────────────────────── Modelos de texto (provisionales) ─────────────────────────

const fechaLarga = (iso: string) =>
  new Date(iso + "T12:00:00Z").toLocaleDateString("es-CO", { day: "numeric", month: "long", year: "numeric", timeZone: "America/Bogota" });

function encabezado(o: Organismo) {
  const sede = o.sedes.find((s) => s.principal);
  return [
    `${o.razonSocial.toUpperCase()}${o.sigla ? ` (${o.sigla})` : ""}`,
    `NIT ${o.nit}${o.direccion ? ` · ${o.direccion}` : ""}${o.ciudad || sede?.ciudad ? ` · ${o.ciudad ?? sede?.ciudad}` : ""}`,
    `Organismo de inspección tipo A${o.codigoAcreditacion ? `, acreditado por ONAC con el código ${o.codigoAcreditacion},` : ""} conforme a la norma ISO/IEC 17020:2012.`,
  ].join("\n");
}

const identificacion = (p: Persona) => `${nombre(p)}, con documento de identidad ${p.tipoDocumento} ${p.documento}`;
const matricula = (p: Persona) =>
  p.matriculaNumero ? `, matrícula profesional ${p.matriculaNumero}${p.matriculaEntidad ? ` (${entidadMatricula(p.matriculaEntidad)})` : ""}` : "";

function listaActividades(acts: string[]) {
  return acts.map((c) => {
    const m = categoriaDeActividad(c);
    return `  • ${actividad(c)?.nombre ?? c}${m ? ` — categoría ${etiquetaCategoria(m.req.reglamento, m.cat.codigo)}` : ""}`;
  }).join("\n");
}

export type BorradorDocumento = { titulo: string; contenido: string };

/** Genera el título y el texto del documento con los datos de la designación. */
export function generarDocumento(b: BaseOrganismos, d: Designacion, evaluadorId?: string, fecha = hoy()): BorradorDocumento | null {
  const tipo = TIPO_DE_ROL[d.rol];
  const o = b.organismos.find((x) => x.id === d.organismoId);
  const p = b.personas.find((x) => x.id === d.personaId);
  if (!tipo || !o || !p) return null;
  const titulo = NOMBRE_TIPO[tipo].toUpperCase();
  const ciudad = o.ciudad ?? o.sedes.find((s) => s.principal)?.ciudad ?? "";
  const acto = d.acto ? `\nActo interno: ${d.acto}.` : "";
  const parrafos: string[] = [];

  if (tipo === "designacion_gerente") {
    parrafos.push(
      `Se deja constancia de la designación de ${identificacion(p)}, como GERENTE del organismo, a partir del ${fechaLarga(d.desde)}.`,
      `Designación hecha por: ${d.acto ? d.acto : "autodesignación"}.`,
      "Como gerente, tiene la responsabilidad general del organismo de inspección (ISO/IEC 17020 §5.2.1): asegurar los recursos, la imparcialidad (§4.1) y la confidencialidad (§4.2), designar y autorizar al personal y responder por el cumplimiento de los requisitos de acreditación.",
      "Con su firma, acepta la designación y declara conocer el sistema de gestión del organismo.",
    );
  } else if (tipo === "designacion_responsable_sg") {
    parrafos.push(
      `La gerencia designa a ${identificacion(p)}, como RESPONSABLE DEL SISTEMA DE GESTIÓN, a partir del ${fechaLarga(d.desde)}.${acto}`,
      "Tiene la autoridad y la responsabilidad de asegurar que el sistema de gestión se implemente, se mantenga y se mejore (ISO/IEC 17020 §8, opción A), e informar a la gerencia sobre su desempeño y las necesidades de mejora.",
    );
  } else if (tipo === "designacion_asistente_direccion_tecnica") {
    parrafos.push(
      `La gerencia designa a ${identificacion(p)}, como ASISTENTE DE DIRECCIÓN TÉCNICA, a partir del ${fechaLarga(d.desde)}.${acto}`,
      [
        "Funciones:",
        "  • Pedir las evidencias de las inspecciones y revisar que estén completas antes de pasarlas al director técnico.",
        "  • Hacer seguimiento a que las inspecciones se realicen.",
        "  • Atender a los inspectores cuando les falte un formato, un procedimiento o una indicación de dónde encontrar algo en el sistema o en los procedimientos.",
        "  • Realizar el control metrológico de los equipos; los documentos, tablas y decisiones los aprueba un director técnico.",
        "  • Acompañar a los inspectores como personal de apoyo en la inspección, cuando se requiera.",
      ].join("\n"),
      "No firma dictámenes ni decide sobre la conformidad de las instalaciones.",
    );
  } else {
    const rol = tipo === "autorizacion_inspector" ? "INSPECTOR" : tipo === "autorizacion_director_tecnico" ? "DIRECTOR TÉCNICO" : "DIRECTOR TÉCNICO SUPLENTE";
    const quien = tipo === "autorizacion_inspector" ? "La gerencia y la dirección técnica autorizan" : "La gerencia autoriza";
    parrafos.push(
      `${quien} a ${identificacion(p)}${matricula(p)}, como ${rol}, a partir del ${fechaLarga(d.desde)}, para las siguientes actividades del alcance acreditado (ISO/IEC 17020 §6.1.6):${acto}`,
      listaActividades(d.actividades),
    );
    const certs = p.certificados.filter((c) => !c.anulado && c.fechaVencimiento >= fecha);
    if (certs.length)
      parrafos.push(`Certificados de competencias: ${certs.map((c) => `N.° ${c.numero} (${c.certificador}, categorías ${c.categorias.join(", ")}, vence ${c.fechaVencimiento})`).join("; ")}.`);
    if (tipo === "autorizacion_inspector") {
      const ev = b.personas.find((x) => x.id === evaluadorId);
      parrafos.push(
        `La competencia fue evaluada por ${nombre(ev)}, director técnico del organismo, con base en la formación, la experiencia verificada y los certificados de competencias del inspector.`,
        "El inspector realiza las inspecciones según los procedimientos del organismo, con imparcialidad y confidencialidad, y solo en las actividades aquí autorizadas.",
      );
    } else {
      parrafos.push("Responde técnicamente por las actividades de inspección autorizadas (ISO/IEC 17020 §5.2.5): revisión técnica y firma de dictámenes, evaluación y supervisión del personal de inspección, y aprobación de los documentos técnicos y del control metrológico.");
      if (tipo === "autorizacion_director_tecnico_suplente") {
        const principal = b.designaciones.find((x) => x.organismoId === o.id && x.rol === "director_tecnico" && vigente(x, fecha));
        parrafos.push(`Reemplaza al director técnico principal${principal ? `, ${nombre(b.personas.find((x) => x.id === principal.personaId))},` : ""} en sus ausencias (ISO/IEC 17020 §5.2.6).`);
      }
    }
  }

  const contenido = [encabezado(o), "", titulo, "", `${ciudad ? `${ciudad}, ` : ""}${fechaLarga(fecha)}`, "", ...parrafos.flatMap((x) => [x, ""])].join("\n").trimEnd();
  return { titulo: NOMBRE_TIPO[tipo], contenido };
}
