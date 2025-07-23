import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class MantenimientoFisico {
  /// Registra una nueva limpieza:
  /// - Guarda la fecha actual como última limpieza.
  /// - Agrega la fecha al historial (lista).
  static Future<void> registrarLimpieza(String tipo) async {
    final prefs = await SharedPreferences.getInstance();

    // Fecha actual como string legible y formato ISO para última fecha
    final ahora = DateTime.now();
    final fechaLegible = DateFormat('yyyy-MM-dd HH:mm').format(ahora);
    final claveUltima = 'ultima_$tipo';
    final claveHistorial = 'limpieza_$tipo';

    // Guardar como última limpieza
    prefs.setString(claveUltima, ahora.toIso8601String());

    // Guardar también en historial
    final historial = prefs.getStringList(claveHistorial) ?? [];
    historial.add(fechaLegible);
    await prefs.setStringList(claveHistorial, historial);
  }

  /// Devuelve la fecha de la última limpieza (o null si no existe)
  static Future<DateTime?> obtenerUltimaLimpieza(String tipo) async {
    final prefs = await SharedPreferences.getInstance();
    final fechaStr = prefs.getString('ultima_$tipo');
    return fechaStr != null ? DateTime.tryParse(fechaStr) : null;
  }

  /// Verifica si pasaron más de `dias` desde la última limpieza
  static Future<bool> requiereLimpieza(String tipo, int dias) async {
    final ultima = await obtenerUltimaLimpieza(tipo);
    if (ultima == null) return true;
    final diferencia = DateTime.now().difference(ultima).inDays;
    return diferencia >= dias;
  }

  /// Devuelve la lista de limpiezas registradas (historial)
  static Future<List<String>> obtenerHistorial(String tipo) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('limpieza_$tipo') ?? [];
  }

  /// Elimina un registro del historial por índice
  static Future<void> eliminarRegistro(String tipo, int index) async {
    final prefs = await SharedPreferences.getInstance();
    final clave = 'limpieza_$tipo';
    final historial = prefs.getStringList(clave) ?? [];
    if (index >= 0 && index < historial.length) {
      historial.removeAt(index);
      await prefs.setStringList(clave, historial);
    }
  }
}
