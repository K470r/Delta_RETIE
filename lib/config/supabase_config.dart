/// Configuración de Supabase.
///
/// Las credenciales NO se guardan en el código. Se pasan al compilar/ejecutar:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
///
/// o con un archivo (no versionado):
///
///   flutter run --dart-define-from-file=supabase.env.json
class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Bucket de Storage donde se suben las evidencias.
  static const String bucketEvidencias = 'evidencias';

  /// Tabla donde se guardan las no conformidades.
  static const String tablaNC = 'no_conformidades';

  static bool get configurado => url.isNotEmpty && anonKey.isNotEmpty;
}
