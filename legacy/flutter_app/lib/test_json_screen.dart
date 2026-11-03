import 'screens/nc_list_screen.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'widgets/formato_header.dart';
import 'screens/nc_detail_screen.dart';

class TestJsonScreen extends StatefulWidget {
  @override
  State<TestJsonScreen> createState() => _TestJsonScreenState();
}

class _TestJsonScreenState extends State<TestJsonScreen> {
  List items = [];

  // 🔹 DATOS DEL FORMATO (DESDE JSON)
  String codigoFormato = "";
  String nombreFormato = "";
  String versionFormato = "";
  String fechaFormato = "";

  // 🔹 LISTA DE NC GUARDADAS
  List<Map> noConformidades = [];

  // 🔹 ESTADO VISUAL (BOTÓN ROJO)
  Set<String> ncRegistradas = {};

  @override
  void initState() {
    super.initState();
    cargarJson();
  }

  Future<void> cargarJson() async {
    final String response =
        await rootBundle.loadString('assets/f229.json');
    final data = json.decode(response);

    setState(() {
      items = data['items'] ?? [];

      codigoFormato = data['codigo_formato'] ?? "F-229-D";
      nombreFormato = data['nombre_formato'] ??
          "LISTA DE VERIFICACIÓN DE  REQUISITOS DE  PROTECCIÓN DE LAS INSTALACIONES DE USO FINAL";
      versionFormato = data['version'] ?? "00";
      fechaFormato = data['fecha'] ?? "2026-04-15";
    });
  }

  // 🔹 ABRIR / EDITAR NC
  void abrirNC(BuildContext context, Map item) async {
    final codigo = item['codigo'];

    // 🔹 BUSCAR SI YA EXISTE NC
    Map? ncExistente;

    try {
      ncExistente = noConformidades.firstWhere(
        (nc) => nc['codigo'] == codigo,
      );
    } catch (e) {
      ncExistente = null;
    }

    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NcDetailScreen(
          item: item,
          instructivo: codigoFormato,
          ncExistente: ncExistente, // 👈 CLAVE
        ),
      ),
    );

    if (resultado != null && resultado is Map) {
      setState(() {
        ncRegistradas.add(codigo);

        // 🔹 REEMPLAZAR SI YA EXISTE
        final index = noConformidades.indexWhere(
          (nc) => nc['codigo'] == codigo,
        );

        if (index >= 0) {
          noConformidades[index] = resultado;
        } else {
          noConformidades.add(resultado);
        }
      });

      print("NC guardadas: ${noConformidades.length}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [

            // 🔹 HEADER
            FormatoHeader(
              codigo: codigoFormato,
              nombre: nombreFormato,
              version: versionFormato,
              fecha: fechaFormato,
            ),

            // 🔹 BOTÓN VER NC
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NcListScreen(
                          ncList: noConformidades,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    "Ver No Conformidades (${noConformidades.length})",
                  ),
                ),
              ),
            ),

            // 🔹 LISTA
            Expanded(
              child: items.isEmpty
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

                        final codigo = item['codigo'] ?? '';
                        final tieneNC =
                            ncRegistradas.contains(codigo);

                        // 🔹 ITEM
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [

                                // 🔹 CÓDIGO + ARTÍCULO
                                Text(
                                  "$codigo  |  ${item['articulo'] ?? ''}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),

                                const SizedBox(height: 8),

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

                                const SizedBox(height: 8),

                                // 🔹 REQUISITO
                                Text(
                                  "Requisito: ${item['requisito'] ?? ''}",
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                // 🔹 ASPECTO
                                Text(
                                  "Aspecto: ${item['aspecto'] ?? ''}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // 🔹 BOTÓN NC
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton(
                                      style:
                                          ElevatedButton.styleFrom(
                                        backgroundColor: tieneNC
                                            ? Colors.red.shade400
                                            : Colors.grey.shade300,
                                        foregroundColor: tieneNC
                                            ? Colors.white
                                            : Colors.black,
                                        elevation:
                                            tieneNC ? 2 : 4,
                                      ),
                                      onPressed: () =>
                                          abrirNC(context, item),
                                      child: const Text("NC"),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}