import { test } from "node:test";
import assert from "node:assert/strict";
import { validarDesignacion } from "../src/lib/organismo/reglas";
import type { BaseOrganismos } from "../src/lib/organismo/tipos";

const base: BaseOrganismos = {
  organismos: [{ id: "o", razonSocial: "OIN", nit: "1", tipo: "A", creado: "", sedes: [],
    alcance: [{ actividad: "RETIE24-UF-BASICAS", estado: "acreditada", fechaEstado: "2020-01-01" }] }],
  personas: [{ id: "p", tipoDocumento: "CC", documento: "1", nombres: "A", apellidos: "B", matriculaNumero: "M",
    formacion: [], experiencias: [], certificados: [], creado: "" }],
  vinculaciones: [{ id: "v", organismoId: "o", personaId: "p", tipo: "laboral", cargo: "DT", desde: "2020-01-01" }],
  designaciones: [], declaraciones: [], revisionesSG: [],
};

test("se puede designar director técnico o inspector con las actividades pendientes", () => {
  for (const rol of ["director_tecnico", "director_tecnico_suplente", "inspector"] as const)
    assert.deepEqual(validarDesignacion(base, { organismoId: "o", personaId: "p", rol, desde: "2026-01-01", actividades: [] }), [], rol);
});

test("pero no se le autoriza una actividad si no cumple los requisitos", () => {
  const e = validarDesignacion(base, { organismoId: "o", personaId: "p", rol: "inspector", desde: "2026-01-01", actividades: ["RETIE24-UF-BASICAS"] });
  assert.equal(e.length, 1);
  assert.match(e[0], /Uso final|básicas/i);
});
