/**
 * Almacenamiento local (IndexedDB) para trabajar sin conexión en sitio.
 * Los registros se sincronizan con el servidor cuando vuelve la señal.
 */
import { openDB, type IDBPDatabase } from "idb";

export type Resultado = "C" | "NC" | "NA";

export type RespuestaItem = {
  resultado?: Resultado;
  observacion?: string;
  evidencias: string[]; // ids en el almacén "evidencias"
  actualizado: string;
};

export type BorradorInspeccion = {
  ordenId: string;
  respuestas: Record<string, RespuestaItem>;
  equiposUsados: string[];
  ubicacion?: { lat: number; lon: number; precision: number; fecha: string };
  estado: "borrador" | "lista_para_revision";
  actualizado: string;
};

export type Evidencia = {
  id: string;
  ordenId: string;
  itemCodigo: string;
  tipo: string;
  nombre: string;
  datos: Blob;
  tomada: string;
};

let db: Promise<IDBPDatabase> | null = null;
function abrir() {
  db ??= openDB("delta-retie", 1, {
    upgrade(base) {
      base.createObjectStore("inspecciones", { keyPath: "ordenId" });
      const ev = base.createObjectStore("evidencias", { keyPath: "id" });
      ev.createIndex("porOrden", "ordenId");
    },
  });
  return db;
}

export async function leerBorrador(ordenId: string): Promise<BorradorInspeccion | undefined> {
  return (await abrir()).get("inspecciones", ordenId);
}

export async function guardarBorrador(b: BorradorInspeccion) {
  await (await abrir()).put("inspecciones", { ...b, actualizado: new Date().toISOString() });
}

export async function guardarEvidencia(e: Evidencia) {
  await (await abrir()).put("evidencias", e);
}

export async function leerEvidencia(id: string): Promise<Evidencia | undefined> {
  return (await abrir()).get("evidencias", id);
}

export async function borrarEvidencia(id: string) {
  await (await abrir()).delete("evidencias", id);
}
