import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:piscina_app/controllers/settings_controller.dart';
import 'package:piscina_app/utils/stock_service.dart';

class PantallaStock extends StatefulWidget {
  const PantallaStock({Key? key}) : super(key: key);

  @override
  State<PantallaStock> createState() => _PantallaStockState();
}

class _PantallaStockState extends State<PantallaStock> {
  late Future<Map<String, double>> _stockFuture;

  @override
  void initState() {
    super.initState();
    _stockFuture = StockService.getAllStock();
  }

  void _editarStock(BuildContext context, String productoKey, double actual) {
    final loc = AppLocalizations.of(context)!;
    final settings = Provider.of<SettingsController>(context, listen: false);
    final controller = TextEditingController(text: actual.toStringAsFixed(2));

    showDialog<double>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(loc.editQuantity),
          content: Builder(
            builder: (context) {
              Future.delayed(Duration.zero, () {
                controller.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: controller.text.length,
                );
              });

              return TextField(
                controller: controller,
                autofocus: true,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.left,
                decoration: InputDecoration(labelText: loc.enterNewQuantity),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.cancel),
            ),
            TextButton(
              onPressed: () async {
                final value =
                double.tryParse(controller.text.replaceAll(',', '.'));
                if (value != null) {
                  await StockService.setStock(productoKey, value); // sumar
                  Navigator.pop(context);
                  setState(() {
                    _stockFuture = StockService.getAllStock();
                  });
                }
              },
              child: Text(loc.agregar),
            ),
            TextButton(
              onPressed: () async {
                final value =
                double.tryParse(controller.text.replaceAll(',', '.'));
                if (value != null) {
                  await StockService.reemplazarStock(productoKey, value); // reemplazar
                  Navigator.pop(context);
                  setState(() {
                    _stockFuture = StockService.getAllStock();
                  });
                }
              },
              child: Text(loc.reemplazar),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final settings = Provider.of<SettingsController>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.stockTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _stockFuture = StockService.getAllStock();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, double>>(
        future: _stockFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final stock = snapshot.data!;
          if (stock.isEmpty) {
            return Center(child: Text(loc.noStockData));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: stock.entries.map((entry) {
              final productoKey = entry.key;
              final cantidad = entry.value;
              final nombre = StockService.nombreProducto(productoKey, context);
              final comercial = StockService.nombreComercial(productoKey);
              final formatted = StockService.formatoCantidad(
                  cantidad, settings.unidadSistema);
              final unidad =
              settings.unidadSistema == 'imperial' ? 'lb' : 'kg';

              return FutureBuilder<bool>(
                future: StockService.esBajoStock(productoKey, 1.0),
                builder: (context, bajoSnapshot) {
                  final esBajo = bajoSnapshot.data == true;

                  return Card(
                    color: esBajo ? Colors.red[50] : null,
                    child: ListTile(
                      title: Text(nombre),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${loc.available}: $formatted $unidad'),
                          Text(
                            comercial,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          FutureBuilder<bool>(
                            future: StockService.necesitaReabastecerUltimoUso(
                                productoKey),
                            builder: (context, avisoSnapshot) {
                              if (avisoSnapshot.connectionState ==
                                  ConnectionState.done &&
                                  avisoSnapshot.data == true) {
                                return Text(
                                  '⚠️ ${loc.suggestReplenish}',
                                  style: const TextStyle(color: Colors.red),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (esBajo)
                            const Icon(Icons.warning_amber_rounded,
                                color: Colors.red),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () =>
                                _editarStock(context, productoKey, cantidad),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
