/**
 * Habilitación del personal técnico según los requisitos de competencia
 * del reglamento (RETIE 2024 §4.4.2.x, RETILAP 2024 §4.5.2.x) y la
 * vigencia de los certificados (5 años con seguimiento al mes 30).
 */
import { entidadMatricula, estadoMatricula } from "./matricula";
import { categoriaDeActividad, etiquetaCategoria, requisitosDe, AREAS_ILUMINACION, type RequisitosReglamento } from "../requisitos";
import type { CertificadoCompetencia, Persona, RolTecnico } from "./tipos";

const DIA = 86_400_000;
const iso = (d: Date) => d.toISOString().slice(0, 10);
const diasEntre = (a: string, b: string) => Math.round((new Date(b).getTime() - new Date(a).getTime()) / DIA);

export function sumarAnios(fecha: string, anios: number): string {
  const d = new Date(fecha + "T00:00:00Z");
  d.setUTCFullYear(d.getUTCFullYear() + anios);
  d.setUTCDate(d.getUTCDate() - 1);
  return iso(d);
}

/** Fecha límite del seguimiento: mes 30 contado desde el día siguiente a la emisión. */
export function fechaSeguimiento(c: Pick<CertificadoCompetencia, "fechaEmision" | "reglamento">): string {
  const meses = requisitosDe(c.reglamento)?.seguimientoMes ?? 30;
  const d = new Date(c.fechaEmision + "T00:00:00Z");
  d.setUTCDate(d.getUTCDate() + 1);
  d.setUTCMonth(d.getUTCMonth() + meses);
  return iso(d);
}

export type EstadoCertificado = { vigente: boolean; motivo?: string; alertas: string[] };

/** Fecha (en Colombia) de un instante ISO. */
export const fechaColombia = (instante: string) => new Date(instante).toLocaleDateString("en-CA", { timeZone: "America/Bogota" });
const sumarDias = (fecha: string, n: number) => {
  const d = new Date(fecha + "T00:00:00Z");
  d.setUTCDate(d.getUTCDate() + n);
  return iso(d);
};

/**
 * Desde cuándo vuelve a contar el certificado después del seguimiento: la fecha del seguimiento
 * o la de su registro en la plataforma, la que sea posterior (0011).
 */
export function seguimientoEfectivo(c: CertificadoCompetencia): string | undefined {
  if (!c.seguimiento) return undefined;
  const reg = c.seguimiento.registradoEn ? fechaColombia(c.seguimiento.registradoEn) : c.seguimiento.fecha;
  return reg > c.seguimiento.fecha ? reg : c.seguimiento.fecha;
}

/** Periodo en que no pudo ejercer con el certificado por no tener el seguimiento registrado a tiempo. */
export function periodoSinSeguimiento(c: CertificadoCompetencia, hoy: string): { desde: string; hasta?: string } | undefined {
  if (c.anulado || c.seguimiento?.resultado === "no_conforme") return undefined;
  const limite = fechaSeguimiento(c);
  if (!c.seguimiento) return hoy > limite ? { desde: sumarDias(limite, 1) } : undefined;
  const ef = seguimientoEfectivo(c)!;
  return ef > sumarDias(limite, 1) ? { desde: sumarDias(limite, 1), hasta: sumarDias(ef, -1) } : undefined;
}

export type NivelSeguimiento = "hecho" | "pendiente" | "proximo" | "vencido";
/** Estado del seguimiento del mes 30 para mostrarlo en pantalla. */
export function estadoSeguimiento(c: CertificadoCompetencia, hoy: string, anticipacion = 60) {
  const limite = fechaSeguimiento(c);
  const dias = diasEntre(hoy, limite);
  const nivel: NivelSeguimiento = c.seguimiento ? "hecho" : hoy > limite ? "vencido" : dias <= anticipacion ? "proximo" : "pendiente";
  return { nivel, limite, dias, periodo: periodoSinSeguimiento(c, hoy) };
}

export function estadoCertificado(c: CertificadoCompetencia, fecha: string, anticipacion = 60): EstadoCertificado {
  const alertas: string[] = [];
  if (c.anulado) return { vigente: false, motivo: `Certificado ${c.numero} anulado`, alertas };
  if (fecha < c.fechaEmision) return { vigente: false, motivo: `Certificado ${c.numero} aún no emitido`, alertas };
  if (fecha > c.fechaVencimiento) return { vigente: false, motivo: `Certificado ${c.numero} vencido el ${c.fechaVencimiento}`, alertas };
  const seg = fechaSeguimiento(c);
  if (c.seguimiento?.resultado === "no_conforme")
    return { vigente: false, motivo: `Certificado ${c.numero} con seguimiento no conforme (${c.seguimiento.fecha})`, alertas };
  if (fecha > seg) {
    if (!c.seguimiento)
      return { vigente: false, motivo: `Certificado ${c.numero}: seguimiento del mes 30 vencido desde el ${sumarDias(seg, 1)}; no puede ejercer hasta registrarlo`, alertas };
    const ef = seguimientoEfectivo(c)!;
    if (fecha < ef)
      return { vigente: false, motivo: `Certificado ${c.numero}: sin habilitación del ${sumarDias(seg, 1)} al ${sumarDias(ef, -1)} (seguimiento registrado tarde)`, alertas };
  }
  if (!c.seguimiento && diasEntre(fecha, seg) <= anticipacion)
    alertas.push(`Certificado ${c.numero}: seguimiento del mes 30 antes del ${seg}`);
  if (diasEntre(fecha, c.fechaVencimiento) <= anticipacion)
    alertas.push(`Certificado ${c.numero} vence el ${c.fechaVencimiento}`);
  return { vigente: true, alertas };
}

export function certificadoParaCategoria(p: Persona, reglamento: string, categoria: string, fecha: string) {
  return p.certificados.find((c) => c.reglamento === reglamento && c.categorias.includes(categoria) && c.verificada && estadoCertificado(c, fecha).vigente);
}

/** Años de experiencia verificada, sin contar dos veces periodos que se traslapan. */
export function aniosExperiencia(p: Persona, f: { reglamento: string; categoria?: string; tipos: string[] }, fecha: string): number {
  const tramos = p.experiencias
    .filter((e) => e.verificada && e.reglamento === f.reglamento)
    .filter((e) => !f.categoria || e.categorias.includes(f.categoria))
    .filter((e) => e.tipos.some((t) => f.tipos.includes(t)))
    .map((e) => [e.desde, e.hasta && e.hasta < fecha ? e.hasta : fecha] as const)
    .filter(([a, b]) => a <= b)
    .sort((x, y) => x[0].localeCompare(y[0]));
  let dias = 0;
  let [ini, fin] = ["", ""];
  for (const [a, b] of tramos) {
    if (!ini) { [ini, fin] = [a, b]; continue; }
    if (a <= fin) { if (b > fin) fin = b; }
    else { dias += diasEntre(ini, fin) + 1; [ini, fin] = [a, b]; }
  }
  if (ini) dias += diasEntre(ini, fin) + 1;
  return dias / 365.25;
}

export type ItemRequisito = { requisito: string; cumple: boolean; detalle: string; bloquea: boolean };
export type Habilitacion = { cumple: boolean; categoria: string; items: ItemRequisito[]; alertas: string[] };

const a1 = (n: number) => n.toFixed(1).replace(".", ",");

/** Verifica todos los requisitos de competencia de una persona para una actividad y rol. */
export function evaluarCompetencia(p: Persona, actividad: string, rol: RolTecnico, fecha: string): Habilitacion {
  const m = categoriaDeActividad(actividad);
  if (!m) return { cumple: false, categoria: "?", items: [{ requisito: "Categoría", cumple: false, detalle: "Actividad sin categoría de certificación", bloquea: true }], alertas: [] };
  const { req, cat } = m;
  const items: ItemRequisito[] = [];
  const alertas: string[] = [];
  const add = (requisito: string, cumple: boolean, detalle: string, bloquea = true) => items.push({ requisito, cumple, detalle, bloquea });

  // Identificación y matrícula
  add("Cédula", !!p.documento, p.documento ? `${p.tipoDocumento} ${p.documento}` : "Sin documento");
  if (req.matriculaRequerida) {
    const e = estadoMatricula(p);
    const datos = `${p.matriculaNumero ?? ""} ${entidadMatricula(p.matriculaEntidad) ?? ""}${p.matriculaEspecialidad ? ` · ${p.matriculaEspecialidad}` : ""}`.trim();
    add("Matrícula profesional de ingeniero", e === "ingeniero" || e === "aceptada",
      e === "sin_matricula" ? "Sin matrícula registrada (Leyes 842 de 2003 y 51 de 1986)"
        : e === "conte" ? `${datos}: consejo de técnicos o tecnólogos (CONTE, CONALTEL); se requiere matrícula de ingeniero (CPNIEMPA o COPNIA)`
        : e === "por_aceptar" ? `${datos}: otra entidad; requiere aceptación de la gerencia`
        : e === "aceptada" ? `${datos} (aceptada por la gerencia)` : datos);
  }

  // Formación especializada (RETILAP)
  if (req.formacionEspecializada) {
    const posgrados = p.formacion.filter((f) => f.verificada && f.enIluminacion && req.formacionEspecializada!.tipos.includes(f.tipo));
    add("Posgrado en iluminación", posgrados.length > 0,
      posgrados.length ? posgrados.map((f) => `${f.titulo} (${f.institucion})`).join("; ") : req.formacionEspecializada.texto);
    const area = req.profundizacionPorActividad?.[actividad];
    if (area) {
      const enPlan = posgrados.some((f) => f.areasIluminacion.includes(area));
      const curso = p.formacion.find((f) => f.verificada && f.tipo === "curso_profundizacion" && f.areasIluminacion.includes(area));
      add(`Profundización: ${AREAS_ILUMINACION[area] ?? area}`, enPlan || !!curso,
        enPlan ? "Incluida en el plan de estudios del posgrado" : curso ? `${curso.titulo} (${curso.institucion})`
          : "Requiere curso de profundización certificado por institución de educación superior");
    }
  }

  // Experiencia del inspector
  const catExp = req.experienciaPorCategoria ? cat.codigo : undefined;
  const expTec = aniosExperiencia(p, { reglamento: req.reglamento, categoria: catExp, tipos: req.tiposExperienciaTecnica }, fecha);
  add(`Experiencia como inspector (${cat.experienciaInspectorAnios} años${catExp ? `, categoría ${cat.codigo}` : ""})`,
    expTec >= cat.experienciaInspectorAnios, `${a1(expTec)} años verificados`);

  // Director técnico
  if (rol === "director_tecnico") {
    const dt = req.directorTecnico;
    const catDT = dt.porCategoria ? cat.codigo : undefined;
    const total = aniosExperiencia(p, { reglamento: req.reglamento, categoria: catDT, tipos: [...req.tiposExperienciaTecnica, ...dt.tiposExperienciaDireccion] }, fecha);
    const dir = aniosExperiencia(p, { reglamento: req.reglamento, categoria: catDT, tipos: dt.tiposExperienciaDireccion }, fecha);
    const okTotal = dt.experienciaTotalEstricta ? total > dt.experienciaTotalAnios : total >= dt.experienciaTotalAnios;
    add(`Experiencia total director técnico (${dt.experienciaTotalEstricta ? "más de " : ""}${dt.experienciaTotalAnios} años${catDT ? `, categoría ${cat.codigo}` : ""})`,
      okTotal, `${a1(total)} años verificados`);
    add(`Experiencia en gerencia/dirección (${dt.experienciaDireccionAnios} años)`, dir >= dt.experienciaDireccionAnios, `${a1(dir)} años verificados`);
  }

  // Certificado de competencias
  if (req.exigeCertificado) {
    const c = certificadoParaCategoria(p, req.reglamento, cat.codigo, fecha);
    const candidatos = p.certificados.filter((x) => x.reglamento === req.reglamento && x.categorias.includes(cat.codigo));
    add(`Certificado de competencias ${etiquetaCategoria(req.reglamento, cat.codigo)}`, !!c,
      c ? `${c.numero} (${c.certificador}) vigente hasta ${c.fechaVencimiento}`
        : candidatos.length ? candidatos.map((x) => estadoCertificado(x, fecha).motivo ?? (x.verificada ? undefined : `Certificado ${x.numero} sin verificar (lo verifica la gerencia, el SG o un director técnico)`)).filter(Boolean).join("; ")
          : "Sin certificado para esta categoría");
    if (c) alertas.push(...estadoCertificado(c, fecha).alertas);
    if (cat.requiereCategoriaVigente) {
      const g = certificadoParaCategoria(p, req.reglamento, cat.requiereCategoriaVigente, fecha);
      add(`Certificado vigente en categoría ${cat.requiereCategoriaVigente} (prerrequisito de ${cat.codigo})`, !!g,
        g ? `${g.numero} vigente hasta ${g.fechaVencimiento}` : `Sin certificado vigente en categoría ${cat.requiereCategoriaVigente}`, false);
    }
  } else {
    add("Certificado de competencias", true, req.notaCertificado || "No exigido", false);
  }

  return { cumple: items.every((i) => i.cumple || !i.bloquea), categoria: etiquetaCategoria(req.reglamento, cat.codigo), items, alertas };
}

/** Primer requisito bloqueante incumplido, o null. */
export function motivoCompetencia(p: Persona, actividad: string, rol: RolTecnico, fecha: string): string | null {
  const h = evaluarCompetencia(p, actividad, rol, fecha);
  const falla = h.items.find((i) => i.bloquea && !i.cumple);
  return falla ? `${h.categoria} — ${falla.requisito}: ${falla.detalle}` : null;
}

export type { RequisitosReglamento };
