import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/pool_calculator.dart';
import '../models/test_registro.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import '../utils/color_utils.dart';

class TestIndividualScreen extends StatefulWidget {
  const TestIndividualScreen({super.key});

  @override
  State<TestIndividualScreen> createState() => _TestIndividualScreenState();
}

class _TestIndividualScreenState extends State<TestIndividualScreen> {
  final TextEditingController _valorController = TextEditingController();
  final TextEditingController _gotasController = TextEditingController();

  String _parametroSeleccionado = 'Cloro libre';
  String _volumenSeleccionado = '25';
  String? _titulantePhSeleccionado;

  Map<String, String> _recomendaciones = {};
  Map<String, dynamic> _registroActual = {};
  Map<String, Map<String, String>> _todasLasRecomendaciones = {};

  @override
  void initState() {
    super.initState();
    _cargarEstadoTemporal();
    _verificarVolumenSeleccionado();
  }

  void _verificarVolumenSeleccionado() {
    if (!['10', '25'].contains(_volumenSeleccionado)) {
      _volumenSeleccionado = '25';
    }
  }

  Future<Map<String, double>?> _pedirDatosShock(
      BuildContext context, {
        double? fcActual,
        double? cyaActual,
      }) async {
    final l = AppLocalizations.of(context)!;

    final fcCtrl = TextEditingController(
      text: (fcActual != null) ? fcActual.toStringAsFixed(1) : '',
    );
    final cyaCtrl = TextEditingController(
      text: (cyaActual != null) ? cyaActual.toStringAsFixed(0) : '',
    );

    return showDialog<Map<String, double>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l.shockModeTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.shockDialogIntro),
              const SizedBox(height: 8),
              TextField(
                controller: fcCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l.freeChlorinePpmLabel,
                  hintText: l.freeChlorineHintExample,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: cyaCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l.cyaPpmLabel,
                  hintText: l.cyaHintExample,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(l.btnCancel),
            ),
            FilledButton(
              onPressed: () {
                final fc = double.tryParse(fcCtrl.text.trim());
                final cya = double.tryParse(cyaCtrl.text.trim());
                if (fc == null || cya == null) return; // guard simple
                Navigator.of(ctx).pop({'fc': fc, 'cya': cya});
              },
              child: Text(l.btnUseValues),
            ),
          ],
        );
      },
    );
  }


  Future<void> _cargarEstadoTemporal() async {
    final prefs = await SharedPreferences.getInstance();
    final tempRegistro = prefs.getString('temp_individual');
    final tempRecs = prefs.getString('temp_recomendaciones_individual');


    if (tempRegistro != null) {
      final Map<String, dynamic> datos = json.decode(tempRegistro);
      final Map<String, String> datosConvertidos =
      datos.map((k, v) => MapEntry(k, v.toString()));

      // Restaurar volumen si es válido
      final String? volumenGuardado = datos['volumen_muestra']?.toString();
      final valoresPermitidos = ['10', '25'];
      _volumenSeleccionado = valoresPermitidos.contains(volumenGuardado)
          ? volumenGuardado!
          : '25'; // valor por defecto si es inválido

      String parametroValido = datos['parametro_seleccionado']?.toString() ?? 'Cloro libre';

      setState(() {
        _registroActual = datosConvertidos;
        _parametroSeleccionado = parametroValido;
        _valorController.text = datos[parametroValido]?.toString() ?? '';
      });
    }

    if (tempRecs != null) {
      final Map<String, dynamic> recs = json.decode(tempRecs);
      final Map<String, String> recomendacionesConvertidas =
      recs.map((k, v) => MapEntry(k, v.toString()));

      setState(() {
        _recomendaciones = recomendacionesConvertidas;
        if (_recomendaciones.containsKey(_parametroSeleccionado)) {
          _todasLasRecomendaciones[_parametroSeleccionado] = {
            _parametroSeleccionado: _recomendaciones[_parametroSeleccionado]!
          };
        }
      });
    }
    final tempTodas = prefs.getString('temp_todas_recomendaciones');
    if (tempTodas != null) {
      final Map<String, dynamic> todas = json.decode(tempTodas);
      setState(() {
        _todasLasRecomendaciones = todas.map((k, v) => MapEntry(k, {k: v.toString()}));
        if (_todasLasRecomendaciones.containsKey(_parametroSeleccionado)) {
          _recomendaciones[_parametroSeleccionado] =
          _todasLasRecomendaciones[_parametroSeleccionado]![_parametroSeleccionado]!;
        }
      });
    }

  }

  // Devuelve el último valor guardado en 'test_registros' para un parámetro dado.
  Future<double?> _getUltimoValorDe(String parametroBuscado) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('test_registros');
    if (raw == null || raw.isEmpty) return null;

    try {
      final List list = json.decode(raw);
      // Recorremos desde el final (más reciente)
      for (int i = list.length - 1; i >= 0; i--) {
        final item = Map<String, dynamic>.from(list[i]);
        final p = (item['parametro'] ?? '').toString();
        if (p.toLowerCase().trim() == parametroBuscado.toLowerCase().trim()) {
          final v = item['valor'];
          if (v is num) return v.toDouble();
          if (v is String) {
            final d = double.tryParse(v);
            if (d != null) return d;
          }
        }
      }
    } catch (_) {}
    return null;
  }


  Future<void> _calcular() async {
    FocusScope.of(context).unfocus();

    final local = AppLocalizations.of(context)!;
    final prefs = await SharedPreferences.getInstance();
    final gotas = double.tryParse(_gotasController.text.trim());
    final valorManual = double.tryParse(_valorController.text.trim());
    final parametro = _parametroSeleccionado;
    final volumen = _volumenSeleccionado;

    final registro = <String, dynamic>{
      'volumen_muestra': volumen,
      'tipo': 'individual',
      'fecha': DateTime.now().toIso8601String(),
    };

    if (gotas != null) {
      registro['${parametro} gotas'] = gotas;
    }

    // Calcular valor final en ppm
    final valor = valorManual ??
        (gotas != null
            ? (parametro.toLowerCase().contains('cloro')
            ? (volumen == '10' ? gotas * 0.5 : gotas * 0.2)
            : gotas)
            : null);

    if (valor != null) {
      registro['parametro'] = parametro;
      registro['valor_ppm'] = double.parse(valor.toStringAsFixed(2));
    }

    final unidad = Provider.of<SettingsController>(context, listen: false).unidadSistema;

// Construir mapa de parámetros completo
    final Map<String, dynamic> parametrosAjuste = {
      parametro: valor ?? 0.0,
      'volumen_muestra': volumen,
    };
    if (parametro == 'pH' && gotas != null) {
      parametrosAjuste['pH gotas'] = gotas.toInt().toString();

      if (_titulantePhSeleccionado != null) {
        parametrosAjuste['pH titulante'] = _titulantePhSeleccionado;
      }
    } else if (gotas != null) {
      parametrosAjuste['${parametro} gotas'] = gotas;
    }


    if (parametro == 'pH' && gotas != null) {
      parametrosAjuste['pH gotas'] = gotas.toInt().toString(); // <-- necesario para el cálculo de pH dinámico
    } else if (gotas != null) {
      parametrosAjuste['${parametro} gotas'] = gotas;
    }

    // 🔸 Paso 2: auto-completar para modo shock en "Cloro combinado"
    if (parametro == 'Cloro combinado' || parametro == 'Combined chlorine') {
      // Si no viene CYA este turno, buscamos el último
      if (parametrosAjuste['CYA'] == null) {
        final ultCya = await _getUltimoValorDe('CYA');
        if (ultCya != null) parametrosAjuste['CYA'] = ultCya;
      }
      // Si no viene FC este turno, buscamos el último
      if (parametrosAjuste['Cloro libre'] == null &&
          parametrosAjuste['Cloro libre gotas'] == null) {
        final ultFc = await _getUltimoValorDe('Cloro libre');
        if (ultFc != null) parametrosAjuste['Cloro libre'] = ultFc;
      }
    }

    // 🔸 Paso 2.5: si CC dispara shock y aún faltan FC o CYA, pedirlos al vuelo (i18n)  ⬅️ NUEVO
    if (parametro == 'Cloro combinado' || parametro == 'Combined chlorine') {
      // El CC actual (en ppm) es el 'valor' calculado arriba si estás testeando CC
      final double? ccActual = valor;

      // Usamos el mismo umbral que en pool_calculator (_isShockNeeded: >= 0.3)
      final bool shock = (ccActual != null && ccActual >= 0.3);

      // ¿Siguen faltando FC o CYA tras el auto-completado?
      final bool faltaFC = !(parametrosAjuste.containsKey('Cloro libre') ||
          parametrosAjuste.containsKey('Cloro libre gotas'));
      final bool faltaCYA = !parametrosAjuste.containsKey('CYA');

      if (shock && (faltaFC || faltaCYA)) {
        final overrides = await _pedirDatosShock(
          context,
          // Si tenés algo previo en memoria, se muestra como valor inicial (opcional)
          fcActual: double.tryParse((_registroActual['cloroLibre'] ?? '').toString()),
          cyaActual: double.tryParse((_registroActual['cya'] ?? '').toString()),
        );
        if (overrides != null) {
          // Inyectamos valores directos en ppm para que calcularAjustes haga dosis exacta
          parametrosAjuste['Cloro libre'] = overrides['fc'];
          parametrosAjuste.remove('Cloro libre gotas'); // por si había gotas
          parametrosAjuste['CYA'] = overrides['cya'];

          // Opcional: guardar en el estado para reuso inmediato
          _registroActual['cloroLibre'] = overrides['fc']!.toStringAsFixed(1);
          _registroActual['cya'] = overrides['cya']!.toStringAsFixed(0);
        }
      }
    }


    final recomendaciones = await calcularAjustes(
      parametrosAjuste,
      context,
      unidad,
    );

// ---- Elegir UN solo texto para este parámetro ----
    final String param = _parametroSeleccionado;

// 1) el del parámetro, si existe y no está vacío
    String? textoSel = recomendaciones[param];
// 2) si no, el primero del mapa (si hay)
    if (textoSel == null || textoSel.trim().isEmpty) {
      textoSel = recomendaciones.isNotEmpty ? recomendaciones.values.first : '—';
    }

// guardá también en el registro (para el popup / historial)
    registro['parametro_seleccionado'] = param;
    registro['recomendacion'] = textoSel;

    setState(() {
      // Estado del registro en memoria (todo a String)
      _registroActual = registro.map((k, v) => MapEntry(k, v.toString()));

      // 🔒 UNA sola tarjeta para este parámetro
      _todasLasRecomendaciones[param] = { param: textoSel! };

      // Texto que se muestra debajo
      _recomendaciones[param] = textoSel!;
    });

// ---- Persistencia temporal (formato compatible con tu _cargarEstadoTemporal) ----
    await prefs.setString('temp_individual', json.encode(_registroActual));
    await prefs.setString('temp_recomendaciones_individual', json.encode(_recomendaciones));
    await prefs.setString(
      'temp_todas_recomendaciones',
      json.encode(
        _todasLasRecomendaciones.map((p, rec) => MapEntry(p, rec.values.first)),
      ),
    );



  }

  Future<void> _guardarTesteo() async {
    if (_registroActual.isEmpty) return;

    final parametro = _parametroSeleccionado;
    final volumen = _volumenSeleccionado;           // "10" o "25"
    final valorStr = _valorController.text.trim();
    final gotasStr = _gotasController.text.trim();

    final double? valorManual = double.tryParse(valorStr);
    final double? gotas = double.tryParse(gotasStr);

    double? valorPPM;

    // Calculamos PPM según el parámetro y si vino en gotas o manual
    switch (parametro) {
      case 'Cloro libre':
      case 'Cloro combinado':
        if (valorManual != null) {
          valorPPM = valorManual;
        } else if (gotas != null) {
          final factor = (volumen == '10') ? 0.5 : 0.2; // FAS‑DPD
          valorPPM = gotas * factor;                    // 130 gotas @25mL → 26 ppm
        }
        break;

      case 'Alcalinidad':
        if (valorManual != null) {
          valorPPM = valorManual;
        } else if (gotas != null) {
          final factor = (volumen == '10') ? 25.0 : 10.0; // Taylor
          valorPPM = gotas * factor;
        }
        break;

      case 'Dureza':
        if (valorManual != null) {
          valorPPM = valorManual;
        } else if (gotas != null) {
          valorPPM = gotas * 10.0; // 1 gota = 10 ppm
        }
        break;

    // pH, CYA, Salinidad: se guardan tal cual el valor ingresado
      default:
        valorPPM = valorManual;
        break;
    }

    // Guardamos en el registro actual (incluye contexto)
    if (gotas != null) {
      _registroActual['${parametro} gotas'] = gotas;
    }
    _registroActual['volumen_muestra'] = volumen;
    _registroActual['parametro'] = parametro;

    if (valorPPM != null) {
      _registroActual['valor_ppm'] = double.parse(valorPPM.toStringAsFixed(2));
    }

    _registroActual['tipo'] = 'individual';
    final texto = _recomendaciones[parametro] ?? '❌ (no se calculó recomendación)';
    _registroActual['recomendacion'] = texto;

    await _saveRegistro(_registroActual); // Guarda en test_individual

    // Además guardamos en test_registros para históricos/gráficos:
    final registro = TestRegistro(
      tipo: 'individual',
      fecha: DateTime.now(),
      parametro: parametro,
      valor: valorPPM ?? 0.0,  // 👈 aquí va el ppm correcto
      recomendacion: texto,
    );

    final prefs = await SharedPreferences.getInstance();
    final registrosRaw = prefs.getString('test_registros') ?? '[]';
    final List decoded = json.decode(registrosRaw);
    decoded.add(registro.toJson());
    await prefs.setString('test_registros', json.encode(decoded));

    // limpiar estado temporal + UI como ya tenías…
    await prefs.remove('temp_individual');
    await prefs.remove('temp_recomendaciones_individual');
    await prefs.remove('temp_todas_recomendaciones');

    _todasLasRecomendaciones.remove(_parametroSeleccionado);

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


  Future<void> _saveRegistro(Map<String, dynamic> registro) async {
    final prefs = await SharedPreferences.getInstance();

    // Guardar también en lista de 'registros' (opcional si todavía lo usás)
    final List<String> registros = prefs.getStringList('registros') ?? [];
    registros.add(json.encode(registro));
    await prefs.setStringList('registros', registros);

    // Guardar en 'test_individual' o 'test_completo' según tipo
    final String tipo = registro['tipo'] ?? 'individual';
    final String clave = tipo == 'completo' ? 'test_completo' : 'test_individual';

    final String? dataGuardada = prefs.getString(clave);
    List<Map<String, dynamic>> lista = [];

    if (dataGuardada != null && dataGuardada.isNotEmpty) {
      try {
        lista = List<Map<String, dynamic>>.from(json.decode(dataGuardada));
      } catch (_) {}
    }

    lista.add(registro);
    await prefs.setString(clave, json.encode(lista));
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final esAguaSalada =
        Provider.of<SettingsController>(context).esAguaSalada;

    // ✅ Validación antes de renderizar
    if (!['10', '25'].contains(_volumenSeleccionado)) {
      _volumenSeleccionado = '10';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(local.testIndividual),
      ),
      body: SingleChildScrollView(
        child: Container(
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

                      // ✅ Forzar 25 mL si se selecciona Dureza
                      if (value == 'Dureza') {
                        _volumenSeleccionado = '25';
                      }
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
                            color: colorParaParametro(_parametroSeleccionado),
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

              if (_parametroSeleccionado == 'Dureza')
                TextField(
                  controller: _gotasController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${local.gotas} (25 mL)',
                    border: const OutlineInputBorder(),
                  ),
                )
              else if (_parametroSeleccionado.contains('Cloro') ||
                  _parametroSeleccionado == 'Alcalinidad')
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
                          : '10', // fallback seguro
                      hint: const Text("Seleccionar volumen"),
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
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _gotasController,
                          keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: local.gotas,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: _titulantePhSeleccionado,
                          isExpanded: true,
                          hint: Text('R-005 / R-006'),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(value: 'R-005', child: Text('R-005 (ácido)')),
                            DropdownMenuItem(value: 'R-006', child: Text('R-006 (base)')),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _titulantePhSeleccionado = val;
                            });
                          },
                        ),
                      ),
                    ],
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
              if (_todasLasRecomendaciones[_parametroSeleccionado]?.isNotEmpty ?? false)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _todasLasRecomendaciones[_parametroSeleccionado]!.entries.map((entry) {
                    final lines = entry.value.trim().split('\n');

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(2, 2),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localLabel(_parametroSeleccionado, local),
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
              // Mostrar leyenda del tipo de pileta actual
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  local.leyendaModoActual(
                    esAguaSalada ? local.resumenAguaSalada : local.resumenAguaDulce,
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700],
                  ),
                ),
              ),

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



}