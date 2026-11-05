# Pasos en Supabase para activar el inicio de sesión

Hágalos en orden. Si algo no se ve igual a lo descrito, tome una captura de pantalla y
envíela en el chat.

## Paso 1 — Ejecutar la migración 0003 (una sola vez)

1. Abra el archivo `supabase/migrations/0003_autenticacion.sql` del repositorio
   (en GitHub: botón **Raw**), seleccione todo (Ctrl+A) y cópielo (Ctrl+C).
2. Entre a <https://supabase.com/dashboard> y abra su proyecto.
3. En el menú de la izquierda haga clic en **SQL Editor**.
4. Haga clic en **+ New query** (consulta nueva).
5. Pegue el texto (Ctrl+V) y haga clic en **Run** (abajo a la derecha).
6. Abajo debe aparecer:
   `Migración 0003 aplicada. Administradores de la plataforma: directortecnico.gceisas@gmail.com`

   Si Supabase muestra un aviso de "operación destructiva" o de "nueva tabla sin RLS",
   confirme con **Run this query**: la migración no borra datos y la tabla nueva sí tiene RLS.
   Puede ejecutarse otra vez sin problema.

> **No** vuelva a ejecutar `instalar_todo.sql`: ya lo hizo y fallaría porque las tablas ya existen.

## Paso 1b — Ejecutar la migración 0004 (logos del organismo)

Igual que el paso 1, con el archivo `supabase/migrations/0004_logos.sql`. Abajo debe aparecer
`Migración 0004 aplicada: logos del organismo`. Crea el lugar donde se guardan el logo del
organismo y el símbolo de acreditado ONAC (máximo 2 MB, PNG, JPG o WEBP). Solo la gerencia
o el responsable del SG pueden cargarlos.

## Paso 1c — Ejecutar la migración 0005 (acceso por rol y archivos privados)

Igual que el paso 1, con `supabase/migrations/0005_acceso_por_rol.sql`. Abajo debe aparecer
`Migración 0005 aplicada: acceso por rol y archivos privados`.

## Paso 1d — Que nadie pueda crearse una cuenta por su cuenta

**Authentication → Sign In / Providers** (en algunas versiones **Providers** o **Settings**):
desactive **Allow new users to sign up** y guarde. Los usuarios se crean en
**Authentication → Users → Add user → Create new user** (correo, contraseña provisional y
**Auto Confirm User** marcado).

## Paso 2 (opcional, más adelante) — Que el correo traiga también un código

Supabase solo deja editar las plantillas de correo si se configura un servidor de correo
propio (**Authentication → Emails → SMTP Settings**). Con el servidor gratuito el correo
trae solo el enlace, y eso basta: ábralo en el mismo equipo donde usa la aplicación.
Cuando se configure un SMTP propio, agregue a las plantillas **Magic link or OTP** y
**Confirm sign up** esta línea, para poder ingresar con el código desde otro equipo:

```html
<p>Su código de ingreso es: <b>{{ .Token }}</b></p>
```

## Paso 3 — Ingresar

1. Abra la aplicación y vaya a **Ingresar**.
2. Escriba su correo y haga clic en **Enviarme el enlace**.
3. Abra el correo (revise *spam* o *promociones*) y haga clic en el enlace, o escriba el código.

Supabase permite pocos correos por hora con su servidor de correo gratuito. Si aparece
"Se enviaron demasiados correos", espere unos minutos.

## Paso 4 — Crear el organismo (solo el administrador de la plataforma)

1. **Organismos** → **+ Nuevo organismo**: datos, sede principal y alcance acreditado.
2. Dentro del organismo aparece el recuadro **Arranque del organismo**:
   1. Regístrese como persona (cédula, nombres, matrícula). El correo ya viene puesto:
      así su usuario queda enlazado a su cédula.
   2. Desígnese en la gerencia (por ejemplo, gerente) o como responsable del SG. En el mismo formulario se registran la
      vinculación y las declaraciones de imparcialidad y confidencialidad.
   (La designación como director técnico exige que **otra persona** del organismo verifique
   su experiencia; hágala después.)
3. Desde ese momento puede vincular y designar a las demás personas. Cada persona
   registrada con su correo podrá ingresar con ese mismo correo y verá su organismo.

## Más adelante — Al publicar la aplicación en internet

En **Authentication → URL Configuration** cambie **Site URL** por la dirección pública
(por ejemplo `https://delta-retie.vercel.app`) y agréguela también en **Redirect URLs**.
Mientras tanto, el valor por defecto `http://localhost:3000` sirve para las pruebas.

## Borrar los datos de prueba

`supabase/limpiar_datos_prueba.sql` borra los organismos con NIT que empieza por `PRUEBA`
y las personas con documento que empieza por `PRUEBA`. La bitácora se conserva.
Péguelo en el SQL Editor y haga clic en **Run**; al final debe mostrar `0` y `0`.

## Probar la aplicación en su propio computador (Windows)

Se hace una sola vez la instalación (pasos 1 a 4); después, cada vez que quiera usarla,
solo los pasos 5 y 6.

1. **Instale Node.js**: entre a <https://nodejs.org>, descargue la versión **LTS** e
   instálela con todas las opciones por defecto (Siguiente, Siguiente, Instalar).
2. **Descargue el programa**: en GitHub abra el repositorio `k470r/delta_retie`, cambie la
   rama (botón que dice `main`) a `claude/dreamy-hypatia-a2u57a`, haga clic en el botón
   verde **Code** → **Download ZIP**. Descomprímalo (clic derecho → *Extraer todo*), por
   ejemplo en `C:\DeltaRETIE`.
3. **Cree el archivo de conexión** dentro de la carpeta descomprimida (donde está `package.json`):
   1. Abra el Bloc de notas y escriba estas dos líneas, con sus datos de Supabase
      (**Project Settings → API**, o el botón **Connect**: *Project URL* y la clave
      *publishable* / *anon*; **nunca** la clave *secret* / *service_role*):
      ```
      NEXT_PUBLIC_SUPABASE_URL=https://xxxxxxxx.supabase.co
      NEXT_PUBLIC_SUPABASE_ANON_KEY=sb_publishable_xxxxxxxx
      ```
   2. **Archivo → Guardar como**, en *Tipo* elija **Todos los archivos (\*.\*)** y en
      *Nombre* escriba exactamente `.env.local`
4. **Instale las dependencias**: abra la carpeta, haga clic en la barra de direcciones del
   Explorador, escriba `cmd` y pulse Enter. En la ventana negra escriba
   `npm install` y pulse Enter (tarda unos minutos).
5. **Arranque la aplicación**: en esa misma ventana escriba `npm run dev` y pulse Enter.
   Déjela abierta mientras use la aplicación (para apagarla: Ctrl+C).
6. Abra el navegador en <http://localhost:3000>, escriba su correo y abra el enlace
   del correo **en ese mismo computador**.

## Dar acceso a sus aliados con usuario y contraseña

Necesita la aplicación publicada en internet (ver "Publicar en Vercel"). Para cada aliado:

1. **Créele el usuario en Supabase**: **Authentication → Users → Add user → Create new user**.
   Escriba su correo y una contraseña provisional (mínimo 8 caracteres), deje marcada
   **Auto Confirm User** y haga clic en **Create user**.
2. **Regístrelo en la aplicación** como persona, con **el mismo correo**, y vincúlelo o
   desígnelo en el organismo (pestañas Gerencia, Sistema de gestión, Directores técnicos o
   Inspectores). La base de datos enlaza su usuario con su cédula por el correo.
   Sin vinculación vigente, el aliado entra pero no ve ningún organismo.
3. Envíele la dirección de la aplicación, su correo y la contraseña provisional por un
   medio privado. Al entrar, que la cambie en **Mi cuenta** (arriba a la derecha).

Lo que cada aliado puede hacer depende de su designación: la gerencia, el responsable del
SG y la dirección técnica administran el organismo; los inspectores solo consultan.

## Publicar en Vercel (gratis)

1. Entre a <https://vercel.com> → **Sign Up** → plan **Hobby** → **Continue with GitHub**.
2. **Add New… → Project** → busque `delta_retie` → **Import** (si no aparece, use
   *Adjust GitHub App Permissions* y dé acceso a ese repositorio).
3. Antes de **Deploy**, abra **Environment Variables** y agregue las dos variables del
   archivo `.env.local` (mismo nombre y valor). Luego **Deploy**.
4. Al terminar, Vercel muestra la dirección, por ejemplo `https://delta-retie.vercel.app`.
5. En Supabase: **Authentication → URL Configuration**:
   - **Site URL**: la dirección de Vercel → **Save changes**.
   - **Redirect URLs → Add URL**: `https://delta-retie.vercel.app/**` y también
     `http://localhost:3000/**` (para seguir probando en su computador).

Vercel publica la rama `main`. Debe contener la aplicación web (no la de Flutter).
