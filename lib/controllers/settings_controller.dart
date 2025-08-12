import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  String _idioma = 'en'; // Ingles por defecto
  String _unidadSistema = 'imperial'; // 'imperial' o 'metrico'
  bool _esAguaSalada = true; // ✅ Por defecto es pileta con sal

  // === [1.1] NUEVO: porcentaje de cloro líquido guardado en ajustes ===
  double _porcentajeCloroLiquido = 12.5; // NEW: 12.5% por defecto (pool shock)
  double get porcentajeCloroLiquido => _porcentajeCloroLiquido; // NEW

  ThemeMode get themeMode => _themeMode;
  String get idioma => _idioma;
  String get unidadSistema => _unidadSistema;
  bool get esAguaSalada => _esAguaSalada; // ✅ getter nuevo
  Locale get locale => Locale(_idioma);

  /// ✅ Carga las preferencias guardadas al iniciar la app
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final savedTheme = prefs.getString('themeMode');
    final savedIdioma = prefs.getString('idioma');
    final savedUnidad = prefs.getString('unidad_sistema');
    final savedTipoPileta = prefs.getBool('tipo_pileta_salada'); // ✅ nueva clave

    // === [1.2] NUEVO: leer % cloro líquido si existe ===
    final savedPorcCloro = prefs.getDouble('porcentaje_cloro_liquido'); // NEW

    if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }

    if (savedIdioma != null && (savedIdioma == 'es' || savedIdioma == 'en')) {
      _idioma = savedIdioma;
    }

    if (savedUnidad != null && (savedUnidad == 'imperial' || savedUnidad == 'metrico')) {
      _unidadSistema = savedUnidad;
    }

    if (savedTipoPileta != null) {
      _esAguaSalada = savedTipoPileta;
    }

    // === [1.2] NUEVO: aplicar el valor leído del % de cloro ===
    if (savedPorcCloro != null) {           // NEW
      _porcentajeCloroLiquido = savedPorcCloro; // NEW
    }                                       // NEW

    notifyListeners();
  }

  /// Cambia el modo claro/oscuro desde ajustes_screen.dart
  void updateThemeMode(ThemeMode newThemeMode) async {
    _themeMode = newThemeMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', newThemeMode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  /// Cambia el idioma desde ajustes_screen.dart
  void updateLocale(Locale newLocale) async {
    _idioma = newLocale.languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('idioma', _idioma);
    notifyListeners();
  }

  /// Cambia el sistema de unidades (imperial o métrico)
  void updateUnidadSistema(String nuevaUnidad) async {
    _unidadSistema = nuevaUnidad;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('unidad_sistema', nuevaUnidad);
    notifyListeners();
  }

  /// ✅ Cambia el tipo de pileta: true = con sal, false = sin sal
  void setTipoPileta(bool nuevaOpcion) async {
    _esAguaSalada = nuevaOpcion;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tipo_pileta_salada', nuevaOpcion);
    notifyListeners();
  }

  // === [1.3] NUEVO: setter para % de cloro líquido ===
  Future<void> setPorcentajeCloroLiquido(double v) async { // NEW
    _porcentajeCloroLiquido = v;                            // NEW
    final prefs = await SharedPreferences.getInstance();    // NEW
    await prefs.setDouble('porcentaje_cloro_liquido', v);   // NEW
    notifyListeners();                                      // NEW
  }                                                         // NEW

  /// Versión anterior de modo oscuro (opcional)
  void toggleModoOscuro(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  /// Versión anterior de idioma (opcional)
  void setIdioma(String nuevoIdioma) {
    _idioma = nuevoIdioma;
    notifyListeners();
  }

  /// ✅ Borra todos los registros guardados
  Future<void> resetAllData(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('registros');
    await prefs.remove('test_individual');
    await prefs.remove('test_registros');
    await prefs.remove('modo_tecnico');
    // Nota: NO borramos 'porcentaje_cloro_liquido' aquí.

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Datos reiniciados correctamente.')),
    );
    notifyListeners();
  }

  /// ✅ Borra solo los registros de gráficos
  Future<void> resetCharts(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('test_registros');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('📊 Gráficos reiniciados correctamente.')),
    );
    notifyListeners();
  }
}
