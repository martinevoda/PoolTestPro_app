// ... importaciones igual
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
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('temp_individual');
    });
    _verificarVolumenSeleccionado();
    _cargarEstadoTemporal();
  }

  void _verificarVolumenSeleccionado() {
    if (!['10', '25'].contains(_volumenSeleccionado)) {
      _volumenSeleccionado = '10';
    }
  }

  Future<void> _cargarEstadoTemporal() async {
    final prefs = await SharedPreferences.getInstance();
    final tempRegistro = prefs.getString('temp_individual');
    final tempRecs = prefs.getString('temp_recomendaciones_individual');

    if (tempRegistro != null) {
      final Map<String, dynamic> datos = json.decode(tempRegistro);
      final Map<String, String> datosConvertidos =
      datos.map((k, v) => MapEntry(k, v.toString()));

      final String? volumenGuardado = datos['volumen_muestra']?.toString();
      final valoresPermitidos = ['10', '25'];

      if (!valoresPermitidos.contains(volumenGuardado)) {
        datos.remove('volumen_muestra');
        _volumenSeleccionado = '10';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('temp_individual', json.encode(datos));
      } else {
        _volumenSeleccionado = volumenGuardado!;
      }

      setState(() {
        _registroActual = datosConvertidos;
        _parametroSeleccionado = datos.keys.first;
        _valorController.text = datos.values.first.toString();
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
    final unidadSistema =
        Provider.of<SettingsController>(context, listen: false).unidadSistema;

    final gotas = int.tryParse(_gotasController.text.trim());
    final valorManual = double.tryParse(_valorController.text.trim());

    if (gotas == null && valorManual == null) return;

    final Map<String, String> registro = {
      'volumen_muestra': _volumenSeleccionado,
      'tipo': 'individual',
      'fecha': DateTime.now().toIso8601String(),
    };

    if (_parametroSeleccionado.contains('Cloro') ||
        _parametroSeleccionado == 'Alcalinidad' ||
        _parametroSeleccionado == 'Dureza' ||
        _parametroSeleccionado == 'pH') {
      if (gotas != null) {
        registro['${_parametroSeleccionado} gotas'] = gotas.toString();
        if (_parametroSeleccionado == 'pH' && valorManual != null) {
          registro['pH'] = valorManual.toStringAsFixed(2);
        }
      } else if (valorManual != null) {
        registro[_parametroSeleccionado] = valorManual.toStringAsFixed(2);
      }
    } else {
      if (valorManual != null) {
        registro[_parametroSeleccionado] = valorManual.toStringAsFixed(2);
      }
    }

    final recomendaciones =
    await calcularAjustes(registro, context, unidadSistema);

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
    final esAguaSalada =
        Provider.of<SettingsController>(context).esAguaSalada;

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
                  .map((param) => DropdownMenuItem(
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
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _colorParaParametro(_parametroSeleccionado),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        local.steps,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),
                  Text(
                    _instruccionesTest(local),
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            if (_parametroSeleccionado.contains('Cloro') ||
                _parametroSeleccionado == 'Alcalinidad' ||
                _parametroSeleccionado == 'Dureza')
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _gotasController,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: '${local.gotas}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: ['10', '25'].contains(_volumenSeleccionado)
                        ? _volumenSeleccionado
                        : '10',
                    items: ['10', '25']
                        .map((v) => DropdownMenuItem<String>(
                      value: v,
                      child: Text('$v mL'),
                    ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _volumenSeleccionado = val;
                        });
                      }
                    },
                  ),
                ],
              )
            else if (_parametroSeleccionado == 'pH')
              TextField(
                controller: _gotasController,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '${local.gotas}',
                  border: const OutlineInputBorder(),
                ),
              ),

            const SizedBox(height: 12),

            if (!(_parametroSeleccionado.contains('Cloro') ||
                _parametroSeleccionado == 'Alcalinidad' ||
                _parametroSeleccionado == 'Dureza' ||
                _parametroSeleccionado == 'pH') ||
                (_gotasController.text.trim().isEmpty &&
                    (_parametroSeleccionado == 'Cloro libre' ||
                        _parametroSeleccionado == 'Cloro combinado' ||
                        _parametroSeleccionado == 'pH' ||
                        _parametroSeleccionado == 'Alcalinidad' ||
                        _parametroSeleccionado == 'Dureza'))) ...[
              if (_parametroSeleccionado != 'CYA' && _parametroSeleccionado != 'Salinidad')
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    local.leyendaValorManual,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),

              TextField(
                controller: _valorController,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: local.valor,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],

            const SizedBox(height: 20),

            if (_recomendaciones.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _recomendaciones.entries.map((entry) {
                  final lines = entry.value.trim().split('\n');

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lines.first,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        ...lines.skip(1).map(
                              (line) => Text(
                            line,
                            style: TextStyle(
                              color: line.contains('⚠️') || line.contains('❌')
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

  String _instruccionesTest(AppLocalizations local) {
    final volumen = _volumenSeleccionado;
    switch (_parametroSeleccionado) {
      case 'Cloro libre':
        return local.instruccionesCloroLibre(volumen);
      case 'Cloro combinado':
        return local.instruccionesCloroCombinado(volumen);
      case 'Alcalinidad':
        return local.instruccionesAlcalinidad(volumen);
      case 'Dureza':
        return local.instruccionesDureza(volumen);
      case 'pH':
        return local.instruccionesPh;
      case 'CYA':
        return local.instruccionesCya;
      case 'Salinidad':
        return local.instruccionesSalinidad;

      default:
        return '';
    }
  }

  Color _colorParaParametro(String parametro) {
    final p = parametro.toLowerCase();
    if (p.contains('cloro')) return Colors.amber;
    if (p == 'ph') return Colors.redAccent;
    if (p == 'alcalinidad') return Colors.green;
    if (p == 'cya') return Colors.grey.shade300;
    if (p == 'dureza') return Colors.blueAccent;
    return Colors.transparent; // salinidad o sin color
  }

}
