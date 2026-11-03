"use client";
import { useState } from "react";
import { ACTIVIDADES } from "@/lib/catalogo";
import { actualizar, nuevoId } from "@/lib/organismo/almacen";
import { hoyISO } from "@/lib/organismo/reglas";
import type { BaseOrganismos, CertificadoCompetencia, Persona } from "@/lib/organismo/tipos";
import { Boton, Campo, Entrada, Errores, Grupo, Selector } from "../Formulario";
import { SelectorActividades } from "../SelectorActividades";

type DatosPersona = Omit<Persona, "id" | "certificados" | "creado">;
const VACIA: DatosPersona = { tipoDocumento: "CC", documento: "", nombres: "", apellidos: "", correo: "", telefono: "", profesion: "", matriculaNumero: "", matriculaEntidad: "" };

/** Crea o edita los datos básicos de una persona. Devuelve el id guardado. */
export function FormularioPersona({ base, persona, onGuardado, onCancelar }: {
  base: BaseOrganismos; persona?: Persona; onGuardado: (id: string) => void; onCancelar?: () => void;
}) {
  const [d, setD] = useState<DatosPersona>(persona ?? VACIA);
  const [errores, setErrores] = useState<string[]>([]);
  const set = (k: keyof DatosPersona) => (e: { target: { value: string } }) => setD({ ...d, [k]: e.target.value });

  const guardar = () => {
    const e: string[] = [];
    if (!d.documento.trim()) e.push("El documento es obligatorio");
    if (!d.nombres.trim() || !d.apellidos.trim()) e.push("Nombres y apellidos son obligatorios");
    const dup = base.personas.find((p) => p.documento === d.documento.trim() && p.id !== persona?.id);
    if (dup) e.push(`Ya existe una persona con el documento ${d.documento} (${dup.nombres} ${dup.apellidos})`);
    setErrores(e);
    if (e.length) return;
    const id = persona?.id ?? nuevoId();
    actualizar((b) => ({
      ...b,
      personas: persona
        ? b.personas.map((p) => (p.id === id ? { ...p, ...d, documento: d.documento.trim() } : p))
        : [...b.personas, { ...d, documento: d.documento.trim(), id, certificados: [], creado: new Date().toISOString() }],
    }));
    onGuardado(id);
  };

  return (
    <div className="space-y-3">
      <div className="grid gap-3 sm:grid-cols-[8rem_1fr]">
        <Campo etiqueta="Tipo doc.">
          <Selector value={d.tipoDocumento} onChange={set("tipoDocumento")}>
            <option value="CC">CC</option><option value="CE">CE</option><option value="PA">PA</option><option value="PPT">PPT</option>
          </Selector>
        </Campo>
        <Campo etiqueta="Número de documento"><Entrada value={d.documento} onChange={set("documento")} inputMode="numeric" /></Campo>
      </div>
      <div className="grid gap-3 sm:grid-cols-2">
        <Campo etiqueta="Nombres"><Entrada value={d.nombres} onChange={set("nombres")} /></Campo>
        <Campo etiqueta="Apellidos"><Entrada value={d.apellidos} onChange={set("apellidos")} /></Campo>
        <Campo etiqueta="Correo"><Entrada type="email" value={d.correo} onChange={set("correo")} /></Campo>
        <Campo etiqueta="Teléfono"><Entrada type="tel" value={d.telefono} onChange={set("telefono")} /></Campo>
        <Campo etiqueta="Profesión"><Entrada value={d.profesion} onChange={set("profesion")} placeholder="Ingeniero electricista" /></Campo>
        <div className="grid grid-cols-2 gap-3">
          <Campo etiqueta="Matrícula profesional"><Entrada value={d.matriculaNumero} onChange={set("matriculaNumero")} /></Campo>
          <Campo etiqueta="Entidad"><Entrada value={d.matriculaEntidad} onChange={set("matriculaEntidad")} placeholder="CONTE / COPNIA" /></Campo>
        </div>
      </div>
      <Errores errores={errores} />
      <div className="flex gap-2">
        <Boton onClick={guardar}>{persona ? "Guardar cambios" : "Crear persona"}</Boton>
        {onCancelar && <Boton variante="secundario" onClick={onCancelar}>Cancelar</Boton>}
      </div>
    </div>
  );
}

/** Registra un certificado de competencias (ISO/IEC 17024) con las actividades que cubre. */
export function FormularioCertificado({ personaId, onGuardado, onCancelar, sugeridas = [] }: {
  personaId: string; onGuardado?: () => void; onCancelar?: () => void; sugeridas?: string[];
}) {
  const [c, setC] = useState<Omit<CertificadoCompetencia, "id" | "anulado">>({
    numero: "", certificador: "", fechaEmision: hoyISO(), fechaVencimiento: "", actividades: sugeridas,
  });
  const [errores, setErrores] = useState<string[]>([]);

  const guardar = () => {
    const e: string[] = [];
    if (!c.numero.trim()) e.push("Número del certificado obligatorio");
    if (!c.certificador.trim()) e.push("Indique el organismo de certificación de personas que lo emitió");
    if (!c.fechaVencimiento) e.push("Fecha de vencimiento obligatoria");
    else if (c.fechaVencimiento <= c.fechaEmision) e.push("El vencimiento debe ser posterior a la emisión");
    if (!c.actividades.length) e.push("Seleccione las actividades que cubre el certificado");
    setErrores(e);
    if (e.length) return;
    actualizar((b) => ({
      ...b,
      personas: b.personas.map((p) => (p.id === personaId
        ? { ...p, certificados: [...p.certificados, { ...c, id: nuevoId(), anulado: false }] } : p)),
    }));
    onGuardado?.();
  };

  return (
    <div className="space-y-3 rounded-lg border p-3" style={{ borderColor: "var(--borde)" }}>
      <div className="text-sm font-semibold">Certificado de competencias</div>
      <div className="grid gap-3 sm:grid-cols-2">
        <Campo etiqueta="Número"><Entrada value={c.numero} onChange={(e) => setC({ ...c, numero: e.target.value })} /></Campo>
        <Campo etiqueta="Organismo certificador (ISO/IEC 17024)"><Entrada value={c.certificador} onChange={(e) => setC({ ...c, certificador: e.target.value })} /></Campo>
        <Campo etiqueta="Fecha de emisión"><Entrada type="date" value={c.fechaEmision} onChange={(e) => setC({ ...c, fechaEmision: e.target.value })} /></Campo>
        <Campo etiqueta="Fecha de vencimiento"><Entrada type="date" value={c.fechaVencimiento} onChange={(e) => setC({ ...c, fechaVencimiento: e.target.value })} /></Campo>
      </div>
      <Grupo etiqueta="Actividades que cubre">
        <div className="max-h-96 overflow-y-auto pr-1">
          <SelectorActividades actividades={ACTIVIDADES} seleccion={c.actividades} onCambio={(a) => setC({ ...c, actividades: a })} />
        </div>
      </Grupo>
      <Errores errores={errores} />
      <div className="flex gap-2">
        <Boton onClick={guardar}>Guardar certificado</Boton>
        {onCancelar && <Boton variante="secundario" onClick={onCancelar}>Cancelar</Boton>}
      </div>
    </div>
  );
}
