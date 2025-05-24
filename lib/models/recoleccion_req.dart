class RecoleccionReq {
  final DateTime fechaRecoleccion;
  final String metodoRecoleccion;
  final int usuarioId;
  final int contenedorId;

  RecoleccionReq({
    required this.fechaRecoleccion,
    required this.metodoRecoleccion,
    required this.usuarioId,
    required this.contenedorId,
  });

  Map<String, dynamic> toJson() => {
    'fecha_recoleccion': fechaRecoleccion.toIso8601String(),
    'metodo_recoleccion': metodoRecoleccion,
    'usuario_ID': usuarioId,
    'contenedor_ID': contenedorId,
  };
}