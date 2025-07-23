import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Map<String, String> calcularAjustes(Map<String, String> parametros, AppLocalizations local) {
  final recomendaciones = <String, String>{};
  double? toDouble(String? valor) => double.tryParse(valor ?? '');
  double volumenLitros = 49210; // 13,000 galones

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
        mensaje += '\n' + local.cloroLibreAgregar(galones.toStringAsFixed(1));
      }
      mensaje += '\n' + local.cloroLibreTip;
    } else if (cloroLibre > 5.0) {
      mensaje += local.cloroLibreAlto;
    } else {
      mensaje += local.estaEnRango;
    }

    recomendaciones['Cloro libre'] = mensaje;
  }

  // Cloro combinado
  if (cloroCombinado != null) {
    String mensaje = local.cloroCombinadoTitulo(cloroCombinado.toStringAsFixed(1)) + '\n';

    if (cloroCombinado > 0.2) {
      double diferencia = (cloroCombinado > 0.5) ? (cloroCombinado - 0.2) : 0.5;
      double galones = (diferencia * volumenLitros * 0.00013).clamp(0.5, 2.5);
      mensaje += local.cloroCombinadoAlto +
          '\n' + local.cloroCombinadoAgregar(galones.toStringAsFixed(1)) +
          '\n' + local.cloroCombinadoTip;
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
      mensaje += local.phAlto(ml.toStringAsFixed(0));
    } else if (ph < 7.2) {
      double libras = 1.0 + ((7.2 - ph) * 3.5);
      mensaje += local.phBajo(libras.toStringAsFixed(1));
    } else {
      mensaje += local.estaEnRango;
    }

    recomendaciones['pH'] = mensaje;
  }

  // Alcalinidad
  if (alcalinidad != null) {
    String mensaje = local.alcalinidadTitulo(alcalinidad.toStringAsFixed(0)) + '\n';

    if (alcalinidad < 80) {
      double incremento = 80 - alcalinidad;
      double libras = incremento / 10;
      mensaje += local.alcalinidadBaja(libras.toStringAsFixed(1));
    } else if (alcalinidad > 130) {
      double exceso = alcalinidad - 120;
      double ml = exceso * 10;
      mensaje += local.alcalinidadAlta(ml.toStringAsFixed(0));
    } else {
      mensaje += local.estaEnRango;
    }

    recomendaciones['Alcalinidad'] = mensaje;
  }

  // CYA
  if (cya != null) {
    String mensaje = local.cyaTitulo(cya.toStringAsFixed(0)) + '\n';

    if (cya < 30) {
      double incremento = 30 - cya;
      double libras = incremento / 10;
      mensaje += local.cyaBajo(libras.toStringAsFixed(1));
    } else if (cya > 70) {
      mensaje += local.cyaAlto;
    } else {
      mensaje += local.estaEnRango;
    }

    recomendaciones['CYA'] = mensaje;
  }

  // Dureza cálcica
  if (dureza != null) {
    String mensaje = local.durezaTitulo(dureza.toStringAsFixed(0)) + '\n';

    if (dureza < 200) {
      double incremento = 200 - dureza;
      double libras = incremento / 20;
      mensaje += local.durezaBaja(libras.toStringAsFixed(1));
    } else if (dureza > 450) {
      mensaje += local.durezaAlta;
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
      mensaje += local.salinidadBaja(libras.toStringAsFixed(1));
    } else if (salinidad > 3700) {
      mensaje += local.salinidadAlta;
    } else {
      mensaje += local.estaEnRango;
    }

    recomendaciones['Salinidad'] = mensaje;
  }

  return recomendaciones;
}
