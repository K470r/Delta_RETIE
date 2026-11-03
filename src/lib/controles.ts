/**
 * Motor de controles de cumplimiento ISO/IEC 17020.
 *
 * Cada control se evalúa automáticamente a partir de los datos operativos
 * del OEC (personal, equipos, órdenes, quejas, documentos...). Así el
 * cumplimiento deja de ser una revisión manual previa a la auditoría y se
 * convierte en un indicador vivo.
 */
import { NOMBRE_ALCANCE, type DatosOEC, type Persona } from "./tipos";

export type EstadoControl = "cumple" | "alerta" | "incumple" | "no_aplica";

export type ResultadoControl = {
  estado: EstadoControl;
  resumen: string;
  hallazgos: string[];
};

export type Control = {
  id: string;
  numeral: string;
  titulo: string;
  evaluar: (d: DatosOEC, hoy: Date) => ResultadoControl;
};

const DIA = 86_400_000;

export function diasEntre(desde: string | Date, hasta: Date): number {
  return Math.floor((hasta.getTime() - new Date(desde).getTime()) / DIA);
}

function diasHasta(fecha: string, hoy: Date): number {
  return Math.floor((new Date(fecha).getTime() - hoy.getTime()) / DIA);
}

function resultado(
  hallazgos: string[],
  alertas: string[],
  okMsg: string,
): ResultadoControl {
  if (hallazgos.length)
    return { estado: "incumple", resumen: `${hallazgos.length} hallazgo(s)`, hallazgos: [...hallazgos, ...alertas] };
  if (alertas.length)
    return { estado: "alerta", resumen: `${alertas.length} por vencer`, hallazgos: alertas };
  return { estado: "cumple", resumen: okMsg, hallazgos: [] };
}

/** Evalúa una fecha de vencimiento: vencida → hallazgo, próxima → alerta. */
function revisarVencimiento(
  etiqueta: string,
  vence: string | undefined,
  hoy: Date,
  anticipacion: number,
  h: string[],
  a: string[],
) {
  if (!vence) return h.push(`${etiqueta}: sin registro`);
  const dias = diasHasta(vence, hoy);
  if (dias < 0) h.push(`${etiqueta}: vencido hace ${-dias} día(s) (${vence})`);
  else if (dias <= anticipacion) a.push(`${etiqueta}: vence en ${dias} día(s) (${vence})`);
}

/** Evalúa que un evento periódico se haya hecho dentro de su periodicidad. */
function revisarPeriodicidad(
  etiqueta: string,
  ultima: string | undefined,
  periodoDias: number,
  hoy: Date,
  anticipacion: number,
  h: string[],
  a: string[],
) {
  if (!ultima) return h.push(`${etiqueta}: nunca registrado`);
  const vence = new Date(new Date(ultima).getTime() + periodoDias * DIA).toISOString().slice(0, 10);
  revisarVencimiento(etiqueta, vence, hoy, anticipacion, h, a);
}

const ultimaFecha = (xs: { fecha: string }[]) =>
  xs.map((x) => x.fecha).sort().at(-1);

const personalActivo = (d: DatosOEC) => d.personas.filter((p) => p.activo);
const inspectores = (d: DatosOEC) =>
  personalActivo(d).filter((p) => p.roles.includes("inspector"));
const nombre = (d: DatosOEC, id?: string) =>
  d.personas.find((p) => p.id === id)?.nombre ?? "(sin asignar)";

const ORDENES_ACTIVAS = new Set(["asignada", "en_inspeccion", "en_revision"]);

export const CONTROLES: Control[] = [
  // ───────────── 4.1 Imparcialidad e independencia ─────────────
  {
    id: "C-4.1-01",
    numeral: "4.1",
    titulo: "Personal con declaración de imparcialidad vigente",
    evaluar: (d, hoy) => {
      const h: string[] = [], a: string[] = [];
      for (const p of personalActivo(d))
        revisarPeriodicidad(p.nombre, p.declaracionImparcialidad,
          d.config.plazos.vigenciaDeclaracionImparcialidad, hoy, d.config.plazos.alertaAnticipada, h, a);
      return resultado(h, a, "Todo el personal tiene declaración vigente");
    },
  },
  {
    id: "C-4.1-02",
    numeral: "4.1",
    titulo: "Análisis de riesgos a la imparcialidad actualizado",
    evaluar: (d, hoy) => {
      const h: string[] = [], a: string[] = [];
      revisarPeriodicidad("Análisis de riesgos", ultimaFecha(d.analisisRiesgosImparcialidad),
        d.config.plazos.analisisRiesgosImparcialidad, hoy, d.config.plazos.alertaAnticipada, h, a);
      return resultado(h, a, "Análisis vigente");
    },
  },
  {
    id: "C-4.1-03",
    numeral: "4.1",
    titulo: "Sin asignaciones con conflicto de interés declarado",
    evaluar: (d) => {
      const h = d.ordenes
        .filter((o) => o.estado !== "cancelada" && o.inspectorId)
        .filter((o) => d.personas.find((p) => p.id === o.inspectorId)?.conflictosConClientes.includes(o.clienteId))
        .map((o) => `${o.consecutivo}: ${nombre(d, o.inspectorId)} declaró conflicto con el cliente`);
      return resultado(h, [], "Ninguna asignación en conflicto");
    },
  },
  // ───────────── 4.2 Confidencialidad ─────────────
  {
    id: "C-4.2-01",
    numeral: "4.2",
    titulo: "Acuerdo de confidencialidad firmado por todo el personal",
    evaluar: (d) => {
      const h = personalActivo(d)
        .filter((p) => !p.acuerdoConfidencialidad)
        .map((p) => `${p.nombre}: sin acuerdo de confidencialidad`);
      return resultado(h, [], "Todo el personal firmó");
    },
  },
  // ───────────── 5.1 / 5.2 Estructura ─────────────
  {
    id: "C-5.1-01",
    numeral: "5.1",
    titulo: "Póliza de responsabilidad civil vigente",
    evaluar: (d, hoy) => {
      const h: string[] = [], a: string[] = [];
      revisarVencimiento("Póliza RC", d.config.polizaRCVence, hoy, d.config.plazos.alertaAnticipada, h, a);
      return resultado(h, a, `Vigente hasta ${d.config.polizaRCVence}`);
    },
  },
  {
    id: "C-5.2-01",
    numeral: "5.2",
    titulo: "Director técnico y suplente designados y activos",
    evaluar: (d) => {
      const h: string[] = [];
      const activo = (id?: string) => d.personas.some((p) => p.id === id && p.activo);
      if (!activo(d.config.directorTecnicoId)) h.push("Director técnico no designado o inactivo");
      if (!activo(d.config.directorTecnicoSuplenteId)) h.push("Suplente del director técnico no designado o inactivo");
      return resultado(h, [], "Designaciones vigentes");
    },
  },
  // ───────────── 6.1 Personal ─────────────
  {
    id: "C-6.1-01",
    numeral: "6.1",
    titulo: "Inspecciones asignadas solo dentro del alcance autorizado",
    evaluar: (d) => {
      const h = d.ordenes
        .filter((o) => o.estado !== "cancelada" && o.inspectorId)
        .filter((o) => !d.personas.find((p) => p.id === o.inspectorId)?.alcancesAutorizados.includes(o.alcance))
        .map((o) => `${o.consecutivo}: ${nombre(d, o.inspectorId)} sin autorización para ${NOMBRE_ALCANCE[o.alcance]}`);
      return resultado(h, [], "Todas las asignaciones dentro de alcance");
    },
  },
  {
    id: "C-6.1-02",
    numeral: "6.1",
    titulo: "Supervisión / monitoreo en sitio de cada inspector",
    evaluar: (d, hoy) => {
      const h: string[] = [], a: string[] = [];
      for (const p of inspectores(d))
        revisarPeriodicidad(p.nombre, p.ultimaSupervisionEnSitio,
          d.config.plazos.vigenciaSupervisionEnSitio, hoy, d.config.plazos.alertaAnticipada, h, a);
      return resultado(h, a, "Monitoreos al día");
    },
  },
  {
    id: "C-6.1-03",
    numeral: "6.1",
    titulo: "Matrícula profesional vigente de inspectores",
    evaluar: (d) => {
      const h = inspectores(d)
        .filter((p: Persona) => !p.matriculaProfesional?.numero)
        .map((p) => `${p.nombre}: sin matrícula profesional registrada`);
      return resultado(h, [], "Matrículas registradas");
    },
  },
  // ───────────── 6.2 Equipos ─────────────
  {
    id: "C-6.2-01",
    numeral: "6.2",
    titulo: "Equipos operativos con calibración vigente",
    evaluar: (d, hoy) => {
      const h: string[] = [], a: string[] = [];
      for (const e of d.equipos.filter((e) => e.estado === "operativo"))
        revisarVencimiento(`${e.codigo} ${e.nombre}`, e.vencimientoCalibracion, hoy, d.config.plazos.alertaAnticipada, h, a);
      return resultado(h, a, "Todos los equipos calibrados");
    },
  },
  {
    id: "C-6.2-02",
    numeral: "6.2",
    titulo: "Ninguna inspección con equipo de calibración vencida",
    evaluar: (d) => {
      const h: string[] = [];
      for (const o of d.ordenes.filter((o) => o.fechaInspeccion))
        for (const id of o.equiposUsados) {
          const e = d.equipos.find((x) => x.id === id);
          if (e && e.vencimientoCalibracion < o.fechaInspeccion!)
            h.push(`${o.consecutivo}: usó ${e.codigo} con calibración vencida el ${e.vencimientoCalibracion}`);
        }
      return resultado(h, [], "Sin uso de equipos vencidos");
    },
  },
  {
    id: "C-6.2-03",
    numeral: "6.2",
    titulo: "Verificaciones intermedias al día",
    evaluar: (d, hoy) => {
      const h: string[] = [], a: string[] = [];
      for (const e of d.equipos.filter((e) => e.estado === "operativo" && e.proximaVerificacionIntermedia))
        revisarVencimiento(`${e.codigo} verificación intermedia`, e.proximaVerificacionIntermedia, hoy, d.config.plazos.alertaAnticipada, h, a);
      return resultado(h, a, "Verificaciones al día");
    },
  },
  // ───────────── 6.3 Subcontratación ─────────────
  {
    id: "C-6.3-01",
    numeral: "6.3",
    titulo: "Subcontratistas con evaluación vigente",
    evaluar: (d, hoy) => {
      if (!d.subcontratistas.length) return { estado: "no_aplica", resumen: "No se subcontrata", hallazgos: [] };
      const h: string[] = [], a: string[] = [];
      for (const s of d.subcontratistas)
        revisarVencimiento(s.nombre, s.evaluacionVence, hoy, d.config.plazos.alertaAnticipada, h, a);
      return resultado(h, a, "Evaluaciones vigentes");
    },
  },
  // ───────────── 7.1 Métodos ─────────────
  {
    id: "C-7.1-01",
    numeral: "7.1",
    titulo: "Solicitudes revisadas antes de aceptar el servicio",
    evaluar: (d) => {
      const h = d.ordenes
        .filter((o) => !["cotizada", "cancelada"].includes(o.estado) && !o.solicitudRevisada)
        .map((o) => `${o.consecutivo}: aceptada sin revisión de la solicitud`);
      return resultado(h, [], "Todas las solicitudes revisadas");
    },
  },
  {
    id: "C-7.1-02",
    numeral: "7.1",
    titulo: "Inspecciones en curso con versión vigente del formato",
    evaluar: (d) => {
      const h = d.ordenes
        .filter((o) => ORDENES_ACTIVAS.has(o.estado))
        .filter((o) => d.config.formatosVigentes[o.formato.codigo] !== o.formato.version)
        .map((o) => `${o.consecutivo}: usa ${o.formato.codigo} v${o.formato.version} (vigente: v${d.config.formatosVigentes[o.formato.codigo] ?? "?"})`);
      return resultado(h, [], "Formatos vigentes");
    },
  },
  // ───────────── 7.3 Registros ─────────────
  {
    id: "C-7.3-01",
    numeral: "7.3",
    titulo: "Registros de inspección completos antes de revisión",
    evaluar: (d) => {
      const h: string[] = [];
      for (const o of d.ordenes.filter((o) => ["en_revision", "emitida", "entregada"].includes(o.estado))) {
        if (o.itemsEvaluados < o.itemsTotales)
          h.push(`${o.consecutivo}: ${o.itemsTotales - o.itemsEvaluados} ítem(s) sin evaluar`);
        if (o.ncSinEvidencia > 0)
          h.push(`${o.consecutivo}: ${o.ncSinEvidencia} no conformidad(es) sin evidencia`);
      }
      return resultado(h, [], "Registros completos");
    },
  },
  // ───────────── 7.4 Informes ─────────────
  {
    id: "C-7.4-01",
    numeral: "7.4",
    titulo: "Dictámenes revisados por persona distinta al inspector",
    evaluar: (d) => {
      const h = d.ordenes
        .filter((o) => ["emitida", "entregada"].includes(o.estado))
        .filter((o) => !o.revisorId || o.revisorId === o.inspectorId)
        .map((o) => `${o.consecutivo}: sin revisión independiente`);
      return resultado(h, [], "Revisión independiente en todos");
    },
  },
  {
    id: "C-7.4-02",
    numeral: "7.4",
    titulo: "Dictámenes emitidos dentro del plazo",
    evaluar: (d, hoy) => {
      const plazo = d.config.plazos.emisionDictamen;
      const h: string[] = [], a: string[] = [];
      for (const o of d.ordenes.filter((o) => o.fechaInspeccion && !["cancelada"].includes(o.estado))) {
        const fin = o.fechaEmision ? new Date(o.fechaEmision) : hoy;
        const dias = diasEntre(o.fechaInspeccion!, fin);
        if (dias > plazo) h.push(`${o.consecutivo}: ${dias} días desde la inspección (plazo ${plazo})`);
        else if (!o.fechaEmision && dias > plazo - 3) a.push(`${o.consecutivo}: lleva ${dias} de ${plazo} días`);
      }
      return resultado(h, a, "Emisión oportuna");
    },
  },
  // ───────────── 7.5 / 7.6 Quejas y apelaciones ─────────────
  {
    id: "C-7.6-01",
    numeral: "7.6",
    titulo: "Quejas y apelaciones con acuse y dentro de plazo",
    evaluar: (d, hoy) => {
      const { acuseQueja, resolucionQueja } = d.config.plazos;
      const h: string[] = [], a: string[] = [];
      for (const q of d.quejas.filter((q) => q.estado === "abierta")) {
        const dias = diasEntre(q.fechaRecepcion, hoy);
        if (!q.fechaAcuse && dias > acuseQueja) h.push(`${q.id}: sin acuse de recibo tras ${dias} días`);
        if (dias > resolucionQueja) h.push(`${q.id}: abierta hace ${dias} días (plazo ${resolucionQueja})`);
        else if (dias > resolucionQueja - d.config.plazos.alertaAnticipada) a.push(`${q.id}: abierta hace ${dias} días`);
      }
      return resultado(h, a, "Sin quejas fuera de plazo");
    },
  },
  {
    id: "C-7.6-02",
    numeral: "7.6",
    titulo: "Decisiones tomadas por personal no involucrado",
    evaluar: (d) => {
      const h = d.quejas
        .filter((q) => q.decisorId && q.involucradosIds.includes(q.decisorId))
        .map((q) => `${q.id}: decidida por ${nombre(d, q.decisorId)}, con participación previa en el caso`);
      return resultado(h, [], "Decisiones independientes");
    },
  },
  // ───────────── 8.3 Documentos ─────────────
  {
    id: "C-8.3-01",
    numeral: "8.3",
    titulo: "Documentos vigentes revisados dentro del periodo",
    evaluar: (d, hoy) => {
      const h: string[] = [], a: string[] = [];
      for (const doc of d.documentos.filter((x) => x.estado === "vigente"))
        revisarPeriodicidad(`${doc.codigo} v${doc.version}`, doc.fechaRevision,
          d.config.plazos.revisionDocumentos, hoy, d.config.plazos.alertaAnticipada, h, a);
      return resultado(h, a, `${d.documentos.filter((x) => x.estado === "vigente").length} documentos al día`);
    },
  },
  // ───────────── 8.5 / 8.6 Revisión y auditoría ─────────────
  {
    id: "C-8.5-01",
    numeral: "8.5",
    titulo: "Revisión por la dirección dentro del periodo",
    evaluar: (d, hoy) => {
      const h: string[] = [], a: string[] = [];
      revisarPeriodicidad("Revisión por la dirección", ultimaFecha(d.revisionesDireccion),
        d.config.plazos.revisionDireccion, hoy, d.config.plazos.alertaAnticipada, h, a);
      return resultado(h, a, `Última: ${ultimaFecha(d.revisionesDireccion)}`);
    },
  },
  {
    id: "C-8.6-01",
    numeral: "8.6",
    titulo: "Auditoría interna dentro del periodo",
    evaluar: (d, hoy) => {
      const h: string[] = [], a: string[] = [];
      revisarPeriodicidad("Auditoría interna", ultimaFecha(d.auditoriasInternas),
        d.config.plazos.auditoriaInterna, hoy, d.config.plazos.alertaAnticipada, h, a);
      return resultado(h, a, `Última: ${ultimaFecha(d.auditoriasInternas)}`);
    },
  },
  {
    id: "C-8.6-02",
    numeral: "8.6",
    titulo: "Programa de auditoría cubre todos los numerales",
    evaluar: (d, hoy) => {
      const ventana = d.config.plazos.auditoriaInterna;
      const cubiertos = new Set(
        d.auditoriasInternas.filter((x) => diasEntre(x.fecha, hoy) <= ventana).flatMap((x) => x.numeralesCubiertos),
      );
      const faltan = CONTROLES_NUMERALES.filter((n) => !cubiertos.has(n));
      return resultado(faltan.map((n) => `Numeral ${n} no auditado en el último ciclo`), [], "Cobertura completa");
    },
  },
  // ───────────── 8.7 Acciones correctivas ─────────────
  {
    id: "C-8.7-01",
    numeral: "8.7",
    titulo: "Acciones correctivas dentro de plazo y con eficacia verificada",
    evaluar: (d, hoy) => {
      const h: string[] = [], a: string[] = [];
      for (const ac of d.acciones) {
        if (ac.estado !== "cerrada") {
          const dias = diasHasta(ac.fechaLimite, hoy);
          if (dias < 0) h.push(`${ac.id}: vencida hace ${-dias} día(s)`);
          else if (dias <= d.config.plazos.alertaAnticipada) a.push(`${ac.id}: vence en ${dias} día(s)`);
        } else if (!ac.eficaciaVerificada) h.push(`${ac.id}: cerrada sin verificar eficacia`);
      }
      return resultado(h, a, "Acciones al día");
    },
  },
];

/** Numerales que el programa de auditoría interna debe cubrir. */
const CONTROLES_NUMERALES = [
  "4.1", "4.2", "5.1", "5.2", "6.1", "6.2", "6.3", "7.1", "7.2", "7.3", "7.4",
  "7.5", "7.6", "8.2", "8.3", "8.4", "8.5", "8.6", "8.7", "8.8",
];

export type EvaluacionNumeral = {
  numeral: string;
  estado: EstadoControl | "sin_controles";
  controles: (Control & { resultado: ResultadoControl })[];
};

const PESO: Record<EstadoControl, number> = { incumple: 3, alerta: 2, cumple: 1, no_aplica: 0 };

export function evaluarCumplimiento(d: DatosOEC, numerales: string[], hoy = new Date()): EvaluacionNumeral[] {
  return numerales.map((numeral) => {
    const controles = CONTROLES.filter((c) => c.numeral === numeral).map((c) => ({ ...c, resultado: c.evaluar(d, hoy) }));
    if (!controles.length) return { numeral, estado: "sin_controles", controles };
    const peor = controles.reduce<EstadoControl>(
      (acc, c) => (PESO[c.resultado.estado] > PESO[acc] ? c.resultado.estado : acc),
      "no_aplica",
    );
    return { numeral, estado: peor, controles };
  });
}
