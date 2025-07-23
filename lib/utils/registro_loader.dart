import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/test_registro.dart';

Future<List<TestRegistro>> cargarTodosLosRegistros() async {
  final prefs = await SharedPreferences.getInstance();
  final data = prefs.getString('test_registros') ?? '[]';

  final listaJson = json.decode(data) as List;

  return listaJson.map((e) => TestRegistro.fromJson(e)).toList()
    ..sort((a, b) => a.fecha.compareTo(b.fecha));
}

Future<DateTime?> obtenerFechaUltimoTest() async {
  final registros = await cargarTodosLosRegistros();
  if (registros.isEmpty) return null;
  registros.sort((a, b) => b.fecha.compareTo(a.fecha)); // más reciente primero
  return registros.first.fecha;
}
