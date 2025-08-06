import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import '../models/test_registro.dart';


class RegistrosAnterioresPage extends StatefulWidget {
  const RegistrosAnterioresPage({super.key});

  @override
  State<RegistrosAnterioresPage> createState() => _RegistrosAnterioresPageState();
}

class _RegistrosAnterioresPageState extends State<RegistrosAnterioresPage> {
  List<TestRegistro> _testRegistros = [];

  @override
  void initState() {
    super.initState();
    _loadRegistros();
  }

  Future<void> _loadRegistros() async {
    final prefs = await SharedPreferences.getInstance();
    final registrosRaw = prefs.getString('test_registros') ?? '[]';
    final List decoded = json.decode(registrosRaw);
    final List<TestRegistro> registros = decoded
        .map((e) => TestRegistro.fromJson(e as Map<String, dynamic>))
        .where((r) => r.tipo == 'individual') // ✅ Solo individuales
        .toList();

    registros.sort((a, b) => b.fecha.compareTo(a.fecha)); // Más nuevos arriba

    setState(() {
      _testRegistros = registros;
    });
  }

  Future<void> _borrarRegistro(TestRegistro registro) async {
    final prefs = await SharedPreferences.getInstance();
    final registrosRaw = prefs.getString('test_registros') ?? '[]';
    final List decoded = json.decode(registrosRaw);
    decoded.removeWhere((item) => item['fecha'] == registro.fecha.toIso8601String());
    await prefs.setString('test_registros', json.encode(decoded));
    _loadRegistros();
  }

  void _confirmarBorrado(TestRegistro registro) {
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
              _borrarRegistro(registro);
            },
            child: Text(local.borrar),
          ),
        ],
      ),
    );
  }

  String localLabel(String key, AppLocalizations local) {
    switch (key.toLowerCase()) {
      case 'cloro libre':
        return local.cloroLibreLabel;
      case 'cloro combinado':
        return local.cloroCombinadoLabel;
      case 'ph':
        return local.ph;
      case 'alcalinidad':
        return local.alcalinidad;
      case 'cya':
        return local.cya;
      case 'dureza':
        return local.dureza;
      case 'salinidad':
        return local.salinidad;
      default:
        return key;
    }
  }

  Widget _buildRegistroCard(TestRegistro registro, AppLocalizations local) {
    final esAguaSalada = Provider.of<SettingsController>(context).esAguaSalada;
    if (!esAguaSalada && registro.parametro.toLowerCase() == 'salinidad') {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text('🧪 ${local.testIndividual}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(
              '📅 ${local.fecha}: ${registro.fecha.toLocal().toString().substring(0, 16)}',
              style: const TextStyle(color: Colors.blue),
            ),
            const SizedBox(height: 6),
            Text('${localLabel(registro.parametro, local)}: ${registro.valor.toStringAsFixed(1)}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _confirmarBorrado(registro),
        ),
        onTap: () => _mostrarDetalles(registro, local),
      ),
    );
  }

  void _mostrarDetalles(TestRegistro registro, AppLocalizations local) async {
    final parametroTraducido = traducirParametro(registro.parametro.toLowerCase());
    final parametroNormalizado = normalizarParametro(parametroTraducido);
    final valores = {
      parametroNormalizado: registro.valor,
      'volumen_muestra': 10,
    };

    final texto = registro.recomendacion;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          '${localLabel(registro.parametro, local)} (${registro.valor.toStringAsFixed(1)})',
        ),
        content: texto != null && texto.trim().isNotEmpty
            ? SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: texto.trim().split('\n').map((linea) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Text(
                  linea,
                  style: TextStyle(
                    color: linea.contains('⚠️') || linea.contains('❌')
                        ? Colors.red
                        : linea.contains('✅')
                        ? Colors.green
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        )
            : Text(local.sinRecomendaciones),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String traducirParametro(String key) {
    final k = key.trim().toLowerCase();
    if (k.contains('free chlorine')) return 'cloro libre';
    if (k.contains('combined chlorine')) return 'cloro combinado';
    if (k.contains('ph')) return 'ph';
    if (k.contains('alkalinity')) return 'alcalinidad';
    if (k.contains('stabilizer') || k.contains('cya')) return 'cya';
    if (k.contains('hardness') || k.contains('calcium')) return 'dureza';
    if (k.contains('salinity')) return 'salinidad';
    return key;
  }

  String normalizarParametro(String parametro) {
    final p = parametro.toLowerCase();
    if (p.contains('cloro libre')) return 'Free chlorine';
    if (p.contains('cloro combinado')) return 'Combined chlorine';
    if (p.contains('ph')) return 'pH';
    if (p.contains('alcalinidad')) return 'Alkalinity';
    if (p.contains('cya') || p.contains('estabilizador')) return 'Stabilizer';
    if (p.contains('dureza')) return 'Calcium hardness';
    if (p.contains('salinidad')) return 'Salinity';
    return parametro;
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(local.registrosAnteriores)),
      body: _testRegistros.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(local.sinRegistros),
        ),
      )
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🧪 ${local.testIndividual}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._testRegistros.map((r) => _buildRegistroCard(r, local)),
            ],
          ),
        ),
      ),
    );
  }
}
