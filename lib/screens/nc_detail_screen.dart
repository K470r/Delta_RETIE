import 'package:flutter/material.dart';

class NcDetailScreen extends StatefulWidget {
  final Map item;
  final String instructivo; // 👈 NUEVO

  const NcDetailScreen({
    super.key,
    required this.item,
    required this.instructivo, // 👈 NUEVO
  });

  @override
  State<NcDetailScreen> createState() => _NcDetailScreenState();
}

class _NcDetailScreenState extends State<NcDetailScreen> {
  final TextEditingController observacionController =
      TextEditingController();

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final instructivo = widget.instructivo; // 👈 NUEVO

    return Scaffold(
      appBar: AppBar(title: const Text("No Conformidad")),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [

            // 🔹 CONTENIDO SCROLL
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // 🔹 IDENTIFICACIÓN
                    Text(
                      "Código: ${item['codigo']}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text("Instructivo: $instructivo"), // 👈 NUEVO

                    const SizedBox(height: 4),

                    Text("Artículo: ${item['articulo']}"),

                    const SizedBox(height: 12),

                    // 🔹 ACTIVIDAD
                    Text(
                      item['actividad'] ?? '',
                      textAlign: TextAlign.justify,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 🔹 REQUISITO / ASPECTO
                    Text("Requisito: ${item['requisito']}"),
                    Text("Aspecto: ${item['aspecto']}"),

                    const SizedBox(height: 12),

                    // 🔹 DESCRIPCIÓN RETIE
                    Text(
                      item['descripcion'] ?? '',
                      textAlign: TextAlign.justify,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 🔹 OBSERVACIÓN
                    const Text(
                      "Observación del inspector",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 6),

                    TextField(
                      controller: observacionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText:
                            "Describa la no conformidad encontrada...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 🔹 EVIDENCIAS (UI)
                    const Text(
                      "Evidencias",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [

                        ElevatedButton(
                          onPressed: () {},
                          child: const Text("📷 Tomar foto"),
                        ),

                        ElevatedButton(
                          onPressed: () {},
                          child: const Text("📁 Cargar foto"),
                        ),

                        ElevatedButton(
                          onPressed: () {},
                          child: const Text("🎥 Tomar video"),
                        ),

                        ElevatedButton(
                          onPressed: () {},
                          child: const Text("📁 Cargar video"),
                        ),

                        ElevatedButton(
                          onPressed: () {},
                          child: const Text("🎙️ Grabar audio"),
                        ),

                        ElevatedButton(
                          onPressed: () {},
                          child: const Text("📄 Documento"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 🔹 BOTÓN FINAL
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final nc = {
                    "codigo": item['codigo'],
                    "instructivo": instructivo, // 👈 CLAVE
                    "articulo": item['articulo'],
                    "actividad": item['actividad'],
                    "requisito": item['requisito'],
                    "aspecto": item['aspecto'],
                    "descripcion": item['descripcion'],
                    "observacion": observacionController.text,
                    "evidencias": [],
                  };

                  Navigator.pop(context, nc);
                },
                child: const Text("REGISTRAR NO CONFORMIDAD"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}