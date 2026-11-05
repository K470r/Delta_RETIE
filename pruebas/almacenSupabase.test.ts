import { test } from "node:test";
import assert from "node:assert/strict";
import { operaciones } from "../src/lib/organismo/almacenSupabase";
import type { BaseOrganismos, Persona } from "../src/lib/organismo/tipos";

const VACIA: BaseOrganismos = { organismos: [], personas: [], vinculaciones: [], designaciones: [], declaraciones: [], revisionesSG: [] };
const persona: Persona = {
  id: "p1", tipoDocumento: "CC", documento: "1001", nombres: "Ana", apellidos: "Pérez", correo: "Ana@X.com",
  formacion: [], certificados: [], creado: "2026-01-01",
  experiencias: [{ id: "e1", empresa: "E", cargo: "C", desde: "2020-01-01", reglamento: "RETIE-2024", categorias: ["g"], tipos: ["diseno"], verificada: false }],
};

test("crear un organismo inserta organismo, sede y alcance en ese orden", () => {
  const d: BaseOrganismos = { ...VACIA, organismos: [{
    id: "o1", razonSocial: "OIN", nit: "900", tipo: "A", creado: "", sedes: [{ id: "s1", nombre: "Principal", principal: true }],
    alcance: [{ actividad: "RETIE24-UF-BASICAS", estado: "acreditada", fechaEstado: "2026-01-01" }],
  }] };
  const ops = operaciones(VACIA, d);
  assert.deepEqual(ops.map((o) => `${o.tipo}:${o.tabla}`), ["insertar:organismos", "insertar:sedes", "insertar:alcance_acreditado"]);
  const org = ops[0] as { fila: Record<string, unknown> };
  assert.ok(!("sigla" in org.fila), "los campos vacíos no se envían al insertar");
  assert.ok(!("creado_por" in org.fila), "creado_por lo asigna la base de datos");
});

test("verificar un soporte envía solo verificada y verificada_por", () => {
  const a = { ...VACIA, personas: [persona] };
  const d = { ...VACIA, personas: [{ ...persona, experiencias: [{ ...persona.experiencias[0], verificada: true, verificadaPor: "p2" }] }] };
  assert.deepEqual(operaciones(a, d), [
    { tipo: "modificar", tabla: "experiencias", clave: { id: "e1" }, cambios: { verificada: true, verificada_por: "p2" } },
  ]);
});

test("sin cambios no envía nada; el correo se guarda en minúsculas", () => {
  const a = { ...VACIA, personas: [persona] };
  assert.deepEqual(operaciones(a, a), []);
  const ins = operaciones(VACIA, a)[0] as { fila: Record<string, unknown> };
  assert.equal(ins.fila.correo, "ana@x.com");
  assert.ok(!("usuario_id" in ins.fila), "usuario_id lo enlaza la base de datos");
});

test("finalizar una designación la modifica (no la borra) y las actividades se agregan o quitan", () => {
  const des = { id: "d1", organismoId: "o1", personaId: "p1", rol: "inspector" as const, desde: "2026-01-01", actividades: ["A", "B"] };
  const a = { ...VACIA, designaciones: [des] };
  const d = { ...VACIA, designaciones: [{ ...des, hasta: "2026-02-01", actividades: ["A", "C"] }] };
  assert.deepEqual(operaciones(a, d), [
    { tipo: "modificar", tabla: "designaciones", clave: { id: "d1" }, cambios: { hasta: "2026-02-01" } },
    { tipo: "insertar", tabla: "designacion_actividades", fila: { designacion_id: "d1", actividad_codigo: "C" } },
    { tipo: "eliminar", tabla: "designacion_actividades", clave: { designacion_id: "d1", actividad_codigo: "B" } },
  ]);
});
