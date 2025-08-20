import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../utils/pool_calculator.dart';

/// === Helper para ejecutar una acción con un Locale inyectado ===
class _LocaleRunner<T> extends StatefulWidget {
  final Future<T?> Function(BuildContext) action;
  const _LocaleRunner({required this.action});

  @override
  State<_LocaleRunner<T>> createState() => _LocaleRunnerState<T>();
}

class _LocaleRunnerState<T> extends State<_LocaleRunner<T>> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final result = await widget.action(context);
      if (mounted) Navigator.of(context).pop<T>(result);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class DevCalculatorSmokePage extends StatefulWidget {
  const DevCalculatorSmokePage({super.key});

  @override
  State<DevCalculatorSmokePage> createState() => _DevCalculatorSmokePageState();
}

class _DevCalculatorSmokePageState extends State<DevCalculatorSmokePage> {
  final List<String> _log = [];
  bool _running = false;

  void _p(String msg) {
    debugPrint(msg);
    setState(() => _log.add(msg));
  }

  Future<T?> _withLocale<T>(
      Locale locale,
      Future<T?> Function(BuildContext) action,
      ) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, __, ___) {
          return Localizations.override(
            context: context,
            locale: locale,
            child: _LocaleRunner<T>(action: action),
          );
        },
      ),
    );
  }

  void _ok(bool cond, String okMsg, String failMsg) {
    _p(cond ? '✅ $okMsg' : '❌ $failMsg');
  }

  bool _isEs(BuildContext c) => Localizations.localeOf(c).languageCode == 'es';

  bool _hasDose(String s) =>
      s.contains('➕') || s.contains('➖') || s.contains('Agregar') || s.contains('Add');

  Set<String> _expectedTitlesEs(AppLocalizations l) => {
    l.cloroLibreLabel,
    l.cloroCombinadoLabel,
    l.alcalinidadLabel,
    l.durezaLabel,
    'Dureza', // alias permitido
    l.cyaLabel,
    l.salinidadLabel,
    l.ph,
  };

  Set<String> _expectedTitlesEn() => {
    'Free chlorine',
    'Combined Chlorine',
    'Alkalinity',
    'Calcium hardness',
    'CYA',
    'Salinity',
    'pH',
  };

  // === NUEVO: validaciones adicionales por tarjeta ===
  void _validateRecs({
    required Map<String, String> recs,
    required BuildContext ctxConLocale,
    required bool esSalada,
    required String unidadSistema, // 'metrico' o 'imperial'
  }) {
    final l10n = AppLocalizations.of(ctxConLocale)!;
    final es = _isEs(ctxConLocale);

    final rangoFC = esSalada ? '3–6 ppm' : '1–3 ppm';
    final rangoCYA = esSalada ? '60–80 ppm' : '30–50 ppm';

    final expectedHere = es ? _expectedTitlesEs(l10n) : _expectedTitlesEn();
    final expectedOther = es ? _expectedTitlesEn() : _expectedTitlesEs(l10n);

    for (final entry in recs.entries) {
      final title = entry.key;
      final body = entry.value;

      // 1) Título en el idioma correcto
      if (expectedHere.contains(title)) {
        _ok(true, 'Título OK: $title', '');
      } else if (expectedOther.contains(title)) {
        _ok(false, '', 'Título en idioma opuesto: $title (revisar localización de keys)');
      } else {
        _ok(false, '', 'Título inesperado: $title');
      }

      // 2) La tarjeta debe mostrar rango “📏 …” (todas las que no son “modo shock puro”)
      final muestraRango = body.contains('📏');
      _ok(muestraRango || body.contains('🧪'),
          'Tarjeta con rango o modo shock ($title)',
          'Falta rango (“📏 …”) y no es shock en $title');

      // 3) FC y CYA → validar rangos correctos en el cuerpo
      if (title == (es ? l10n.cloroLibreLabel : 'Free chlorine')) {
        _ok(body.contains(rangoFC),
            es ? 'FC rango OK ($rangoFC)' : 'FC range OK ($rangoFC)',
            (es ? 'FC rango incorrecto (esperado ' : 'Wrong FC range (expected ') + rangoFC + ')');
      }
      if (title == (es ? l10n.cyaLabel : 'CYA')) {
        _ok(body.contains(rangoCYA),
            es ? 'CYA rango OK ($rangoCYA)' : 'CYA range OK ($rangoCYA)',
            (es ? 'CYA rango incorrecto (esperado ' : 'Wrong CYA range (expected ') + rangoCYA + ')');
      }

      // 4) Estado esperado: si hay dosis → debe contener “➕/➖” y un “⚠️”;
      //    si es normal → debería contener “✅”.
      final hasDose = _hasDose(body);
      if (hasDose) {
        _ok(body.contains('⚠️') || body.contains('🧪'),
            'Tarjeta con acción/alerta ($title)',
            'Se esperaba alerta/acción en $title');
      } else {
        _ok(body.contains('✅') || body.contains('🧪'),
            'Tarjeta sin dosis con estado OK/shock ($title)',
            'Se esperaba “✅ normal” o “🧪 shock” en $title');
      }

      // 5) Unidades correctas según sistema
      if (unidadSistema == 'metrico') {
        _ok(!body.contains(' gal'), es ? 'Sin "gal" en métrico' : 'No "gal" in metric',
            es ? 'Encontré "gal" en métrico' : 'Found "gal" in metric');
        _ok(!body.contains(' lb'), es ? 'Sin "lb" en métrico' : 'No "lb" in metric',
            es ? 'Encontré "lb" en métrico' : 'Found "lb" in metric');

        if (hasDose) {
          if (body.contains(' L')) _p('✅ Usa L en $title');
          if (body.contains(' kg')) _p('✅ Usa kg en $title');
        }
      } else {
        _ok(!body.contains(' L'), es ? 'Sin "L" en imperial' : 'No "L" in imperial',
            es ? 'Encontré "L" en imperial' : 'Found "L" in imperial');
        _ok(!body.contains(' kg'), es ? 'Sin "kg" en imperial' : 'No "kg" in imperial',
            es ? 'Encontré "kg" en imperial' : 'Found "kg" in imperial');

        if (hasDose) {
          if (body.contains(' gal')) _p('✅ Usa gal en $title');
          if (body.contains(' lb')) _p('✅ Usa lb en $title');
        }
      }

      // 6) Shock: si la tarjeta dice “🧪”, debe aparecer “🎯” (objetivo)
      if (body.contains('🧪')) {
        _ok(body.contains('🎯'), 'Shock muestra objetivo (🎯) en $title',
            'Falta objetivo (🎯) en shock de $title');
      }
    }
  }

  Future<void> _seedPrefs({
    required bool salada,
    required double volumenGal,
    double fuerzaCloroPct = 12.5,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('tipo_pileta_salada', salada);
    await p.setDouble('volumen_piscina', volumenGal);
    await p.setDouble('porcentaje_cloro_liquido', fuerzaCloroPct);
  }

  Future<void> _runAll() async {
    if (_running) return;
    setState(() => _running = true);
    _log.clear();

    for (final locale in const [Locale('es'), Locale('en')]) {
      for (final unidadSistema in ['metrico', 'imperial']) {
        for (final esSalada in [true, false]) {
          await _seedPrefs(salada: esSalada, volumenGal: 13000, fuerzaCloroPct: 12.5);

          _p('\n================= 🌐 ${locale.languageCode.toUpperCase()} · ${unidadSistema == 'metrico' ? 'L/kg' : 'gal/lb'} · ${esSalada ? "SALADA" : "DULCE"} =================');

          // Helper con callback para validaciones extra por caso (NUEVO)
          Future<void> runCase({
            required String titulo,
            required Map<String, dynamic> parametros,
            void Function(BuildContext ctx, Map<String, String> recs)? extraChecks,
          }) async {
            _p('\n--- $titulo ---');
            await _withLocale(locale, (ctx) async {
              final recs = await calcularAjustes(
                parametros,
                ctx,
                unidadSistema,
                overrideSalada: esSalada,
              );

              if (recs.isEmpty) {
                _p('❌ SIN RECOMENDACIONES (recs.isEmpty)');
                return null;
              }

              // Log de cada tarjeta
              for (final e in recs.entries) {
                _p('• [${e.key}]');
                _p(e.value);
              }

              // Validaciones genéricas
              _validateRecs(
                recs: recs,
                ctxConLocale: ctx,
                esSalada: esSalada,
                unidadSistema: unidadSistema,
              );

              // Validaciones específicas del caso (NUEVO)
              if (extraChecks != null) {
                extraChecks(ctx, recs);
              }
              return null;
            });
          }

          // ======== SUITE DE PRUEBAS ========

          // FC (FAS-DPD) – 25 mL => 0.2 ppm/gota
          await runCase(
            titulo: 'FC BAJO (espera dosis de cloro)',
            parametros: {'volumen_muestra': '25', 'Cloro libre gotas': 5}, // 1.0 ppm
          );
          await runCase(
            titulo: 'FC NORMAL (no dosis)',
            parametros: {'volumen_muestra': '25', 'Cloro libre gotas': 20}, // 4.0 ppm
          );
          await runCase(
            titulo: 'FC ALTO (alerta sin shock)',
            parametros: {'volumen_muestra': '25', 'Cloro libre gotas': 40, 'Cloro combinado': 0.0}, // 8.0 ppm
          );

          // SHOCK por CC
          await runCase(
            titulo: 'CC=0.4 ppm con CYA=60 (requiere SHOCK)',
            parametros: {'Cloro combinado': 0.4, 'Cloro libre': 2.0, 'CYA': 60.0},
            extraChecks: (ctx, recs) {
              // Debe existir una tarjeta de FC o CC con “🧪” y “🎯”
              final hayShock = recs.values.any((s) => s.contains('🧪') && s.contains('🎯'));
              _ok(hayShock, 'Shock activado con objetivo visible', 'Shock no activado/visible');
            },
          );

          // NUEVO: Caso “shock completado” (CC<=0.2 y FC>=target)
          await runCase(
            titulo: 'Shock completado (CC=0.2, FC≥target, CYA=60)',
            parametros: {'Cloro combinado': 0.2, 'Cloro libre': 25.0, 'CYA': 60.0},
            extraChecks: (ctx, recs) {
              final ok = recs.values.any((s) => s.contains('✅') && s.contains('shock'));
              _ok(ok, 'Mensaje de shock completado / volver a operación normal',
                  'Falta mensaje de shock completado');
            },
          );

          await runCase(titulo: 'CC=0.0 (normal)', parametros: {'Cloro combinado': 0.0});
          await runCase(titulo: 'CC=0.1 (advertencia leve)', parametros: {'Cloro combinado': 0.1});

          // ALCALINIDAD – 25 mL => 10 ppm/gota
          await runCase(
            titulo: 'TA BAJA (80 objetivo) -> dosis bicarbonato',
            parametros: {'volumen_muestra': '25', 'Alcalinidad gotas': 5}, // 50 ppm
          );
          await runCase(
            titulo: 'TA NORMAL',
            parametros: {'volumen_muestra': '25', 'Alcalinidad gotas': 10}, // 100 ppm
          );
          await runCase(
            titulo: 'TA ALTA -> ácido (bajar)',
            parametros: {'volumen_muestra': '25', 'Alcalinidad gotas': 15}, // 150 ppm
          );

          // DUREZA – 25 mL => 10 ppm/gota
          await runCase(
            titulo: 'CH BAJA -> aumentar',
            parametros: {'volumen_muestra': '25', 'Dureza gotas': 10}, // 100 ppm
          );
          await runCase(
            titulo: 'CH NORMAL',
            parametros: {'volumen_muestra': '25', 'Dureza gotas': 30}, // 300 ppm
          );
          await runCase(
            titulo: 'CH ALTA -> advertencia',
            parametros: {'volumen_muestra': '25', 'Dureza gotas': 45}, // 450 ppm
          );

          // pH (manual + demanda)
          await runCase(titulo: 'pH MANUAL BAJO (sin dosis)', parametros: {'pH': 7.0});
          await runCase(titulo: 'pH MANUAL NORMAL', parametros: {'pH': 7.5});
          await runCase(titulo: 'pH MANUAL ALTO', parametros: {'pH': 8.0});
          await runCase(
            titulo: 'pH DEMANDA ÁCIDO (R-005)',
            parametros: {'pH gotas': '2', 'pH titulante': 'R-005'},
          );
          await runCase(
            titulo: 'pH DEMANDA BASE (R-006)',
            parametros: {'pH gotas': '2', 'pH titulante': 'R-006'},
          );

          // CYA
          await runCase(titulo: 'CYA BAJO -> agregar estabilizador', parametros: {'CYA': 20.0});
          await runCase(
            titulo: 'CYA NORMAL',
            parametros: {'CYA': esSalada ? 70.0 : 40.0},
          );
          await runCase(
            titulo: 'CYA ALTO -> advertencia/descarga',
            parametros: {'CYA': esSalada ? 90.0 : 60.0},
          );

          // SALINIDAD
          if (esSalada) {
            await runCase(titulo: 'Salinidad BAJA -> agregar sal', parametros: {'Salinidad': 2800.0});
            await runCase(titulo: 'Salinidad NORMAL', parametros: {'Salinidad': 3200.0});
            await runCase(titulo: 'Salinidad ALTA -> advertencia', parametros: {'Salinidad': 3800.0});
          } else {
            // NUEVO: asegurar que en DULCE ignoramos salinidad aunque venga en el input
            await runCase(
              titulo: 'DULCE: ignora salinidad',
              parametros: {'Salinidad': 2800.0},
              extraChecks: (ctx, recs) {
                final l10n = AppLocalizations.of(ctx)!;
                final haySal = recs.keys.any((k) => k == l10n.salinidadLabel || k == 'Salinity');
                _ok(!haySal, 'No hay tarjeta de Salinidad en dulce', 'Apareció Salinidad en dulce');
              },
            );
          }
        }
      }
    }

    _p('\n✅ FIN DE PRUEBAS');
    setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dev: Pool Calculator Smoke Test')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _running ? null : _runAll,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Ejecutar todas'),
                ),
                const SizedBox(width: 12),
                Text(_running ? 'Corriendo… mira la consola' : 'Listo'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _log.length,
              itemBuilder: (_, i) => Text(_log[i]),
            ),
          ),
        ],
      ),
    );
  }
}
