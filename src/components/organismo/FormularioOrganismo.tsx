"use client";
import { useState } from "react";
import { ACTIVIDADES } from "@/lib/catalogo";
import { actualizar, nuevoId } from "@/lib/organismo/almacen";
import { hoyISO } from "@/lib/organismo/reglas";
import type { BaseOrganismos, Organismo } from "@/lib/organismo/tipos";
import { Boton, Campo, Entrada, Errores } from "../Formulario";
import { SelectorActividades } from "../SelectorActividades";

type Datos = Omit<Organismo, "id" | "creado" | "sedes" | "alcance" | "tipo">;

/** Crea un organismo con su alcance acreditado, o edita sus datos generales. */
export function FormularioOrganismo({ base, organismo, onGuardado, onCancelar }: {
  base: BaseOrganismos; organismo?: Organismo; onGuardado: (id: string) => void; onCancelar?: () => void;
}) {
  const [d, setD] = useState<Datos>(organismo ?? { razonSocial: "", nit: "" });
  const [sede, setSede] = useState({ nombre: "Sede principal", direccion: "", ciudad: "" });
  const [alcance, setAlcance] = useState<string[]>([]);
  const [errores, setErrores] = useState<string[]>([]);
  const set = (k: keyof Datos) => (e: { target: { value: string } }) => setD({ ...d, [k]: e.target.value || undefined });

  const guardar = () => {
    const e: string[] = [];
    if (!d.razonSocial?.trim()) e.push("La razón social es obligatoria");
    if (!d.nit?.trim()) e.push("El NIT es obligatorio");
    if (base.organismos.some((o) => o.nit === d.nit?.trim() && o.id !== organismo?.id)) e.push("Ya existe un organismo con ese NIT");
    if (d.acreditacionOtorgada && d.acreditacionVence && d.acreditacionVence <= d.acreditacionOtorgada)
      e.push("El vencimiento de la acreditación debe ser posterior al otorgamiento");
    if (!organismo && !alcance.length) e.push("Seleccione al menos una actividad del alcance acreditado");
    setErrores(e);
    if (e.length) return;

    const id = organismo?.id ?? nuevoId();
    actualizar((b) => ({
      ...b,
      organismos: organismo
        ? b.organismos.map((o) => (o.id === id ? { ...o, ...d } : o))
        : [...b.organismos, {
            ...d, id, tipo: "A", creado: new Date().toISOString(),
            sedes: [{ id: nuevoId(), ...sede, principal: true }],
            alcance: alcance.map((a) => ({ actividad: a, estado: "acreditada", fechaEstado: d.acreditacionOtorgada ?? hoyISO() })),
          }],
    }));
    onGuardado(id);
  };

  return (
    <div className="space-y-6">
      <section className="tarjeta space-y-3 p-4">
        <h2 className="font-semibold">Datos del organismo</h2>
        <div className="grid gap-3 sm:grid-cols-2">
          <Campo etiqueta="Razón social"><Entrada value={d.razonSocial ?? ""} onChange={set("razonSocial")} /></Campo>
          <div className="grid grid-cols-2 gap-3">
            <Campo etiqueta="NIT"><Entrada value={d.nit ?? ""} onChange={set("nit")} /></Campo>
            <Campo etiqueta="Sigla"><Entrada value={d.sigla ?? ""} onChange={set("sigla")} /></Campo>
          </div>
          <Campo etiqueta="Dirección"><Entrada value={d.direccion ?? ""} onChange={set("direccion")} /></Campo>
          <Campo etiqueta="Ciudad"><Entrada value={d.ciudad ?? ""} onChange={set("ciudad")} /></Campo>
          <Campo etiqueta="Teléfono"><Entrada type="tel" value={d.telefono ?? ""} onChange={set("telefono")} /></Campo>
          <Campo etiqueta="Correo"><Entrada type="email" value={d.correo ?? ""} onChange={set("correo")} /></Campo>
        </div>
        <p className="suave text-xs">Tipo de organismo: <b>A</b> (independiente de las partes involucradas — ISO/IEC 17020 Anexo A.1).</p>
      </section>

      <section className="tarjeta space-y-3 p-4">
        <h2 className="font-semibold">Acreditación ONAC (17020 §5.1)</h2>
        <div className="grid gap-3 sm:grid-cols-3">
          <Campo etiqueta="Código de acreditación"><Entrada value={d.codigoAcreditacion ?? ""} onChange={set("codigoAcreditacion")} placeholder="15-OIN-000" /></Campo>
          <Campo etiqueta="Fecha de otorgamiento"><Entrada type="date" value={d.acreditacionOtorgada ?? ""} onChange={set("acreditacionOtorgada")} /></Campo>
          <Campo etiqueta="Fecha de vencimiento"><Entrada type="date" value={d.acreditacionVence ?? ""} onChange={set("acreditacionVence")} /></Campo>
          <Campo etiqueta="Póliza RC — número"><Entrada value={d.polizaRCNumero ?? ""} onChange={set("polizaRCNumero")} /></Campo>
          <Campo etiqueta="Póliza RC — vence"><Entrada type="date" value={d.polizaRCVence ?? ""} onChange={set("polizaRCVence")} /></Campo>
          <Campo etiqueta="Declaración de independencia (tipo A)" ayuda="Fecha del documento firmado por la gerencia">
            <Entrada type="date" value={d.declaracionIndependencia ?? ""} onChange={set("declaracionIndependencia")} />
          </Campo>
        </div>
      </section>

      {!organismo && (
        <>
          <section className="tarjeta space-y-3 p-4">
            <h2 className="font-semibold">Sede principal</h2>
            <div className="grid gap-3 sm:grid-cols-3">
              <Campo etiqueta="Nombre"><Entrada value={sede.nombre} onChange={(e) => setSede({ ...sede, nombre: e.target.value })} /></Campo>
              <Campo etiqueta="Dirección"><Entrada value={sede.direccion} onChange={(e) => setSede({ ...sede, direccion: e.target.value })} /></Campo>
              <Campo etiqueta="Ciudad"><Entrada value={sede.ciudad} onChange={(e) => setSede({ ...sede, ciudad: e.target.value })} /></Campo>
            </div>
          </section>
          <section className="tarjeta space-y-3 p-4">
            <div>
              <h2 className="font-semibold">Alcance acreditado</h2>
              <p className="suave text-sm">
                Marque las actividades de su certificado de acreditación. Catálogo tomado de ONAC NTE-3.3-88 (RETIE 2024) y NTE-3.3-89 (RETILAP 2024).
              </p>
            </div>
            <SelectorActividades actividades={ACTIVIDADES} seleccion={alcance} onCambio={setAlcance} />
          </section>
        </>
      )}

      <Errores errores={errores} />
      <div className="flex gap-2">
        <Boton onClick={guardar}>{organismo ? "Guardar cambios" : "Crear organismo"}</Boton>
        {onCancelar && <Boton variante="secundario" onClick={onCancelar}>Cancelar</Boton>}
      </div>
    </div>
  );
}
