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

## Paso 2 (recomendado) — Que el correo traiga también un código

Sirve cuando se abre el correo en un equipo distinto (por ejemplo, el correo en el celular
y la aplicación en el PC): basta con escribir el código.

1. Menú de la izquierda: **Authentication** → **Emails** (en algunas versiones: **Email Templates**).
2. Abra la plantilla **Magic Link**. En el cuadro del mensaje, agregue al final esta línea:

   ```html
   <p>Su código de ingreso es: <b>{{ .Token }}</b></p>
   ```

3. Haga clic en **Save**.
4. Repita lo mismo en la plantilla **Confirm signup** (es la que llega la primera vez que un
   correo ingresa).

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
   2. Desígnese (por ejemplo, director técnico). En el mismo formulario se registran la
      vinculación y las declaraciones de imparcialidad y confidencialidad.
3. Desde ese momento puede vincular y designar a las demás personas. Cada persona
   registrada con su correo podrá ingresar con ese mismo correo y verá su organismo.

## Más adelante — Al publicar la aplicación en internet

En **Authentication → URL Configuration** cambie **Site URL** por la dirección pública
(por ejemplo `https://delta-retie.vercel.app`) y agréguela también en **Redirect URLs**.
Mientras tanto, el valor por defecto `http://localhost:3000` sirve para las pruebas.
