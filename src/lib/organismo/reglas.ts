/**
 * Reglas 17020 para la estructura del organismo y su personal.
 * Son las mismas que aplica la base de datos (puede_ejercer, exclusiones de
 * roles únicos, etc.), evaluadas aquí para dar retroalimentación inmediata
 * en pantalla y para el tablero de cumplimiento del organismo.
 */
import { nombreCorto } from "../catalogo";
import {
  NOMBRE_ROL, PLAZOS_POR_DEFECTO, ROLES_CON_ACTIVIDADES, ROLES_UNICOS,
  type BaseOrganismos, type Designacion, type Organismo, type Persona, type RolOEC,
} from "./tipos";

export const hoyISO = () => new Date().toISOString().slice(0, 10);
const DIA = 86_400_000;
const dias = (desde: string, hasta: string) => Math.round((new Date(hasta).getTime() - new Date(desde).getTime()) / DIA);
const sumar = (fecha: string, n: number) => new Date(new Date(fecha).getTime() + n * DIA).toISOString().slice(0, 10);

export const vigenteEn = (x: { desde: string; hasta?: string }, fecha: string) =>
  x.desde <= fecha && (!x.hasta || x.hasta >= fecha);

const seSolapan = (a: { desde: string; hasta?: string }, b: { desde: string; hasta?: string }) =>
  a.desde <= (b.hasta ?? "9999-12-31") && b.desde <= (a.hasta ?? "9999-12-31");

export const nombrePersona = (p?: Persona) => (p ? `${p.nombres} ${p.apellidos}` : "(desconocida)");

export function lineasAcreditadas(o: Organismo): string[] {
  return o.alcance.filter((l) => l.estado === "acreditada").map((l) => l.actividad);
}

export function certificadoVigente(p: Persona, actividad: string, fecha: string) {
  return p.certificados.find(
    (c) => !c.anulado && c.actividades.includes(actividad) && c.fechaEmision <= fecha && c.fechaVencimiento >= fecha,
  );
}

export function vinculacionVigente(b: BaseOrganismos, organismoId: string, personaId: string, fecha: string) {
  return b.vinculaciones.find((v) => v.organismoId === organismoId && v.personaId === personaId && vigenteEn(v, fecha));
}

/** Motivo por el que la persona NO puede ejercer la actividad en el organismo, o null si puede. */
export function motivoNoPuedeEjercer(b: BaseOrganismos, o: Organismo, p: Persona, actividad: string, fecha = hoyISO()): string | null {
  if (!lineasAcreditadas(o).includes(actividad))
    return "No está en el alcance acreditado vigente del organismo";
  if (!vinculacionVigente(b, o.id, p.id, fecha))
    return "Sin vinculación vigente con el organismo";
  if (!certificadoVigente(p, actividad, fecha))
    return "Sin certificado de competencias vigente para esta actividad";
  return null;
}

/** Valida una designación nueva antes de guardarla. */
export function validarDesignacion(b: BaseOrganismos, d: Omit<Designacion, "id">): string[] {
  const errores: string[] = [];
  const o = b.organismos.find((x) => x.id === d.organismoId);
  const p = b.personas.find((x) => x.id === d.personaId);
  if (!o || !p) return ["Organismo o persona inexistente"];
  if (d.hasta && d.hasta < d.desde) errores.push("La fecha final es anterior a la inicial");
  if (!vinculacionVigente(b, o.id, p.id, d.desde))
    errores.push("La persona debe estar vinculada al organismo en la fecha de designación (17020 §5.2 / §6.1)");

  if (ROLES_UNICOS.includes(d.rol)) {
    const otro = b.designaciones.find((x) => x.organismoId === o.id && x.rol === d.rol && seSolapan(x, d));
    if (otro)
      errores.push(`Ya hay ${NOMBRE_ROL[d.rol].toLowerCase()} vigente (${nombrePersona(b.personas.find((y) => y.id === otro.personaId))}). Finalice esa designación primero.`);
  }
  const mismo = b.designaciones.find((x) => x.organismoId === o.id && x.personaId === p.id && x.rol === d.rol && seSolapan(x, d));
  if (mismo) errores.push(`La persona ya tiene una designación vigente como ${NOMBRE_ROL[d.rol].toLowerCase()}`);

  if (ROLES_CON_ACTIVIDADES.includes(d.rol)) {
    if (!d.actividades.length) errores.push("Seleccione al menos una actividad autorizada (17020 §6.1.6)");
    const fecha = d.desde > hoyISO() ? d.desde : hoyISO();
    for (const a of d.actividades) {
      const m = motivoNoPuedeEjercer(b, o, p, a, fecha);
      if (m) errores.push(`${nombreCorto(a)}: ${m}`);
    }
  } else if (d.actividades.length) {
    errores.push("Este rol no lleva actividades autorizadas");
  }
  return errores;
}

// ───────────────────────── Tablero del organismo ─────────────────────────

export type EstadoControl = "cumple" | "alerta" | "incumple";
export type ControlOrganismo = { id: string; numeral: string; titulo: string; estado: EstadoControl; hallazgos: string[] };

const control = (id: string, numeral: string, titulo: string, incumple: string[], alerta: string[] = []): ControlOrganismo => ({
  id, numeral, titulo,
  estado: incumple.length ? "incumple" : alerta.length ? "alerta" : "cumple",
  hallazgos: [...incumple, ...alerta],
});

export function designacionesVigentes(b: BaseOrganismos, organismoId: string, roles: RolOEC[], fecha = hoyISO()) {
  return b.designaciones.filter((d) => d.organismoId === organismoId && roles.includes(d.rol) && vigenteEn(d, fecha));
}

export function evaluarOrganismo(b: BaseOrganismos, o: Organismo, hoy = hoyISO(), plazos = PLAZOS_POR_DEFECTO): ControlOrganismo[] {
  const persona = (id: string) => b.personas.find((p) => p.id === id);
  const lineas = lineasAcreditadas(o);
  const res: ControlOrganismo[] = [];

  // 5.1 Acreditación
  {
    const inc: string[] = [], al: string[] = [];
    if (!o.codigoAcreditacion) inc.push("Sin código de acreditación ONAC registrado");
    if (!o.acreditacionVence) inc.push("Sin fecha de vencimiento de la acreditación");
    else if (o.acreditacionVence < hoy) inc.push(`Acreditación vencida desde ${o.acreditacionVence}`);
    else if (dias(hoy, o.acreditacionVence) <= plazos.alertaAcreditacion)
      al.push(`La acreditación vence en ${dias(hoy, o.acreditacionVence)} días (${o.acreditacionVence})`);
    if (!lineas.length) inc.push("No hay ninguna línea de alcance en estado acreditada");
    res.push(control("O-5.1-01", "5.1", "Acreditación vigente con alcance definido", inc, al));
  }
  {
    const inc: string[] = [], al: string[] = [];
    if (!o.polizaRCVence) inc.push("Sin póliza de responsabilidad civil registrada");
    else if (o.polizaRCVence < hoy) inc.push(`Póliza RC vencida desde ${o.polizaRCVence}`);
    else if (dias(hoy, o.polizaRCVence) <= plazos.alertaAnticipada) al.push(`Póliza RC vence el ${o.polizaRCVence}`);
    res.push(control("O-5.1-02", "5.1", "Póliza de responsabilidad civil vigente", inc, al));
  }
  // 4.1 Tipo A
  res.push(control("O-4.1-01", "4.1 / Anexo A", "Declaración de independencia del organismo tipo A",
    o.declaracionIndependencia ? [] : ["No se ha registrado la declaración de independencia (Anexo A.1)"]));

  // 5.2 Gerencia
  {
    const rl = designacionesVigentes(b, o.id, ["representante_legal"]);
    const ger = designacionesVigentes(b, o.id, ["representante_legal", "gerente", "miembro_gerencia"]);
    const inc: string[] = [];
    if (!rl.length) inc.push("No hay representante legal designado");
    if (!ger.length) inc.push("No hay personas en la gerencia del organismo");
    res.push(control("O-5.2-01", "5.2.1", "Gerencia y representante legal designados", inc));
  }
  // Sistema de gestión
  {
    const sg = designacionesVigentes(b, o.id, ["responsable_sg"]);
    const inc: string[] = [], al: string[] = [];
    if (!sg.length) inc.push("No hay responsable del sistema de gestión vigente");
    if (!designacionesVigentes(b, o.id, ["suplente_sg"]).length) al.push("No hay suplente del responsable del SG para cubrir ausencias");
    res.push(control("O-8-01", "8.1 – 8.8", "Responsable del sistema de gestión designado", inc, al));

    const revs = b.revisionesSG.filter((r) => r.organismoId === o.id).map((r) => r.fecha).sort();
    const ultima = revs.at(-1);
    const inc2: string[] = [], al2: string[] = [];
    if (!ultima) inc2.push("El responsable del SG no ha registrado ninguna revisión");
    else {
      const d = dias(ultima, hoy);
      if (d > plazos.revisionResponsableSG) inc2.push(`Última revisión hace ${d} días (periodicidad ${plazos.revisionResponsableSG} días)`);
      else if (d > plazos.revisionResponsableSG - 7) al2.push(`Próxima revisión antes del ${sumar(ultima, plazos.revisionResponsableSG)}`);
    }
    res.push(control("O-8-02", "8.1 – 8.8", "Revisión continua del responsable del SG", inc2, al2));
  }

  // 5.2.5 / 5.2.6 Dirección técnica por línea
  {
    const dts = designacionesVigentes(b, o.id, ["director_tecnico"]);
    const sup = designacionesVigentes(b, o.id, ["director_tecnico_suplente"]);
    const inc: string[] = [], al: string[] = [];
    for (const a of lineas) {
      const cubre = (ds: Designacion[]) => ds.some((d) => d.actividades.includes(a) && !motivoNoPuedeEjercer(b, o, persona(d.personaId)!, a, hoy));
      if (!cubre(dts)) inc.push(`${nombreCorto(a)}: sin director técnico habilitado`);
      else if (!cubre(sup)) al.push(`${nombreCorto(a)}: sin director técnico suplente`);
    }
    res.push(control("O-5.2-02", "5.2.5 – 5.2.6", "Dirección técnica y suplencia para cada línea acreditada", inc, al));
  }
  // 6.1 Inspectores por línea
  {
    const insp = designacionesVigentes(b, o.id, ["inspector"]);
    const al: string[] = [];
    for (const a of lineas)
      if (!insp.some((d) => d.actividades.includes(a) && !motivoNoPuedeEjercer(b, o, persona(d.personaId)!, a, hoy)))
        al.push(`${nombreCorto(a)}: sin inspector habilitado (no se pueden atender servicios)`);
    res.push(control("O-6.1-01", "6.1", "Inspectores habilitados para cada línea acreditada", [], al));
  }
  // 6.1 Autorizaciones que perdieron soporte (certificado vencido, línea retirada, desvinculación)
  {
    const inc: string[] = [], al: string[] = [];
    for (const d of designacionesVigentes(b, o.id, ROLES_CON_ACTIVIDADES)) {
      const p = persona(d.personaId)!;
      for (const a of d.actividades) {
        const m = motivoNoPuedeEjercer(b, o, p, a, hoy);
        if (m) inc.push(`${nombrePersona(p)} (${NOMBRE_ROL[d.rol]}) — ${nombreCorto(a)}: ${m}`);
        else {
          const c = certificadoVigente(p, a, hoy)!;
          if (dias(hoy, c.fechaVencimiento) <= plazos.alertaAnticipada)
            al.push(`${nombrePersona(p)}: certificado ${c.numero} vence el ${c.fechaVencimiento}`);
        }
      }
    }
    res.push(control("O-6.1-02", "6.1.1 – 6.1.6", "Autorizaciones soportadas por certificado vigente y alcance acreditado", inc, [...new Set(al)]));
  }
  // 6.1 Matrícula profesional
  {
    const inc = [...new Set(designacionesVigentes(b, o.id, ROLES_CON_ACTIVIDADES).map((d) => d.personaId))]
      .map((id) => persona(id)!)
      .filter((p) => !p.matriculaNumero)
      .map((p) => `${nombrePersona(p)}: sin matrícula profesional registrada`);
    res.push(control("O-6.1-03", "6.1", "Matrícula profesional de directores técnicos e inspectores", inc));
  }
  // 4.1 / 4.2 Declaraciones del personal designado
  {
    const inc: string[] = [], al: string[] = [];
    const ids = [...new Set(designacionesVigentes(b, o.id, Object.keys(NOMBRE_ROL) as RolOEC[]).map((d) => d.personaId))];
    for (const id of ids) {
      const p = persona(id)!;
      for (const tipo of ["imparcialidad", "confidencialidad"] as const) {
        const ult = b.declaraciones.filter((x) => x.organismoId === o.id && x.personaId === id && x.tipo === tipo).map((x) => x.fecha).sort().at(-1);
        if (!ult) inc.push(`${nombrePersona(p)}: sin declaración de ${tipo}`);
        else if (tipo === "imparcialidad") {
          const vence = sumar(ult, plazos.vigenciaDeclaraciones);
          if (vence < hoy) inc.push(`${nombrePersona(p)}: declaración de imparcialidad vencida (${ult})`);
          else if (dias(hoy, vence) <= plazos.alertaAnticipada) al.push(`${nombrePersona(p)}: renovar declaración de imparcialidad antes del ${vence}`);
        }
      }
    }
    res.push(control("O-4.1-02", "4.1 / 4.2", "Declaraciones de imparcialidad y confidencialidad del personal", inc, al));
  }
  return res;
}
