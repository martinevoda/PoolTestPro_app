import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:piscina_app/controllers/settings_controller.dart';
import 'package:piscina_app/pages/test_individual.dart';
import 'package:piscina_app/pages/registros_anteriores.dart';
import 'package:piscina_app/pages/grafico_parametro.dart';
import 'package:piscina_app/pages/ajustes_screen.dart';
import 'package:piscina_app/pages/historial_mantenimiento.dart';
import 'package:piscina_app/utils/notification_service.dart';
import 'package:piscina_app/utils/registro_loader.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:piscina_app/pages/pantalla_stock.dart';
import 'package:piscina_app/pages/tutorial_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dev/dev_calculator_smoke_page.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;




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
      title: 'PoolTest Pro',
      debugShowCheckedModeBanner: false,
      themeMode: settingsController.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      // 👇 Aquí se agrega la ruta de debug
      routes: {
        // Visible en Debug y Profile; oculto en Release
        if (!kReleaseMode) '/dev/smoke': (_) => const DevCalculatorSmokePage(),
      },
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _modoTecnico = false;

  @override
  void initState() {
    super.initState();
    _cargarModoTecnico();
  }

  Future<void> _cargarModoTecnico() async {
    final prefs = await SharedPreferences.getInstance();
    final valor = prefs.getBool('modo_tecnico') ?? false;
    setState(() {
      _modoTecnico = valor;
    });
  }


  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB3E5FC), Color(0xFFE1F5FE)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('PoolTest Pro'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildMenuButton(
              context,
              icon: Icons.tune,
              label: local.testIndividual,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TestIndividualScreen()),
              ),
            ),
            _buildMenuButton(
              context,
              icon: Icons.list,
              label: local.verRegistrosAnteriores,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegistrosAnterioresPage()),
              ),
            ),
            _buildMenuButton(
              context,
              icon: Icons.show_chart,
              label: local.verGraficoParametro,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GraficoParametroPage()),
              ),
            ),
            _buildMenuButton(
              context,
              icon: Icons.cleaning_services,
              label: local.historialMantenimiento,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistorialMantenimientoScreen()),
              ),
            ),
            _buildMenuButton(
              context,
              icon: Icons.inventory,
              label: AppLocalizations.of(context)!.stockProductos,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PantallaStock()),
              ),
            ),
            _buildMenuButton(
              context,
              icon: Icons.settings,
              label: local.settings,
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AjustesScreen()),
                );
                _cargarModoTecnico(); // 🔁 recarga real al volver
              },
            ),
            _buildMenuButton(
              context,
              icon: Icons.school,
              label: local.tutorialTitle,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TutorialScreen()),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context,
      {required IconData icon, required String label, required VoidCallback onPressed}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Icon(icon, size: 32, color: theme.colorScheme.primary),
        title: Text(label, style: theme.textTheme.titleMedium),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onPressed,
      ),
    );
  }
}


