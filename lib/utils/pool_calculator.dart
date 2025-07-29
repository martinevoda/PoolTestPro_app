import 'package:flutter/material.dart';
import 'package:piscina_app/utils/stock_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Map<String, String>> calcularAjustes(
    Map<String, String> parametros,
    BuildContext context,
    String unidadSistema,
    ) async {
  final recomendaciones = <String, String>{};
  await StockService.getAllStock();

  double? toDouble(String? valor) => double.tryParse(valor ?? '');

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

  double? cloroLibre = toDouble(parametros['Cloro libre']);
  double? cloroCombinado = toDouble(parametros['Cloro combinado']);
  double? ph = toDouble(parametros['pH']);
  double? alcalinidad = toDouble(parametros['Alcalinidad']);
  double? cya = toDouble(parametros['CYA']);
  double? dureza = toDouble(parametros['Dureza']);
  double? salinidad = toDouble(parametros['Salinidad']);

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
      case 'acido_muriatico':
        tituloTraducido = localizations.phLabel;
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

    String texto = '**$tituloTraducido**\n'
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

    recomendaciones[tituloTraducido] = texto;
  }


    // BLOQUES PARA CADA PARÁMETRO

    if (cloroLibre != null) {
      String valor = '${localizations.cloroLibreLabel}: ${cloroLibre
          .toStringAsFixed(1)}';
      if (cloroLibre < 3.0) {
        double incremento = 3.0 - cloroLibre;
        double galones = (incremento * volumenLitros * 0.0002).clamp(0.5, 2.5);
        double cantidad = esMetrico ? galones * factorVolumen : galones;
        await procesarUso(
          key: 'cloro_liquido',
          cantidad: cantidad,
          nombreProducto: localizations.nombreProductoCloro,
          nombreComercial: localizations.nombreComercialCloro,
          mensajeBase: '⚠️ ${localizations.cloroLibreBajo}\n➕ ${localizations.recomendacionGenerica(
            cantidad.toStringAsFixed(1),
            unidadVol,
            localizations.nombreProductoCloro,
            localizations.nombreComercialCloro,
          )}',
          valorNormal: localizations.normalRangeCloroLibre,
          valorActualFormateado: '${localizations.cloroLibreLabel}: ${cloroLibre.toStringAsFixed(1)}',
        );
      } else if (cloroLibre > 6.0) {
          recomendaciones['Cloro libre'] = '**${localizations
              .cloroLibreLabel}**\n📏 Valor normal: 3.0–6.0 ppm\n$valor\n⚠️ ${localizations
              .cloroLibreAlto}';
        } else {
          recomendaciones['Cloro libre'] = '**${localizations
              .cloroLibreLabel}**\n📏 Valor normal: 3.0–6.0 ppm\n$valor\n✅ ${localizations
              .valorNormal} (3.0–6.0 ppm)';
        }
      }

    if (cloroCombinado != null) {
      String valor = '${localizations.cloroCombinadoLabel}: ${cloroCombinado
          .toStringAsFixed(1)}';
      if (cloroCombinado > 0.5) {
        double diferencia = cloroCombinado - 0.2;
        double galones = (diferencia * volumenLitros * 0.00013).clamp(0.5, 2.5);
        double cantidad = esMetrico ? galones * factorVolumen : galones;
        await procesarUso(
          key: 'cloro_liquido',
          cantidad: cantidad,
          nombreProducto: localizations.nombreProductoCloro,
          nombreComercial: localizations.nombreComercialCloro,
          mensajeBase: '⚠️ ${localizations.cloroCombinadoAlto}\n${localizations.requiereTratamientoChoque}\n➕ ${localizations.recomendacionGenerica(
            cantidad.toStringAsFixed(1),
            unidadVol,
            localizations.nombreProductoCloro,
            localizations.nombreComercialCloro,
          )}',
          valorNormal: localizations.normalRangeCloroCombinado,
          valorActualFormateado: '${localizations.cloroCombinadoLabel}: ${cloroCombinado.toStringAsFixed(1)}',
        );
      } else if (cloroCombinado < 0.1) {
          recomendaciones['Cloro combinado'] = '**${localizations
              .cloroCombinadoLabel}**\n📏 Valor normal: 0–0.5 ppm\n$valor\n⚠️ ${localizations
              .cloroCombinadoBajo}';
        } else {
          recomendaciones['Cloro combinado'] = '**${localizations
              .cloroCombinadoLabel}**\n📏 Valor normal: 0–0.5 ppm\n$valor\n✅ ${localizations
              .valorNormal} (0–0.5 ppm)';
        }
      }

    if (ph != null) {
      String valor = '${localizations.phLabel}: ${ph.toStringAsFixed(2)}';
      if (ph > 7.8) {
        double ml = (ph >= 8.0) ? 500 : 300;
        double volumen = esMetrico ? ml : (ml / 29.5735);
        String unidad = esMetrico ? 'mL' : 'fl oz';
        await procesarUso(
          key: 'acido_muriatico',
          cantidad: volumen,
          nombreProducto: localizations.nombreProductoPHAlto,
          nombreComercial: localizations.nombreComercialPHAlto,
          mensajeBase: '⚠️ ${localizations.phAlto}\n➕ ${localizations.recomendacionGenerica(
            volumen.toStringAsFixed(1),
            unidad,
            localizations.nombreProductoPHAlto,
            localizations.nombreComercialPHAlto,
          )}',
          valorNormal: localizations.normalRangePH,
          valorActualFormateado: '${localizations.phLabel}: ${ph.toStringAsFixed(2)}',
        );
    } else if (ph < 7.2) {
        double libras = ((7.2 - ph) * 0.16 * (volumenLitros / 1000));
        double cantidad = esMetrico ? libras * factorPeso : libras;
        await procesarUso(
          key: 'ph_increaser',
          cantidad: cantidad,
          nombreProducto: localizations.productoPh,
          nombreComercial: localizations.nombreComercialPHBajo,
          mensajeBase: '⚠️ ${localizations.phBajo}\n➕ ${localizations.recomendacionGenerica(
            cantidad.toStringAsFixed(1),
            unidadPeso,
            localizations.productoPh,
            localizations.nombreComercialPHBajo,
          )}',
          valorNormal: localizations.normalRangePH,
          valorActualFormateado: '${localizations.phLabel}: ${ph.toStringAsFixed(2)}',
        );
      } else {
        recomendaciones['pH'] = '**${localizations
            .phLabel}**\n📏 Valor normal: 7.2–7.8\n$valor\n✅ ${localizations
            .valorNormal} (7.2–7.8)';
      }
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

      recomendaciones['Alcalinidad'] = '**${localizations.alcalinidadLabel}**\n'
          '📏 ${localizations.normalRangeAlcalinidad}\n'
          '$valor\n'
          '⚠️ ${localizations.alcalinidadAltaTexto}\n'
          '➕ ${localizations.recomendacionGenerica(
        cantidadFormateada,
        esMetrico ? 'mL' : 'gal',
        localizations.nombreProductoPHAlto,
        localizations.nombreComercialPHAlto,
      )}\n'
          '💡 ${localizations.alcalinidadAltaConsejo1}\n'
          '💡 ${localizations.alcalinidadAltaConsejo2}';


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
