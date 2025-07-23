import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:piscina_app/controllers/settings_controller.dart';
import 'package:piscina_app/pages/test_completo.dart';
import 'package:piscina_app/pages/test_individual.dart';
import 'package:piscina_app/pages/registros_anteriores.dart';
import 'package:piscina_app/pages/grafico_parametro.dart';
import 'package:piscina_app/pages/ajustes_screen.dart';
import 'package:piscina_app/pages/historial_mantenimiento.dart'; // NUEVO
import 'package:piscina_app/utils/notification_service.dart';
import 'package:piscina_app/utils/registro_loader.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsController = SettingsController();
  await settingsController.loadSettings();

  await NotificationService.initialize();
  await verificarInactividadYNotificar();

  runApp(
    ChangeNotifierProvider.value(
      value: settingsController,
      child: const PiscinaApp(),
    ),
  );
}

Future<void> verificarInactividadYNotificar() async {
  final ultimaFecha = await obtenerFechaUltimoTest();
  if (ultimaFecha == null) return;

  final hoy = DateTime.now();
  final diferencia = hoy.difference(ultimaFecha).inDays;

  if (diferencia >= 7) {
    final scheduledTime = hoy.add(const Duration(minutes: 1));
    await NotificationService.scheduleWeeklyNotification(
      id: 99,
      title: '⚠️ Recordatorio de test',
      body: 'No se ha registrado ningún test en más de 7 días. ¡Haz un test hoy!',
      scheduledTime: scheduledTime,
    );
  }
}

class PiscinaApp extends StatelessWidget {
  const PiscinaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = Provider.of<SettingsController>(context);

    return MaterialApp(
      title: 'Mantenimiento Piscina',
      debugShowCheckedModeBanner: false,
      themeMode: settingsController.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      locale: settingsController.locale,
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text('🧪 ${local.title}'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TestCompletoPage()),
              );
            },
            child: Text('🧪 ${local.testCompleto}'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TestIndividualScreen()),
              );
            },
            child: Text('🧪 ${local.testIndividual}'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegistrosAnterioresPage()),
              );
            },
            child: Text('📄 ${local.verRegistrosAnteriores}'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GraficoParametroPage()),
              );
            },
            child: Text('📈 ${local.verGraficoParametro}'),
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistorialMantenimientoScreen()),
              );
            },
            child: Text(' ${local.historialMantenimiento}'),
          ),
          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AjustesScreen()),
              );
            },
            child: Text('⚙️ ${local.settings}'),
          ),
        ],
      ),
    );
  }
}
