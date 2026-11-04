/** Pruebas del motor de habilitación (RETIE 2024 §4.4.2.x, RETILAP 2024 §4.5.2.x). */
import assert from "node:assert/strict";
import { test } from "node:test";
import { aniosExperiencia, estadoCertificado, evaluarCompetencia, fechaSeguimiento, sumarAnios } from "../src/lib/organismo/competencia";
import type { CertificadoCompetencia, Experiencia, Formacion, Persona } from "../src/lib/organismo/tipos";

const HOY = "2026-11-03";
const UF = "RETIE24-UF-BASICAS";       // categoría g
const SUB_MT = "RETIE24-SUB-MT";       // categoría c
const ILUM_INT = "RETILAP24-INTERIOR"; // categoría 1
const ILUM_TUN = "RETILAP24-TUNELES";  // categoría 4, requiere profundización

let n = 0;
const exp = (desde: string, hasta: string | undefined, cats: string[], tipos = ["inspeccion"], reglamento = "RETIE-2024", verificada = true): Experiencia =>
  ({ id: `e${n++}`, empresa: "X", cargo: "Y", desde, hasta, reglamento, categorias: cats, tipos, verificada });
const cert = (cats: string[], emision: string, extra: Partial<CertificadoCompetencia> = {}): CertificadoCompetencia =>
  ({ id: `c${n++}`, numero: `N${n}`, certificador: "OCP", reglamento: "RETIE-2024", categorias: cats, fechaEmision: emision, fechaVencimiento: sumarAnios(emision, 5), anulado: false, ...extra });
const persona = (p: Partial<Persona>): Persona => ({
  id: "p", tipoDocumento: "CC", documento: "123", nombres: "A", apellidos: "B", matriculaNumero: "CN-1",
  formacion: [], experiencias: [], certificados: [], creado: "", ...p,
});
const ok = (p: Persona, act: string, rol: "inspector" | "director_tecnico" = "inspector") => evaluarCompetencia(p, act, rol, HOY).cumple;

test("seguimiento al mes 30 desde el día siguiente a la emisión; vigencia 5 años", () => {
  assert.equal(fechaSeguimiento({ fechaEmision: "2024-01-10", reglamento: "RETIE-2024" }), "2026-07-11");
  assert.equal(sumarAnios("2024-01-10", 5), "2029-01-09");
});

test("certificado sin seguimiento después del mes 30 deja de estar vigente", () => {
  const c = cert(["g"], "2024-01-10");
  assert.equal(estadoCertificado(c, "2026-07-11").vigente, true);
  assert.equal(estadoCertificado(c, "2026-07-12").vigente, false);
  assert.equal(estadoCertificado({ ...c, seguimiento: { fecha: "2026-06-01", resultado: "conforme" } }, "2026-07-12").vigente, true);
  assert.equal(estadoCertificado({ ...c, seguimiento: { fecha: "2026-06-01", resultado: "no_conforme" } }, "2026-07-12").vigente, false);
  assert.ok(estadoCertificado(c, "2026-06-01").alertas.some((a) => a.includes("seguimiento")));
});

test("experiencia: solo verificada y sin contar traslapes dos veces", () => {
  const p = persona({ experiencias: [
    exp("2020-01-01", "2021-12-31", ["g"]),
    exp("2021-01-01", "2022-12-31", ["g"]),          // traslapa un año
    exp("2015-01-01", "2019-12-31", ["g"], ["inspeccion"], "RETIE-2024", false), // sin verificar
  ] });
  const a = aniosExperiencia(p, { reglamento: "RETIE-2024", categoria: "g", tipos: ["inspeccion"] }, HOY);
  assert.ok(Math.abs(a - 3) < 0.01, `esperaba ~3 años, obtuve ${a}`);
});

test("inspector RETIE g: 2 años en la categoría + certificado vigente + matrícula", () => {
  const base = { certificados: [cert(["g"], "2026-01-01")] };
  assert.equal(ok(persona({ ...base, experiencias: [exp("2024-10-01", undefined, ["g"])] }), UF), true);
  assert.equal(ok(persona({ ...base, experiencias: [exp("2025-01-01", undefined, ["g"])] }), UF), false, "menos de 2 años");
  assert.equal(ok(persona({ ...base, experiencias: [exp("2020-01-01", undefined, ["c"])] }), UF), false, "experiencia de otra categoría");
  assert.equal(ok(persona({ ...base, matriculaNumero: undefined, experiencias: [exp("2020-01-01", undefined, ["g"])] }), UF), false, "sin matrícula");
  assert.equal(ok(persona({ experiencias: [exp("2020-01-01", undefined, ["g"])] }), UF), false, "sin certificado");
});

test("inspector RETIE c: 3 años; certificado g vigente es advertencia, no bloqueo", () => {
  const p = persona({ certificados: [cert(["c"], "2026-01-01")], experiencias: [exp("2023-06-01", undefined, ["c"])] });
  const h = evaluarCompetencia(p, SUB_MT, "inspector", HOY);
  assert.equal(h.cumple, true);
  assert.ok(h.items.some((i) => !i.cumple && !i.bloquea && i.requisito.includes("categoría g")));
  assert.equal(ok(persona({ ...p, experiencias: [exp("2024-06-01", undefined, ["c"])] }), SUB_MT), false, "menos de 3 años");
});

test("director técnico RETIE: más de 10 años en la categoría con mínimo 2 en gerencia/dirección", () => {
  const c = [cert(["g"], "2026-01-01")];
  const p = (tecDesde: string, gerDesde: string) => persona({ certificados: c, experiencias: [
    exp(tecDesde, "2023-12-31", ["g"], ["diseno", "construccion"]),
    exp(gerDesde, undefined, ["g"], ["gerencia_direccion"]),
  ] });
  assert.equal(ok(p("2015-01-01", "2024-01-01"), UF, "director_tecnico"), true, "~11,8 años, 2,8 en dirección");
  assert.equal(ok(p("2017-01-01", "2025-01-01"), UF, "director_tecnico"), false, "menos de 10 años en total");
  assert.equal(ok(p("2010-01-01", "2025-06-01"), UF, "director_tecnico"), false, "menos de 2 años en dirección");
  assert.equal(ok(p("2015-01-01", "2024-01-01"), UF, "inspector"), true);
});

test("RETILAP: sin certificado (no hay organismo certificador), con posgrado y 3 años", () => {
  const posgrado: Formacion = { id: "f", tipo: "especializacion", titulo: "Esp. Iluminación", institucion: "U", fecha: "2018-01-01", areasIluminacion: [], enIluminacion: true, verificada: true };
  const e = [exp("2022-01-01", undefined, [], ["diseno"], "RETILAP-2024")];
  assert.equal(ok(persona({ formacion: [posgrado], experiencias: e }), ILUM_INT), true);
  assert.equal(ok(persona({ experiencias: e }), ILUM_INT), false, "sin posgrado en iluminación");
  assert.equal(ok(persona({ formacion: [{ ...posgrado, verificada: false }], experiencias: e }), ILUM_INT), false, "posgrado sin verificar");
  assert.equal(ok(persona({ formacion: [posgrado], experiencias: e }), ILUM_TUN), false, "túneles requiere profundización");
  const curso: Formacion = { ...posgrado, id: "g", tipo: "curso_profundizacion", titulo: "Túneles", areasIluminacion: ["tuneles"] };
  assert.equal(ok(persona({ formacion: [posgrado, curso], experiencias: e }), ILUM_TUN), true, "con curso de profundización");
  assert.equal(ok(persona({ formacion: [{ ...posgrado, areasIluminacion: ["tuneles"] }], experiencias: e }), ILUM_TUN), true, "área incluida en el posgrado");
});

test("director técnico RETILAP: 7 años en total y 1 en coordinación/gerencia", () => {
  const posgrado: Formacion = { id: "f", tipo: "maestria", titulo: "M. Iluminación", institucion: "U", fecha: "2015-01-01", areasIluminacion: [], enIluminacion: true, verificada: true };
  const p = (desde: string, coord: string) => persona({ formacion: [posgrado], experiencias: [
    exp(desde, "2025-01-01", [], ["inspeccion"], "RETILAP-2024"), exp(coord, undefined, [], ["coordinacion_proyectos"], "RETILAP-2024"),
  ] });
  assert.equal(ok(p("2019-01-01", "2025-01-02"), ILUM_INT, "director_tecnico"), true);
  assert.equal(ok(p("2021-01-01", "2025-01-02"), ILUM_INT, "director_tecnico"), false, "menos de 7 años");
  assert.equal(ok(p("2019-01-01", "2026-06-01"), ILUM_INT, "director_tecnico"), false, "menos de 1 año en coordinación");
});
