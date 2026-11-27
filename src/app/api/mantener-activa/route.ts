/**
 * Mantener activa la base de datos (plan gratuito de Supabase).
 * Supabase pausa los proyectos gratuitos con una semana sin actividad. Vercel llama a esta
 * dirección una vez al día (vercel.json → crons) y aquí se hace una consulta mínima de solo
 * lectura al catálogo de reglamentos. No lee ni escribe datos de personas ni de organismos.
 * Cuando el proyecto pase a un plan de pago (que no se pausa), se puede quitar.
 */
export const dynamic = "force-dynamic";

export async function GET() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const clave = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !clave) return Response.json({ ok: false, motivo: "Sin conexión a Supabase configurada" }, { status: 500 });
  try {
    const r = await fetch(`${url}/rest/v1/reglamentos?select=id&limit=1`, {
      headers: { apikey: clave, Authorization: `Bearer ${clave}` },
      cache: "no-store",
    });
    return Response.json({ ok: r.ok, estado: r.status, hora: new Date().toISOString() }, { status: r.ok ? 200 : 502 });
  } catch (e) {
    return Response.json({ ok: false, motivo: String(e) }, { status: 502 });
  }
}
