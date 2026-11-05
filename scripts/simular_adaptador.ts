/**
 * Convierte las operaciones del adaptador Supabase en SQL para probarlas en un
 * PostgreSQL local con supabase/tests/simular_supabase.sql (prueba de desarrollo).
 * Uso (base nueva con simular_supabase.sql, instalar_todo.sql y tests/funciones_prueba.sql):
 *   npx tsx scripts/simular_adaptador.ts | psql -d prueba
 */
import { operaciones } from "../src/lib/organismo/almacenSupabase";
import type { BaseOrganismos, Persona } from "../src/lib/organismo/tipos";

const q = (s: string) => `'${s.replace(/'/g, "''")}'`;
const lit = (v: unknown) => `${q(JSON.stringify(v))}::jsonb`;
const cols = (f: Record<string, unknown>) => Object.keys(f).join(", ");
const donde = (c: Record<string, unknown>) => Object.entries(c).map(([k, v]) => `${k} = '${v}'`).join(" and ");

function sql(a: BaseOrganismos, d: BaseOrganismos, titulo: string, espera = "") {
  const s = operaciones(a, d).map((op) =>
    op.tipo === "insertar" ? `insert into ${op.tabla} (${cols(op.fila)}) select ${cols(op.fila)} from jsonb_populate_record(null::${op.tabla}, ${lit(op.fila)})`
    : op.tipo === "modificar" ? `update ${op.tabla} set (${cols(op.cambios)}) = (select ${cols(op.cambios)} from jsonb_populate_record(null::${op.tabla}, ${lit(op.cambios)})) where ${donde(op.clave)}`
    : `delete from ${op.tabla} where ${donde(op.clave)}`).join("; ");
  const f = espera ? "prueba.debe_fallar" : "prueba.debe_pasar";
  console.log(`select ${f}(${q(titulo)}, ${q(`do $x$ begin ${s}; end $x$`)}${espera ? `, ${q(espera)}` : ""});`);
}

const login = (uid: string) => console.log(`reset role; select set_config('request.jwt.claims', '{"sub":"${uid}"}', false); set role authenticated;`);

const ADMIN = "aaaaaaaa-0000-0000-0000-0000000000a1";
const hoy = new Date().toISOString().slice(0, 10);
console.log(`insert into auth.users (id, email) values ('${ADMIN}', 'directortecnico.gceisas@gmail.com');`);
login(ADMIN);

const V: BaseOrganismos = { organismos: [], personas: [], vinculaciones: [], designaciones: [], declaraciones: [], revisionesSG: [] };
const O = "11111111-0000-0000-0000-000000000001";
let b1: BaseOrganismos = { ...V, organismos: [{
  id: O, razonSocial: "GCEI S.A.S.", nit: "901000111", tipo: "A", creado: "", codigoAcreditacion: "15-OIN-777",
  sedes: [{ id: "11111111-0000-0000-0000-0000000000s1".replace("s", "5"), nombre: "Sede principal", ciudad: "Bogotá", principal: true }],
  alcance: [{ actividad: "RETIE24-UF-BASICAS", estado: "acreditada", fechaEstado: hoy }],
}] };
sql(V, b1, "crear organismo (sede y alcance)");

const yo: Persona = { id: "22222222-0000-0000-0000-000000000001", tipoDocumento: "CC", documento: "79000001", nombres: "Director", apellidos: "Técnico",
  correo: "DirectorTecnico.gceisas@gmail.com", matriculaNumero: "CN-1", matriculaEntidad: "COPNIA", formacion: [], experiencias: [], certificados: [], creado: "" };
const insp: Persona = { id: "22222222-0000-0000-0000-000000000002", tipoDocumento: "CC", documento: "79000002", nombres: "Laura", apellidos: "Inspectora",
  correo: "laura@example.com", matriculaNumero: "CN-2", matriculaEntidad: "CPNIEMPA", formacion: [], experiencias: [], certificados: [], creado: "" };
const b2 = { ...b1, personas: [yo] };
sql(b1, b2, "registrarse como persona");
const b3: BaseOrganismos = { ...b2,
  vinculaciones: [{ id: "33333333-0000-0000-0000-000000000001", organismoId: O, personaId: yo.id, tipo: "laboral", cargo: "Director técnico", desde: hoy }],
  designaciones: [{ id: "44444444-0000-0000-0000-000000000001", organismoId: O, personaId: yo.id, rol: "director_tecnico", desde: hoy, actividades: [] },
    // También gerente: desde 0009 solo la gerencia y el SG modifican el organismo y el estado del alcance.
    { id: "44444444-0000-0000-0000-0000000000a1", organismoId: O, personaId: yo.id, rol: "gerente", desde: hoy, actividades: [] }],
  declaraciones: (["imparcialidad", "confidencialidad"] as const).map((tipo, i) => ({ id: `55555555-0000-0000-0000-00000000000${i}`, organismoId: O, personaId: yo.id, tipo, fecha: hoy })),
};
sql(b2, b3, "vincularse, designarse director técnico y gerente, y declarar");

const desde = (dias: number) => new Date(Date.now() - dias * 864e5).toISOString().slice(0, 10);
const inspCompleta: Persona = { ...insp,
  experiencias: [{ id: "66666666-0000-0000-0000-000000000001", empresa: "E", cargo: "Inspectora", desde: desde(1000), reglamento: "RETIE-2024", categorias: ["g"], tipos: ["inspeccion"], verificada: false }],
  certificados: [{ id: "77777777-0000-0000-0000-000000000001", numero: "CP-1", certificador: "OCP", reglamento: "RETIE-2024", categorias: ["g"], fechaEmision: desde(100), fechaVencimiento: desde(100 - 1825), anulado: false }],
};
const b4 = { ...b3, personas: [yo, inspCompleta] };
sql(b3, b4, "registrar inspectora con experiencia y certificado");
const verificar = (por?: string) => ({ ...b4, personas: [yo, { ...inspCompleta, experiencias: [{ ...inspCompleta.experiencias[0], verificada: true, verificadaPor: por }] }] });
sql(b4, verificar(insp.id), "verificar a nombre de otra persona rechazado", "quien inició sesión");
sql(b4, verificar(undefined), "verificación sin persona rechazada", "quien inició sesión");
const b5 = verificar(yo.id);
sql(b4, b5, "verificar experiencia a nombre de quien inició sesión");
const sinVinc: BaseOrganismos = { ...b5, designaciones: [...b5.designaciones,
  { id: "44444444-0000-0000-0000-000000000009", organismoId: O, personaId: insp.id, rol: "inspector", desde: hoy, actividades: [] }] };
sql(b5, sinVinc, "designar sin vinculación rechazado", "vinculada al organismo");
const b6: BaseOrganismos = { ...b5,
  vinculaciones: [...b5.vinculaciones, { id: "33333333-0000-0000-0000-000000000002", organismoId: O, personaId: insp.id, tipo: "prestacion_servicios", cargo: "Inspectora", desde: hoy }],
  designaciones: [...b5.designaciones, { id: "44444444-0000-0000-0000-000000000002", organismoId: O, personaId: insp.id, rol: "inspector", desde: hoy, actividades: ["RETIE24-UF-BASICAS"] }],
};
sql(b5, b6, "vincular y designar inspectora con actividad autorizada");
const b7: BaseOrganismos = { ...b6, designaciones: b6.designaciones.map((d) => d.personaId === insp.id ? { ...d, actividades: [...d.actividades, "RETIE24-SUB-MT"] } : d) };
sql(b6, b7, "autorizar actividad fuera del alcance rechazado", "alcance acreditado");
const b8: BaseOrganismos = { ...b6, designaciones: [...b6.designaciones,
  { id: "44444444-0000-0000-0000-000000000003", organismoId: O, personaId: yo.id, rol: "responsable_sg", desde: hoy, actividades: [] },
  { id: "44444444-0000-0000-0000-000000000004", organismoId: O, personaId: insp.id, rol: "responsable_sg", desde: hoy, actividades: [] }] };
sql(b6, b8, "dos responsables del SG a la vez rechazado", "exclusion");
const b9: BaseOrganismos = { ...b6, designaciones: b6.designaciones.map((d) => d.personaId === insp.id ? { ...d, hasta: hoy, acto: "Finalizada" } : d) };
sql(b6, b9, "finalizar designación (se modifica, no se borra)");
const b10: BaseOrganismos = { ...b9, organismos: b9.organismos.map((o) => ({ ...o, ciudad: "Medellín", alcance: o.alcance.map((l) => ({ ...l, estado: "suspendida" as const, observacion: "ONAC" })) })) };
sql(b9, b10, "editar organismo y suspender línea del alcance");
console.log(`reset role; select prueba.debe_ser('bitácora con usuario', $q$select (count(*) filter (where usuario = '${ADMIN}') = count(*))::text from bitacora$q$, 'true');`);
