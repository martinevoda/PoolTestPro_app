import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  String _idioma = 'es'; // Español por defecto
  String _unidadSistema = 'imperial'; // 'imperial' o 'metrico'

  ThemeMode get themeMode => _themeMode;
  String get idioma => _idioma;
  String get unidadSistema => _unidadSistema;
  Locale get locale => Locale(_idioma);

  /// ✅ Carga las preferencias guardadas al iniciar la app
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final savedTheme = prefs.getString('themeMode');
    final savedIdioma = prefs.getString('idioma');
    final savedUnidad = prefs.getString('unidad_sistema');

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
