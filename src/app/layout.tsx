import type { Metadata, Viewport } from "next";
import "./globals.css";
import { MODO_DEMO } from "@/lib/datos";
import { MarcoSesion } from "@/components/MarcoSesion";
import { NOMBRE_PRODUCTO } from "@/lib/producto";

export const metadata: Metadata = {
  title: NOMBRE_PRODUCTO,
  description: "Gestión del organismo de inspección: inspección RETIE / RETILAP y cumplimiento ISO/IEC 17020",
  manifest: "/manifest.webmanifest",
};

export const viewport: Viewport = { width: "device-width", initialScale: 1, themeColor: "#0D2B35" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="" />
        {/* eslint-disable-next-line @next/next/no-page-custom-font */}
        <link href="https://fonts.googleapis.com/css2?family=Manrope:wght@600;700;800&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet" />
      </head>
      <body className="min-h-screen">
        {MODO_DEMO && (
          <div className="bg-amber-50 px-4 py-1.5 text-center text-xs text-amber-900">
            Modo local: los datos se guardan solo en este navegador hasta conectar la base de datos (Supabase).
          </div>
        )}
        <MarcoSesion>{children}</MarcoSesion>
      </body>
    </html>
  );
}
