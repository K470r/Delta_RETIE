"use client";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useState } from "react";
import { Boton, Campo, Entrada, Errores } from "@/components/Formulario";
import { mensajeAuth } from "@/lib/errores";
import { useSesion } from "@/lib/sesion";
import { CON_SUPABASE, supabase } from "@/lib/supabase";

export default function Ingresar() {
  return <Suspense><Formulario /></Suspense>;
}

/** Errores que Supabase devuelve en la dirección cuando el enlace falla (#error=...). */
function errorEnDireccion(): string | null {
  if (typeof window === "undefined") return null;
  const p = new URLSearchParams(window.location.hash.slice(1) || window.location.search.slice(1));
  const d = p.get("error_description") ?? p.get("error");
  return d ? mensajeAuth(d.replace(/\+/g, " ")) : null;
}

function Formulario() {
  const sesion = useSesion();
  const router = useRouter();
  const volver = useSearchParams().get("volver") || "/inicio";
  const [correo, setCorreo] = useState("");
  const [codigo, setCodigo] = useState("");
  const [clave, setClave] = useState("");
  const [modo, setModo] = useState<"clave" | "enlace">("clave");
  const [enviado, setEnviado] = useState(false);
  const [ocupado, setOcupado] = useState(false);
  const [errores, setErrores] = useState<string[]>([]);

  useEffect(() => {
    const e = errorEnDireccion();
    if (e) setErrores([e]);
  }, []);

  useEffect(() => {
    if (sesion.estado === "con_sesion" || sesion.estado === "local") router.replace(volver.startsWith("/") ? volver : "/inicio");
  }, [sesion.estado, router, volver]);

  if (!CON_SUPABASE) return <p className="suave">Modo local: no se requiere iniciar sesión.</p>;
  if (sesion.estado === "con_sesion") return <p className="suave">Ingresando…</p>;

  const enviar = async () => {
    const c = correo.trim().toLowerCase();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(c)) return setErrores(["Escriba un correo válido"]);
    setOcupado(true); setErrores([]);
    const { error } = await supabase().auth.signInWithOtp({
      email: c,
      options: { emailRedirectTo: `${window.location.origin}/ingresar?volver=${encodeURIComponent(volver)}`, shouldCreateUser: false },
    });
    setOcupado(false);
    if (error) return setErrores([mensajeAuth(error.message)]);
    setCorreo(c);
    setEnviado(true);
  };

  const conClave = async () => {
    const c = correo.trim().toLowerCase();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(c)) return setErrores(["Escriba un correo válido"]);
    if (!clave) return setErrores(["Escriba su contraseña"]);
    setOcupado(true); setErrores([]);
    const { error } = await supabase().auth.signInWithPassword({ email: c, password: clave });
    setOcupado(false);
    if (error) setErrores([mensajeAuth(error.message)]);
  };

  const verificar = async () => {
    const t = codigo.replace(/\s/g, "");
    if (!/^\d{6,10}$/.test(t)) return setErrores(["El código son los números que llegaron en el correo"]);
    setOcupado(true); setErrores([]);
    const { error } = await supabase().auth.verifyOtp({ email: correo, token: t, type: "email" });
    setOcupado(false);
    if (error) setErrores([mensajeAuth(error.message)]);
  };

  return (
    <div className="mx-auto max-w-md space-y-4">
      <h1 className="text-2xl font-bold">Ingresar</h1>
      {modo === "clave" ? (
        <form className="tarjeta space-y-3 p-4" onSubmit={(e) => { e.preventDefault(); conClave(); }}>
          <Campo etiqueta="Correo electrónico">
            <Entrada type="email" autoComplete="email" value={correo} onChange={(e) => setCorreo(e.target.value)} placeholder="nombre@empresa.com" autoFocus />
          </Campo>
          <Campo etiqueta="Contraseña">
            <Entrada type="password" autoComplete="current-password" value={clave} onChange={(e) => setClave(e.target.value)} />
          </Campo>
          <Errores errores={errores} />
          <div className="flex flex-wrap items-center gap-3">
            <Boton type="submit" disabled={ocupado}>{ocupado ? "Ingresando…" : "Ingresar"}</Boton>
            <button type="button" className="suave text-sm underline" onClick={() => { setModo("enlace"); setErrores([]); }}>
              No tengo contraseña: enviarme un enlace al correo
            </button>
          </div>
        </form>
      ) : !enviado ? (
        <form className="tarjeta space-y-3 p-4" onSubmit={(e) => { e.preventDefault(); enviar(); }}>
          <p className="suave text-sm">Sin contraseña: le enviaremos un enlace a su correo.</p>
          <Campo etiqueta="Correo electrónico">
            <Entrada type="email" autoComplete="email" value={correo} onChange={(e) => setCorreo(e.target.value)} placeholder="nombre@empresa.com" autoFocus />
          </Campo>
          <Errores errores={errores} />
          <button type="button" className="suave block text-sm underline" onClick={() => { setModo("clave"); setErrores([]); }}>Ingresar con contraseña</button>
          <Boton type="submit" disabled={ocupado}>{ocupado ? "Enviando…" : "Enviarme el enlace"}</Boton>
        </form>
      ) : (
        <form className="tarjeta space-y-3 p-4" onSubmit={(e) => { e.preventDefault(); verificar(); }}>
          <p className="text-sm">Enviamos un correo a <b>{correo}</b>.</p>
          <ol className="list-decimal space-y-1 pl-5 text-sm">
            <li>Abra el correo <b>en este mismo equipo y navegador</b> (revise también <i>spam</i> o <i>promociones</i>).</li>
            <li>Haga clic en el enlace. Entrará automáticamente; puede cerrar esta pestaña.</li>
          </ol>
          <p className="suave text-xs">Cada enlace sirve una sola vez y vence en una hora: use siempre el correo más reciente.</p>
          <details className="text-sm">
            <summary className="suave cursor-pointer">¿El correo trae un código de números?</summary>
            <div className="mt-2 space-y-2">
              <Campo etiqueta="Código del correo">
                <Entrada inputMode="numeric" autoComplete="one-time-code" value={codigo} onChange={(e) => setCodigo(e.target.value)} placeholder="123456" />
              </Campo>
              <Boton type="submit" disabled={ocupado}>{ocupado ? "Verificando…" : "Ingresar con el código"}</Boton>
            </div>
          </details>
          <Errores errores={errores} />
          <Boton variante="secundario" onClick={() => { setEnviado(false); setCodigo(""); setErrores([]); }}>Usar otro correo</Boton>
        </form>
      )}
    </div>
  );
}
