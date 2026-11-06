"use client";
/**
 * Motivo por el que algo no se cumple, como enlace a la parte de la hoja de vida donde se
 * carga o se diligencia lo que falta (matrícula, certificados, experiencia o formación).
 */
import Link from "next/link";

export function seccionDeMotivo(texto: string): string | undefined {
  const t = texto.toLowerCase();
  if (t.includes("matrícula")) return "matricula";
  if (t.includes("experiencia")) return "experiencias";
  if (t.includes("certificado") || t.includes("seguimiento")) return "certificados";
  if (t.includes("posgrado") || t.includes("profundización") || t.includes("formación")) return "formacion";
  return undefined;
}

export function EnlaceMotivo({ personaId, texto, className = "", seccion: dada }: { personaId?: string; texto: string; className?: string; seccion?: string }) {
  const seccion = dada ?? seccionDeMotivo(texto);
  if (!personaId || !seccion) return <span className={className}>{texto}</span>;
  const volver = typeof window === "undefined" ? "" : `&volver=${encodeURIComponent(window.location.pathname + window.location.search)}`;
  return (
    <Link href={`/mi-hoja-de-vida?persona=${personaId}&seccion=${seccion}${volver}`} scroll={false}
      className={`${className.replace(/text-red-\d+/g, "")} enlace-motivo`}
      title="Ir a la hoja de vida para cargar o diligenciar lo que falta">
      {texto} <span className="whitespace-nowrap">→ Completar</span>
    </Link>
  );
}
