import f229 from "@datos/formatos/F229.json";

export type ItemFormato = {
  tipo: "item";
  codigo: string;
  articulo: string;
  requisito: string;
  aspecto: string;
  actividad: string;
  descripcion: string;
};
export type SeccionFormato = { tipo: "seccion"; titulo: string };
export type Formato = {
  codigo_formato: string;
  version: string;
  /** Versión del reglamento al que corresponde la lista (RETIE 2024, RETIE 2026...). */
  reglamento: string;
  items: (ItemFormato | SeccionFormato)[];
};

const FORMATOS: Record<string, Formato> = {
  "F-229-D": { ...(f229 as Omit<Formato, "reglamento">), reglamento: "RETIE 2024" },
};

export function obtenerFormato(codigo: string): Formato | undefined {
  return FORMATOS[codigo];
}
