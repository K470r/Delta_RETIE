import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart'; // 👈 NUEVO
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class NcDetailScreen extends StatefulWidget {
  final Map item;
  final String instructivo;
  final Map? ncExistente;

  const NcDetailScreen({
    super.key,
    required this.item,
    required this.instructivo,
    this.ncExistente,
  });

  @override
  State<NcDetailScreen> createState() => _NcDetailScreenState();
}

class _NcDetailScreenState extends State<NcDetailScreen> {
  final TextEditingController observacionController =
      TextEditingController();

  List<Map> evidencias = [];

  @override
  void initState() {
    super.initState();

    if (widget.ncExistente != null) {
      observacionController.text =
          widget.ncExistente!['observacion'] ?? "";

      evidencias =
          List<Map>.from(widget.ncExistente!['evidencias'] ?? []);
    }
  }

  // 🔥 CÁMARA
  Future<void> tomarMultiplesFotos() async {
    final picker = ImagePicker();

    while (true) {
      final XFile? foto = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (foto == null) break;

      final directory = await getApplicationDocumentsDirectory();

      final String nuevaRuta =
          '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final File nuevaImagen = await File(foto.path).copy(nuevaRuta);

      setState(() {
        evidencias.add({
          "tipo": "foto",
          "ruta": nuevaImagen.path,
        });
      });

      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  // 🔥 GALERÍA
  Future<void> cargarDesdeGaleria() async {
    final picker = ImagePicker();

    final List<XFile> archivos = await picker.pickMultiImage(
      imageQuality: 70,
    );

    if (archivos.isEmpty) return;

    final directory = await getApplicationDocumentsDirectory();

    for (var foto in archivos) {
      final String nuevaRuta =
          '${directory.path}/${DateTime.now().millisecondsSinceEpoch}_${foto.name}';

      final File nuevaImagen = await File(foto.path).copy(nuevaRuta);

      setState(() {
        evidencias.add({
          "tipo": "foto",
          "ruta": nuevaImagen.path,
        });
      });
    }
  }

  // 🔥 DOCUMENTOS (SOLO PDF + IMÁGENES)
  Future<void> cargarDocumento() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );

    if (result == null) return;

    final directory = await getApplicationDocumentsDirectory();

    for (var file in result.files) {
      final path = file.path;
      if (path == null) continue;

      final extension = file.extension?.toLowerCase() ?? "";

      // 🔹 VALIDACIÓN
      const allowed = [
        "pdf",
        "jpg",
        "jpeg",
        "png"
      ];

      if (!allowed.contains(extension)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Archivo no permitido: ${file.name}"),
          ),
        );
        continue;
      }

      final String nuevaRuta =
          '${directory.path}/${DateTime.now().millisecondsSinceEpoch}_${file.name}';

      final File nuevoArchivo =
          await File(path).copy(nuevaRuta);

      setState(() {
        evidencias.add({
          "tipo": extension == "pdf"
              ? "pdf"
              : "foto",
          "ruta": nuevaRuta,
          "nombre": file.name,
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final instructivo = widget.instructivo;

    return Scaffold(
      appBar: AppBar(title: const Text("No Conformidad")),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text("Código: ${item['codigo']}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),

                    Text("Instructivo: $instructivo"),
                    Text("Artículo: ${item['articulo']}"),

                    const SizedBox(height: 12),

                    Text(
                      item['actividad'] ?? '',
                      textAlign: TextAlign.justify,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text("Requisito: ${item['requisito']}"),
                    Text("Aspecto: ${item['aspecto']}"),

                    const SizedBox(height: 12),

                    Text(
                      item['descripcion'] ?? '',
                      textAlign: TextAlign.justify,
                      style:
                          const TextStyle(color: Colors.grey),
                    ),

                    const SizedBox(height: 16),

                    const Text("Observación"),

                    TextField(
                      controller: observacionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    ElevatedButton(
                      onPressed: tomarMultiplesFotos,
                      child: const Text("Tomar fotos"),
                    ),

                    const SizedBox(height: 8),

                    ElevatedButton(
                      onPressed: cargarDesdeGaleria,
                      child:
                          const Text("Cargar desde galería"),
                    ),

                    const SizedBox(height: 8),

                    ElevatedButton(
                      onPressed: cargarDocumento,
                      child:
                          const Text("Cargar documentos"),
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: evidencias.map((e) {
                        return Stack(
                          children: [

                            e['tipo'] == 'foto'
                                ? Image.file(
                                    File(e['ruta']),
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.red.shade100,
                                    child: const Icon(
                                        Icons.picture_as_pdf),
                                  ),

                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    evidencias.remove(e);
                                  });
                                },
                                child: Container(
                                  color: Colors.black54,
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final nc = {
                    "codigo": item['codigo'],
                    "instructivo": instructivo,
                    "articulo": item['articulo'],
                    "actividad": item['actividad'],
                    "requisito": item['requisito'],
                    "aspecto": item['aspecto'],
                    "descripcion": item['descripcion'],
                    "observacion":
                        observacionController.text,
                    "evidencias": evidencias,
                  };

                  Navigator.pop(context, nc);
                },
                child: const Text(
                    "REGISTRAR NO CONFORMIDAD"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}