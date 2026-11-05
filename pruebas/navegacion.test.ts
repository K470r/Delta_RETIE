import { test } from "node:test";
import assert from "node:assert/strict";
import { SECCIONES, rolesMenu, rutaSeccion, seccionActual, visible } from "../src/lib/navegacion";
import type { BaseOrganismos } from "../src/lib/organismo/tipos";

const ORG = "6f2a7820-d8f1-4609-b77e-5ec9ef43561c";
const VACIA: BaseOrganismos = { organismos: [], personas: [], vinculaciones: [], designaciones: [], declaraciones: [], revisionesSG: [] };

test("la sección activa se reconoce por la ruta y la pestaña", () => {
  assert.equal(seccionActual(`/organismos/${ORG}`, null)?.id, "inicio");
  assert.equal(seccionActual(`/organismos/${ORG}`, "inspectores")?.id, "personal");
  assert.equal(seccionActual(`/organismos/${ORG}`, "gerencia")?.id, "organismo");
  assert.equal(seccionActual("/personas", null)?.id, "personal");
  assert.equal(seccionActual("/inspeccion/abc", null)?.id, "inspecciones");
  assert.equal(seccionActual("/seccion/ia", null)?.id, "ia");
  assert.equal(seccionActual("/organismos", null)?.id, "plataforma");
});

test("cada sección lleva a una página que existe", () => {
  const rutas = SECCIONES.map((s) => rutaSeccion(s, ORG));
  for (const r of rutas) assert.match(r, /^\/(organismos(\/[0-9a-f-]{36}\?p=\w+)?|seccion\/\w+|ordenes)$/, r);
});

test("el inspector no ve las secciones de la gerencia; el administrador ve Plataforma", () => {
  const base: BaseOrganismos = { ...VACIA, designaciones: [{ id: "d", organismoId: ORG, personaId: "p", rol: "inspector", desde: "2020-01-01", actividades: [] }] };
  const insp = rolesMenu({ local: false, esAdminPlataforma: false, base, personaId: "p", organismoId: ORG });
  const ver = (r: Set<never> | ReturnType<typeof rolesMenu>) => SECCIONES.filter((s) => visible(s, r)).map((s) => s.id);
  assert.ok(ver(insp).includes("inspecciones"));
  assert.ok(!ver(insp).includes("cotizaciones"));
  assert.ok(!ver(insp).includes("plataforma"));
  const admin = rolesMenu({ local: false, esAdminPlataforma: true, base: VACIA });
  assert.ok(ver(admin).includes("plataforma"));
});

test("sin organismo, cada sección se ilumina ella misma (no Plataforma)", () => {
  for (const s of SECCIONES) {
    const r = rutaSeccion(s, undefined);
    assert.equal(seccionActual(r.split("?")[0], null)?.id, s.id, `${s.id} → ${r}`);
  }
});

test("con organismo, cada sección se ilumina ella misma", () => {
  for (const s of SECCIONES) {
    const r = rutaSeccion(s, ORG);
    const [ruta, q] = r.split("?p=");
    assert.equal(seccionActual(ruta, q ?? null)?.id, s.id, `${s.id} → ${r}`);
  }
});

test("permisos del organismo: estado solo la gerencia; agregar, documentos y datos la gerencia y el SG", async () => {
  const { permisosOrganismo } = await import("../src/lib/navegacion");
  const org = { id: ORG, razonSocial: "O", nit: "1", tipo: "A" as const, creado: "", sedes: [], alcance: [], creadoPor: "u-creador" };
  const des = (personaId: string, rol: "gerente" | "suplente_sg" | "director_tecnico_suplente" | "inspector") =>
    ({ id: personaId + rol, organismoId: ORG, personaId, rol, desde: "2020-01-01", actividades: [] });
  const vacio: BaseOrganismos = { ...VACIA, organismos: [org] };
  assert.deepEqual(permisosOrganismo({ local: false, usuarioId: "u-creador", base: vacio, organismoId: ORG }), { gerencia: true, gestion: true, arranque: true });
  const base: BaseOrganismos = { ...vacio, designaciones: [des("g", "gerente"), des("s", "suplente_sg"), des("d", "director_tecnico_suplente"), des("i", "inspector")] };
  const p = (personaId: string) => permisosOrganismo({ local: false, usuarioId: "otro", base, personaId, organismoId: ORG });
  assert.deepEqual(p("g"), { gerencia: true, gestion: true, arranque: false });
  assert.deepEqual(p("s"), { gerencia: false, gestion: true, arranque: false });
  assert.deepEqual(p("d"), { gerencia: false, gestion: false, arranque: false });
  assert.deepEqual(p("i"), { gerencia: false, gestion: false, arranque: false });
  assert.equal(permisosOrganismo({ local: false, usuarioId: "u-creador", base, organismoId: ORG }).arranque, false, "el arranque termina al designar");
});
