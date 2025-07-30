class TestRegistro {
  final String tipo;
  final DateTime fecha;
  final String parametro;
  final double valor;
  final String? recomendacion; // ✅ nuevo campo opcional

  TestRegistro({
    required this.tipo,
    required this.fecha,
    required this.parametro,
    required this.valor,
    this.recomendacion,
  });

  factory TestRegistro.fromJson(Map<String, dynamic> json) {
    final rawValor = json['valor'];
    double parsedValor;

    if (rawValor is num) {
      parsedValor = rawValor.toDouble();
    } else if (rawValor is String) {
      parsedValor = double.tryParse(rawValor) ?? 0.0;
    } else {
      throw Exception("Valor inválido en JSON: ${json['valor']}");
    }

    return TestRegistro(
      tipo: json['tipo'] ?? 'desconocido',
      fecha: DateTime.parse(json['fecha']),
      parametro: json['parametro'],
      valor: parsedValor,
      recomendacion: json['recomendacion'], // ✅ cargar recomendación si existe
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tipo': tipo,
      'fecha': fecha.toIso8601String(),
      'parametro': parametro,
      'valor': valor,
      'recomendacion': recomendacion, // ✅ guardar recomendación
    };
  }
}
