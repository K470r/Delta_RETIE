"use client";
import { useRouter } from "next/navigation";
import { FormularioOrganismo } from "@/components/organismo/FormularioOrganismo";
import { useBase } from "@/lib/organismo/almacen";

export default function NuevoOrganismo() {
  const base = useBase();
  const router = useRouter();
  if (!base) return <p className="suave">Cargando…</p>;
  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">Nuevo organismo de inspección</h1>
      <FormularioOrganismo base={base} onGuardado={(id) => router.push(`/organismos/${id}`)} onCancelar={() => router.back()} />
    </div>
  );
}
