import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class RegistrosAnterioresPage extends StatefulWidget {
  const RegistrosAnterioresPage({super.key});

  @override
  State<RegistrosAnterioresPage> createState() => _RegistrosAnterioresPageState();
}

class _RegistrosAnterioresPageState extends State<RegistrosAnterioresPage> {
  List<Map<String, dynamic>> _completos = [];
  List<Map<String, dynamic>> _individuales = [];

  @override
  void initState() {
    super.initState();
    _loadRegistros();
  }

  Future<void> _loadRegistros() async {
    final prefs = await SharedPreferences.getInstance();
    final completos = prefs.getString('test_completo') ?? '[]';
    final individuales = prefs.getString('test_individual') ?? '[]';

    setState(() {
      _completos = List<Map<String, dynamic>>.from(json.decode(completos));
      _individuales = List<Map<String, dynamic>>.from(json.decode(individuales));
    });
  }

  Future<void> _borrarRegistro(int index, String tipo) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = tipo == 'completo' ? _completos : _individuales;
    final registro = lista[index];
    final fecha = registro['fecha'];

    // Borrar del tipo correspondiente
    final key = tipo == 'completo' ? 'test_completo' : 'test_individual';
    final data = prefs.getString(key) ?? '[]';
    final registrosGuardados = List<Map<String, dynamic>>.from(json.decode(data));
    registrosGuardados.removeWhere((item) => item['fecha'] == fecha);
    await prefs.setString(key, json.encode(registrosGuardados));

    // Borrar también de test_registros
    final registrosGraficosRaw = prefs.getString('test_registros') ?? '[]';
    final registrosGraficos = List<Map<String, dynamic>>.from(json.decode(registrosGraficosRaw));
    registrosGraficos.removeWhere((item) => item['fecha'] == fecha);
    await prefs.setString('test_registros', json.encode(registrosGraficos));

    _loadRegistros();
  }

  void _confirmarBorrado(int index, String tipo) {
    final local = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(local.confirmarBorradoTitulo),
        content: Text(local.confirmarBorradoMensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(local.cancelar),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _borrarRegistro(index, tipo);
            },
            child: Text(local.borrar),
          ),
        ],
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

  Widget _buildRegistroCard(Map<String, dynamic> registro, int index, String tipo, AppLocalizations local) {
    final fecha = DateTime.tryParse(registro['fecha'] ?? '');
    final sinFecha = fecha == null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(
          tipo == 'completo'
              ? '🧪 ${local.testCompleto}'
              : '🧪 ${local.testIndividual}',
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!sinFecha)
              Text('📅 ${local.fecha}: ${fecha.toLocal().toString().substring(0, 16)}'),
            const SizedBox(height: 6),
            ...registro.entries
                .where((e) => e.key != 'fecha' && e.key != 'tipo')
                .map((e) => e.key != null && e.value != null
                ? Text('${localLabel(e.key, local)}: ${e.value}')
                : const SizedBox.shrink()),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _confirmarBorrado(index, tipo),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(local.registrosAnteriores)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_individuales.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🧪 ${local.testIndividual}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ...List.generate(_individuales.length,
                            (index) => _buildRegistroCard(_individuales[index], index, 'individual', local)),
                  ],
                ),
              ),
            if (_completos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🧪 ${local.testCompleto}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ...List.generate(_completos.length,
                            (index) => _buildRegistroCard(_completos[index], index, 'completo', local)),
                  ],
                ),
              ),
            if (_individuales.isEmpty && _completos.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text(local.sinRegistros)),
              )
          ],
        ),
      ),
    );
  }
}
