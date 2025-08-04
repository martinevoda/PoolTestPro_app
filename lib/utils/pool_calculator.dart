import 'package:flutter/material.dart';
import 'package:piscina_app/utils/stock_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  double volumenGalones = prefs.getDouble('volumen_piscina') ?? 13000;
  double volumenLitros = volumenGalones * 3.785;
  double factorVolumenEscala = volumenGalones / 10000;

  final localizations = AppLocalizations.of(context)!;
  bool esMetrico = unidadSistema == 'metrico';
  double factorPeso = 0.4536;
  double factorVolumen = 3.785;

  final unidadPeso = esMetrico ? localizations.unidadKg : localizations.unidadLb;
  final unidadVol = esMetrico ? localizations.unidadLitro : localizations.unidadGalon;

  final volumenMuestra = parametros['volumen_muestra'] ?? '25';
  final double factorCloro = volumenMuestra == '10' ? 0.5 : 0.2;
  final double factorAlcalinidad = volumenMuestra == '10' ? 25 : 10;
  final double factorDureza = 10;

  final cloroLibre = parametros.containsKey('Cloro libre gotas')
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
  final String? titulantePh = parametros['pH titulante'];
  final String? strGotasPh = parametros['pH gotas'];
  final int? gotasPh = int.tryParse(strGotasPh ?? '');
  final cya = toDouble(parametros['CYA']);
  final salinidad = toDouble(parametros['Salinidad']);


  // Función auxiliar general
  Future<void> procesarUso({
    required String key,
    required double cantidad,
    required String nombreProducto,
    required String nombreComercial,
    required String mensajeBase,
    required String valorNormal,
    required String valorActualFormateado,
  }) async {
    String tituloTraducido = '';
    switch (key) {
      case 'cloro_liquido':
        tituloTraducido = localizations.cloroLibreLabel;
        break;
      case 'ph_increaser':
        tituloTraducido = 'pH';
        break;
      case 'acido_muriatico':
      // Diferenciar si se trata de alcalinidad alta
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



  // BLOQUES PARA CADA PARÁMETRO

  if (cloroLibre != null) {
    String valor = '${localizations.cloroLibreLabel}: ${cloroLibre.toStringAsFixed(1)}';

    if (cloroLibre < 1.0) {
      // 🔻 Bajo → calcular cuánto agregar
      double incremento = 3.0 - cloroLibre; // subir hasta 3 ppm
      double galones = incremento * volumenLitros * 0.00013;
      double cantidad = esMetrico ? galones * factorVolumen : galones;

      String mensaje = '⚠️ ${localizations.cloroLibreBajo}\n➕ ${localizations.recomendacionGenerica(
        cantidad.toStringAsFixed(1),
        unidadVol,
        localizations.nombreProductoCloro,
        localizations.nombreComercialCloro,
      )}';

      if (galones > 5.0) {
        mensaje += '\n⚠️ ${localizations.choqueAlto}';
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
    } else if (cloroLibre > 6.0) {
      // 🚨 Muy alto → advertencia
      recomendaciones['Cloro libre'] = '**${localizations.cloroLibreLabel}**\n📏 ${localizations.normalRangeCloroLibre}\n$valor\n⚠️ ${localizations.cloroLibreAltoSugerencia}';
    } else {
      // ✅ Normal
      recomendaciones['Cloro libre'] = '**${localizations.cloroLibreLabel}**\n📏 ${localizations.normalRangeCloroLibre}\n$valor\n✅ ${localizations.valorNormal}';
    }
  }





  if (cloroCombinado != null) {
    String valor = '${localizations.cloroCombinadoLabel}: ${cloroCombinado.toStringAsFixed(1)}';

    if (cloroCombinado == 0.0) {
      recomendaciones['Cloro combinado'] =
      '**${localizations.cloroCombinadoLabel}**\n📏 ${localizations.normalRangeCloroCombinado}\n$valor\n✅ ${localizations.cloroCombinadoCero}';
    } else if (cloroCombinado > 0.5) {
      double diferencia = cloroCombinado - 0.2;
      double galones = (diferencia * volumenLitros * 0.00013);
      double cantidad = esMetrico ? galones * factorVolumen : galones;

      String mensaje = '⚠️ ${localizations.cloroCombinadoAlto}\n${localizations.requiereTratamientoChoque}\n➕ ${localizations.recomendacionGenerica(
        cantidad.toStringAsFixed(1),
        unidadVol,
        localizations.nombreProductoCloro,
        localizations.nombreComercialCloro,
      )}';

      if (galones > 5.0) {
        mensaje += '\n⚠️ ${localizations.choqueAlto}';
      }

      await procesarUso(
        key: 'cloro_liquido',
        cantidad: cantidad,
        nombreProducto: localizations.nombreProductoCloro,
        nombreComercial: localizations.nombreComercialCloro,
        mensajeBase: mensaje,
        valorNormal: localizations.normalRangeCloroCombinado,
        valorActualFormateado: '${localizations.cloroCombinadoLabel}: ${cloroCombinado.toStringAsFixed(1)}',
      );
    } else if (cloroCombinado >= 0.2 && cloroCombinado <= 0.5) {
      recomendaciones['Cloro combinado'] =
      '**${localizations.cloroCombinadoLabel}**\n📏 ${localizations.normalRangeCloroCombinado}\n$valor\n${localizations.cloroCombinadoAdvertenciaLeve}';
    } else if (cloroCombinado < 0.1) {
      recomendaciones['Cloro combinado'] =
      '**${localizations.cloroCombinadoLabel}**\n📏 ${localizations.normalRangeCloroCombinado}\n$valor\n⚠️ ${localizations.cloroCombinadoBajo}';
    } else {
      recomendaciones['Cloro combinado'] =
      '**${localizations.cloroCombinadoLabel}**\n📏 ${localizations.normalRangeCloroCombinado}\n$valor\n✅ ${localizations.valorNormal}';
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
      cantidad = calcularPhBajoLb(gotas!.toInt(), volumenGalones);
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
      cantidad = calcularPhAltoQt(gotas!.toInt(), volumenGalones);
      producto = localizations.nombreProductoPhBajar;
      nombreComercial = localizations.nombreComercialPhBajar;

      mensaje = '⚠️ ${localizations.phAlto}\n➖ ${localizations.recomendacionGenerica(
        cantidad.toStringAsFixed(2),
        unidadPeso,
        producto,
        nombreComercial,
      )}';
    } else {
      recomendaciones['pH'] =
      '**${localizations.ph}**\n📏 ${localizations.normalRangePh}\n⚠️ ${localizations.phTitulanteInvalido}';
      return recomendaciones;
    }

    await procesarUso(
      key: 'ph',
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
    double volumenGalones = prefs.getDouble('volumen_piscina') ?? 13000;
    double volumenLitros = volumenGalones * 3.785;

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
        mensajeBase: '⚠️ ${localizations.alcalinidadAltaTexto}\n➕ ${localizations.recomendacionGenerica(
          cantidadFormateada,
          '',
          localizations.nombreProductoPHAlto,
          localizations.nombreComercialPHAlto,
        )}\n💡 ${localizations.alcalinidadAltaConsejo1}',
        valorNormal: localizations.normalRangeAlcalinidad,
        valorActualFormateado: valor,
      );


    } else {
      recomendaciones['Alcalinidad'] = '**${localizations.alcalinidadLabel}**\n📏 ${localizations.normalRangeAlcalinidad}\n$valor\n✅ ${localizations.valorNormal} (80–120 ppm)';
    }
  }


  if (cya != null) {
      String valor = '${localizations.cyaLabel}: ${cya.toStringAsFixed(0)}';
      if (cya < 30) {
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
          valorNormal: localizations.normalRangeCYA,
          valorActualFormateado: '${localizations.cyaLabel}: ${cya.toStringAsFixed(0)}',
        );
      } else if (cya > 70) {
        recomendaciones['CYA'] = '**${localizations
            .cyaLabel}**\n📏 Valor normal: 30–70 ppm\n$valor\n⚠️ ${localizations
            .cyaAlto}\n💡 ${localizations.cyaAltoConsejo}';
      } else {
        recomendaciones['CYA'] = '**${localizations
            .cyaLabel}**\n📏 Valor normal: 30–70 ppm\n$valor\n✅ ${localizations
            .valorNormal} (30–70 ppm)';
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
        recomendaciones['Dureza'] = '**${localizations
            .durezaLabel}**\n📏 Valor normal: 200–400 ppm\n$valor\n⚠️ ${localizations
            .durezaAlta}\n💡 ${localizations.durezaAltaConsejo}';
      } else {
        recomendaciones['Dureza'] = '**${localizations
            .durezaLabel}**\n📏 Valor normal: 200–400 ppm\n$valor\n✅ ${localizations
            .valorNormal} (200–400 ppm)';
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
        recomendaciones['Salinidad'] = '**${localizations
            .salinidadLabel}**\n📏 Valor normal: 3000–3500 ppm\n$valor\n⚠️ ${localizations
            .salinidadAlta}\n💡 ${localizations.salinidadAltaConsejo}';
      } else {
        recomendaciones['Salinidad'] = '**${localizations
            .salinidadLabel}**\n📏 Valor normal: 3000–3500 ppm\n$valor\n✅ ${localizations
            .valorNormal} (3000–3500 ppm)';
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

