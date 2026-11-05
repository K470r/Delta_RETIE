"use client";
import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { useBase } from "@/lib/organismo/almacen";
import { useOrganismoActual } from "@/lib/organismo/actual";

/** Lleva al tablero del organismo con el que se trabaja (o a la lista si aún no hay). */
export default function Inicio() {
  const base = useBase();
  const organismo = useOrganismoActual(base);
  const router = useRouter();
  useEffect(() => {
    if (!base) return;
    router.replace(organismo ? `/organismos/${organismo.id}?p=resumen` : "/seccion/inicio");
  }, [base, organismo, router]);
  return <p className="suave">Cargando…</p>;
}
