import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/pool_calculator.dart';
import '../models/test_registro.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TestIndividualScreen extends StatefulWidget {
  const TestIndividualScreen({super.key});

  @override
  _TestIndividualScreenState createState() => _TestIndividualScreenState();
}

class _TestIndividualScreenState extends State<TestIndividualScreen> {
  final TextEditingController _valorController = TextEditingController();
  final TextEditingController _gotasController = TextEditingController();
  String _parametroSeleccionado = 'Cloro libre';
  String _volumenSeleccionado = '10';
  bool _usarGotas = true;

  List<Map<String, dynamic>> _registros = [];
  Map<String, String> _recomendaciones = {};

  @override
  void initState() {
    super.initState();
    _loadRegistros();
  }

  @override
  void dispose() {
    _valorController.dispose();
    _gotasController.dispose();
    super.dispose();
  }

  Future<void> _loadRegistros() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('test_individual') ?? '[]';
    setState(() {
      _registros = List<Map<String, dynamic>>.from(json.decode(data));
    });
  }

  Future<void> _saveRegistro(Map<String, dynamic> registro) async {
    final prefs = await SharedPreferences.getInstance();
    _registros.add(registro);
    await prefs.setString('test_individual', json.encode(_registros));
  }

  Future<void> _saveComoTestRegistro(String parametro, String valor) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('test_registros') ?? '[]';
    List<Map<String, dynamic>> lista = List<Map<String, dynamic>>.from(json.decode(data));

    lista.add({
      'parametro': parametro,
      'valor': double.tryParse(valor) ?? 0.0,
      'fecha': DateTime.now().toIso8601String(),
      'tipo': 'individual',
    });

    await prefs.setString('test_registros', json.encode(lista));
  }

  void _calcularYGuardar() {
    double ppm = 0;
    final registro = <String, String>{};

    if (_usarGotas) {
      final gotas = int.tryParse(_gotasController.text.trim()) ?? 0;
      ppm = _volumenSeleccionado == '10' ? gotas * 0.5 : gotas * 0.2;
    } else {
      ppm = double.tryParse(_valorController.text.trim()) ?? 0;
    }

    final valorFinal = ppm.toStringAsFixed(2);
    registro[_parametroSeleccionado] = valorFinal;
    registro['tipo'] = 'individual';
    registro['fecha'] = DateTime.now().toIso8601String();

    _saveRegistro(Map<String, dynamic>.from(registro));
    _saveComoTestRegistro(_parametroSeleccionado, valorFinal);

    final local = AppLocalizations.of(context)!;
    setState(() {
      _recomendaciones = calcularAjustes(registro, local);
    });
  }

  Map<String, String> getParametros(AppLocalizations local) => {
    'Cloro libre': local.cloroLibre,
    'Cloro combinado': local.cloroCombinado,
    'pH': 'pH',
    'Alcalinidad': local.alcalinidad,
    'CYA': local.cya,
    'Dureza': local.dureza,
    'Salinidad': local.salinidad,
  };

  Widget _buildInputFields(AppLocalizations local) {
    if (_parametroSeleccionado == 'Cloro libre' || _parametroSeleccionado == 'Cloro combinado') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: _usarGotas,
                onChanged: (val) => setState(() => _usarGotas = val ?? true),
              ),
              Text(local.usarGotasCheckbox),
            ],
          ),
          if (_usarGotas)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _gotasController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: local.cantidadGotas,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                DropdownButton<String>(
                  value: _volumenSeleccionado,
                  items: ['10', '25']
                      .map((v) => DropdownMenuItem(value: v, child: Text('$v mL')))
                      .toList(),
                  onChanged: (val) => setState(() => _volumenSeleccionado = val ?? '10'),
                ),
              ],
            )
          else
            TextField(
              controller: _valorController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: local.valorEnPPM,
                border: OutlineInputBorder(),
              ),
            ),
        ],
      );
    } else {
      return TextField(
        controller: _valorController,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: local.valorMedido,
          border: OutlineInputBorder(),
        ),
      );
    }
  }

  Color _getColor(String line) {
    if (line.contains('✅')) return Colors.green[700]!;
    if (line.contains('⚠️') || line.contains('Bajo') || line.contains('Alto')) return Colors.red[700]!;
    if (line.contains('🔹')) return Colors.blueGrey;
    return Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final parametrosTraducidos = getParametros(local);

    return Scaffold(
      appBar: AppBar(title: Text(local.testIndividual)),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _parametroSeleccionado,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _parametroSeleccionado = value;
                    _usarGotas = value == 'Cloro libre' || value == 'Cloro combinado';
                  });
                }
              },
              items: parametrosTraducidos.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              decoration: InputDecoration(
                labelText: local.parametro,
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            _buildInputFields(local),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _calcularYGuardar,
              child: Text(local.calcular),
            ),
            SizedBox(height: 24),
            if (_recomendaciones.isNotEmpty) ...[
              Text(
                local.recomendacionesTitulo,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              ..._recomendaciones.entries.map((entry) {
                final lines = entry.value.split('\n');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: lines.map((line) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: TextStyle(
                            fontSize: 16,
                            color: _getColor(line),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
