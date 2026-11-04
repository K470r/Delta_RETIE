# delta_retie

App Flutter para inspecciones RETIE (lista de verificación F-229 y registro de no conformidades con evidencias).

## Conexión con Supabase

La app guarda cada no conformidad en la tabla `no_conformidades` y sube las evidencias al bucket `evidencias` de Supabase Storage. Si no hay credenciales configuradas, funciona solo en local.

1. Crea un proyecto en [supabase.com](https://supabase.com).
2. En **SQL Editor**, ejecuta [`supabase/schema.sql`](supabase/schema.sql) (crea la tabla, el bucket y las políticas).
3. Copia `supabase.env.example.json` a `supabase.env.json` y pon tu **Project URL** y **anon key** (Project Settings → API). Ese archivo está en `.gitignore`.
4. Instala dependencias y ejecuta:

```bash
flutter pub get
```

```bash
flutter run --dart-define-from-file=supabase.env.json
```

> ⚠️ Las políticas de `schema.sql` permiten acceso con la anon key porque la app aún no tiene login. Antes de producción hay que agregar Supabase Auth y restringirlas.
