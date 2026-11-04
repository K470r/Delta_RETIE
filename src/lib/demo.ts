/**
 * Datos de demostración. Las fechas son relativas al día actual para que el
 * tablero siempre muestre una mezcla realista de "cumple", "alerta" e
 * "incumple". Se reemplazan por Supabase cuando se configuran las variables
 * de entorno.
 */
import type { DatosOEC } from "./tipos";

const DIA = 86_400_000;
const f = (dias: number) => new Date(Date.now() + dias * DIA).toISOString().slice(0, 10);

export function datosDemo(): DatosOEC {
  return {
    config: {
      nombre: "Delta RETIE — OEC (demostración)",
      tipoOrganismo: "A",
      polizaRCVence: f(200),
      directorTecnicoId: "p-dt",
      directorTecnicoSuplenteId: "p-insp1",
      formatosVigentes: { "F-229-D": "1.0" },
      plazos: {
        vigenciaDeclaracionImparcialidad: 365,
        vigenciaSupervisionEnSitio: 365,
        revisionDocumentos: 365,
        auditoriaInterna: 365,
        revisionDireccion: 365,
        analisisRiesgosImparcialidad: 365,
        acuseQueja: 5,
        resolucionQueja: 30,
        emisionDictamen: 15,
        alertaAnticipada: 30,
      },
    },
    personas: [
      {
        id: "p-dt", nombre: "Director Técnico", roles: ["director_tecnico", "revisor"],
        matriculaProfesional: { numero: "CN-000001" },
        declaracionImparcialidad: f(-100), acuerdoConfidencialidad: f(-700),
        alcancesAutorizados: ["USO_FINAL_RESIDENCIAL", "USO_FINAL_NO_RESIDENCIAL", "DISTRIBUCION", "TRANSFORMACION"],
        conflictosConClientes: [], activo: true,
      },
      {
        id: "p-insp1", nombre: "Inspectora A", roles: ["inspector", "director_tecnico_suplente", "revisor"],
        matriculaProfesional: { numero: "CN-000002" },
        declaracionImparcialidad: f(-345), acuerdoConfidencialidad: f(-400),
        alcancesAutorizados: ["USO_FINAL_RESIDENCIAL", "USO_FINAL_NO_RESIDENCIAL"],
        ultimaSupervisionEnSitio: f(-120), conflictosConClientes: ["c-2"], activo: true,
      },
      {
        id: "p-insp2", nombre: "Inspector B", roles: ["inspector"],
        matriculaProfesional: { numero: "CN-000003" },
        declaracionImparcialidad: f(-60), acuerdoConfidencialidad: f(-60),
        alcancesAutorizados: ["USO_FINAL_RESIDENCIAL"],
        ultimaSupervisionEnSitio: f(-390), conflictosConClientes: [], activo: true,
      },
      {
        id: "p-vend", nombre: "Asesor Comercial", roles: ["vendedor"],
        declaracionImparcialidad: f(-30), acuerdoConfidencialidad: undefined,
        alcancesAutorizados: [], conflictosConClientes: [], activo: true,
      },
    ],
    equipos: [
      { id: "e-1", codigo: "EQ-001", nombre: "Telurómetro", marcaModelo: "—", serie: "T-1001",
        ultimaCalibracion: f(-300), vencimientoCalibracion: f(65), proximaVerificacionIntermedia: f(20), estado: "operativo" },
      { id: "e-2", codigo: "EQ-002", nombre: "Megóhmetro", marcaModelo: "—", serie: "M-2002",
        ultimaCalibracion: f(-380), vencimientoCalibracion: f(-15), estado: "operativo" },
      { id: "e-3", codigo: "EQ-003", nombre: "Pinza amperimétrica", marcaModelo: "—", serie: "P-3003",
        ultimaCalibracion: f(-90), vencimientoCalibracion: f(275), proximaVerificacionIntermedia: f(90), estado: "operativo" },
      { id: "e-4", codigo: "EQ-004", nombre: "Probador de RCD/DPS", marcaModelo: "—", serie: "R-4004",
        ultimaCalibracion: f(-200), vencimientoCalibracion: f(165), estado: "operativo" },
    ],
    clientes: [
      { id: "c-1", nombre: "Constructora Ejemplo S.A.S.", nit: "900000001-1" },
      { id: "c-2", nombre: "Conjunto Residencial Demo", nit: "900000002-2" },
    ],
    ordenes: [
      { id: "o-1", consecutivo: "OS-2026-001", clienteId: "c-1", instalacion: "Torre 1 — acometida y zonas comunes",
        alcance: "USO_FINAL_RESIDENCIAL", estado: "entregada", solicitudRevisada: true,
        inspectorId: "p-insp1", revisorId: "p-dt", fechaInspeccion: f(-40), fechaEmision: f(-33),
        equiposUsados: ["e-1", "e-3"], formato: { codigo: "F-229-D", version: "1.0" },
        itemsTotales: 27, itemsEvaluados: 27, ncSinEvidencia: 0 },
      { id: "o-2", consecutivo: "OS-2026-002", clienteId: "c-2", instalacion: "Subestación local 150 kVA",
        alcance: "TRANSFORMACION", estado: "asignada", solicitudRevisada: true,
        inspectorId: "p-insp1", equiposUsados: [], formato: { codigo: "F-229-D", version: "1.0" },
        itemsTotales: 27, itemsEvaluados: 0, ncSinEvidencia: 0 },
      { id: "o-3", consecutivo: "OS-2026-003", clienteId: "c-1", instalacion: "Local comercial 101",
        alcance: "USO_FINAL_RESIDENCIAL", estado: "en_revision", solicitudRevisada: true,
        inspectorId: "p-insp2", fechaInspeccion: f(-5), equiposUsados: ["e-2", "e-3"],
        formato: { codigo: "F-229-D", version: "1.0" }, itemsTotales: 27, itemsEvaluados: 25, ncSinEvidencia: 1 },
      { id: "o-4", consecutivo: "OS-2026-004", clienteId: "c-1", instalacion: "Casa campestre lote 8",
        alcance: "USO_FINAL_RESIDENCIAL", estado: "aprobada", solicitudRevisada: false,
        equiposUsados: [], formato: { codigo: "F-229-D", version: "1.0" },
        itemsTotales: 27, itemsEvaluados: 0, ncSinEvidencia: 0 },
    ],
    quejas: [
      { id: "Q-2026-001", tipo: "queja", descripcion: "Demora en entrega del dictamen",
        fechaRecepcion: f(-45), fechaAcuse: f(-44), estado: "abierta", involucradosIds: ["p-insp2"] },
      { id: "A-2026-001", tipo: "apelacion", descripcion: "Apelación a decisión de no conformidad",
        fechaRecepcion: f(-80), fechaAcuse: f(-79), estado: "cerrada", decisorId: "p-dt", involucradosIds: ["p-insp1"] },
    ],
    acciones: [
      { id: "AC-2026-001", origen: "Auditoría interna", descripcion: "Actualizar procedimiento de revisión de solicitudes",
        fechaLimite: f(12), estado: "abierta", eficaciaVerificada: false },
      { id: "AC-2026-002", origen: "Queja Q-2025-004", descripcion: "Capacitación en registro de evidencias",
        fechaLimite: f(-50), estado: "cerrada", eficaciaVerificada: true },
    ],
    documentos: [
      { codigo: "PR-01", titulo: "Procedimiento de inspección RETIE", version: "3", fechaRevision: f(-200), estado: "vigente" },
      { codigo: "PR-02", titulo: "Revisión de solicitudes, ofertas y contratos", version: "2", fechaRevision: f(-420), estado: "vigente" },
      { codigo: "PR-03", titulo: "Quejas y apelaciones", version: "2", fechaRevision: f(-150), estado: "vigente" },
      { codigo: "PR-04", titulo: "Gestión de la imparcialidad", version: "1", fechaRevision: f(-350), estado: "vigente" },
      { codigo: "F-229-D", titulo: "Lista de verificación RETIE — uso final", version: "1.0", fechaRevision: f(-60), estado: "vigente" },
    ],
    subcontratistas: [],
    auditoriasInternas: [
      { fecha: f(-210), numeralesCubiertos: ["4.1", "4.2", "5.1", "5.2", "6.1", "6.2", "6.3", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "8.2", "8.3", "8.4", "8.5", "8.7", "8.8"] },
    ],
    revisionesDireccion: [{ fecha: f(-180) }],
    analisisRiesgosImparcialidad: [{ fecha: f(-190) }],
  };
}
