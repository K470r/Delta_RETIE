# Tarea: conectar la aplicación web a Supabase

## Contexto (leer primero)

- La aplicación de este proyecto es **web** (Next.js + TypeScript + Supabase).
  **No usar ni modificar Flutter.** La app Flutter anterior está archivada en
  `legacy/flutter_app/` solo como referencia.
- Partir de la rama **`claude/dreamy-hypatia-a2u57a`** (tiene todo el trabajo):
  `git fetch origin claude/dreamy-hypatia-a2u57a && git checkout -B <rama-de-esta-sesión> origin/claude/dreamy-hypatia-a2u57a`
- **Ignorar la rama `claude/busy-rubin-2r5ykq`**: es un intento en Flutter que no se va a usar.
  Sus tablas (`perfiles`, `no_conformidades`) y el bucket `evidencias` pueden existir en el
  proyecto de Supabase; no estorban y no se deben borrar sin preguntar.
- Leer `README.md` para entender módulos, reglas 17020 y requisitos de competencia.

## Estado de Supabase

- El usuario ya ejecutó `supabase/instalar_todo.sql` en el SQL Editor del proyecto
  (resultado: "Instalación terminada: 36 actividades, 12 categorías").
- Variables de entorno ya configuradas en el entorno de la sesión:
  `NEXT_PUBLIC_SUPABASE_URL` y `NEXT_PUBLIC_SUPABASE_ANON_KEY` (clave *publishable*).
- **No hay conexión directa a la base de datos** (no hay contraseña en el entorno, a propósito).
  Todo cambio de esquema se entrega como archivo SQL nuevo en `supabase/migrations/`
  y el usuario lo pega en el SQL Editor (darle pasos muy simples). Nunca pedir contraseñas
  ni claves secretas en el chat.
- El acceso de red debe permitir `*.supabase.co`. Verificarlo primero con una petición a
  `$NEXT_PUBLIC_SUPABASE_URL/rest/v1/actividades?select=codigo&limit=1` usando la clave pública
  (con RLS sin sesión debe responder 200 con lista vacía, o 401; cualquier respuesta HTTP
  prueba la conectividad).

## Administrador principal

- Correo: **directortecnico.gceisas@gmail.com**
- Es el **administrador de la plataforma**: el único que puede crear organismos.

## Lo que hay que hacer

1. **Migración `0003_autenticacion.sql`**
   - Tabla `administradores_plataforma (correo text primary key)` con el correo anterior.
   - Trigger en `auth.users` (alta de usuario): si su correo coincide con una persona
     (`personas.correo`) sin `usuario_id`, enlazarla; así cada persona entra y queda
     asociada a su cédula.
   - Políticas RLS para que el administrador de la plataforma pueda crear organismos,
     y para que pueda auto-registrarse como persona y vincularse/designarse en el primer
     organismo que crea (arranque inicial).
   - Probar la migración en PostgreSQL local (simulando el esquema `auth`) antes de entregarla.
2. **Inicio de sesión** con Supabase Auth por **enlace mágico o código al correo** (sin contraseña).
   Página `/ingresar`, cierre de sesión, y proteger las rutas de la app.
3. **Adaptador Supabase** con la misma interfaz que `src/lib/organismo/almacen.ts`
   (hoy guarda en `localStorage`). Organismos, alcance, sedes, personas, hoja de vida
   (formación, experiencias, certificados y categorías), vinculaciones, designaciones,
   declaraciones y revisiones del SG. Los errores de las reglas de la base de datos
   deben mostrarse en pantalla en español, tal como llegan.
4. **Verificación de soportes**: al marcar "soporte verificado" guardar `verificada_por`
   con la persona que inició sesión (la base de datos rechaza la autoverificación).
5. **Probar de punta a punta en el navegador** contra el Supabase real: entrar con el
   correo del administrador (pedirle al usuario que abra el enlace del correo), crear el
   organismo, designar personas y ver el tablero.
6. Commit y push a la rama de la sesión. No crear pull request salvo que el usuario lo pida.

## Después (no en esta tarea)

- Publicar la web (por ejemplo en Vercel) y ajustar en Supabase
  *Authentication → URL Configuration → Site URL*.
- Migrar órdenes, inspección en sitio (con evidencias en Storage) y dictámenes al modelo multi-organismo.
