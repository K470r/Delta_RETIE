import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
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

  final Record _recorder = Record();
  bool grabando = false;

  List<Map> fotosTomadas = [];
  List<Map> fotosGaleria = [];
  List<Map> documentos = [];
  List<Map> videos = [];
  List<Map> audios = [];

  @override
  void initState() {
    super.initState();

    if (widget.ncExistente != null) {
      observacionController.text =
          widget.ncExistente!['observacion'] ?? "";

      fotosTomadas =
          List<Map>.from(widget.ncExistente!['fotosTomadas'] ?? []);
      fotosGaleria =
          List<Map>.from(widget.ncExistente!['fotosGaleria'] ?? []);
      documentos =
          List<Map>.from(widget.ncExistente!['documentos'] ?? []);
      videos =
          List<Map>.from(widget.ncExistente!['videos'] ?? []);
      audios =
          List<Map>.from(widget.ncExistente!['audios'] ?? []);
    }
  }

  // 📷 CÁMARA
  Future<void> tomarMultiplesFotos() async {
    final picker = ImagePicker();

    while (true) {
      final foto = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (foto == null) break;

      final dir = await getApplicationDocumentsDirectory();
      final ruta =
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final file = await File(foto.path).copy(ruta);

      setState(() {
        fotosTomadas.add({"ruta": file.path});
      });
    }
  }

  // 🖼 GALERÍA
  Future<void> cargarDesdeGaleria() async {
    final picker = ImagePicker();
    final archivos = await picker.pickMultiImage(imageQuality: 70);

    if (archivos.isEmpty) return;

    final dir = await getApplicationDocumentsDirectory();

    for (var foto in archivos) {
      final ruta =
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${foto.name}';

      final file = await File(foto.path).copy(ruta);

      setState(() {
        fotosGaleria.add({"ruta": file.path});
      });
    }
  }

  // 📄 DOCUMENTOS
  Future<void> cargarDocumento() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );

    if (result == null) return;

    final dir = await getApplicationDocumentsDirectory();

    for (var file in result.files) {
      final path = file.path;
      if (path == null) continue;

      final ext = file.extension?.toLowerCase() ?? "";
      const allowed = ["pdf", "jpg", "jpeg", "png"];

      if (!allowed.contains(ext)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No permitido: ${file.name}")),
        );
        continue;
      }

      final ruta =
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${file.name}';

      final nuevo = await File(path).copy(ruta);

      setState(() {
        documentos.add({
          "ruta": nuevo.path,
          "tipo": ext == "pdf" ? "pdf" : "imagen",
        });
      });
    }
  }

  // 🎥 VIDEO
  Future<void> grabarVideo() async {
    final picker = ImagePicker();

    final video = await picker.pickVideo(
      source: ImageSource.camera,
    );

    if (video == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final ruta =
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.mp4';

    final file = await File(video.path).copy(ruta);

    setState(() {
      videos.add({"ruta": file.path});
    });
  }

  // 🎙 AUDIO
  Future<void> toggleAudio() async {
    final dir = await getApplicationDocumentsDirectory();
    final ruta =
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';

    if (!grabando) {
      bool permiso = await _recorder.hasPermission();
      if (!permiso) return;

      await _recorder.start(
        path: ruta,
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        samplingRate: 44100,
      );

      setState(() {
        grabando = true;
      });
    } else {
      final path = await _recorder.stop();

      if (path != null) {
        setState(() {
          audios.add({"ruta": path});
        });
      }

      setState(() {
        grabando = false;
      });
    }
  }

  // 🔹 PREVIEW
  Widget buildPreview(List<Map> lista, String tipo) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: lista.map((e) {
        return Stack(
          children: [
            tipo == "foto"
                ? Image.file(
                    File(e['ruta']),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 80,
                    height: 80,
                    color: Colors.black12,
                    child: Icon(
                      tipo == "pdf"
                          ? Icons.picture_as_pdf
                          : tipo == "video"
                              ? Icons.videocam
                              : Icons.mic,
                    ),
                  ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    lista.remove(e);
                  });
                },
                child: Container(
                  color: Colors.black54,
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
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

                    Text("Código: ${item['codigo']}"),
                    Text("Instructivo: $instructivo"),
                    Text("Artículo: ${item['articulo']}"),

                    const SizedBox(height: 12),

                    // 🔹 ACTIVIDAD
                    Text(
                      item['actividad'] ?? "",
                      textAlign: TextAlign.justify,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 🔹 ARTÍCULO COMPLETO (RECUPERADO)
                    Text(
                      item['descripcion'] ?? '',
                      textAlign: TextAlign.justify,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 12),

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
                    ElevatedButton(
                      onPressed: cargarDesdeGaleria,
                      child: const Text("Cargar fotos"),
                    ),
                    ElevatedButton(
                      onPressed: cargarDocumento,
                      child: const Text("Cargar documentos"),
                    ),
                    ElevatedButton(
                      onPressed: grabarVideo,
                      child: const Text("Grabar video"),
                    ),
                    ElevatedButton(
                      onPressed: toggleAudio,
                      child: Text(
                        grabando
                            ? "Detener grabación"
                            : "Grabar audio",
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (fotosTomadas.isNotEmpty) ...[
                      const Text("📷 Fotos tomadas"),
                      buildPreview(fotosTomadas, "foto"),
                    ],

                    if (fotosGaleria.isNotEmpty) ...[
                      const Text("🖼 Fotos cargadas"),
                      buildPreview(fotosGaleria, "foto"),
                    ],

                    if (documentos.isNotEmpty) ...[
                      const Text("📄 Documentos"),
                      buildPreview(documentos, "pdf"),
                    ],

                    if (videos.isNotEmpty) ...[
                      const Text("🎥 Videos"),
                      buildPreview(videos, "video"),
                    ],

                    if (audios.isNotEmpty) ...[
                      const Text("🎙 Audios"),
                      buildPreview(audios, "audio"),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    "codigo": item['codigo'],
                    "instructivo": instructivo,
                    "articulo": item['articulo'],
                    "actividad": item['actividad'],
                    "requisito": item['requisito'],
                    "aspecto": item['aspecto'],
                    "descripcion": item['descripcion'],
                    "observacion": observacionController.text,
                    "fotosTomadas": fotosTomadas,
                    "fotosGaleria": fotosGaleria,
                    "documentos": documentos,
                    "videos": videos,
                    "audios": audios,
                  });
                },
                child: const Text("GUARDAR"),
              ),
            )
          ],
        ),
      ),
    );
  }
}