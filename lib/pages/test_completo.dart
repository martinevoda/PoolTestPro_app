// ... importaciones igual
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../utils/pool_calculator.dart';
import '../models/test_registro.dart';
import 'dart:convert';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import '../utils/stock_service.dart';

class TestCompletoPage extends StatefulWidget {
  const TestCompletoPage({super.key});

  @override
  _TestCompletoPageState createState() => _TestCompletoPageState();
}

class _TestCompletoPageState extends State<TestCompletoPage> {
  final Map<String, TextEditingController> _controllers = {
    'pH': TextEditingController(),
    'Alcalinidad': TextEditingController(),
    'CYA': TextEditingController(),
    'Dureza': TextEditingController(),
    'Salinidad': TextEditingController(),
  };

  final TextEditingController _cloroLibreGotas = TextEditingController();
  final TextEditingController _cloroCombinadoGotas = TextEditingController();

  String _volumenCloroLibre = '10';
  String _volumenCloroCombinado = '10';

  Map<String, String> _recomendaciones = {};
  Map<String, String> _registroActual = {};

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _cloroLibreGotas.dispose();
    _cloroCombinadoGotas.dispose();
    super.dispose();
  }

  Future<void> _calcularYGuardar() async {
    double cloroLibrePPM = 0;
    double cloroCombinadoPPM = 0;

    final gotasLibre = int.tryParse(_cloroLibreGotas.text.trim());
    final gotasCombinado = int.tryParse(_cloroCombinadoGotas.text.trim());

    if (gotasLibre != null) {
      cloroLibrePPM = _volumenCloroLibre == '10' ? gotasLibre * 0.5 : gotasLibre * 0.2;
    }

    if (gotasCombinado != null) {
      cloroCombinadoPPM = _volumenCloroCombinado == '10' ? gotasCombinado * 0.5 : gotasCombinado * 0.2;
    }

    final Map<String, String> registro = {
      'Cloro libre': cloroLibrePPM.toStringAsFixed(2),
      'Cloro combinado': cloroCombinadoPPM.toStringAsFixed(2),
      for (var key in _controllers.keys) key: _controllers[key]!.text.trim(),
      'tipo': 'completo',
      'fecha': DateTime.now().toIso8601String(),
    };

    final unidadSistema = Provider.of<SettingsController>(context, listen: false).unidadSistema;

    final recomendaciones = await calcularAjustes(registro, context, unidadSistema);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('temp_test_completo', json.encode(registro));

    setState(() {
      _recomendaciones = recomendaciones;
      _registroActual = registro;
    });
  }

  Future<void> _guardar() async {
    if (_registroActual.isEmpty) return;

    await _saveRegistro(_registroActual);
    await _saveRegistrosComoTestRegistro(_registroActual);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('temp_test_completo');

    setState(() {
      for (var controller in _controllers.values) {
        controller.clear();
      }
      _cloroLibreGotas.clear();
      _cloroCombinadoGotas.clear();
      _volumenCloroLibre = '10';
      _volumenCloroCombinado = '10';
      _recomendaciones.clear();
      _registroActual.clear();
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

    final String? existentes = prefs.getString('test_completo');
    List<Map<String, dynamic>> lista = [];

    if (existentes != null) {
      lista = List<Map<String, dynamic>>.from(json.decode(existentes));
    }

    lista.add(registro);
    await prefs.setString('test_completo', json.encode(lista));
  }

  Future<void> _saveRegistrosComoTestRegistro(Map<String, String> registro) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('test_registros');
    List<Map<String, dynamic>> lista = [];

    if (data != null) {
      lista = List<Map<String, dynamic>>.from(json.decode(data));
    }

    final now = DateTime.now();
    for (var entry in registro.entries) {
      if (entry.key != 'fecha' && entry.key != 'tipo') {
        final valorStr = entry.value.trim();
        final valor = double.tryParse(valorStr);
        if (valor != null) {
          final test = TestRegistro(
            tipo: registro['tipo'] ?? 'completo',
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
    final esAguaSalada = Provider.of<SettingsController>(context).esAguaSalada;

    return Scaffold(
      appBar: AppBar(title: Text(local.testCompleto)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildCloroField(local.cloroLibre, _cloroLibreGotas,
                    (val) => setState(() => _volumenCloroLibre = val!), _volumenCloroLibre),
            const SizedBox(height: 12),
            _buildCloroField(local.cloroCombinado, _cloroCombinadoGotas,
                    (val) => setState(() => _volumenCloroCombinado = val!), _volumenCloroCombinado),
            const SizedBox(height: 16),
            for (var entry in _controllers.entries)
              if (esAguaSalada || entry.key != 'Salinidad')
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: entry.value,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: localLabel(entry.key, local),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
            const SizedBox(height: 20),
            if (_recomendaciones.isNotEmpty)
              Card(
                color: Theme.of(context).cardColor,
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _recomendaciones.entries.map((entry) {
                      final mensaje = entry.value;
                      final esNormal = mensaje.contains('✅');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${localLabel(entry.key, local)}: $mensaje',
                          style: TextStyle(
                            color: esNormal ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _calcularYGuardar,
                  child: Text(local.calcular),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _guardar,
                  child: Text(local.guardarTesteo),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloroField(String label, TextEditingController controller,
      void Function(String?) onChanged, String volumenSeleccionado) {
    final local = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '$label (${local.gotas})',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        DropdownButton<String>(
          value: volumenSeleccionado,
          items: ['10', '25']
              .map((vol) => DropdownMenuItem(value: vol, child: Text('$vol mL')))
              .toList(),
          onChanged: onChanged,
        ),
      ],
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
