import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  String _idioma = 'es'; // Español por defecto

  ThemeMode get themeMode => _themeMode;
  String get idioma => _idioma;
  Locale get locale => Locale(_idioma);

  /// ✅ Carga las preferencias guardadas al iniciar la app
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final savedTheme = prefs.getString('themeMode');
    final savedIdioma = prefs.getString('idioma');

    if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }

    if (savedIdioma != null && (savedIdioma == 'es' || savedIdioma == 'en')) {
      _idioma = savedIdioma;
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

  /// Borrar todos los datos
  Future<void> resetAllData(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Todos los datos han sido borrados.')),
    );
  }

  /// Borrar solo los registros de los gráficos
  Future<void> resetCharts(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('test_registros');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📊 Gráficos reiniciados.')),
    );
  }
}
