import 'package:flutter/material.dart';
import 'test_json_screen.dart'; // 👈 NUEVO
// import 'screens/lista_items_screen.dart'; // opcional comentarlo

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delta RETIE',
      home: TestJsonScreen(), // 👈 CAMBIO
    );
  }
}