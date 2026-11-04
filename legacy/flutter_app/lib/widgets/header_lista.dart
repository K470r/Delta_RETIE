import 'package:flutter/material.dart';

class HeaderLista extends StatelessWidget {
  final String titulo;
  final String codigo;
  final String version;
  final String fecha;
  final String instructivo;
  final String descripcion;

  const HeaderLista({
    super.key,
    required this.titulo,
    required this.codigo,
    required this.version,
    required this.fecha,
    required this.instructivo,
    required this.descripcion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 🔹 Título + logo
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                child: const Text("LOGO"),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    titulo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 🔹 Código / versión / fecha
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.black)),
            ),
            child: Row(
              children: [
                Expanded(child: Text("Código: $codigo")),
                Expanded(child: Center(child: Text("Versión: $version"))),
                Expanded(child: Align(
                  alignment: Alignment.centerRight,
                  child: Text("Fecha: $fecha"),
                )),
              ],
            ),
          ),

          // 🔹 Instructivo
          Container(
            color: Colors.yellow,
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                const Text("INSTRUCTIVO: "),
                Text(instructivo,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Expanded(child: Text(descripcion)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}