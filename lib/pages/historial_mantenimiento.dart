import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class HistorialMantenimientoScreen extends StatefulWidget {
  const HistorialMantenimientoScreen({Key? key}) : super(key: key);

  @override
  State<HistorialMantenimientoScreen> createState() => _HistorialMantenimientoScreenState();
}

class _HistorialMantenimientoScreenState extends State<HistorialMantenimientoScreen> {
  List<String> limpiezaFiltro = [];
  List<String> limpiezaCelda = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      cargarHistorial();
    });
  }

  Future<void> cargarHistorial() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      limpiezaFiltro = prefs.getStringList('limpieza_filtro') ?? [];
      limpiezaCelda = prefs.getStringList('limpieza_celda') ?? [];
    });
  }

  Future<void> eliminarRegistro(String tipo, int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (tipo == 'filtro' && index < limpiezaFiltro.length) {
        limpiezaFiltro.removeAt(index);
        prefs.setStringList('limpieza_filtro', limpiezaFiltro);
      } else if (tipo == 'celda' && index < limpiezaCelda.length) {
        limpiezaCelda.removeAt(index);
        prefs.setStringList('limpieza_celda', limpiezaCelda);
      }
    });
  }

  Widget _buildSeccion(String titulo, List<String> datos, String tipo, AppLocalizations localizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        if (datos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(localizations.noRecordsYet),
          ),
        ...datos.asMap().entries.map((entry) {
          final index = entry.key;
          final fecha = entry.value;
          return ListTile(
            leading: const Icon(Icons.cleaning_services),
            title: Text(fecha),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => eliminarRegistro(tipo, index),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.maintenanceHistory),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          _buildSeccion(
            localizations.filterCleaningSectionTitle,
            limpiezaFiltro,
            'filtro',
            localizations,
          ),
          const Divider(),
          _buildSeccion(
            localizations.cellCleaningSectionTitle,
            limpiezaCelda,
            'celda',
            localizations,
          ),
        ],
      ),
    );
  }
}
