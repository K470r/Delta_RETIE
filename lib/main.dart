import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/supabase_service.dart';
import 'test_json_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.inicializar();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delta RETIE',
      home: SupabaseService.disponible
          ? const _AuthGate()
          : TestJsonScreen(),
    );
  }
}

/// Muestra el login o la lista F-229 según haya sesión iniciada.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: SupabaseService.cambiosSesion,
      builder: (context, _) {
        return SupabaseService.sesion == null
            ? const LoginScreen()
            : TestJsonScreen();
      },
    );
  }
}
