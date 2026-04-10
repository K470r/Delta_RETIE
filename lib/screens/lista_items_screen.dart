import 'package:flutter/material.dart';
import 'registrar_screen.dart';

class ListaItemsScreen extends StatelessWidget {
  ListaItemsScreen({super.key});

  final List<Map<String, String>> items = [
    {
      "numero": "22",
      "codigoNc": "IB221",
      "articulo": "3.27.3.a",
      "texto": "Verificar que exista tablero general con protección por cada alimentador.",
      "requisito": "Protecciones",
      "aspecto": "Dispositivos de seccionamiento y mando"
    },
    {
      "numero": "23",
      "codigoNc": "IB222",
      "articulo": "3.27.3.b",
      "texto": "Verificar coordinación adecuada de protecciones en la instalación.",
      "requisito": "Protecciones",
      "aspecto": "Coordinación de protecciones"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("F-229")),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔴 Número
                  Container(
                    width: 45,
                    height: 45,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item["numero"] ?? "",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 📄 Información
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🔹 Fila superior
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            // Código NC
                            Text(
                              item["codigoNc"] ?? "",
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // Requisito esencial
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.green),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "Requisito esencial: ${item["requisito"] ?? ""}",
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),

                            // Aspecto a evaluar
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.blue),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "Aspecto a evaluar: ${item["aspecto"] ?? ""}",
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // 🔹 Actividad de inspección
                        const Text(
                          "Actividad de inspección:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),

                        Text(
                          item["texto"] ?? "",
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 🔘 Botón
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RegistrarScreen(item: item),
                        ),
                      );
                    },
                    child: const Text("NC"),
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