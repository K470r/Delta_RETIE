import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Acceso a Supabase: guarda las NC en la tabla `no_conformidades`
/// y sube las evidencias (fotos, documentos, videos, audios) al bucket
/// `evidencias` (privado) de Storage. Requiere sesión iniciada.
class SupabaseService {
  SupabaseService._();

  static bool _inicializado = false;

  /// Inicializa Supabase si hay credenciales. Si no las hay, la app
  /// sigue funcionando solo en local.
  static Future<void> inicializar() async {
    if (!SupabaseConfig.configurado || _inicializado) return;

    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    _inicializado = true;
  }

  static bool get disponible => _inicializado;

  static SupabaseClient get _client => Supabase.instance.client;

  // ------------------------------------------------------------------
  // Autenticación
  // ------------------------------------------------------------------

  static Stream<AuthState> get cambiosSesion =>
      _client.auth.onAuthStateChange;

  static Session? get sesion => _client.auth.currentSession;

  static User? get usuario => _client.auth.currentUser;

  static Future<void> iniciarSesion(String email, String password) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Registra un usuario. Devuelve `true` si queda pendiente de
  /// confirmar el correo.
  static Future<bool> registrar(String email, String password) async {
    final res = await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    return res.session == null;
  }

  static Future<void> cerrarSesion() => _client.auth.signOut();

  /// Rol del usuario actual: 'admin' o 'inspector'.
  static Future<String?> rolActual() async {
    final uid = usuario?.id;
    if (uid == null) return null;
    final fila = await _client
        .from('perfiles')
        .select('rol')
        .eq('id', uid)
        .maybeSingle();
    return fila?['rol'] as String?;
  }

  /// Listas de evidencias dentro del Map de una NC.
  static const List<String> _camposEvidencia = [
    'fotosTomadas',
    'fotosGaleria',
    'documentos',
    'videos',
    'audios',
  ];

  /// Sube las evidencias pendientes y hace upsert de la NC.
  ///
  /// Devuelve la NC con cada evidencia completada con `storage_path`
  /// para no volver a subirla en un guardado posterior.
  static Future<Map> guardarNC({
    required String inspeccionId,
    required Map nc,
  }) async {
    if (!disponible) {
      throw StateError('Supabase no está configurado');
    }
    final uid = usuario?.id;
    if (uid == null) {
      throw StateError('Debe iniciar sesión');
    }

    final codigo = (nc['codigo'] ?? 'sin_codigo').toString();
    final resultado = Map.from(nc);

    for (final campo in _camposEvidencia) {
      final lista = List<Map>.from(nc[campo] ?? const []);
      final subidas = <Map>[];

      for (final evidencia in lista) {
        subidas.add(await _subirEvidencia(
          uid: uid,
          inspeccionId: inspeccionId,
          codigo: codigo,
          campo: campo,
          evidencia: evidencia,
        ));
      }

      resultado[campo] = subidas;
    }

    await _client.from(SupabaseConfig.tablaNC).upsert(
      {
        'inspeccion_id': inspeccionId,
        'codigo': codigo,
        'instructivo': resultado['instructivo'],
        'articulo': resultado['articulo'],
        'actividad': resultado['actividad'],
        'requisito': resultado['requisito'],
        'aspecto': resultado['aspecto'],
        'descripcion': resultado['descripcion'],
        'observacion': resultado['observacion'],
        'evidencias': {
          for (final campo in _camposEvidencia)
            campo: (resultado[campo] as List)
                .map((e) => {
                      'storage_path': e['storage_path'],
                      if (e['tipo'] != null) 'tipo': e['tipo'],
                    })
                .toList(),
        },
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'inspeccion_id,codigo',
    );

    return resultado;
  }

  static Future<Map> _subirEvidencia({
    required String uid,
    required String inspeccionId,
    required String codigo,
    required String campo,
    required Map evidencia,
  }) async {
    // Ya subida en un guardado anterior.
    if (evidencia['storage_path'] != null) return evidencia;

    final ruta = evidencia['ruta']?.toString();
    if (ruta == null) return evidencia;

    final archivo = File(ruta);
    if (!await archivo.exists()) return evidencia;

    final nombre = ruta.split(Platform.pathSeparator).last;
    final storagePath = '$uid/$inspeccionId/$codigo/$campo/$nombre';
    final bucket = _client.storage.from(SupabaseConfig.bucketEvidencias);

    await bucket.upload(
      storagePath,
      archivo,
      fileOptions: FileOptions(
        upsert: true,
        contentType: _contentType(nombre),
      ),
    );

    return {
      ...evidencia,
      'storage_path': storagePath,
    };
  }

  static String? _contentType(String nombre) {
    final ext = nombre.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      case 'mp4':
        return 'video/mp4';
      case 'm4a':
        return 'audio/mp4';
      default:
        return null;
    }
  }
}
