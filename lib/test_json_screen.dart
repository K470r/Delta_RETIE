import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class TestJsonScreen extends StatefulWidget {
  @override
  State<TestJsonScreen> createState() => _TestJsonScreenState();
}

class _TestJsonScreenState extends State<TestJsonScreen> {
  List items = [];

  @override
  void initState() {
    super.initState();
    cargarJson();
  }

  Future<void> cargarJson() async {
    final String response =
        await rootBundle.loadString('assets/f229.json');
    final data = json.decode(response);

    print("JSON cargado");

    setState(() {
      items = data['items'] ?? [];
    });

    print("Items cargados: ${items.length}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("F-229")),
      body: items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];

                // 🔹 SECCIÓN
                if (item['tipo'] == 'seccion') {
                  return Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      item['titulo'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }

                // 🔹 ITEM (TARJETA COMPLETA)
                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🔹 CÓDIGO + ARTÍCULO
                        Text(
                          "${item['codigo'] ?? ''}  |  ${item['articulo'] ?? ''}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),

                        const SizedBox(height: 6),

                        // 🔹 REQUISITO
                        Text(
                          "Requisito: ${item['requisito'] ?? ''}",
                          style: const TextStyle(fontSize: 13),
                        ),

                        const SizedBox(height: 4),

                        // 🔹 ASPECTO
                        Text(
                          "Aspecto: ${item['aspecto'] ?? ''}",
                          style: const TextStyle(fontSize: 13),
                        ),

                        const SizedBox(height: 6),

                        // 🔹 DESCRIPCIÓN
                        Text(
                          item['descripcion'] ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}