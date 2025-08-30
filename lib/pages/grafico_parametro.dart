import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/test_registro.dart';
import '../utils/registro_loader.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import '../utils/color_utils.dart';

/// Rango e intervalos del eje Y
class _YRango {
  final double minY;
  final double maxY;
  final double gridInterval; // paso de la grilla horizontal
  const _YRango(this.minY, this.maxY, this.gridInterval);
}

class GraficoParametroPage extends StatefulWidget {
  const GraficoParametroPage({super.key});

  @override
  _GraficoParametroPageState createState() => _GraficoParametroPageState();
}

class _GraficoParametroPageState extends State<GraficoParametroPage> {
  static const double _kAxisReservedLeft = 48;
  static const int _maxPuntosVisibles = 12; // <-- últimas N mediciones visibles

  String parametroSeleccionado = 'Cloro libre';
  List<TestRegistro> registros = [];

  @override
  void initState() {
    super.initState();
    _cargarRegistros();
  }

  void _cargarRegistros() async {
    final datos = await cargarTodosLosRegistros();
    setState(() {
      registros = datos;
    });
  }

  List<TestRegistro> _filtrarPorParametro(String parametro) {
    final list = registros.where((r) => r.parametro == parametro).toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    // Limitar a las últimas N mediciones
    if (list.length > _maxPuntosVisibles) {
      return list.sublist(list.length - _maxPuntosVisibles);
    }
    return list;
  }

  String _unidadPara(String parametro) {
    switch (parametro) {
      case 'pH':
        return '';
      case 'Salinidad':
        return ' ppm';
      case 'CYA':
      case 'Alcalinidad':
      case 'Dureza':
      case 'Cloro libre':
      case 'Cloro combinado':
      default:
        return ' ppm';
    }
  }

  /// Devuelve [min, max] ordenado y según tipo de pileta
  List<double> _valoresNormalesPara(
      String parametro, {
        required bool esAguaSalada,
      }) {
    List<double> v;
    switch (parametro) {
      case 'Cloro libre':
        v = esAguaSalada ? [3, 6] : [1, 4];
        break;
      case 'Cloro combinado':
        v = [0, 0.2];
        break;
      case 'pH':
        v = [7.4, 7.6];
        break;
      case 'Alcalinidad':
        v = [80, 120];
        break;
      case 'CYA':
        v = esAguaSalada ? [60, 80] : [30, 50];
        break;
      case 'Dureza':
        v = [200, 400];
        break;
      case 'Salinidad':
        v = [2700, 3400];
        break;
      default:
        v = [0, 0];
    }
    if (v.first > v.last) v = [v.last, v.first];
    return v;
  }

  /// Construye spots usando **índices** (0..n-1) para X y guarda fechas
  ({List<FlSpot> spots, List<DateTime> fechas}) _spotsPorIndice(List<TestRegistro> datos) {
    final fechas = <DateTime>[];
    final spots = <FlSpot>[];
    for (var i = 0; i < datos.length; i++) {
      fechas.add(datos[i].fecha);
      spots.add(FlSpot(i.toDouble(), datos[i].valor));
    }
    return (spots: spots, fechas: fechas);
  }

  _YRango _rangoY(
      List<TestRegistro> datos,
      String parametro,
      List<double> normales,
      ) {
    if (datos.isEmpty) return const _YRango(0, 1, 0.2);

    final valores = datos.map((e) => e.valor).toList();
    double minV = valores.reduce((a, b) => a < b ? a : b);
    double maxV = valores.reduce((a, b) => a > b ? a : b);

    // incluir límites ideales
    minV = (minV < normales[0]) ? minV : normales[0];
    maxV = (maxV > normales[1]) ? maxV : normales[1];

    final span = (maxV - minV).abs();
    final padding = (span == 0 ? 0.2 : span * 0.15);
    double minY = minV - padding;
    double maxY = maxV + padding;

    double gridInterval;
    switch (parametro) {
      case 'pH':
        if (!minY.isFinite || minY < 6.8) minY = 6.8;
        if (!maxY.isFinite || maxY > 8.2) maxY = 8.2;
        if (maxY - minY < 0.6) {
          minY = 6.8;
          maxY = 8.2;
        }
        gridInterval = 0.2;
        break;
      case 'Salinidad':
        if (minY < 0) minY = 0;
        gridInterval = 200;
        break;
      case 'CYA':
        if (minY < 0) minY = 0;
        gridInterval = 10;
        break;
      case 'Alcalinidad':
        if (minY < 0) minY = 0;
        gridInterval = 20;
        break;
      case 'Dureza':
        if (minY < 0) minY = 0;
        gridInterval = 50;
        break;
      case 'Cloro libre':
        if (minY < 0) minY = 0;
        gridInterval = 0.5;
        break;
      case 'Cloro combinado':
        if (minY < 0) minY = 0;
        gridInterval = 0.1;
        break;
      default:
        if (minY < 0) minY = 0;
        gridInterval = (maxY - minY) / 5;
    }

    if (!minY.isFinite || !maxY.isFinite || minY == maxY) {
      minY = parametro == 'pH' ? 6.8 : 0;
      maxY = parametro == 'pH' ? 8.2 : 1;
      gridInterval = parametro == 'pH' ? 0.2 : 0.2;
    }

    return _YRango(minY, maxY, gridInterval);
  }

  /// Intervalo de etiquetas en Y (más grueso que la grilla para no “duplicar”)
  double _labelIntervalY(String parametro, _YRango r) {
    switch (parametro) {
      case 'pH':
        return 0.5;
      case 'Cloro libre':
        return 1.0;
      case 'Cloro combinado':
        return 0.2;
      case 'Alcalinidad':
        return 40;
      case 'CYA':
        return 20;
      case 'Dureza':
        return 100;
      case 'Salinidad':
        return 400;
      default:
        return r.gridInterval;
    }
  }

  Widget _construirGrafico(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final esAguaSalada = Provider.of<SettingsController>(context).esAguaSalada;

    final datosFiltrados = _filtrarPorParametro(parametroSeleccionado);
    if (datosFiltrados.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(local.noDataToPlot),
      );
    }

    final color = colorParaParametro(parametroSeleccionado);
    final valoresNormales = _valoresNormalesPara(
      parametroSeleccionado,
      esAguaSalada: esAguaSalada,
    );
    final unidad = _unidadPara(parametroSeleccionado);

    // --- SPOTS usando índices + fechas para labels/tooltip ---
    final datos = _spotsPorIndice(datosFiltrados);
    final spots = datos.spots;
    final fechas = datos.fechas; // mismo orden que spots

    // Rango X: índice con un poco de padding para que no "toque" los bordes
    final int n = spots.length;
    final double minX = -0.5;
    final double maxX = (n - 1) + 0.5;

    final dateFormat = DateFormat('MM/dd');
    final rango = _rangoY(datosFiltrados, parametroSeleccionado, valoresNormales);
    final labelIntervalY = _labelIntervalY(parametroSeleccionado, rango);

    // Mostrar como máximo ~6 labels en X (salteamos algunos si hay muchos puntos)
    final step = (n <= 6) ? 1 : (n / 6).ceil();

    final Color? textoColor = Theme.of(context).textTheme.bodySmall?.color;
    final Color textoColorSafe = textoColor ?? Colors.grey;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: AspectRatio(
            aspectRatio: 1.5,
            child: LineChart(
              LineChartData(
                minX: minX,
                maxX: maxX,
                minY: rango.minY,
                maxY: rango.maxY,

                clipData: const FlClipData(
                  left: false,
                  right: false,
                  top: true,
                  bottom: true,
                ),

                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: color.withOpacity(0.85),
                    getTooltipItems: (touched) => touched.map((t) {
                      // t.x es el índice → redondeamos al entero más cercano
                      final idx = t.x.round().clamp(0, n - 1);
                      final dt = fechas[idx];
                      final yTxt = (parametroSeleccionado == 'pH')
                          ? t.y.toStringAsFixed(2)
                          : t.y.toStringAsFixed(1);
                      return LineTooltipItem(
                        '${dateFormat.format(dt)}\n${_nombreTrad(local, parametroSeleccionado)}: $yTxt$unidad',
                        const TextStyle(color: Colors.white),
                      );
                    }).toList(),
                  ),
                ),

                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: Text(local.fecha),
                    axisNameSize: 26,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 1, // un tick por índice
                      getTitlesWidget: (value, meta) {
                        // Solo etiquetar índices enteros y cada "step"
                        final idx = value.round();
                        if (idx < 0 || idx >= n) return const SizedBox.shrink();
                        if (idx % step != 0 && idx != n - 1) {
                          return const SizedBox.shrink();
                        }
                        final dt = fechas[idx];
                        return Transform.rotate(
                          angle: -0.45,
                          child: Text(
                            dateFormat.format(dt),
                            style: TextStyle(fontSize: 11, color: textoColorSafe),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: Text(
                      '${local.valor}${_unidadPara(parametroSeleccionado).isNotEmpty ? ' (${_unidadPara(parametroSeleccionado)})' : ''}',
                    ),
                    axisNameSize: 22,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: _kAxisReservedLeft,
                      interval: labelIntervalY,
                      getTitlesWidget: (value, meta) {
                        final txt = (parametroSeleccionado == 'pH')
                            ? value.toStringAsFixed(1)
                            : (labelIntervalY >= 1
                            ? value.toStringAsFixed(0)
                            : value.toStringAsFixed(1));
                        return Text(
                          txt,
                          style: TextStyle(fontSize: 11, color: textoColorSafe),
                        );
                      },
                    ),
                  ),
                ),

                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  horizontalInterval: rango.gridInterval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: textoColorSafe.withOpacity(0.12),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: true),

                lineBarsData: [
                  // Datos
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    barWidth: 3,
                    color: color,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                            radius: 3.5,
                            color: color,
                            strokeWidth: 1.5,
                            strokeColor: color.withOpacity(0.85),
                          ),
                    ),
                  ),
                  // Límites de la banda ideal (en escala de índices)
                  LineChartBarData(
                    spots: [FlSpot(minX, valoresNormales[0]), FlSpot(maxX, valoresNormales[0])],
                    isCurved: false,
                    barWidth: 1,
                    color: Colors.transparent,
                    dotData: FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: [FlSpot(minX, valoresNormales[1]), FlSpot(maxX, valoresNormales[1])],
                    isCurved: false,
                    barWidth: 1,
                    color: Colors.transparent,
                    dotData: FlDotData(show: false),
                  ),
                ],
                betweenBarsData: [
                  BetweenBarsData(
                    fromIndex: 1,
                    toIndex: 2,
                    color: Colors.green.withOpacity(0.16),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Tu string localizada usa {1}–{0}
        Text(
          AppLocalizations.of(context)!.valorIdeal(
            valoresNormales[1],
            valoresNormales[0],
          ),
          style: const TextStyle(color: Colors.green, fontSize: 16),
        ),
      ],
    );
  }

  String _nombreTrad(AppLocalizations local, String parametro) {
    switch (parametro) {
      case 'Cloro libre':
        return local.cloroLibre;
      case 'Cloro combinado':
        return local.cloroCombinado;
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
        return parametro;
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final esAguaSalada = Provider.of<SettingsController>(context).esAguaSalada;

    final mapaParametros = {
      'Cloro libre': local.cloroLibre,
      'Cloro combinado': local.cloroCombinado,
      'pH': local.ph,
      'Alcalinidad': local.alcalinidad,
      'CYA': local.cya,
      'Dureza': local.dureza,
      if (esAguaSalada) 'Salinidad': local.salinidad,
    };

    if (!mapaParametros.containsKey(parametroSeleccionado)) {
      parametroSeleccionado = 'Cloro libre';
    }

    return Scaffold(
      appBar: AppBar(title: Text(local.graficoParametro)),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButtonFormField<String>(
              value: parametroSeleccionado,
              decoration: InputDecoration(
                labelText: local.parametro,
                border: const OutlineInputBorder(),
              ),
              items: mapaParametros.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (nuevo) {
                setState(() => parametroSeleccionado = nuevo!);
              },
            ),
          ),
          const SizedBox(height: 20),
          Expanded(child: _construirGrafico(context)),
        ],
      ),
    );
  }
}
