/** Íconos de trazo (24×24), uniformes en toda la aplicación. */
export const ICONOS = {
  inicio: "M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z",
  cotizaciones: "M3 7h18v13H3zM8 7V4h8v3M3 13h18",
  ordenes: "M4 5h16v16H4zM4 10h16M8 3v4M16 3v4",
  inspecciones: "M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM20 20l-4-4",
  ia: "M5 9h14v10H5zM12 5v4M9 14h.01M15 14h.01M2 13v3M22 13v3",
  dictamenes: "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM8 12l3 3 5-6",
  quejas: "M3 11v3l12 5V6L3 11zM15 9a3 3 0 0 1 0 6M6 15l1 5h3l-1-4",
  imparcialidad: "M12 3v18M5 21h14M5 7h14M5 7l-3 7a3 3 0 0 0 6 0zM19 7l-3 7a3 3 0 0 0 6 0z",
  organismo: "M4 21V5l8-3 8 3v16M4 21h16M9 9h.01M15 9h.01M9 13h.01M15 13h.01M10 21v-4h4v4",
  personal: "M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM2 21a7 7 0 0 1 14 0M16 3.5a4 4 0 0 1 0 7.5M22 21a7 7 0 0 0-4-6.3",
  equipos: "M12 14l4-4M3.3 17a9 9 0 1 1 17.4 0z",
  gestion: "M3 6a1 1 0 0 1 1-1h5l2 2h9a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z",
  configuracion: "M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6zM12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1 7 17M17 7l2.1-2.1",
  rayo: "M13 2 4 14h7l-1 8 9-12h-7z",
  bombillo: "M9 18h6M10 21h4M12 3a6 6 0 0 0-4 10.5c.8.8 1 1.5 1 2.5h6c0-1 .2-1.7 1-2.5A6 6 0 0 0 12 3z",
  alerta: "M12 3 2 20h20zM12 10v4M12 17h.01",
  campana: "M6 8a6 6 0 0 1 12 0c0 7 3 8 3 8H3s3-1 3-8M10 21h4",
  subir: "M12 16V4M7 9l5-5 5 5M4 20h16",
  menu: "M4 6h16M4 12h16M4 18h16",
  cerrar: "M6 6l12 12M18 6 6 18",
  salir: "M15 4h4a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1h-4M10 17l5-5-5-5M15 12H3",
  usuario: "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21a8 8 0 0 1 16 0",
  mas: "M12 5v14M5 12h14",
  ojo: "M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12zM12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z",
  documento: "M6 2h9l5 5v15H6zM14 2v6h6M9 13h6M9 17h6",
  firma: "M3 17c3-1 4-6 6-6s0 6 2 6 3-4 5-4 2 3 5 3M3 21h18",
  imprimir: "M6 9V3h12v6M6 18H4v-7h16v7h-2M8 14h8v7H8z",
  calendario: "M4 5h16v16H4zM4 10h16M8 3v4M16 3v4M9 15l2 2 4-4",
  construccion: "M2 20h20M6 20V10l6-6 6 6v10M10 20v-5h4v5",
} as const;

export type NombreIcono = keyof typeof ICONOS;

export function Icono({ nombre, tamano = 20, color = "currentColor", grosor = 1.9, className }: {
  nombre: NombreIcono; tamano?: number; color?: string; grosor?: number; className?: string;
}) {
  return (
    <svg width={tamano} height={tamano} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={grosor}
      strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" className={className}>
      <path d={ICONOS[nombre]} />
    </svg>
  );
}
