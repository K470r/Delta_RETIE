# Delta RETIE

Plataforma web del Organismo de Evaluación de la Conformidad (OEC) para
**cotizar, aprobar, asignar, inspeccionar, revisar y entregar dictámenes RETIE**,
manteniendo bajo control el cumplimiento de **ISO/IEC 17020:2012**.

Funciona en cualquier navegador (PC, tablet, teléfono) y se puede instalar como
aplicación (PWA). La inspección en sitio trabaja **sin conexión**: los datos y
evidencias se guardan en el dispositivo y se sincronizan al volver la señal.

## Qué hay hoy (Fase 1 — base)

| Módulo | Ruta | Estado |
|---|---|---|
| Tablero de cumplimiento 17020 (25 controles automáticos) | `/` | ✅ |
| Matriz por numeral con hallazgos | `/cumplimiento` | ✅ |
| Órdenes de servicio y su flujo | `/ordenes` | ✅ (lectura) |
| Inspección en sitio F-229 (C/NC/NA, observaciones, fotos/video/audio, GPS, equipos) | `/inspeccion/[orden]` | ✅ sin conexión |
| Personal y equipos | `/recursos` | ✅ (lectura) |
| Esquema de base de datos con reglas 17020 | `supabase/migrations` | ✅ probado |

Mientras no se configure Supabase, la aplicación corre en **modo demostración**
con datos de ejemplo (`src/lib/demo.ts`).

## Cómo funciona el control 17020

El cumplimiento se controla en tres niveles:

1. **Bloqueo en la base de datos** — reglas que no se pueden saltar
   (`supabase/migrations/0001_esquema_base.sql`):
   - No se asigna un inspector sin revisión de la solicitud (§7.1), sin autorización
     para el alcance (§6.1) o con conflicto de interés declarado (§4.1).
   - No se registra un equipo con calibración vencida (§6.2).
   - Toda NC requiere descripción del hallazgo (§7.3).
   - El dictamen lo revisa una persona distinta al inspector (§7.4).
   - Las apelaciones las decide personal no involucrado (§7.6).
   - Nada se borra; todo cambio queda en `bitacora` (§8.4).
2. **Validación en pantalla** — el inspector no puede enviar a revisión si hay
   ítems sin evaluar, NC sin evidencia o sin equipos registrados.
3. **Tablero de controles** (`src/lib/controles.ts`) — vigila vencimientos y
   periodicidades: declaraciones de imparcialidad, monitoreo en sitio,
   calibraciones, póliza RC, quejas fuera de plazo, documentos sin revisar,
   auditoría interna, revisión por la dirección, acciones correctivas...

Los plazos (365 días, 30 días para quejas, etc.) son **valores por defecto** y
deben ajustarse a los procedimientos del OEC en `configuracion_oec.plazos`.

## Normas y formatos versionados

- `reglamentos`: RETIE-2024 (activo), RETIE-2026 (preparado).
- `formatos`: cada lista de verificación es un JSON versionado (ver
  `datos/formatos/F229.json`). Solo una versión puede estar vigente y cada
  inspección guarda la versión usada.
- `datos/formatos/excel_to_json.py` convierte los Excel de listas de verificación.
- `npm run seed:sql` regenera `supabase/seed.sql` desde `datos/formatos/`.

## Desarrollo

```bash
npm install
npm run dev        # http://localhost:3000
npm run build      # compila y verifica tipos
```

Base de datos: crear un proyecto en Supabase, ejecutar en orden
`supabase/migrations/*.sql` y luego `supabase/seed.sql`, y copiar `.env.example`
a `.env.local` con la URL y la clave pública. `supabase/tests/reglas_17020.sql`
verifica las reglas.

## Hoja de ruta

| Fase | Contenido |
|---|---|
| 1 | Base, tablero 17020, inspección sin conexión ← **actual** |
| 1b | Conexión a Supabase, inicio de sesión por rol, sincronización de evidencias |
| 2 | Cotización, aprobación del cliente, revisión de solicitud, asignación |
| 3 | Revisión técnica, decisión, dictamen PDF con QR de verificación, portal del cliente |
| 4 | Control documental, quejas y apelaciones, auditorías, revisión por la dirección, acciones |
| 5 | Listas RETIE 2026 |

La aplicación Flutter anterior quedó en `legacy/flutter_app/` como referencia.
