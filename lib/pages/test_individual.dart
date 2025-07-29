import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/pool_calculator.dart';
import '../models/test_registro.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import '../utils/stock_service.dart';

class TestIndividualScreen extends StatefulWidget {
  const TestIndividualScreen({super.key});

  @override
  State<TestIndividualScreen> createState() => _TestIndividualScreenState();
}

class _TestIndividualScreenState extends State<TestIndividualScreen> {
  final TextEditingController _valorController = TextEditingController();
  final TextEditingController _gotasController = TextEditingController();

  String _parametroSeleccionado = 'Cloro libre';
  String _volumenSeleccionado = '10';
  Map<String, String> _recomendaciones = {};
  Map<String, String> _registroActual = {};

  @override
  void initState() {
    super.initState();
    _cargarEstadoTemporal();
  }

  Future<void> _cargarEstadoTemporal() async {
    final prefs = await SharedPreferences.getInstance();
    final tempRegistro = prefs.getString('temp_individual');
    final tempRecs = prefs.getString('temp_recomendaciones_individual');

    if (tempRegistro != null) {
      final Map<String, dynamic> datos = json.decode(tempRegistro);
      setState(() {
        _registroActual = datos.map((k, v) => MapEntry(k, v.toString()));
        _parametroSeleccionado = datos.keys.first;
        _valorController.text = datos.values.first;
      });
    }

    if (tempRecs != null) {
      final Map<String, dynamic> recs = json.decode(tempRecs);
      setState(() {
        _recomendaciones = recs.map((k, v) => MapEntry(k, v.toString()));
      });
    }
  }

  Future<void> _calcular() async {
    final local = AppLocalizations.of(context)!;
    final unidadSistema = Provider
        .of<SettingsController>(context, listen: false)
        .unidadSistema;

    double? valor;
    final gotas = int.tryParse(_gotasController.text.trim());

    if (_parametroSeleccionado.contains('Cloro') && gotas != null) {
      valor = _volumenSeleccionado == '10' ? gotas * 0.5 : gotas * 0.2;
    } else {
      valor = double.tryParse(_valorController.text.trim());
    }

    if (valor == null) return;

    final Map<String, String> registro = {
      _parametroSeleccionado: valor.toStringAsFixed(2),
      'tipo': 'individual',
      'fecha': DateTime.now().toIso8601String(),
    };

    final recomendaciones = await calcularAjustes(
        registro, context, unidadSistema);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('temp_individual', json.encode(registro));
    await prefs.setString(
        'temp_recomendaciones_individual', json.encode(recomendaciones));

    setState(() {
      _registroActual = registro;
      _recomendaciones = recomendaciones;
    });
  }

  Future<void> _guardarTesteo() async {
    if (_registroActual.isEmpty) return;

    await _saveRegistro(_registroActual);
    await _saveRegistrosComoTestRegistro(_registroActual);


    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('temp_individual');
    await prefs.remove('temp_recomendaciones_individual');

    setState(() {
      _registroActual.clear();
      _recomendaciones.clear();
      _valorController.clear();
      _gotasController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.testGuardadoExito),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _saveRegistro(Map<String, String> registro) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> registros = prefs.getStringList('registros') ?? [];
    registros.add(json.encode(registro));
    await prefs.setStringList('registros', registros);

    final String? individualesData = prefs.getString('test_individual');
    List<Map<String, dynamic>> individuales = [];

    if (individualesData != null && individualesData.isNotEmpty) {
      individuales =
      List<Map<String, dynamic>>.from(json.decode(individualesData));
    }

    individuales.add(registro);
    await prefs.setString('test_individual', json.encode(individuales));
  }

  Future<void> _saveRegistrosComoTestRegistro(
      Map<String, String> registro) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('test_registros');
    List<Map<String, dynamic>> lista = [];

    if (data != null) {
      lista = List<Map<String, dynamic>>.from(json.decode(data));
    }

    final now = DateTime.now();
    for (var entry in registro.entries) {
      if (entry.key != 'fecha' && entry.key != 'tipo') {
        final valor = double.tryParse(entry.value);
        if (valor != null) {
          final test = TestRegistro(
            tipo: registro['tipo'] ?? 'individual',
            parametro: entry.key,
            valor: valor,
            fecha: now,
          );
          lista.add(test.toJson());
        }
      }
    }

    await prefs.setString('test_registros', json.encode(lista));
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final esAguaSalada = Provider
        .of<SettingsController>(context)
        .esAguaSalada;

    return Scaffold(
      appBar: AppBar(
        title: Text(local.testIndividual),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButton<String>(
              value: _parametroSeleccionado,
              isExpanded: true,
              items: [
                'Cloro libre',
                'Cloro combinado',
                'pH',
                'Alcalinidad',
                'CYA',
                'Dureza',
                'Salinidad'
              ]
                  .where((param) => esAguaSalada || param != 'Salinidad')
                  .map((param) =>
                  DropdownMenuItem(
                    value: param,
                    child: Text(localLabel(param, local)),
                  ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _parametroSeleccionado = value;
                    _valorController.clear();
                    _gotasController.clear();
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            if (_parametroSeleccionado.contains('Cloro'))
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _gotasController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: '${local.gotas} (opcional)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _volumenSeleccionado,
                    items: ['10', '25']
                        .map((v) =>
                        DropdownMenuItem(value: v, child: Text('$v mL')))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _volumenSeleccionado = val);
                      }
                    },
                  ),
                ],
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _valorController,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              decoration: InputDecoration(
                labelText: local.valor,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            if (_recomendaciones.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _recomendaciones.entries.map((entry) {
                  final lines = entry.value.trim().split('\n');
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lines.first,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        ...lines.skip(1).map(
                              (line) =>
                              Text(
                                line,
                                style: TextStyle(
                                  color: line.contains('⚠️') ||
                                      line.contains('❌')
                                      ? Colors.red
                                      : line.contains('✅')
                                      ? Colors.green
                                      : null,
                                ),
                              ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _calcular,
                  child: Text(local.calcular),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _guardarTesteo,
                  child: Text(local.guardarTesteo),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String localLabel(String key, AppLocalizations local) {
    switch (key) {
      case 'Cloro libre':
        return local.cloroLibreLabel;
      case 'Cloro combinado':
        return local.cloroCombinadoLabel;
      case 'pH':
        return local.ph;
      case 'Alcalinidad':
        return local.alcalinidad;
      case 'CYA':
        return local.cya;
      case 'Dureza':
        return local.dureza;
      case 'Salinidad':
        return local.salinidad;
      default:
        return key;
    }
  }
}
