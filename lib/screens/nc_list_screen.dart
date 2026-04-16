import 'package:flutter/material.dart';
import 'nc_detail_screen.dart';

class NcListScreen extends StatefulWidget {
  final List<Map> ncList;

  const NcListScreen({super.key, required this.ncList});

  @override
  State<NcListScreen> createState() => _NcListScreenState();
}

class _NcListScreenState extends State<NcListScreen> {
  late List<Map> ncList;

  @override
  void initState() {
    super.initState();
    ncList = List.from(widget.ncList);
  }

  // 🔹 ABRIR NC PARA EDITAR
  void abrirNC(Map nc) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NcDetailScreen(
          item: nc,
          instructivo: nc['instructivo'],
          ncExistente: nc,
        ),
      ),
    );

    if (resultado != null && resultado is Map) {
      setState(() {
        final index =
            ncList.indexWhere((e) => e['codigo'] == nc['codigo']);

        if (index >= 0) {
          ncList[index] = resultado;
        }
      });
    }
  }

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

                return GestureDetector(
                  onTap: () => abrirNC(nc), // 👈 CLAVE
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
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

                          // 🔹 INSTRUCTIVO
                          Text(
                            "Instructivo: ${nc['instructivo'] ?? ''}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),

                          const SizedBox(height: 6),

                          // 🔹 OBSERVACIÓN
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
                  ),
                );
              },
            ),
    );
  }
}