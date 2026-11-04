# Delta RETIE

Plataforma web del Organismo de Evaluación de la Conformidad (OEC) para
**cotizar, aprobar, asignar, inspeccionar, revisar y entregar dictámenes RETIE**,
manteniendo bajo control el cumplimiento de **ISO/IEC 17020:2012**.

Funciona en cualquier navegador (PC, tablet, teléfono) y se puede instalar como
aplicación (PWA). La inspección en sitio trabaja **sin conexión**: los datos y
evidencias se guardan en el dispositivo y se sincronizan al volver la señal.

## Qué hay hoy

### Estructura del organismo (Fase 1 — en uso)

| Módulo | Ruta | 17020 |
|---|---|---|
| Organismos tipo A con datos de acreditación, póliza RC, declaración de independencia y sedes | `/organismos` | §4.1, §5.1, Anexo A |
| Alcance acreditado por actividad (catálogo ONAC RETIE 2024 / RETILAP 2024) con estado: acreditada, en trámite, suspendida o retirada | `/organismos/[id]?p=alcance` | §5.1 |
| Gerencia: representante legal (único), gerente, miembros | `?p=gerencia` | §5.2.1 |
| Responsable del sistema de gestión (único vigente) y suplente, con registro de revisión continua | `?p=sg` | §8 |
| Directores técnicos y suplentes con actividades autorizadas | `?p=dt` | §5.2.5 – 5.2.6 |
| Inspectores con actividades autorizadas | `?p=inspectores` | §6.1.6 |
| Personal en el formato de ONAC (exportable a Excel) | `?p=onac` | NTE-3.3-88/89 §4.1 |
| Tablero de cumplimiento del organismo (11 controles) | `?p=resumen` | varios |
| Directorio de personas y certificados de competencias | `/personas` | §6.1.1 |

Una actividad solo se puede autorizar a un director técnico o inspector si:
1. está en el **alcance acreditado vigente** del organismo,
2. la persona tiene **vinculación vigente** con el organismo, y
3. la persona cumple los **requisitos de competencia** de la categoría de esa actividad
   (RETIE 2024 §4.4.2.x: categorías a–g; RETILAP 2024 §4.5.2.x: categorías 1–5):
   - cédula y matrícula profesional;
   - experiencia **verificada** (sin contar dos veces periodos traslapados): inspector RETIE
     2 años en g / 3 años en a–f en la misma categoría; RETILAP 3 años;
   - director técnico: RETIE más de 10 años en la categoría con mínimo 2 en gerencia o
     dirección; RETILAP mínimo 7 años con mínimo 1 en coordinación, gerencia o dirección;
   - RETILAP: posgrado en iluminación y, para túneles, escenarios deportivos, áreas
     clasificadas, aeropuertos y hospitales, el curso de profundización (si el posgrado no lo incluye);
   - certificado de competencias vigente en la categoría (5 años) **con el seguimiento del
     mes 30 registrado y conforme**. RETILAP no lo exige mientras no exista organismo certificador.
   - RETIE c–f: certificado vigente en g (se muestra como advertencia).

Requisitos versionados en `datos/requisitos/*.json` (para comparar luego con RETIE/RETILAP 2026).
Pruebas del motor: `npm test`.

Si después vence el certificado, se retira la línea o termina la vinculación, la
autorización queda marcada como incumplimiento en el tablero. Nada se borra:
las designaciones se **finalizan** con fecha y motivo, y quedan en el historial.

Catálogo de actividades: `datos/alcances/retie_2024.json` (29 actividades, de
ONAC NTE-3.3-88) y `datos/alcances/retilap_2024.json` (7 actividades, de
NTE-3.3-89). Los PDF fuente están en la misma carpeta.

### Operación (demostración, se migrará al modelo multi-organismo en la fase 2)

| Módulo | Ruta |
|---|---|
| Tablero operativo 17020 (25 controles) | `/operacion` |
| Órdenes de servicio | `/ordenes` |
| Inspección en sitio F-229 sin conexión | `/inspeccion/[orden]` |

Mientras no se configure Supabase, los datos se guardan **solo en el navegador**
(localStorage / IndexedDB). La estructura del organismo ya trabaja con Supabase;
la operación sigue en modo demostración.

### Acceso y conexión a Supabase (Fase 1b)

- **Ingreso sin contraseña** en `/ingresar`: enlace mágico o código enviado al correo
  (Supabase Auth). Con Supabase configurado, todas las páginas exigen sesión.
- **Cada usuario es una persona**: la base de datos enlaza el usuario con la persona
  (cédula) que tenga su mismo correo, al registrarse el usuario o al registrar la persona.
  El enlace no se puede cambiar desde la aplicación.
- **Administrador de la plataforma** (tabla `administradores_plataforma`): el único que
  crea organismos. Inicialmente `directortecnico.gceisas@gmail.com`.
- **Arranque de un organismo**: quien lo crea lo administra mientras nadie esté designado
  en gerencia, SG o dirección técnica, y en ese periodo solo puede vincularse y designarse
  a sí mismo. Desde entonces mandan los roles (§5.2).
- **Verificación de soportes** de la hoja de vida: queda a nombre de quien inició sesión;
  la base de datos rechaza la autoverificación y la verificación a nombre de otro.
- Los errores de las reglas de la base de datos se muestran en pantalla, en español.
- Adaptador: `src/lib/organismo/almacenSupabase.ts` (misma interfaz que el modo local en
  `almacen.ts`): lee lo que la seguridad por filas permite y envía solo los cambios.

## Cómo funciona el control 17020

El cumplimiento se controla en tres niveles:

1. **Bloqueo en la base de datos** — reglas que no se pueden saltar
   (`supabase/migrations/0001_esquema_base.sql`):
   - Solo se autoriza una actividad a un director técnico o inspector si está en el
     alcance acreditado, hay vinculación vigente y certificado de competencias vigente (§6.1).
   - Un único representante legal y un único responsable del SG vigentes a la vez (§5.2, §8).
   - No se designa a nadie sin vinculación con el organismo.
   - No se asigna un inspector sin revisión de la solicitud (§7.1), sin autorización
     para la actividad (§6.1.6) o con conflicto de interés declarado (§4.1).
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
deben ajustarse a los procedimientos de cada organismo en `organismos.plazos`.

## Normas y formatos versionados

- `reglamentos` y `actividades`: RETIE-2024 y RETILAP-2024 con su catálogo ONAC; RETIE-2026 preparado.
- `formatos`: cada lista de verificación es un JSON versionado (ver
  `datos/formatos/F229.json`). Solo una versión puede estar vigente y cada
  inspección guarda la versión usada.
- `datos/formatos/excel_to_json.py` convierte los Excel de listas de verificación.
- `npm run seed:sql` regenera `supabase/seed.sql` (reglamentos y actividades) desde `datos/alcances/`.

## Desarrollo

```bash
npm install
npm run dev        # http://localhost:3000
npm run build      # compila y verifica tipos
```

Base de datos: en un proyecto nuevo de Supabase pegar `supabase/instalar_todo.sql`
en el SQL Editor (o ejecutar en orden `supabase/migrations/*.sql` y `supabase/seed.sql`),
y copiar `.env.example` a `.env.local` con la URL y la clave pública.
Las migraciones nuevas se entregan como archivo aparte en `supabase/migrations/`.

Pruebas de la base de datos en un PostgreSQL local (simula el esquema `auth` de Supabase):

```bash
createdb prueba
psql -d prueba -f supabase/tests/simular_supabase.sql
psql -d prueba -f supabase/instalar_todo.sql
psql -d prueba -f supabase/tests/reglas_17020.sql     # reglas 17020 y competencia
psql -d prueba -f supabase/tests/autenticacion.sql    # 0003: acceso, arranque, verificación
```

`scripts/simular_adaptador.ts` convierte las operaciones del adaptador en SQL para probarlas
igual, sobre una base nueva: después de `simular_supabase.sql`, `instalar_todo.sql` y
`supabase/tests/funciones_prueba.sql`, ejecutar `npx tsx scripts/simular_adaptador.ts | psql -d otra_base`.

## Hoja de ruta

| Fase | Contenido |
|---|---|
| 1 | Base, tablero 17020, inspección sin conexión ✅ |
| 1a | Organismo, alcance acreditado, gerencia, responsable SG, directores técnicos, inspectores ✅ |
| 1b | Conexión a Supabase e inicio de sesión ✅ — publicación web y sincronización de evidencias ← **siguiente** |
| 2 | Cotización, aprobación del cliente, revisión de solicitud, asignación |
| 3 | Revisión técnica, decisión, dictamen PDF con QR de verificación, portal del cliente |
| 4 | Control documental, quejas y apelaciones, auditorías, revisión por la dirección, acciones |
| 5 | Listas RETIE 2026 |

La aplicación Flutter anterior quedó en `legacy/flutter_app/` como referencia.
