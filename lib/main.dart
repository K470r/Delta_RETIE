import 'package:flutter/material.dart';
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
      home: TestJsonScreen(),
    );
  }
}
