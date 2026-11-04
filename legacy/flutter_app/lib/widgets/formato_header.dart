import 'package:flutter/material.dart';

class FormatoHeader extends StatelessWidget {
  final String codigo;
  final String nombre;
  final String version;
  final String fecha;

  const FormatoHeader({
    super.key,
    required this.codigo,
    required this.nombre,
    required this.version,
    required this.fecha,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      color: Colors.grey.shade200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // 🔹 FILA SUPERIOR (LOGO + NOMBRE)
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                color: Colors.grey.shade400, // 👈 placeholder logo
                child: const Center(child: Text("LOGO")),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 🔹 FILA INFERIOR
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Código: $codigo"),
              Text("Versión: $version"),
              Text("Fecha: $fecha"),
            ],
          ),
        ],
      ),
    );
  }
}