import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class RegistrarScreen extends StatefulWidget {
  final Map<String, String> item;

  const RegistrarScreen({super.key, required this.item});

  @override
  State<RegistrarScreen> createState() => _RegistrarScreenState();
}

class _RegistrarScreenState extends State<RegistrarScreen> {
  final controller = TextEditingController();
  final picker = ImagePicker();

  List<Map<String, String>> evidencias = [];

  // 📷 Tomar foto
  Future<void> tomarFoto() async {
    final img = await picker.pickImage(source: ImageSource.camera);
    if (img != null) {
      setState(() {
        evidencias.add({
          "tipo": "foto",
          "path": img.path,
        });
      });
    }
  }

  // 📄 Cargar archivo
  Future<void> seleccionarArchivo() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        evidencias.add({
          "tipo": "documento",
          "path": result.files.single.path!,
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hallazgo")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔹 Información RETIE
            Text("Item ${widget.item["numero"]}"),
            Text("Código NC: ${widget.item["codigoNc"]}"),
            Text("Artículo: ${widget.item["articulo"]}"),
            Text(widget.item["texto"] ?? ""),
            Text("Requisito: ${widget.item["requisito"]}"),
            Text("Aspecto: ${widget.item["aspecto"]}"),

            const SizedBox(height: 10),

            // 🔹 Observación
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "Observación",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 10),

            // 🔹 Botones de evidencia
            ElevatedButton(
              onPressed: tomarFoto,
              child: const Text("📷 Tomar evidencia"),
            ),

            ElevatedButton(
              onPressed: seleccionarArchivo,
              child: const Text("📄 Cargar archivo"),
            ),

            const SizedBox(height: 10),

            // 🔹 Lista de evidencias
            Expanded(
              child: ListView.builder(
                itemCount: evidencias.length,
                itemBuilder: (_, i) {
                  final e = evidencias[i];
                  return ListTile(
                    title: Text(e["tipo"] ?? ""),
                    subtitle: Text(e["path"] ?? ""),
                  );
                },
              ),
            ),

            // 🔹 Guardar
            ElevatedButton(
              onPressed: () {
                final hallazgo = {
                  "numero": widget.item["numero"],
                  "codigoNc": widget.item["codigoNc"],
                  "articulo": widget.item["articulo"],
                  "texto": widget.item["texto"],
                  "requisito": widget.item["requisito"],
                  "aspecto": widget.item["aspecto"],
                  "observacion": controller.text,
                  "evidencias": evidencias,
                };

                print(hallazgo);

                Navigator.pop(context);
              },
              child: const Text("Guardar y enviar al acta"),
            )
          ],
        ),
      ),
    );
  }
}