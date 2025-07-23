import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Map<String, String> calcularAjustes(
    Map<String, String> parametros,
    AppLocalizations local,
    String unidadSistema,
    ) {
  final recomendaciones = <String, String>{};
  double? toDouble(String? valor) => double.tryParse(valor ?? '');
  double volumenLitros = 49210; // 13,000 galones

  bool esMetrico = unidadSistema == 'metrico';
  double factorPeso = 0.4536;
  double factorVolumen = 3.785;

  final unidadPeso = esMetrico ? local.unidadKg : local.unidadLb;
  final unidadVol = esMetrico ? local.unidadLitro : local.unidadGalon;

  double? cloroLibre = toDouble(parametros['Cloro libre']);
  double? cloroCombinado = toDouble(parametros['Cloro combinado']);
  double? ph = toDouble(parametros['pH']);
  double? alcalinidad = toDouble(parametros['Alcalinidad']);
  double? cya = toDouble(parametros['CYA']);
  double? dureza = toDouble(parametros['Dureza']);
  double? salinidad = toDouble(parametros['Salinidad']);

  // Cloro libre
  if (cloroLibre != null) {
    String mensaje = local.cloroLibreTitulo(cloroLibre.toStringAsFixed(1)) + '\n';

    if (cloroLibre < 3.0) {
      mensaje += local.cloroLibreBajo;
      if (cloroLibre < 1.5) {
        double galones = (((3 - cloroLibre) * volumenLitros * 0.00013).clamp(0.5, 2.5));
        double cantidad = esMetrico ? galones * factorVolumen : galones;
        mensaje += '\n' +
            local.cloroLibreAgregar(
                '${cantidad.toStringAsFixed(1)} $unidadVol');
      }
      mensaje += '\n' + local.cloroLibreTip;
    } else if (cloroLibre > 6.0) {
      mensaje += local.cloroLibreAlto;
    } else {
      mensaje += local.estaEnRango;
    }

    recomendaciones['Cloro libre'] = mensaje;
  }

  // Cloro combinado
  if (cloroCombinado != null) {
    String mensaje =
        local.cloroCombinadoTitulo(cloroCombinado.toStringAsFixed(1)) + '\n';

    if (cloroCombinado > 0.5) {
      double diferencia = cloroCombinado - 0.2;
      double galones = (diferencia * volumenLitros * 0.00013).clamp(0.5, 2.5);
      double cantidad = esMetrico ? galones * factorVolumen : galones;
      mensaje += local.cloroCombinadoAlto +
          '\n' +
          local.cloroCombinadoAgregar(
              '${cantidad.toStringAsFixed(1)} $unidadVol') +
          '\n' +
          local.cloroCombinadoTip;
    } else {
      mensaje += local.estaEnRango;
    }

    recomendaciones['Cloro combinado'] = mensaje;
  }

  // pH
  if (ph != null) {
    String mensaje = local.phTitulo(ph.toStringAsFixed(2)) + '\n';

    if (ph > 7.8) {
      double ml = (ph >= 8.0) ? 500 : 300;
      mensaje += local.phAlto('${ml.toStringAsFixed(0)} mL');
    } else if (ph < 7.2) {
      double libras = 1.0 + ((7.2 - ph) * 3.5);
      double cantidad = esMetrico ? libras * factorPeso : libras;
      mensaje += local.phBajo('${cantidad.toStringAsFixed(1)} $unidadPeso');
    } else {
      mensaje += local.estaEnRango;
    }

    recomendaciones['pH'] = mensaje;
  }

  // Alcalinidad
  if (alcalinidad != null) {
    String mensaje = local.alcalinidadTitulo(alcalinidad.toStringAsFixed(0)) + '\n';

    double? cantidad;

    if (alcalinidad < 80) {
      double incremento = 80 - alcalinidad;
      double libras = incremento / 10;
      cantidad = esMetrico ? libras * factorPeso : libras;
      mensaje += local.alcalinidadBaja('${cantidad.toStringAsFixed(1)} $unidadPeso');
    } else if (alcalinidad > 120) {
      double decremento = alcalinidad - 120;
      double libras = decremento / 10;
      cantidad = esMetrico ? libras * factorPeso : libras;
      mensaje += local.alcalinidadAlta('${cantidad.toStringAsFixed(1)} $unidadPeso');
    } else {
      mensaje += local.estaEnRange;
    }

    recomendaciones['Alcalinidad'] = mensaje;
  }


  // CYA
  if (cya != null) {
    String mensaje = local.cyaTitulo(cya.toStringAsFixed(0)) + '\n';

    if (cya < 30) {
      double incremento = 30 - cya;
      double libras = incremento / 10;
      double cantidad = esMetrico ? libras * factorPeso : libras;
      mensaje += local.cyaBajo('${cantidad.toStringAsFixed(1)} $unidadPeso');
    } else if (cya > 70) {
      mensaje += local.cyaAlto;
    } else {
      mensaje += local.estaEnRango;
    }

    recomendaciones['CYA'] = mensaje;
  }

  // Dureza
  if (dureza != null) {
    String mensaje = local.durezaTitulo(dureza.toStringAsFixed(0)) + '\n';

    if (dureza < 200) {
      double incremento = 200 - dureza;
      double libras = incremento / 20;
      double cantidad = esMetrico ? libras * factorPeso : libras;
      mensaje += local.durezaBaja('${cantidad.toStringAsFixed(1)} $unidadPeso');
    } else if (dureza > 400) {
      mensaje += local.durezaAlto;
    } else {
      mensaje += local.estaEnRango;
    }

    recomendaciones['Dureza'] = mensaje;
  }

  // Salinidad
  if (salinidad != null) {
    String mensaje = local.salinidadTitulo(salinidad.toStringAsFixed(0)) + '\n';

    if (salinidad < 3000) {
      double incremento = 3000 - salinidad;
      double libras = incremento * 10.8 / 100;
      double cantidad = esMetrico ? libras * factorPeso : libras;
      mensaje += local.salinidadBaja('${cantidad.toStringAsFixed(1)} $unidadPeso');
    } else if (salinidad > 3700) {
      mensaje += local.salinidadAlta;
    } else {
      mensaje += local.estaEnRango;
    }

    recomendaciones['Salinidad'] = mensaje;
  }

  return recomendaciones;
}
