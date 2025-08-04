import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/test_registro.dart';
import '../utils/registro_loader.dart'; // Asegúrate que esta función existe
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';


class GraficoParametroPage extends StatefulWidget {
  const GraficoParametroPage({super.key});

  @override
  _GraficoParametroPageState createState() => _GraficoParametroPageState();
}

class _GraficoParametroPageState extends State<GraficoParametroPage> {
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
    return registros.where((r) => r.parametro == parametro).toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
  }

  List<FlSpot> _obtenerSpots(List<TestRegistro> datos) {
    return List.generate(
        datos.length, (i) => FlSpot(i.toDouble(), datos[i].valor));
  }

  List<double> _obtenerValoresNormales(String parametro) {
    switch (parametro) {
      case 'Cloro libre':
        return [2, 4];
      case 'Cloro combinado':
        return [0, 0.5];
      case 'pH':
        return [7.4, 7.6];
      case 'Alcalinidad':
        return [80, 120];
      case 'CYA':
        return [30, 50];
      case 'Dureza':
        return [200, 400];
      case 'Salinidad':
        return [2700, 3400];
      default:
        return [0, 0];
    }
  }

  final Map<String, Color> coloresParametros = {
    'Cloro libre': Colors.blue,
    'Cloro combinado': Colors.indigo,
    'pH': Colors.purple,
    'Alcalinidad': Colors.teal,
    'CYA': Colors.orange,
    'Dureza': Colors.red,
    'Salinidad': Colors.green,
  };

  Widget _construirGrafico(BuildContext context) {
    final datosFiltrados = _filtrarPorParametro(parametroSeleccionado);
    final color = coloresParametros[parametroSeleccionado] ?? Colors.blue;
    final valoresNormales = _obtenerValoresNormales(parametroSeleccionado);
    final spots = _obtenerSpots(datosFiltrados);
    final local = AppLocalizations.of(context)!;

    if (spots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(local.noDataToPlot),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.5,
          child: LineChart(
            LineChartData(
              minY: 0,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: color.withOpacity(0.8),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final fecha = DateFormat('MM/dd')
                          .format(datosFiltrados[spot.x.toInt()].fecha);
                      return LineTooltipItem(
                        '$fecha\n${spot.y.toStringAsFixed(2)}',
                        const TextStyle(color: Colors.white),
                      );
                    }).toList();
                  },
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  axisNameWidget: Text(local.fecha),
                  axisNameSize: 30,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();
                      if (index >= 0 && index < datosFiltrados.length) {
                        return Text(
                          DateFormat('MM/dd')
                              .format(datosFiltrados[index].fecha),
                          style: const TextStyle(fontSize: 10),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  axisNameWidget: Text(local.valor),
                  axisNameSize: 30,
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                ),
              ),
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  barWidth: 3,
                  color: color,
                  dotData: FlDotData(show: true),
                ),
                ...valoresNormales.map((limite) =>
                    LineChartBarData(
                      spots: List.generate(
                          spots.length, (i) => FlSpot(i.toDouble(), limite)),
                      isCurved: false,
                      barWidth: 1,
                      color: Colors.green,
                      dashArray: [5, 5],
                      dotData: FlDotData(show: false),
                    )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          local.valorIdeal(valoresNormales[0], valoresNormales[1]),
          style: const TextStyle(color: Colors.green, fontSize: 16),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final esAguaSalada = Provider
        .of<SettingsController>(context)
        .esAguaSalada;

    final mapaParametros = {
      'Cloro libre': local.cloroLibre,
      'Cloro combinado': local.cloroCombinado,
      'pH': local.ph,
      'Alcalinidad': local.alcalinidad,
      'CYA': local.cya,
      'Dureza': local.dureza,
      if (esAguaSalada) 'Salinidad': local.salinidad,
      // ✅ solo si es agua salada
    };

    // Si el parámetro actual seleccionado ya no está disponible (ej. salinidad en agua sin sal), cambiarlo
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
                setState(() {
                  parametroSeleccionado = nuevo!;
                });
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