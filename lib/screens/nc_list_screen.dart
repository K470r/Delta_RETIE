import 'package:flutter/material.dart';

class NcListScreen extends StatelessWidget {
  final List<Map> ncList;

  const NcListScreen({super.key, required this.ncList});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("No Conformidades")),
      body: ncList.isEmpty
          ? const Center(
              child: Text("No hay no conformidades registradas"),
            )
          : ListView.builder(
              itemCount: ncList.length,
              itemBuilder: (context, index) {
                final nc = ncList[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // 🔹 CÓDIGO
                        Text(
                          nc['codigo'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // 🔹 INSTRUCTIVO (NUEVO)
                        Text(
                          "Instructivo: ${nc['instructivo'] ?? ''}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 6),

                        // 🔹 OBSERVACIÓN (PRINCIPAL)
                        Text(
                          nc['observacion'] ?? '',
                          textAlign: TextAlign.justify,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // 🔹 ARTÍCULO
                        Text(
                          "Artículo: ${nc['articulo'] ?? ''}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // 🔹 REQUISITO
                        Text(
                          "Requisito: ${nc['requisito'] ?? ''}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // 🔹 ASPECTO
                        Text(
                          "Aspecto: ${nc['aspecto'] ?? ''}",
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