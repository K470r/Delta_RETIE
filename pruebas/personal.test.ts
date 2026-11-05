import { test } from "node:test";
import assert from "node:assert/strict";
import { actividadSegunInstalacion, actividadesAutorizables, lineaDe } from "../src/lib/catalogo";
import { categoriaDeActividad } from "../src/lib/requisitos";
import { estadoCertificado, estadoSeguimiento, fechaSeguimiento } from "../src/lib/organismo/competencia";
import {
  designacionFirmada, estadoDocumentacion, generarDocumento, huella, pendientesDeFirma, puedeFirmarComo,
} from "../src/lib/organismo/documentos";
import { motivoNoPuedeEjercer } from "../src/lib/organismo/reglas";
import type { BaseOrganismos, CertificadoCompetencia, DocumentoPersonal } from "../src/lib/organismo/tipos";

// ───────────── Seguimiento del mes 30 (0011) ─────────────
const c: CertificadoCompetencia = { id: "c", numero: "N1", certificador: "X", reglamento: "RETIE-2024", categorias: ["g"],
  fechaEmision: "2024-01-10", fechaVencimiento: "2029-01-09", anulado: false };

test("seguimiento: alerta naranja a 60 días o menos, roja después del límite", () => {
  const limite = fechaSeguimiento(c);   // 2026-07-11
  assert.equal(limite, "2026-07-11");
  assert.equal(estadoSeguimiento(c, "2026-03-01").nivel, "pendiente");
  assert.equal(estadoSeguimiento(c, "2026-06-01").nivel, "proximo");
  assert.equal(estadoSeguimiento(c, "2026-06-01").dias, 40);
  assert.equal(estadoSeguimiento(c, "2026-07-12").nivel, "vencido");
  assert.deepEqual(estadoSeguimiento(c, "2026-07-12").periodo, { desde: "2026-07-12" });
});

test("registrado tarde: vuelve a contar solo desde el registro y queda el periodo no habilitado", () => {
  const tarde = { ...c, seguimiento: { fecha: "2026-07-01", resultado: "conforme" as const, registradoEn: "2026-08-05T15:00:00Z" } };
  assert.equal(estadoCertificado(tarde, "2026-07-11").vigente, true);    // hasta el límite
  assert.equal(estadoCertificado(tarde, "2026-07-20").vigente, false);   // sin habilitación
  assert.match(estadoCertificado(tarde, "2026-07-20").motivo!, /del 2026-07-12 al 2026-08-04/);
  assert.equal(estadoCertificado(tarde, "2026-08-05").vigente, true);    // desde el registro
  assert.deepEqual(estadoSeguimiento(tarde, "2026-09-01").periodo, { desde: "2026-07-12", hasta: "2026-08-04" });
});

test("registrado a tiempo: no hay periodo sin habilitación", () => {
  const ok = { ...c, seguimiento: { fecha: "2026-06-01", resultado: "conforme" as const, registradoEn: "2026-06-02T15:00:00Z" } };
  assert.equal(estadoCertificado(ok, "2026-07-20").vigente, true);
  assert.equal(estadoSeguimiento(ok, "2026-09-01").periodo, undefined);
});

// ───────────── Generación según tensión (0012) ─────────────
test("generación: a por encima de 1.000 V AC o 1.500 V DC; g hasta esos valores (incluidos)", () => {
  assert.equal(actividadSegunInstalacion("RETIE24-GEN-FNCE", true, 1000, 1500), "RETIE24-GEN-FNCE-BT");
  assert.equal(actividadSegunInstalacion("RETIE24-GEN-FNCE", true, 1001, 0), "RETIE24-GEN-FNCE");
  assert.equal(actividadSegunInstalacion("RETIE24-GEN-VARIAS", true, 0, 1501), "RETIE24-GEN-VARIAS");
  assert.equal(actividadSegunInstalacion("RETIE24-GEN-FNCE", false, 480, 0), "RETIE24-UF-AUTOGEN");
  assert.equal(actividadSegunInstalacion("RETIE24-GEN-FNCE", false, 13200, 0), "RETIE24-GEN-FNCE");
  assert.equal(categoriaDeActividad("RETIE24-GEN-FNCE-BT")?.cat.codigo, "g");
  assert.equal(categoriaDeActividad("RETIE24-GEN-FNCE")?.cat.codigo, "a");
  assert.equal(lineaDe("RETIE24-GEN-FNCE-BT"), "RETIE24-GEN-FNCE");
});

test("al autorizar, la generación acreditada ofrece los dos rangos de tensión", () => {
  const acts = actividadesAutorizables(["RETIE24-GEN-FNCE", "RETIE24-UF-BASICAS"]).map((a) => a.codigo);
  assert.deepEqual(acts, ["RETIE24-GEN-FNCE", "RETIE24-GEN-FNCE-BT", "RETIE24-UF-BASICAS"]);
});

// ───────────── Documentos firmados (0013) ─────────────
const hoy = new Date().toISOString().slice(0, 10);
const persona = (id: string, nombres: string) => ({ id, tipoDocumento: "CC" as const, documento: id, nombres, apellidos: "P", formacion: [], experiencias: [], certificados: [], creado: "" });
const doc = (id: string, designacionId: string, tipo: DocumentoPersonal["tipo"], extra: Partial<DocumentoPersonal> = {}): DocumentoPersonal =>
  ({ id, organismoId: "o", designacionId, tipo, titulo: "", contenido: "x", huella: "h", actividades: [], creadoEn: "2026-01-01", firmas: [], ...extra });
const firma = (enCalidad: "designado" | "gerente" | "director_tecnico" | "evaluador", personaId: string) => ({ enCalidad, personaId, firmadoEn: "", huella: "h" });

const b: BaseOrganismos = {
  organismos: [{ id: "o", razonSocial: "OI", nit: "1", tipo: "A", creado: "", sedes: [], ciudad: "Bogotá D.C.", codigoAcreditacion: "17-OIN-032",
    alcance: [{ actividad: "RETIE24-GEN-FNCE", estado: "acreditada", fechaEstado: "2020-01-01" }] }],
  personas: [persona("g", "Gina"), persona("dt", "Darío"), persona("i", "Iván")],
  vinculaciones: ["g", "dt", "i"].map((p) => ({ id: p, organismoId: "o", personaId: p, tipo: "laboral" as const, cargo: "C", desde: "2020-01-01" })),
  designaciones: [
    { id: "dg", organismoId: "o", personaId: "g", rol: "gerente", desde: "2020-01-01", actividades: [] },
    { id: "ddt", organismoId: "o", personaId: "dt", rol: "director_tecnico", desde: "2020-01-01", actividades: ["RETIE24-GEN-FNCE"] },
    { id: "di", organismoId: "o", personaId: "i", rol: "inspector", desde: "2020-01-01", actividades: ["RETIE24-GEN-FNCE-BT"] },
  ],
  declaraciones: [], revisionesSG: [],
  documentosPersonal: [
    doc("1", "dg", "designacion_gerente"),
    doc("2", "ddt", "autorizacion_director_tecnico", { actividades: ["RETIE24-GEN-FNCE"] }),
    doc("3", "di", "autorizacion_inspector", { actividades: ["RETIE24-GEN-FNCE-BT"], evaluadorId: "dt" }),
  ],
};

test("el gerente firma primero su designación; solo entonces firma las autorizaciones", () => {
  assert.deepEqual(puedeFirmarComo(b, b.documentosPersonal![1], "g"), []);   // su designación aún sin firmar
  assert.deepEqual(puedeFirmarComo(b, b.documentosPersonal![0], "g"), ["designado"]);
  const b2 = { ...b, documentosPersonal: b.documentosPersonal!.map((x) => (x.id === "1" ? { ...x, firmas: [firma("designado", "g")] } : x)) };
  assert.equal(designacionFirmada(b2, b2.designaciones[0]), true);
  assert.deepEqual(puedeFirmarComo(b2, b2.documentosPersonal![1], "g"), ["gerente"]);
  assert.deepEqual(puedeFirmarComo(b2, b2.documentosPersonal![2], "dt"), []);   // el DT aún sin autorización firmada
  assert.equal(pendientesDeFirma(b2, "g").length, 2);
});

test("el inspector queda pendiente hasta que firmen el gerente y el director técnico que lo evaluó", () => {
  const e = estadoDocumentacion(b, b.designaciones[2]);
  assert.equal(e.firmado, false);
  assert.deepEqual(e.faltan, ["Gerente", "Director técnico que evaluó"]);
  assert.deepEqual(e.sinFirmar, ["RETIE24-GEN-FNCE-BT"]);
  const firmadoA = { ...b, documentosPersonal: b.documentosPersonal!.map((x) => (x.id === "3" ? { ...x, firmas: [firma("gerente", "g"), firma("evaluador", "dt")] } : x)) };
  assert.equal(estadoDocumentacion(firmadoA, b.designaciones[2]).firmado, true);
});

test("el modelo de texto incluye los datos de la designación y las actividades con su categoría", () => {
  const t = generarDocumento(b, b.designaciones[2], "dt")!;
  assert.match(t.contenido, /17-OIN-032/);
  assert.match(t.contenido, /como INSPECTOR/);
  assert.match(t.contenido, /hasta 1\.000 V AC y 1\.500 V DC — categoría RETIE g/);
  assert.match(t.contenido, /evaluada por Darío P/);
});

test("la huella es SHA-256 en hexadecimal (igual que la base de datos)", async () => {
  assert.equal(await huella("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
});

test("sin el documento firmado, el tablero lo marca", async () => {
  const { evaluarOrganismo } = await import("../src/lib/organismo/reglas");
  const ctl = evaluarOrganismo(b, b.organismos[0], hoy).find((x) => x.id === "O-6.1-05")!;
  assert.equal(ctl.estado, "incumple");
  assert.ok(ctl.hallazgos.some((h) => h.includes("Iván P (Inspector)")));
});

test("la variante de baja tensión la cubre la línea de generación del alcance", () => {
  const m = motivoNoPuedeEjercer(b, b.organismos[0], b.personas[2], "RETIE24-GEN-FNCE-BT", hoy, "inspector");
  assert.doesNotMatch(m ?? "", /alcance/);
});
