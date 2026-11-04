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
