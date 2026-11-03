import type { Metadata, Viewport } from "next";
import Link from "next/link";
import "./globals.css";
import { MODO_DEMO } from "@/lib/datos";

export const metadata: Metadata = {
  title: "Delta RETIE",
  description: "Gestión del OEC: cotización, inspección RETIE y cumplimiento ISO/IEC 17020",
  manifest: "/manifest.webmanifest",
};

export const viewport: Viewport = { width: "device-width", initialScale: 1, themeColor: "#0b5cad" };

const MENU = [
  { href: "/", texto: "Tablero 17020" },
  { href: "/ordenes", texto: "Órdenes de servicio" },
  { href: "/recursos", texto: "Personal y equipos" },
];

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es">
      <body className="min-h-screen">
        <header className="border-b" style={{ borderColor: "var(--borde)", background: "var(--tarjeta)" }}>
          <div className="mx-auto flex max-w-6xl flex-wrap items-center gap-x-6 gap-y-2 px-4 py-3">
            <Link href="/" className="text-lg font-bold marca">Delta RETIE</Link>
            <nav className="flex flex-wrap gap-4 text-sm">
              {MENU.map((m) => (
                <Link key={m.href} href={m.href} className="hover:underline">{m.texto}</Link>
              ))}
            </nav>
          </div>
        </header>
        {MODO_DEMO && (
          <div className="bg-amber-50 px-4 py-1.5 text-center text-xs text-amber-900 dark:bg-amber-950 dark:text-amber-200">
            Modo demostración: datos de ejemplo almacenados localmente.
          </div>
        )}
        <main className="mx-auto max-w-6xl px-4 py-6">{children}</main>
      </body>
    </html>
  );
}
