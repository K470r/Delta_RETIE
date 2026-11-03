"use client";
import { useState } from "react";
import { FormularioCertificado, FormularioPersona } from "@/components/organismo/FormularioPersona";
import { Boton, Entrada } from "@/components/Formulario";
import { nombreCorto } from "@/lib/catalogo";
import { actualizar, useBase } from "@/lib/organismo/almacen";
import { hoyISO, nombrePersona, vigenteEn } from "@/lib/organismo/reglas";
import { NOMBRE_ROL } from "@/lib/organismo/tipos";

export default function Personas() {
  const base = useBase();
  const [filtro, setFiltro] = useState("");
  const [creando, setCreando] = useState(false);
  const [editando, setEditando] = useState<string | null>(null);
  const [certPara, setCertPara] = useState<string | null>(null);
  if (!base) return <p className="suave">Cargando…</p>;
  const hoy = hoyISO();
  const lista = base.personas.filter((p) => `${p.nombres} ${p.apellidos} ${p.documento}`.toLowerCase().includes(filtro.toLowerCase()));

  const anular = (personaId: string, certId: string) => {
    if (!confirm("¿Anular este certificado? Quedará en el historial pero dejará de habilitar actividades.")) return;
    actualizar((b) => ({ ...b, personas: b.personas.map((p) => p.id === personaId
      ? { ...p, certificados: p.certificados.map((c) => (c.id === certId ? { ...c, anulado: true } : c)) } : p) }));
  };

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h1 className="text-2xl font-bold">Personas</h1>
          <p className="suave text-sm">Directorio único de personas y sus certificados de competencias. Una persona puede estar vinculada a uno o varios organismos.</p>
        </div>
        {!creando && <Boton onClick={() => setCreando(true)}>+ Nueva persona</Boton>}
      </div>
      {creando && (
        <div className="tarjeta p-4"><FormularioPersona base={base} onGuardado={() => setCreando(false)} onCancelar={() => setCreando(false)} /></div>
      )}
      <Entrada placeholder="Buscar por nombre o documento…" value={filtro} onChange={(e) => setFiltro(e.target.value)} />
      <div className="grid gap-3">
        {lista.map((p) => {
          const designaciones = base.designaciones.filter((d) => d.personaId === p.id && vigenteEn(d, hoy));
          return (
            <article key={p.id} className="tarjeta space-y-3 p-4">
              {editando === p.id ? (
                <FormularioPersona base={base} persona={p} onGuardado={() => setEditando(null)} onCancelar={() => setEditando(null)} />
              ) : (
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div>
                    <div className="font-semibold">{nombrePersona(p)}</div>
                    <div className="suave text-sm">
                      {p.tipoDocumento} {p.documento}{p.profesion && ` · ${p.profesion}`}
                      {p.matriculaNumero ? ` · Matrícula ${p.matriculaNumero} ${p.matriculaEntidad ?? ""}` : " · sin matrícula registrada"}
                    </div>
                    {designaciones.map((d) => (
                      <div key={d.id} className="text-xs">
                        {NOMBRE_ROL[d.rol]} en <b>{base.organismos.find((o) => o.id === d.organismoId)?.razonSocial}</b>
                      </div>
                    ))}
                  </div>
                  <Boton variante="secundario" onClick={() => setEditando(p.id)}>Editar</Boton>
                </div>
              )}
              <div className="space-y-2">
                <div className="text-sm font-semibold">Certificados de competencias</div>
                {p.certificados.length === 0 && <p className="suave text-sm">Sin certificados registrados.</p>}
                {p.certificados.map((c) => {
                  const vencido = c.fechaVencimiento < hoy;
                  return (
                    <div key={c.id} className={`rounded-lg border p-3 text-sm ${c.anulado ? "opacity-50" : ""}`} style={{ borderColor: "var(--borde)" }}>
                      <div className="flex flex-wrap items-start justify-between gap-2">
                        <div>
                          <b>{c.numero}</b> · {c.certificador}
                          <span className={`block text-xs ${vencido ? "font-semibold text-red-600" : "suave"}`}>
                            {c.anulado ? "Anulado · " : ""}Emitido {c.fechaEmision} · {vencido ? "Vencido" : "Vence"} {c.fechaVencimiento}
                          </span>
                        </div>
                        {!c.anulado && <button className="text-xs text-red-600 underline" onClick={() => anular(p.id, c.id)}>Anular</button>}
                      </div>
                      <ul className="suave mt-1 list-disc pl-5 text-xs">
                        {c.actividades.map((a) => <li key={a}>{nombreCorto(a)}</li>)}
                      </ul>
                    </div>
                  );
                })}
                {certPara === p.id ? (
                  <FormularioCertificado personaId={p.id} onGuardado={() => setCertPara(null)} onCancelar={() => setCertPara(null)} />
                ) : (
                  <button className="text-sm underline marca" onClick={() => setCertPara(p.id)}>+ Agregar certificado</button>
                )}
              </div>
            </article>
          );
        })}
      </div>
    </div>
  );
}
