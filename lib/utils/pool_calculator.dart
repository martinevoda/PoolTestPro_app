import 'package:flutter/material.dart';
import 'package:piscina_app/utils/stock_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';


// --- Conversión y formateo de unidades (evita "L" en imperial y "gal" en métrico) ---
const double _L_PER_GAL = 3.785411784;
const double _LB_PER_KG  = 2.2046226218;

String _fmtVol(double raw, {required bool metric}) {
  // `raw` viene en L si metric=true, en gal si metric=false (como ya haces hoy)
  return metric
      ? '${raw.toStringAsFixed(1)} L'
      : '${raw.toStringAsFixed(2)} gal';
}

String _fmtMass(double raw, {required bool metric}) {
  // `raw` viene en kg si metric=true, en lb si metric=false (como ya haces hoy)
  return metric
      ? '${raw.toStringAsFixed(1)} kg'
      : '${raw.toStringAsFixed(1)} lb';
}

Future<Map<String, String>> calcularAjustes(
    Map<String, dynamic> parametros,
    BuildContext context,
    String unidadSistema, {
      bool? overrideSalada, // << NUEVO
    }) async {

  final recomendaciones = <String, String>{};
  final localizations = AppLocalizations.of(context)!;
  final bool esMetrico = unidadSistema == 'metrico';
  final double factorPeso = 0.4536;  // lb -> kg

  await StockService.getAllStock();

  double? toDouble(dynamic valor) {
    if (valor is double) return valor;
    if (valor is int) return valor.toDouble();
    if (valor is String) return double.tryParse(valor);
    return null;
  }

  final prefs = await SharedPreferences.getInstance();

// ✅ usa el modo actual desde SettingsController (no desde prefs)
  final settings = Provider.of<SettingsController>(context, listen: false);
  final bool esAguaSalada = overrideSalada ?? settings.esAguaSalada;

// ✅ rangos oficiales (K-2006C – operación típica)
  final int cyaMin = esAguaSalada ? 60 : 30;
  final int cyaMax = esAguaSalada ? 80 : 50;

  final double limiteCloroBajo = esAguaSalada ? 3.0 : 1.0;
  final double limiteCloroAlto = esAguaSalada ? 6.0 : 3.0;

  final String rangoCloroTexto = esAguaSalada ? '3–6 ppm' : '1–3 ppm';
  final String rangoCyaTexto   = '$cyaMin–$cyaMax ppm';

  final double fuerzaCloro = prefs.getDouble('porcentaje_cloro_liquido') ?? 12.5;


  double volumenGalones = prefs.getDouble('volumen_piscina') ?? 13000;
  //double volumenLitros = volumenGalones * 3.785;
  double factorVolumenEscala = volumenGalones / 10000.0;

  //final double factorVolumen = 3.785; // gal -> L

  final unidadPeso = esMetrico ? localizations.unidadKg : localizations.unidadLb;
  final unidadVol = esMetrico ? localizations.unidadLitro : localizations.unidadGalon;

  final volumenMuestra = parametros['volumen_muestra'] ?? '25';
  final double factorCloro = volumenMuestra == '10' ? 0.5 : 0.2;
  final double factorAlcalinidad = volumenMuestra == '10' ? 25 : 10;
  final double factorDureza = 10;

  // -------- Lectura de parámetros de la entrada --------
  double? cloroLibre = parametros.containsKey('Cloro libre gotas')
      ? (toDouble(parametros['Cloro libre gotas']) != null
      ? toDouble(parametros['Cloro libre gotas'])! * factorCloro
      : null)
      : toDouble(parametros['Cloro libre']);

  final cloroCombinado = parametros.containsKey('Cloro combinado gotas')
      ? (toDouble(parametros['Cloro combinado gotas']) != null
      ? toDouble(parametros['Cloro combinado gotas'])! * factorCloro
      : null)
      : toDouble(parametros['Cloro combinado']);

  final alcalinidad = parametros.containsKey('Alcalinidad gotas')
      ? (toDouble(parametros['Alcalinidad gotas']) != null
      ? toDouble(parametros['Alcalinidad gotas'])! * factorAlcalinidad
      : null)
      : toDouble(parametros['Alcalinidad']);

  final dureza = parametros.containsKey('Dureza gotas')
      ? (toDouble(parametros['Dureza gotas']) != null
      ? toDouble(parametros['Dureza gotas'])! * factorDureza
      : null)
      : toDouble(parametros['Dureza']);

  double? ph = toDouble(parametros['pH']);
  double? cya = toDouble(parametros['CYA']);
  double? salinidad = toDouble(parametros['Salinidad']);



  // -------- Helpers SHOCK --------------------------------------------------
  double _shockTargetFromCYA(double cya) => (cya * 0.40).roundToDouble();
  bool _isShockNeeded(double? cc) => cc != null && cc >= 0.3;

  bool _isShockCleared({
    required double? cc,
    required double? fcActual,
    required double shockTarget,
    double? fcNoche,
    double? fcManana,
  }) {
    final ccOk = (cc != null) && (cc <= 0.2);
    final fcOk = (fcActual != null) && (fcActual >= shockTarget);
    final ocltOk = (fcNoche != null && fcManana != null)
        ? ((fcNoche - fcManana) < 1.0)
        : true;
    return ccOk && fcOk && ocltOk;
  }

  // -------- Helpers de histórico / normalización --------------------------
  double? _leerUltimoDesdeRegistros(SharedPreferences prefs, List<String> nombresParametros) {
    // 1) test_registros
    try {
      final raw = prefs.getString('test_registros');
      if (raw != null && raw.isNotEmpty) {
        final List lista = json.decode(raw);
        for (int i = lista.length - 1; i >= 0; i--) {
          final item = lista[i] as Map<String, dynamic>;
          final p = item['parametro']?.toString();
          if (p != null && nombresParametros.contains(p)) {
            final v = item['valor'];
            if (v is num) return v.toDouble();
            if (v is String) return double.tryParse(v);
          }
        }
      }
    } catch (_) {}

    // 2) test_individual
    try {
      final raw2 = prefs.getString('test_individual');
      if (raw2 != null && raw2.isNotEmpty) {
        final List lista2 = json.decode(raw2);
        for (int i = lista2.length - 1; i >= 0; i--) {
          final item = lista2[i] as Map<String, dynamic>;
          final p = item['parametro']?.toString();
          if (p != null && nombresParametros.contains(p)) {
            final v = item['valor_ppm'] ?? item['valor'];
            if (v is num) return v.toDouble();
            if (v is String) return double.tryParse(v);
          }
        }
      }
    } catch (_) {}

    return null;
  }

  double _normalizaFC(double valor) {
    if (valor > 20 && valor <= 200) return valor * 0.2; // 25 mL: 0.2 ppm/drop
    return valor;
  }

  // Completar FC/CYA desde histórico si falta
  if (cloroLibre == null) {
    final desdeHist = _leerUltimoDesdeRegistros(prefs, ['Cloro libre', 'Free chlorine']);
    if (desdeHist != null) cloroLibre = _normalizaFC(desdeHist);
  }
  cya ??= _leerUltimoDesdeRegistros(
    prefs,
    ['CYA', 'Stabilizer (CYA)', 'Stabilizer', 'Cyanuric acid'],
  );

  // -------- Helpers de presentación / stock -------------------------------
  double _roundToStep(double v, double step) => (v / step).round() * step;

  Map<String, String> _formatCantidad(double cantidad, String unidadVol) {
    final bool enGal = (unidadVol.toLowerCase().contains('gal'));
    if (enGal) {
      final double amigable = _roundToStep(cantidad, 0.05);
      return {'amigable': amigable.toStringAsFixed(2), 'exacta': cantidad.toStringAsFixed(2)};
    } else {
      return {'amigable': cantidad.toStringAsFixed(1), 'exacta': cantidad.toStringAsFixed(1)};
    }
  }

  Future<void> procesarUso({
    required String key,
    required double cantidad,
    required String nombreProducto,
    required String nombreComercial,
    required String mensajeBase,
    required String valorNormal,
    required String valorActualFormateado,
    String? tituloForzado,
  }) async {
    String tituloTraducido = '';
    if (tituloForzado != null && tituloForzado.isNotEmpty) {
      tituloTraducido = tituloForzado;
    } else {
      switch (key) {
        case 'cloro_liquido':
          tituloTraducido = localizations.cloroLibreLabel;
          break;
        case 'ph_increaser':
          tituloTraducido = localizations.ph;
          break;
        case 'acido_muriatico':
          if (mensajeBase.contains(localizations.alcalinidadAltaTexto)) {
            tituloTraducido = localizations.alcalinidadLabel;
          } else {
            tituloTraducido = localizations.ph;
          }
          break;
        case 'alcalinidad':
          tituloTraducido = localizations.alcalinidadLabel;
          break;
        case 'estabilizador':
          tituloTraducido = localizations.cyaLabel;
          break;
        case 'dureza':
          tituloTraducido = localizations.durezaLabel;
          break;
        case 'sal':
          tituloTraducido = localizations.salinidadLabel;
          break;
        default:
          tituloTraducido = key;
      }
    }

    final esLiquido = (key == 'cloro_liquido' || key == 'acido_muriatico');
    //final unidadVisual = esLiquido ? unidadVol : unidadPeso;

    final stockActual = StockService.obtenerStockSeguro(key);
    final necesitaReabastecer = await StockService.necesitaReabastecer(key, cantidad);

    String texto = '$tituloTraducido\n'
        '📏 $valorNormal\n'
        '$valorActualFormateado\n'
        '$mensajeBase';

// --- Formato de cantidades para evitar "L" en imperial y "gal" en métrico ---
    String _fmtRequerido() {
      if (esLiquido) {
        // líquidos: L con 1 decimal (métrico) / gal con 2 decimales (imperial)
        return esMetrico
            ? '${cantidad.toStringAsFixed(1)} ${localizations.unidadLitro}'
            : '${cantidad.toStringAsFixed(2)} ${localizations.unidadGalon}';
      } else {
        // sólidos: kg/lb con 1 decimal
        return esMetrico
            ? '${cantidad.toStringAsFixed(1)} ${localizations.unidadKg}'
            : '${cantidad.toStringAsFixed(1)} ${localizations.unidadLb}';
      }
    }

    String _fmtStock() {
      if (esLiquido) {
        return esMetrico
            ? '${stockActual.toStringAsFixed(1)} ${localizations.unidadLitro}'
            : '${stockActual.toStringAsFixed(2)} ${localizations.unidadGalon}';
      } else {
        return esMetrico
            ? '${stockActual.toStringAsFixed(1)} ${localizations.unidadKg}'
            : '${stockActual.toStringAsFixed(1)} ${localizations.unidadLb}';
      }
    }

    if (necesitaReabastecer) {
      texto += '\n❌ ${localizations.stockInsuficiente(
        nombreProducto,
        nombreComercial,
      )}\n'
          '${localizations.seNecesita}: ${_fmtRequerido()}\n'
          '${localizations.stockActual}: ${_fmtStock()}';
    } else {
      // Conserva tu string de “suficiente”, pero pasando número y unidad correctos
      final numStr = esLiquido
          ? (esMetrico ? stockActual.toStringAsFixed(1) : stockActual.toStringAsFixed(2))
          : stockActual.toStringAsFixed(1);
      final unidadStr = esLiquido
          ? (esMetrico ? localizations.unidadLitro : localizations.unidadGalon)
          : (esMetrico ? localizations.unidadKg : localizations.unidadLb);

      texto += '\n✅ ${localizations.stockDisponibleSuficiente(
        numStr,
        unidadStr,
      )}';
    }

    await StockService.registrarUso(key, cantidad);
    recomendaciones[key] = texto;
    }


    // ================== CLORO LIBRE =========================================
  if (cloroLibre != null) {
    final valor = '${localizations.cloroLibreLabel}: ${cloroLibre.toStringAsFixed(1)}';

    if (cloroLibre < limiteCloroBajo) {
      final incremento = (esAguaSalada ? 3.0 : 2.0) - cloroLibre;
      final galones = incremento * (volumenGalones / 10000.0) / fuerzaCloro;
      final cantidad = esMetrico ? galones * 3.785 : galones;
      final _fmt = _formatCantidad(cantidad, unidadVol);

      String mensaje =
          '⚠️ ${localizations.cloroLibreBajo}\n'
          '➕ ${localizations.recomendacionGenerica(
        _fmt['amigable']!,
        unidadVol,
        localizations.nombreProductoCloro,
        localizations.nombreComercialCloro,
      )} (${_fmt['exacta']} $unidadVol ${localizations.exactSuffix})';

      if (galones > 5.0) {
        mensaje += '\n⚠️ ${localizations.choqueAlto}';
      }
      if (esAguaSalada) {
        mensaje += '\n💡 ${localizations.subirGeneradorSugerencia}';
      }

      await procesarUso(
        key: 'cloro_liquido',
        cantidad: cantidad,
        nombreProducto: localizations.nombreProductoCloro,
        nombreComercial: localizations.nombreComercialCloro,
        mensajeBase: mensaje,
        valorNormal: '${localizations.normalRangePrefix} $rangoCloroTexto',
        valorActualFormateado: valor,
      );

      // ⇨ Mapear a clave pública para la UI
      if (recomendaciones.containsKey('cloro_liquido')) {
        recomendaciones[localizations.cloroLibreLabel] = recomendaciones['cloro_liquido']!;
        recomendaciones.remove('cloro_liquido');
      }


    } else if (cloroLibre > limiteCloroAlto && !_isShockNeeded(cloroCombinado)) {
      recomendaciones[localizations.cloroLibreLabel] =
      '**${localizations.cloroLibreLabel}**\n'
          '📏 ${localizations.normalRangePrefix} $rangoCloroTexto\n'
          '$valor\n'
          '⚠️ ${localizations.cloroLibreAltoSugerencia}';
    } else {
      recomendaciones[localizations.cloroLibreLabel] =
      '**${localizations.cloroLibreLabel}**\n'
          '📏 ${localizations.normalRangePrefix} $rangoCloroTexto\n'
          '$valor\n'
          '✅ ${localizations.valorNormal}';
    }

    if (_isShockNeeded(cloroCombinado)) {
      final lineaTarget = (cya != null)
          ? '\n🎯 ${localizations.shockTargetLabel}: ${_shockTargetFromCYA(cya!).toStringAsFixed(0)} ppm'
          : '';
      final notaAlto = (cloroLibre != null && cloroLibre > limiteCloroAlto)
          ? '\n${localizations.cloroLibreAltoSugerencia}'
          : '';
      recomendaciones[localizations.cloroLibreLabel] =
      '**${localizations.cloroLibreLabel}**\n'
          '📏 ${localizations.normalRangePrefix} $rangoCloroTexto\n'
          '$valor\n'
          '🧪 ${localizations.shockModeTitle}$lineaTarget'
          '$notaAlto';
    }
  }

  // ================== CLORO COMBINADO (modo SHOCK) ========================
  if (cloroCombinado != null) {
    final double shockTargetForCheck = (cya != null) ? _shockTargetFromCYA(cya!) : 0.0;
    final valor = '${localizations.cloroCombinadoLabel}: ${cloroCombinado.toStringAsFixed(1)}';

    if (_isShockNeeded(cloroCombinado)) {
      final double? fc = cloroLibre;
      final double? cyaVal = cya;

      if (cyaVal != null && fc != null) {
        final double shockTarget = _shockTargetFromCYA(cyaVal);
        final condicionesShock =
            '\n⏱️ ${localizations.maintainShockUntil}\n'
            '• ${localizations.shockCondCCUnder02}\n'
            '• ${localizations.shockCondFCHold24h(shockTarget.toStringAsFixed(0))}\n'
            '• ${localizations.shockCondOCLT}';
        final double incrementoFC = shockTarget - fc;

        if (incrementoFC > 0) {
          final double galones = incrementoFC * (volumenGalones / 10000.0) / fuerzaCloro;
          final double cantidad = esMetrico ? galones * 3.785 : galones;
          final _fmt = _formatCantidad(cantidad, unidadVol);

          final mensaje =
              '🧪 ${localizations.shockModeTitle}\n'
              '🎯 ${localizations.shockTargetLabel}: ${shockTarget.toStringAsFixed(0)} ppm\n'
              '${localizations.requiereTratamientoChoque}\n'
              '➕ ${localizations.recomendacionGenerica(
            _fmt['amigable']!,
            unidadVol,
            localizations.nombreProductoCloro,
            localizations.nombreComercialCloro,
          )} (${_fmt['exacta']} $unidadVol ${localizations.exactSuffix})\n'
              '${localizations.cloroLibreAltoSugerencia}'
              '$condicionesShock';

          await procesarUso(
            key: 'cloro_liquido',
            cantidad: cantidad,
            nombreProducto: localizations.nombreProductoCloro,
            nombreComercial: localizations.nombreComercialCloro,
            mensajeBase: mensaje,
            valorNormal: localizations.normalRangeCloroCombinado,
            valorActualFormateado: valor,
            tituloForzado: localizations.cloroCombinadoLabel,
          );

          // Ya tenías este mapeo:
          if (recomendaciones.containsKey('cloro_liquido')) {
            recomendaciones[localizations.cloroCombinadoLabel] = recomendaciones['cloro_liquido']!;
            recomendaciones.remove('cloro_liquido');
          }


        } else {
          recomendaciones[localizations.cloroCombinadoLabel] =
          '🧪 ${localizations.shockModeTitle}\n'
              '🎯 ${localizations.shockTargetLabel}: ${shockTarget.toStringAsFixed(0)} ppm\n'
              '${localizations.requiereTratamientoChoque}\n'
              '✅ ${localizations.fcAlreadyAtShock}\n'
              '$condicionesShock\n'
              '${localizations.cloroLibreAltoSugerencia}';
        }

      } else {
        recomendaciones[localizations.cloroCombinadoLabel] =
        '🧪 ${localizations.shockModeTitle}\n'
            '${localizations.requiereTratamientoChoque}\n'
            '💡 ${localizations.shockMeasureCyaFc}';
      }
    } else if (cya != null && shockTargetForCheck > 0 &&
        _isShockCleared(
          cc: cloroCombinado,
          fcActual: cloroLibre,
          shockTarget: shockTargetForCheck,
        )) {
      recomendaciones[localizations.cloroCombinadoLabel] =
      '🧪 ${localizations.shockModeTitle}\n'
          '✅ ${localizations.shockCompleted}\n'
          '${localizations.resumeNormalOperation}';
    } else if (cloroCombinado == 0.0) {
      recomendaciones[localizations.cloroCombinadoLabel] =
      '**${localizations.cloroCombinadoLabel}**\n'
          '📏 ${localizations.normalRangeCloroCombinado}\n'
          '$valor\n'
          '✅ ${localizations.cloroCombinadoCero}';
    } else if (cloroCombinado >= 0.1 && cloroCombinado <= 0.2) {
      recomendaciones[localizations.cloroCombinadoLabel] =
      '**${localizations.cloroCombinadoLabel}**\n'
          '📏 ${localizations.normalRangeCloroCombinado}\n'
          '$valor\n'
          '⚠️ ${localizations.cloroCombinadoAdvertenciaLeve}';
    } else {
      recomendaciones[localizations.cloroCombinadoLabel] =
      '**${localizations.cloroCombinadoLabel}**\n'
          '📏 ${localizations.normalRangeCloroCombinado}\n'
          '$valor\n'
          '✅ ${localizations.valorNormal}';
    }
  }

  // ==================PH ========================
  final String? titulante = parametros['pH titulante']; // 'R-005' o 'R-006'
  final double? gotas = toDouble(parametros['pH gotas']);
  final bool esMedicionManual =
  (gotas == null || gotas == 0 || titulante == null || titulante.isEmpty);

  if (esMedicionManual && ph != null) {
    String valor = '${localizations.ph}: ${ph.toStringAsFixed(2)}';
    final String ayudaDemanda = '\n💡 ${localizations.phUsaDemandaParaDosis}';

    if (ph < 7.2) {
      recomendaciones[localizations.ph] =
      '**${localizations.ph}**\n📏 ${localizations.normalRangePh}\n$valor\n⚠️ ${localizations.valorBajo}$ayudaDemanda';
    } else if (ph > 7.8) {
      recomendaciones[localizations.ph] =
      '**${localizations.ph}**\n📏 ${localizations.normalRangePh}\n$valor\n⚠️ ${localizations.valorAlto}$ayudaDemanda';
    } else {
      recomendaciones[localizations.ph] =
      '**${localizations.ph}**\n📏 ${localizations.normalRangePh}\n$valor\n✅ ${localizations.valorNormal}';
    }
  } else if (!esMedicionManual) {
    double cantidad;
    String mensaje;
    String producto;
    String nombreComercial;
    String valorVisual = localizations.phVisualPlaceholder;

    if (titulante == 'R-006') {
      final lb = calcularPhBajoLb(gotas!.toInt(), volumenGalones);
      cantidad = esMetrico ? lb * factorPeso : lb; // kg o lb
      producto = localizations.nombreProductoPhSubir;
      nombreComercial = localizations.nombreComercialPhSubir;

      mensaje = '⚠️ ${localizations.phBajo}\n➕ ${localizations.recomendacionGenerica(
        cantidad.toStringAsFixed(2),
        unidadPeso,
        producto,
        nombreComercial,
      )}';
    } else if (titulante == 'R-005') {
      final quarts = calcularPhAltoQt(gotas!.toInt(), volumenGalones);
      cantidad = esMetrico ? quarts * 0.946 : quarts / 4.0; // L o gal
      producto = localizations.nombreProductoPhBajar;
      nombreComercial = localizations.nombreComercialPhBajar;

      mensaje = '⚠️ ${localizations.phAlto}\n➖ ${localizations.recomendacionGenerica(
        cantidad.toStringAsFixed(2),
        unidadVol,
        producto,
        nombreComercial,
      )}';
    } else {
      recomendaciones[localizations.ph] =
      '**${localizations.ph}**\n📏 ${localizations.normalRangePh}\n⚠️ ${localizations.phTitulanteInvalido}';
      return recomendaciones;
    }

    await procesarUso(
      key: (titulante == 'R-006') ? 'ph_increaser' : 'acido_muriatico',
      cantidad: cantidad,
      nombreProducto: producto,
      nombreComercial: nombreComercial,
      mensajeBase: mensaje,
      valorNormal: localizations.normalRangePh,
      valorActualFormateado: valorVisual,
    );

    // ⇨ Mapear a clave pública
    final kPh = (titulante == 'R-006') ? 'ph_increaser' : 'acido_muriatico';
    if (recomendaciones.containsKey(kPh)) {
      recomendaciones[localizations.ph] = recomendaciones[kPh]!;
      recomendaciones.remove(kPh);
    }
  }

  // ================== ALCALINIDAD ========================
  if (alcalinidad != null) {
    String valor = '${localizations.alcalinidadLabel}: ${alcalinidad.toStringAsFixed(0)}';

    if (alcalinidad < 80) {
      double incremento = 80 - alcalinidad;
      double libras = incremento / 10 * 1.4 * (volumenGalones / 10000); // 1.4 lb / 10 ppm / 10k gal
      double cantidad = esMetrico ? libras * factorPeso : libras;

      await procesarUso(
        key: 'alcalinidad',
        cantidad: cantidad,
        nombreProducto: localizations.productoAlcalinidad,
        nombreComercial: localizations.nombreComercialAlcalinidad,
        mensajeBase: '⚠️ ${localizations.alcalinidadBajaTexto}\n➕ ${localizations.recomendacionGenerica(
          cantidad.toStringAsFixed(1),
          unidadPeso,
          localizations.productoAlcalinidad,
          localizations.nombreComercialAlcalinidad,
        )}',
        valorNormal: localizations.normalRangeAlcalinidad,
        valorActualFormateado: valor,
      );

      // ⇨ Mapear a clave pública
      if (recomendaciones.containsKey('alcalinidad')) {
        recomendaciones[localizations.alcalinidadLabel] = recomendaciones['alcalinidad']!;
        recomendaciones.remove('alcalinidad');
      }


    } else if (alcalinidad > 120) {
      final exceso = alcalinidad - 120;
      final litros = (exceso / 10) * 0.50 * (volumenGalones / 10000.0);
      final cantidad = esMetrico ? litros : (litros / 3.785); // L o gal


      await procesarUso(
        key: 'acido_muriatico',
        cantidad: cantidad,
        nombreProducto: localizations.nombreProductoPHAlto,
        nombreComercial: localizations.nombreComercialPHAlto,
        mensajeBase: '⚠️ ${localizations.alcalinidadAltaTexto}\n'
            '➖ ${localizations.recomendacionGenerica(
          cantidad.toStringAsFixed(2), // número sin unidad
          unidadVol,                   // unidad aquí (L o gal)
          localizations.nombreProductoPHAlto,
          localizations.nombreComercialPHAlto,
        )}\n'
            '${localizations.alcalinidadAltaConsejo1}\n'
            '${localizations.alcalinidadAltaAdvertenciaPh}',
        valorNormal: localizations.normalRangeAlcalinidad,
        valorActualFormateado: valor,
      );

      // ⇨ Mapear a clave pública (si subiste/ajustaste con ácido quieres que salga como Alcalinidad)
      if (recomendaciones.containsKey('acido_muriatico')) {
        recomendaciones[localizations.alcalinidadLabel] = recomendaciones['acido_muriatico']!;
        recomendaciones.remove('acido_muriatico');
      }


    } else {
      recomendaciones[localizations.alcalinidadLabel] =
      '**${localizations.alcalinidadLabel}**\n📏 ${localizations.normalRangeAlcalinidad}\n$valor\n✅ ${localizations.valorNormal} (80–120 ppm)';
    }
  }

  // ================== CYA ========================
  if (cya != null) {
    String valor = '${localizations.cyaLabel}: ${cya.toStringAsFixed(0)}';

    if (cya < cyaMin) {
      final double incremento = cyaMin -
          cya; // ← subir hasta el mínimo del rango del modo
      final double libras = incremento / 10 * 0.80 *
          factorVolumenEscala; // 0.8 lb / 10 ppm / 10k gal
      final double cantidad = esMetrico ? libras * factorPeso : libras;

      await procesarUso(
        key: 'estabilizador',
        cantidad: cantidad,
        nombreProducto: localizations.productoCya,
        nombreComercial: localizations.nombreComercialCYA,
        mensajeBase: '⚠️ ${localizations.cyaBajo}\n➕ ${localizations
            .recomendacionGenerica(
          cantidad.toStringAsFixed(1),
          unidadPeso,
          localizations.productoCya,
          localizations.nombreComercialCYA,
        )}',
        valorNormal: localizations.cyaValorNormal(rangoCyaTexto),
        valorActualFormateado: valor,
      );

      if (recomendaciones.containsKey('estabilizador')) {
        recomendaciones[localizations.cyaLabel] = recomendaciones['estabilizador']!;
        recomendaciones.remove('estabilizador');
      }

    } else if (cya > cyaMax) {
      recomendaciones[localizations.cyaLabel] =
      '**${localizations.cyaLabel}**\n'
          '📏 ${localizations.cyaValorNormal(rangoCyaTexto)}\n'
          '$valor\n'
          '⚠️ ${localizations.cyaAlto}\n'
          '💡 ${localizations.cyaAltoConsejo}';
    } else {
      recomendaciones[localizations.cyaLabel] =
      '**${localizations.cyaLabel}**\n'
          '📏 ${localizations.cyaValorNormal(rangoCyaTexto)}\n'
          '$valor\n'
          '✅ ${localizations.valorNormal}';
    }
  }


    // ================== DUREZA CALCICA ========================
  if (dureza != null) {
    String valor = '${localizations.durezaLabel}: ${dureza.toStringAsFixed(0)}';

    if (dureza < 200) {
      double incremento = 200 - dureza;
      double libras = incremento / 10 * 1.33 * factorVolumenEscala; // 94% CaCl2
      double cantidad = esMetrico ? libras * factorPeso : libras;

      await procesarUso(
        key: 'dureza',
        cantidad: cantidad,
        nombreProducto: localizations.productoDureza,
        nombreComercial: localizations.nombreComercialDureza,
        mensajeBase: '⚠️ ${localizations.durezaBaja}\n➕ ${localizations.recomendacionGenerica(
          cantidad.toStringAsFixed(1),
          unidadPeso,
          localizations.productoDureza,
          localizations.nombreComercialDureza,
        )}',
        valorNormal: localizations.normalRangeDureza,
        valorActualFormateado: valor,
      );

      // ⇨ Mapear a clave pública
      if (recomendaciones.containsKey('dureza')) {
        recomendaciones[localizations.durezaLabel] = recomendaciones['dureza']!;
        recomendaciones.remove('dureza');
      }


    } else if (dureza > 400) {
      recomendaciones[localizations.durezaLabel] =
      '**${localizations.durezaLabel}**\n'
          '📏 ${localizations.normalRangeDureza}\n'
          '$valor\n'
          '⚠️ ${localizations.durezaAlta}\n'
          '💡 ${localizations.durezaAltaConsejo}';
    } else {
      recomendaciones[localizations.durezaLabel] =
      '**${localizations.durezaLabel}**\n'
          '📏 ${localizations.normalRangeDureza}\n'
          '$valor\n'
          '✅ ${localizations.valorNormal}';
    }
  }

  // ================== SALINIDAD ========================
  if (salinidad != null && esAguaSalada) {
    String valor = '${localizations.salinidadLabel}: ${salinidad.toStringAsFixed(0)}';

    if (salinidad < 3000) {
      double incremento = 3000 - salinidad;
      double libras = incremento * 0.083 * factorVolumenEscala; // 8.3 lb / 100 ppm / 10k gal
      double cantidad = esMetrico ? libras * factorPeso : libras;

      await procesarUso(
        key: 'sal',
        cantidad: cantidad,
        nombreProducto: localizations.productoSal,
        nombreComercial: localizations.nombreComercialSal,
        mensajeBase: '⚠️ ${localizations.salinidadBaja}\n➕ ${localizations.recomendacionGenerica(
          cantidad.toStringAsFixed(1),
          unidadPeso,
          localizations.productoSal,
          localizations.nombreComercialSal,
        )}',
        valorNormal: localizations.normalRangeSalinidad,
        valorActualFormateado: valor,
      );

      // ⇨ Mapear a clave pública
      if (recomendaciones.containsKey('sal')) {
        recomendaciones[localizations.salinidadLabel] = recomendaciones['sal']!;
        recomendaciones.remove('sal');
      }


    } else if (salinidad > 3500) {
      recomendaciones[localizations.salinidadLabel] =
      '**${localizations.salinidadLabel}**\n'
          '📏 ${localizations.normalRangeSalinidad}\n'
          '$valor\n'
          '⚠️ ${localizations.salinidadAlta}\n'
          '💡 ${localizations.salinidadAltaConsejo}';
    } else {
      recomendaciones[localizations.salinidadLabel] =
      '**${localizations.salinidadLabel}**\n'
          '📏 ${localizations.normalRangeSalinidad}\n'
          '$valor\n'
          '✅ ${localizations.valorNormal}';
    }
  }

  return recomendaciones;
}

double calcularPhBajoLb(int gotas, double volumenGalones) {
  final tabla = {
    10000: [0.51, 1.03, 1.54, 2.05, 2.56, 3.08, 3.59, 4.10, 4.61, 5.13],
    20000: [1.03, 2.05, 3.08, 4.10, 5.13, 6.15, 7.18, 8.20, 9.23, 10.26],
  };

  int gotasIndex = gotas.clamp(1, 10) - 1;
  double base = tabla[10000]![gotasIndex];
  double extra = tabla[20000]![gotasIndex] - base;

  return base + (extra * ((volumenGalones - 10000) / 10000));
}

double calcularPhAltoQt(int gotas, double volumenGalones) {
  final tabla = {
    10000: [1.15, 1.72, 2.29, 2.86, 3.44, 4.01, 4.58, 5.15, 5.73, 6.30],
    20000: [2.29, 3.44, 4.58, 5.73, 6.87, 8.02, 9.16, 10.31, 11.45, 12.60],
  };

  int gotasIndex = gotas.clamp(1, 10) - 1;
  double base = tabla[10000]![gotasIndex];
  double extra = tabla[20000]![gotasIndex] - base;

  return base + (extra * ((volumenGalones - 10000) / 10000));
}
