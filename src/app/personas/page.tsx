"use client";
import { useState } from "react";
import { FormularioPersona } from "@/components/organismo/FormularioPersona";
import { HojaDeVida } from "@/components/organismo/HojaDeVida";
import { Boton, Entrada } from "@/components/Formulario";
import { useBase } from "@/lib/organismo/almacen";
import { hoyISO, nombrePersona, vigenteEn } from "@/lib/organismo/reglas";
import { NOMBRE_ROL } from "@/lib/organismo/tipos";

export default function Personas() {
  const base = useBase();
  const [filtro, setFiltro] = useState("");
  const [creando, setCreando] = useState(false);
  const [editando, setEditando] = useState<string | null>(null);
  const [abierta, setAbierta] = useState<string | null>(null);
  if (!base) return <p className="suave">Cargando…</p>;
  const hoy = hoyISO();
  const lista = base.personas.filter((p) => `${p.nombres} ${p.apellidos} ${p.documento}`.toLowerCase().includes(filtro.toLowerCase()));

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
                      {p.matriculaNumero ? ` · Matrícula ${p.matriculaNumero} ${p.matriculaEntidad ?? ""}${p.matriculaEspecialidad ? ` (${p.matriculaEspecialidad})` : ""}` : " · sin matrícula registrada"}
                    </div>
                    {designaciones.map((d) => (
                      <div key={d.id} className="text-xs">
                        {NOMBRE_ROL[d.rol]} en <b>{base.organismos.find((o) => o.id === d.organismoId)?.razonSocial}</b>
                      </div>
                    ))}
                  </div>
                  <Boton variante="contorno" tamano="pequeno" onClick={() => setEditando(p.id)}>Editar</Boton>
                </div>
              )}
              <details open={abierta === p.id} onToggle={(e) => { if ((e.target as HTMLDetailsElement).open) setAbierta(p.id); }}>
                <summary className="cursor-pointer text-sm font-semibold marca">
                  Hoja de vida técnica · {p.certificados.filter((c) => !c.anulado).length} certificado(s) · {p.experiencias.length} experiencia(s)
                </summary>
                <div className="mt-3"><HojaDeVida persona={p} /></div>
              </details>
            </article>
          );
        })}
      </div>
    </div>
  );
}
