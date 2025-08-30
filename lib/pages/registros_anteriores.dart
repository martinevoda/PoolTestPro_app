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

  /// Carga el HISTORIAL desde `registros`.
  /// Si está vacío pero hay datos en `test_registros`, hace una migración 1-vez.
  Future<void> _loadRegistros() async {
    final prefs = await SharedPreferences.getInstance();

    // --- Migración 1 vez: si 'registros' está vacío y existe 'test_registros', copiar entradas básicas.
    List<String> registrosStrList = prefs.getStringList('registros') ?? [];
    if (registrosStrList.isEmpty) {
      final testRaw = prefs.getString('test_registros') ?? '[]';
      try {
        final List list = json.decode(testRaw) as List;
        final List<String> migrados = [];
        for (final item in list) {
          try {
            final m = Map<String, dynamic>.from(item as Map);
            migrados.add(json.encode({
              'tipo': m['tipo'] ?? 'individual',
              'fecha': m['fecha'],
              'parametro': m['parametro'],
              // en test_registros suele estar 'valor'; en historial usamos 'valor_ppm'
              'valor_ppm': m['valor'] ?? m['valor_ppm'],
              'recomendacion': m['recomendacion'],
            }));
          } catch (_) {/*ignorar item corrupto*/}
        }
        if (migrados.isNotEmpty) {
          await prefs.setStringList('registros', migrados);
          registrosStrList = migrados;
        }
      } catch (_) {/*sin migración*/}
    }

    // --- Construir lista a mostrar desde 'registros'
    final List<TestRegistro> registros = [];
    for (final s in registrosStrList) {
      try {
        final Map<String, dynamic> m = Map<String, dynamic>.from(json.decode(s));
        final String? param = (m['parametro'] ?? m['parametro_seleccionado'])?.toString();
        final String? fechaIso = m['fecha']?.toString();
        if (param == null || fechaIso == null) continue;

        double? valor;
        final vppm = m['valor_ppm'];
        if (vppm is num) valor = vppm.toDouble();
        if (vppm is String) valor ??= double.tryParse(vppm);
        if (valor == null) {
          final v = m['valor'];
          if (v is num) valor = v.toDouble();
          if (v is String) valor ??= double.tryParse(v);
        }
        valor ??= 0.0;

        registros.add(
          TestRegistro(
            tipo: (m['tipo']?.toString() ?? 'individual'),
            fecha: DateTime.tryParse(fechaIso) ?? DateTime.now(),
            parametro: param,
            valor: valor,
            recomendacion: m['recomendacion']?.toString(),
          ),
        );
      } catch (_) {/*ignorar entrada corrupta*/}
    }

    final filtrados = registros
        .where((r) => r.tipo.toLowerCase() == 'individual')
        .toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha)); // más nuevos primero

    if (mounted) {
      setState(() => _testRegistros = filtrados);
    }
  }

  /// Borra un registro del HISTORIAL (`registros`) y su espejo en `test_registros`.
  Future<void> _borrarRegistro(TestRegistro registro) async {
    final prefs = await SharedPreferences.getInstance();
    final String fechaIso = registro.fecha.toIso8601String();

    // 1) Quitar de `registros` (StringList)
    final List<String> registrosStrList = prefs.getStringList('registros') ?? [];
    registrosStrList.removeWhere((s) {
      try {
        final m = Map<String, dynamic>.from(json.decode(s));
        return m['fecha']?.toString() == fechaIso;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList('registros', registrosStrList);

    // 2) Quitar de `test_registros` (lista JSON)
    final testRaw = prefs.getString('test_registros') ?? '[]';
    List testList;
    try {
      testList = List.from(json.decode(testRaw));
    } catch (_) {
      testList = [];
    }
    testList.removeWhere((item) {
      try {
        final m = Map<String, dynamic>.from(item as Map);
        return m['fecha']?.toString() == fechaIso;
      } catch (_) {
        return false;
      }
    });
    await prefs.setString('test_registros', json.encode(testList));

    await _loadRegistros();
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

  void _mostrarDetalles(TestRegistro registro, AppLocalizations local) {
    final texto = registro.recomendacion;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          '${localLabel(registro.parametro, local)} (${registro.valor.toStringAsFixed(1)})',
        ),
        content: (texto != null && texto.trim().isNotEmpty)
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
