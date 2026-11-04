"use client";
import { useState } from "react";
import { Boton, Campo, Entrada, Errores } from "@/components/Formulario";
import { mensajeAuth } from "@/lib/errores";
import { useSesion } from "@/lib/sesion";
import { CON_SUPABASE, supabase } from "@/lib/supabase";

/** Cada usuario cambia su propia contraseña (la que le asignó el administrador). */
export default function Cuenta() {
  const sesion = useSesion();
  const [clave, setClave] = useState("");
  const [repetir, setRepetir] = useState("");
  const [errores, setErrores] = useState<string[]>([]);
  const [listo, setListo] = useState(false);
  const [ocupado, setOcupado] = useState(false);
  if (!CON_SUPABASE) return <p className="suave">Modo local: no hay cuentas de usuario.</p>;
  if (sesion.estado !== "con_sesion") return null;

  const guardar = async () => {
    const e: string[] = [];
    if (clave.length < 8) e.push("Use al menos 8 caracteres");
    if (clave !== repetir) e.push("Las dos contraseñas no coinciden");
    setErrores(e); setListo(false);
    if (e.length) return;
    setOcupado(true);
    const { error } = await supabase().auth.updateUser({ password: clave });
    setOcupado(false);
    if (error) return setErrores([mensajeAuth(error.message)]);
    setClave(""); setRepetir(""); setListo(true);
  };

  return (
    <div className="mx-auto max-w-md space-y-4">
      <h1 className="text-2xl font-bold">Mi cuenta</h1>
      <p className="suave text-sm">Usuario: <b>{sesion.correo}</b></p>
      <form className="tarjeta space-y-3 p-4" onSubmit={(e) => { e.preventDefault(); guardar(); }}>
        <h2 className="font-semibold">Cambiar mi contraseña</h2>
        <p className="suave text-sm">Si el administrador le asignó una contraseña, cámbiela por una que solo usted conozca.</p>
        <Campo etiqueta="Contraseña nueva"><Entrada type="password" autoComplete="new-password" value={clave} onChange={(e) => setClave(e.target.value)} /></Campo>
        <Campo etiqueta="Repita la contraseña nueva"><Entrada type="password" autoComplete="new-password" value={repetir} onChange={(e) => setRepetir(e.target.value)} /></Campo>
        <Errores errores={errores} />
        {listo && <p className="text-sm text-emerald-600">Contraseña cambiada.</p>}
        <Boton type="submit" disabled={ocupado}>{ocupado ? "Guardando…" : "Guardar contraseña"}</Boton>
      </form>
    </div>
  );
}
