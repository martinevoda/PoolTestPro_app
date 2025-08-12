import 'package:flutter/material.dart';
import 'package:piscina_app/utils/stock_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';


Future<Map<String, String>> calcularAjustes(
    Map<String, dynamic> parametros,
    BuildContext context,
    String unidadSistema,
    ) async {
  final recomendaciones = <String, String>{};

  await StockService.getAllStock();

  double? toDouble(dynamic valor) {
    if (valor is double) return valor;
    if (valor is int) return valor.toDouble();
    if (valor is String) return double.tryParse(valor);
    return null;
  }

  final prefs = await SharedPreferences.getInstance();
  final bool esAguaSalada = prefs.getBool('tipo_pileta_salada') ?? true;
  final cyaMax = esAguaSalada ? 80 : 50;
  final limiteCloroAlto = esAguaSalada ? 6.0 : 4.0;
  final limiteCloroBajo = esAguaSalada ? 3.0 : 1.0;
  final rangoCloroTexto = esAguaSalada ? '3–6 ppm' : '1–3 ppm';
  final rangoCyaTexto = esAguaSalada ? '60–80 ppm' : '30–50 ppm';
  final double fuerzaCloro = prefs.getDouble('porcentaje_cloro_liquido') ?? 12.5;

  double volumenGalones = prefs.getDouble('volumen_piscina') ?? 13000;
  double volumenLitros = volumenGalones * 3.785;
  double factorVolumenEscala = volumenGalones / 10000.0;

  final localizations = AppLocalizations.of(context)!;
  final bool esMetrico = unidadSistema == 'metrico';
  final double factorPeso = 0.4536;  // lb -> kg
  final double factorVolumen = 3.785; // gal -> L

  final unidadPeso = esMetrico ? localizations.unidadKg : localizations.unidadLb;
  final unidadVol = esMetrico ? localizations.unidadLitro : localizations.unidadGalon;

  final volumenMuestra = parametros['volumen_muestra'] ?? '25';
  final double factorCloro = volumenMuestra == '10' ? 0.5 : 0.2;
  final double factorAlcalinidad = volumenMuestra == '10' ? 25 : 10;
  final double factorDureza = 10;

  // -------- Lectura de parámetros de la entrada --------
  double? cloroLibre = parametros.containsKey('Cloro libre gotas')
      ? toDouble(parametros['Cloro libre gotas'])! * factorCloro
      : toDouble(parametros['Cloro libre']);

  final cloroCombinado = parametros.containsKey('Cloro combinado gotas')
      ? toDouble(parametros['Cloro combinado gotas'])! * factorCloro
      : toDouble(parametros['Cloro combinado']);

  final alcalinidad = parametros.containsKey('Alcalinidad gotas')
      ? toDouble(parametros['Alcalinidad gotas'])! * factorAlcalinidad
      : toDouble(parametros['Alcalinidad']);

  final dureza = parametros.containsKey('Dureza gotas')
      ? toDouble(parametros['Dureza gotas'])! * factorDureza
      : toDouble(parametros['Dureza']);

  double? ph = toDouble(parametros['pH']);
  double? cya = toDouble(parametros['CYA']);
  final salinidad = toDouble(parametros['Salinidad']);

  // -------- Helpers SHOCK --------------------------------------------------

  double _shockTargetFromCYA(double cya) {
    // ~40% del CYA, redondeado a entero
    return (cya * 0.40).roundToDouble();
  }

  bool _isShockNeeded(double? cc) {
    // Umbral: CC >= 0.3 ppm → shock
    return cc != null && cc >= 0.3;
  }

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
        : true; // si no hay OCLT, no bloquea
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
    // Si parece número de gotas (25 mL): 20 < valor ≤ 200 → ppm = valor * 0.2
    if (valor > 20 && valor <= 200) {
      return valor * 0.2; // = valor / 5
    }
    return valor;
  }

  // Completar FC/CYA desde histórico si falta
  if (cloroLibre == null) {
    final desdeHist = _leerUltimoDesdeRegistros(
      prefs,
      ['Cloro libre', 'Free chlorine'],
    );
    if (desdeHist != null) {
      cloroLibre = _normalizaFC(desdeHist);
    }
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
      return {
        'amigable': amigable.toStringAsFixed(2),
        'exacta': cantidad.toStringAsFixed(2),
      };
    } else {
      return {
        'amigable': cantidad.toStringAsFixed(1),
        'exacta': cantidad.toStringAsFixed(1),
      };
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
    String? tituloForzado,          // ← NUEVO
  }) async {
    String tituloTraducido = '';
    if (tituloForzado != null && tituloForzado.isNotEmpty) {
      tituloTraducido = tituloForzado;          // ← usa el forzado
    } else {
      switch (key) {
        case 'cloro_liquido':
          tituloTraducido = localizations.cloroLibreLabel;
          break;
        case 'ph_increaser':
          tituloTraducido = 'pH';
          break;
        case 'acido_muriatico':
          if (mensajeBase.contains(localizations.alcalinidadAltaTexto)) {
            tituloTraducido = localizations.alcalinidadLabel;
          } else {
            tituloTraducido = 'pH';
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
    final unidadVisual = esLiquido ? unidadVol : unidadPeso;

    final stockActual = StockService.obtenerStockSeguro(key);
    final necesitaReabastecer = await StockService.necesitaReabastecer(key, cantidad);

    String texto = '$tituloTraducido\n'
        '📏 $valorNormal\n'
        '$valorActualFormateado\n'
        '$mensajeBase';

    if (necesitaReabastecer) {
      texto += '\n❌ ${localizations.stockInsuficiente(
        nombreProducto,
        nombreComercial,
      )}\n'
          '${localizations.seNecesita}: ${cantidad.toStringAsFixed(1)} $unidadVisual\n'
          '${localizations.stockActual}: ${stockActual.toStringAsFixed(1)} $unidadVisual';
    } else {
      texto += '\n✅ ${localizations.stockDisponibleSuficiente(
        stockActual.toStringAsFixed(1),
        unidadVisual,
      )}';
    }

    await StockService.registrarUso(key, cantidad);
    recomendaciones[key] = texto;
  }

  // ================== CLORO LIBRE =========================================
  if (cloroLibre != null) {
    final valor = '${localizations.cloroLibreLabel}: ${cloroLibre.toStringAsFixed(1)}';

    if (cloroLibre < limiteCloroBajo) {
      final incremento = (esAguaSalada ? 3.0 : 2.0) - cloroLibre; // o tu target
      final galones = incremento * (volumenGalones / 10000.0) / fuerzaCloro;  // ← divide por 12.5
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
        valorNormal: localizations.normalRangeCloroLibre,
        valorActualFormateado: valor,
      );

    } else if (cloroLibre > limiteCloroAlto && !_isShockNeeded(cloroCombinado)) {
      recomendaciones['Cloro libre'] =
      '**${localizations.cloroLibreLabel}**\n'
          '📏 ${localizations.normalRangePrefix} $rangoCloroTexto\n'
          '$valor\n'
          '⚠️ ${localizations.cloroLibreAltoSugerencia}';
    } else {
      recomendaciones['Cloro libre'] =
      '**${localizations.cloroLibreLabel}**\n'
          '📏 ${localizations.normalRangePrefix} $rangoCloroTexto\n'
          '$valor\n'
          '✅ ${localizations.valorNormal}';
    }

    // ────────────────────────────────────────────────────────────────────────
    // PARCHE SHOCK (solo presentación):
    // Si hay modo shock por CC alto, NO queremos que esta tarjeta diga “✅ Normal”.
    // No tocamos cálculos ni stock; solo sobreescribimos el texto mostrado.
    // PARCHE SHOCK (solo presentación):
    if (_isShockNeeded(cloroCombinado)) {
      final lineaTarget = (cya != null)
          ? '\n🎯 ${localizations.shockTargetLabel}: ${_shockTargetFromCYA(cya!).toStringAsFixed(0)} ppm'
          : '';

      // Solo avisar “alto” si realmente está alto:
      final notaAlto = (cloroLibre != null && cloroLibre > limiteCloroAlto)
          ? '\n${localizations.cloroLibreAltoSugerencia}'
          : ''; // si no, nada (o ver “opcional” abajo)

      recomendaciones['Cloro libre'] =
      '**${localizations.cloroLibreLabel}**\n'
          '📏 ${localizations.normalRangePrefix} $rangoCloroTexto\n'
          '$valor\n'
          '🧪 ${localizations.shockModeTitle}$lineaTarget'
          '$notaAlto';
    }

    // ────────────────────────────────────────────────────────────────────────
  }


  // ================== CLORO COMBINADO (modo SHOCK) ========================
  // ================== CLORO COMBINADO (modo SHOCK) ========================
  if (cloroCombinado != null) {
    final double shockTargetForCheck = (cya != null) ? _shockTargetFromCYA(cya!) : 0.0;
    final valor = '${localizations.cloroCombinadoLabel}: ${cloroCombinado.toStringAsFixed(1)}';

    // 1) SHOCK (igual que lo tenías)
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
            tituloForzado: localizations.cloroCombinadoLabel, // (opcional, solo para título)
          );

          if (recomendaciones.containsKey('cloro_liquido')) {
            recomendaciones['Cloro combinado'] = recomendaciones['cloro_liquido']!;
          }
          recomendaciones.remove('cloro_liquido');

        } else {
          recomendaciones['Cloro combinado'] =
          '🧪 ${localizations.shockModeTitle}\n'
              '🎯 ${localizations.shockTargetLabel}: ${shockTarget.toStringAsFixed(0)} ppm\n'
              '${localizations.requiereTratamientoChoque}\n'
              '✅ ${localizations.fcAlreadyAtShock}\n'
              '$condicionesShock\n'
              '${localizations.cloroLibreAltoSugerencia}';
        }

      } else {
        recomendaciones['Cloro combinado'] =
        '🧪 ${localizations.shockModeTitle}\n'
            '${localizations.requiereTratamientoChoque}\n'
            '💡 ${localizations.shockMeasureCyaFc}';
      }
    }

    // 2) SHOCK COMPLETADO (mismo código que tenías, movido aquí)
    else if (cya != null && shockTargetForCheck > 0 &&
        _isShockCleared(
          cc: cloroCombinado,
          fcActual: cloroLibre,
          shockTarget: shockTargetForCheck,
        )) {
      recomendaciones['Cloro combinado'] =
      '🧪 ${localizations.shockModeTitle}\n'
          '✅ ${localizations.shockCompleted}\n'
          '${localizations.resumeNormalOperation}';
    }

    // 3) CC = 0.0 (como lo tenías)
    else if (cloroCombinado == 0.0) {
      recomendaciones['Cloro combinado'] =
      '**${localizations.cloroCombinadoLabel}**\n'
          '📏 ${localizations.normalRangeCloroCombinado}\n'
          '$valor\n'
          '✅ ${localizations.cloroCombinadoCero}';
    }

    // 4) CC leve 0.1–0.2 (este bloque lo movimos debajo del shock completado)
    else if (cloroCombinado >= 0.1 && cloroCombinado <= 0.2) {
      recomendaciones['Cloro combinado'] =
      '**${localizations.cloroCombinadoLabel}**\n'
          '📏 ${localizations.normalRangeCloroCombinado}\n'
          '$valor\n'
          '⚠️ ${localizations.cloroCombinadoAdvertenciaLeve}';
    }

    // 5) Resto: normal
    else {
      recomendaciones['Cloro combinado'] =
      '**${localizations.cloroCombinadoLabel}**\n'
          '📏 ${localizations.normalRangeCloroCombinado}\n'
          '$valor\n'
          '✅ ${localizations.valorNormal}';
    }
  }


  final String? titulante = parametros['pH titulante']; // 'R-005' o 'R-006'
  final double? gotas = toDouble(parametros['pH gotas']);
  final bool esMedicionManual = (gotas == null || gotas == 0 || titulante == null || titulante.isEmpty);

  if (esMedicionManual && ph != null) {
    // ✅ Modo manual (ingresado visualmente con tirilla o color)
    String valor = '${localizations.ph}: ${ph.toStringAsFixed(2)}';

    if (ph < 7.2) {
      recomendaciones['pH'] =
      '**${localizations.ph}**\n📏 ${localizations.normalRangePh}\n$valor\n⚠️ ${localizations.valorBajo}';
    } else if (ph > 7.8) {
      recomendaciones['pH'] =
      '**${localizations.ph}**\n📏 ${localizations.normalRangePh}\n$valor\n⚠️ ${localizations.valorAlto}';
    } else {
      recomendaciones['pH'] =
      '**${localizations.ph}**\n📏 ${localizations.normalRangePh}\n$valor\n✅ ${localizations.valorNormal}';
    }

  } else if (!esMedicionManual) {
    // ✅ Modo visual (usando titulante R-005 o R-006 + gotas)
    double cantidad;
    String mensaje;
    String producto;
    String nombreComercial;
    String valorVisual = localizations.phVisualPlaceholder;

    if (titulante == 'R-006') {
      // ✅ R-006 → BASE DEMAND → pH bajo → subir pH
      double baseCantidad = calcularPhAltoQt(gotas!.toInt(), volumenGalones);
      cantidad = esMetrico ? baseCantidad * factorPeso : baseCantidad;
      producto = localizations.nombreProductoPhSubir;
      nombreComercial = localizations.nombreComercialPhSubir;

      mensaje = '⚠️ ${localizations.phBajo}\n➕ ${localizations.recomendacionGenerica(
        cantidad.toStringAsFixed(2),
        unidadPeso,
        producto,
        nombreComercial,
      )}';
    } else if (titulante == 'R-005') {
      // ✅ R-005 → ACID DEMAND → pH alto → bajar pH
      double baseCantidad = calcularPhAltoQt(gotas!.toInt(), volumenGalones);
      cantidad = esMetrico ? baseCantidad * factorVolumen : baseCantidad;
      producto = localizations.nombreProductoPhBajar;
      nombreComercial = localizations.nombreComercialPhBajar;

      mensaje = '⚠️ ${localizations.phAlto}\n➖ ${localizations.recomendacionGenerica(
        cantidad.toStringAsFixed(2),
        unidadVol,
        producto,
        nombreComercial,
      )}';
    } else {
      recomendaciones['pH'] =
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
  }

  if (alcalinidad != null) {
    String valor = '${localizations.alcalinidadLabel}: ${alcalinidad.toStringAsFixed(0)}';

    if (alcalinidad < 80) {
      double incremento = 80 - alcalinidad;
      double libras = incremento / 10 * 1.4 * (volumenGalones / 10000); // 1.4 lb por 10 ppm cada 10,000 gal
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
    } else if (alcalinidad > 120) {
      double exceso = alcalinidad - 120;
      double litros = exceso / 10 * 0.5 * (volumenLitros / 37850); // 0.5 L por 10 ppm cada 10,000 gal
      double cantidad = esMetrico ? litros * 1000 : litros / 3.785; // mL o gal
      String cantidadFormateada = esMetrico
          ? '${cantidad.toStringAsFixed(0)} mL'
          : '${cantidad.toStringAsFixed(2)} gal';

      await procesarUso(
        key: 'acido_muriatico',
        cantidad: cantidad,
        nombreProducto: localizations.nombreProductoPHAlto,
        nombreComercial: localizations.nombreComercialPHAlto,
        mensajeBase: '⚠️ ${localizations.alcalinidadAltaTexto}\n➖ ${localizations.recomendacionGenerica(
          cantidadFormateada,
          '',
          localizations.nombreProductoPHAlto,
          localizations.nombreComercialPHAlto,
        )}\n${localizations.alcalinidadAltaConsejo1}\n${localizations.alcalinidadAltaAdvertenciaPh}',
        valorNormal: localizations.normalRangeAlcalinidad,
        valorActualFormateado: valor,
      );


    } else {
      recomendaciones['Alcalinidad'] = '**${localizations.alcalinidadLabel}**\n📏 ${localizations.normalRangeAlcalinidad}\n$valor\n✅ ${localizations.valorNormal} (80–120 ppm)';
    }
  }

  if (cya != null) {
    String valor = '${localizations.cyaLabel}: ${cya.toStringAsFixed(0)}';

    final int cyaLimiteAlto = cyaMax; // 80 en salada, 50 en no salada


    if (cya < 30) {
      // (mantienes tu cálculo "desde 30 ppm")
      double incremento = 30 - cya;
      double libras = incremento / 10 * 1.25 * factorVolumenEscala;
      double cantidad = esMetrico ? libras * factorPeso : libras;

      await procesarUso(
        key: 'estabilizador',
        cantidad: cantidad,
        nombreProducto: localizations.productoCya,
        nombreComercial: localizations.nombreComercialCYA,
        mensajeBase: '⚠️ ${localizations.cyaBajo}\n➕ ${localizations.recomendacionGenerica(
          cantidad.toStringAsFixed(1),
          unidadPeso,
          localizations.productoCya,
          localizations.nombreComercialCYA,
        )}',
        // 👇 aquí ahora sí usas el rango correcto
        valorNormal: localizations.cyaValorNormal(rangoCyaTexto),
        valorActualFormateado: valor,
      );

    } else if (cya > cyaLimiteAlto) {
      recomendaciones['CYA'] =
      '**${localizations.cyaLabel}**\n'
          '📏 ${localizations.cyaValorNormal(rangoCyaTexto)}\n'
          '$valor\n'
          '⚠️ ${localizations.cyaAlto}\n'
          '💡 ${localizations.cyaAltoConsejo}';

    } else {
      recomendaciones['CYA'] =
      '**${localizations.cyaLabel}**\n'
          '📏 ${localizations.cyaValorNormal(rangoCyaTexto)}\n'
          '$valor\n'
          '✅ ${localizations.valorNormal}';
    }
  }



  if (dureza != null) {
      String valor = '${localizations.durezaLabel}: ${dureza.toStringAsFixed(
          0)}';
      if (dureza < 200) {
        double incremento = 200 - dureza;
        double libras = incremento / 10 * 1.25 * factorVolumenEscala;
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
          valorActualFormateado: '${localizations.durezaLabel}: ${dureza.toStringAsFixed(0)}',
        );
      } else if (dureza > 400) {
        recomendaciones['Dureza'] =
        '**${localizations.durezaLabel}**\n'
            '📏 ${localizations.normalRangeDureza}\n'
            '$valor\n'
            '⚠️ ${localizations.durezaAlta}\n'
            '💡 ${localizations.durezaAltaConsejo}';
      } else {
        recomendaciones['Dureza'] =
        '**${localizations.durezaLabel}**\n'
            '📏 ${localizations.normalRangeDureza}\n'
            '$valor\n'
            '✅ ${localizations.valorNormal}';
      }
    }

    if (salinidad != null && esAguaSalada) {
      String valor = '${localizations.salinidadLabel}: ${salinidad
          .toStringAsFixed(0)}';
      if (salinidad < 3000) {
        double incremento = 3000 - salinidad;
        double libras = incremento * 10.8 / 100 * factorVolumenEscala;
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
          valorActualFormateado: '${localizations.salinidadLabel}: ${salinidad.toStringAsFixed(0)}',
        );
      } else if (salinidad > 3500) {
        recomendaciones['Salinidad'] =
        '**${localizations.salinidadLabel}**\n'
            '📏 ${localizations.normalRangeSalinidad}\n'
            '$valor\n'
            '⚠️ ${localizations.salinidadAlta}\n'
            '💡 ${localizations.salinidadAltaConsejo}';
      } else {
        recomendaciones['Salinidad'] =
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



