"use client";
import { useState } from "react";
import { actualizar, nuevoId } from "@/lib/organismo/almacen";
import type { BaseOrganismos, Persona } from "@/lib/organismo/tipos";
import { Boton, Campo, Entrada, Errores, Selector } from "../Formulario";

type DatosPersona = Omit<Persona, "id" | "certificados" | "creado" | "formacion" | "experiencias">;
const VACIA: DatosPersona = { tipoDocumento: "CC", documento: "", nombres: "", apellidos: "", correo: "", telefono: "", profesion: "", matriculaNumero: "", matriculaEntidad: "", matriculaEspecialidad: "" };

/** Crea o edita los datos básicos de una persona. Devuelve el id guardado. */
export function FormularioPersona({ base, persona, correoFijo, onGuardado, onCancelar }: {
  base: BaseOrganismos; persona?: Persona; onGuardado: (id: string) => void; onCancelar?: () => void;
  /** Para registrarse uno mismo: el correo de inicio de sesión (enlaza la persona al usuario). */
  correoFijo?: string;
}) {
  const [d, setD] = useState<DatosPersona>(() => {
    if (!persona) return { ...VACIA, correo: correoFijo ?? "" };
    const { id: _i, certificados: _c, creado: _r, formacion: _f, experiencias: _e, usuarioId: _u, ...resto } = persona;
    return resto;
  });
  const [errores, setErrores] = useState<string[]>([]);
  const [guardando, setGuardando] = useState(false);
  const set = (k: keyof DatosPersona) => (e: { target: { value: string } }) => setD({ ...d, [k]: e.target.value });

  const guardar = async () => {
    const e: string[] = [];
    if (!d.documento.trim()) e.push("El número de cédula (documento) es obligatorio");
    else if (!/^[0-9A-Za-z]+$/.test(d.documento.trim())) e.push("El documento debe escribirse sin puntos ni espacios");
    if (!d.nombres.trim() || !d.apellidos.trim()) e.push("Nombres y apellidos son obligatorios");
    const dup = base.personas.find((p) => p.documento === d.documento.trim() && p.id !== persona?.id);
    if (dup) e.push(`Ya existe una persona con el documento ${d.documento} (${dup.nombres} ${dup.apellidos})`);
    setErrores(e);
    if (e.length) return;
    const id = persona?.id ?? nuevoId();
    setGuardando(true);
    const error = await actualizar((b) => ({
      ...b,
      personas: persona
        ? b.personas.map((p) => (p.id === id ? { ...p, ...d, documento: d.documento.trim() } : p))
        : [...b.personas, { ...d, documento: d.documento.trim(), id, certificados: [], formacion: [], experiencias: [], creado: new Date().toISOString() }],
    }), { mostrarError: false });
    setGuardando(false);
    if (error) return setErrores([error]);
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
        <Campo etiqueta="Número de cédula / documento"><Entrada value={d.documento} onChange={set("documento")} inputMode="numeric" /></Campo>
      </div>
      <div className="grid gap-3 sm:grid-cols-2">
        <Campo etiqueta="Nombres"><Entrada value={d.nombres} onChange={set("nombres")} /></Campo>
        <Campo etiqueta="Apellidos"><Entrada value={d.apellidos} onChange={set("apellidos")} /></Campo>
        <Campo etiqueta="Correo" ayuda={correoFijo ? "Su correo de ingreso: así la persona queda enlazada a su usuario" : "Con este correo la persona podrá ingresar y quedará enlazada a su cédula"}>
          <Entrada type="email" value={d.correo} onChange={set("correo")} readOnly={!!correoFijo} />
        </Campo>
        <Campo etiqueta="Teléfono"><Entrada type="tel" value={d.telefono} onChange={set("telefono")} /></Campo>
        <Campo etiqueta="Profesión"><Entrada value={d.profesion} onChange={set("profesion")} placeholder="Ingeniero electricista" /></Campo>
        <div className="grid grid-cols-2 gap-3">
          <Campo etiqueta="Matrícula profesional"><Entrada value={d.matriculaNumero} onChange={set("matriculaNumero")} /></Campo>
          <Campo etiqueta="Entidad"><Entrada value={d.matriculaEntidad} onChange={set("matriculaEntidad")} placeholder="CONTE / COPNIA" /></Campo>
        </div>
        <Campo etiqueta="Especialidad de la matrícula" ayuda="La que lo habilita para emitir dictamen pericial (Ley 842 de 2003 / Ley 51 de 1986)">
          <Entrada value={d.matriculaEspecialidad ?? ""} onChange={set("matriculaEspecialidad")} placeholder="Ingeniería eléctrica" />
        </Campo>
      </div>
      <Errores errores={errores} />
      <div className="flex gap-2">
        <Boton onClick={guardar} disabled={guardando}>{guardando ? "Guardando…" : persona ? "Guardar cambios" : "Crear persona"}</Boton>
        {onCancelar && <Boton variante="secundario" onClick={onCancelar}>Cancelar</Boton>}
      </div>
    </div>
  );
}
