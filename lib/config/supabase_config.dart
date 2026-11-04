/// Configuración de Supabase.
///
/// La URL y la anon key son públicas por diseño (van dentro de la app);
/// la seguridad la dan el login y las políticas RLS de supabase/schema.sql.
/// Se pueden reemplazar al compilar:
///
///   flutter run --dart-define-from-file=supabase.env.json
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://dfufdbqvppcarjgdwzne.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_fvZPKNZ8vsnqUM9hdLefDg_tQm1v_iX',
  );

  /// Bucket de Storage (privado) donde se suben las evidencias.
  static const String bucketEvidencias = 'evidencias';

  /// Tabla donde se guardan las no conformidades.
  static const String tablaNC = 'no_conformidades';

  static bool get configurado => url.isNotEmpty && anonKey.isNotEmpty;
}
