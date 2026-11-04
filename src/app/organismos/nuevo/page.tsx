"use client";
import { useRouter } from "next/navigation";
import { FormularioOrganismo } from "@/components/organismo/FormularioOrganismo";
import { useBase } from "@/lib/organismo/almacen";
import { useSesion } from "@/lib/sesion";

export default function NuevoOrganismo() {
  const base = useBase();
  const router = useRouter();
  const sesion = useSesion();
  if (!base) return <p className="suave">Cargando…</p>;
  if (sesion.estado === "con_sesion" && !sesion.esAdminPlataforma)
    return <p className="tarjeta p-4 text-sm">Solo el administrador de la plataforma puede crear organismos.</p>;
  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">Nuevo organismo de inspección</h1>
      <FormularioOrganismo base={base} onGuardado={(id) => router.push(`/organismos/${id}`)} onCancelar={() => router.back()} />
    </div>
  );
}
