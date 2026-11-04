# delta_retie

App Flutter para inspecciones RETIE (lista de verificación F-229 y registro de no conformidades con evidencias).

## Conexión con Supabase

Proyecto: `dfufdbqvppcarjgdwzne.supabase.co` (la URL y la anon key ya vienen en `lib/config/supabase_config.dart`; son públicas por diseño y la seguridad la dan el login y las políticas RLS).

La app pide iniciar sesión, guarda cada no conformidad en la tabla `no_conformidades` y sube las evidencias al bucket privado `evidencias`.

**Roles**
- `admin`: ve, edita y borra todas las NC y evidencias, y puede cambiar roles. `directortecnico.gceisas@gmail.com` queda como admin automáticamente al registrarse.
- `inspector`: cualquier otro usuario; solo ve y edita sus propias NC.

**Puesta en marcha (una sola vez)**
1. En Supabase → **SQL Editor**, ejecuta [`supabase/schema.sql`](supabase/schema.sql).
2. En Supabase → **Authentication → URL Configuration**, revisa el *Site URL* (el correo de confirmación enlaza ahí).
3. Ejecuta la app, entra en **Crear cuenta** con `directortecnico.gceisas@gmail.com`, confirma el correo e inicia sesión.

```bash
flutter pub get
```

```bash
flutter run
```

Para usar otro proyecto: `flutter run --dart-define-from-file=supabase.env.json` (ver `supabase.env.example.json`).

**Hacer admin a otro usuario** (SQL Editor):

```sql
update public.perfiles set rol = 'admin' where email = 'correo@ejemplo.com';
```
