import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class StockService {
  static const List<String> productos = [
    'cloro_liquido',
    'acido_muriatico',
    'ph_increaser',
    'estabilizador',
    'alcalinidad',
    'dureza',
    'sal',
  ];

  static Map<String, double> _stockCache = {};

  static Future<Map<String, double>> getAllStock() async {
    final prefs = await SharedPreferences.getInstance();
    final stock = <String, double>{};

    for (final producto in productos) {
      stock[producto] = prefs.getDouble('stock_$producto') ?? 0.0;
    }

    _stockCache = stock;
    return stock;
  }

  static Future<void> setStock(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('stock_$key', value);
    _stockCache[key] = value;
  }

  static Future<void> registrarUso(String key, double cantidadUsada) async {
    final prefs = await SharedPreferences.getInstance();
    final actual = prefs.getDouble('stock_$key') ?? 0.0;
    final nuevo = (actual - cantidadUsada).clamp(0.0, double.infinity);
    await prefs.setDouble('stock_$key', nuevo);
    _stockCache[key] = nuevo;
  }

  static Future<bool> necesitaReabastecer(String key, double cantidadNecesaria) async {
    final prefs = await SharedPreferences.getInstance();
    final actual = prefs.getDouble('stock_$key') ?? 0.0;
    return actual < cantidadNecesaria;
  }

  static String sugerenciaReabastecimiento(String key, double cantidadNecesaria, BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final nombre = nombreProducto(key, context);
    final nombreCom = nombreComercial(key);
    return '⚠️ ${loc.reabastecerSugerido(nombre)}\n${loc.productoRecomendado(nombreCom)}\n${loc.cantidadRecomendada(': ${cantidadNecesaria.toStringAsFixed(1)}')}';
  }

  static String nombreProducto(String key, BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    switch (key) {
      case 'cloro_liquido':
        return loc.cloroLibreLabel + ' (desinfectante)';
      case 'acido_muriatico':
        return loc.ph + ' (ácido para bajar)';
      case 'ph_increaser':
        return loc.ph + ' (soda ash para subir)';
      case 'estabilizador':
        return loc.cya;
      case 'alcalinidad':
        return loc.alcalinidad;
      case 'dureza':
        return loc.dureza;
      case 'sal':
        return loc.salinidad;
      default:
        return key;
    }
  }

  static String nombreComercial(String key) {
    switch (key) {
      case 'cloro_liquido':
        return 'HTH Pool Care Liquid Chlorine';
      case 'acido_muriatico':
        return 'Klean Strip Green Muriatic Acid';
      case 'ph_increaser':
        return 'In The Swim pH Increaser (Sodium Carbonate)';
      case 'estabilizador':
        return 'Pool Mate Stabilizer & Conditioner';
      case 'alcalinidad':
        return 'In The Swim Alkalinity Increaser';
      case 'dureza':
        return 'In The Swim Calcium Hardness Increaser';
      case 'sal':
        return 'Morton Professional’s Choice Pool Salt';
      default:
        return '';
    }
  }

  static String formatoCantidad(double cantidad, String unidad) {
    switch (unidad) {
      case 'kg':
        final kilos = cantidad * 0.453592;
        return '${kilos.toStringAsFixed(2)} kg';
      case 'L':
        final litros = cantidad * 3.785;
        return '${litros.toStringAsFixed(2)} L';
      case 'gal':
        return '${cantidad.toStringAsFixed(2)} gal';
      default:
        return '${cantidad.toStringAsFixed(2)} lb';
    }
  }

  static Future<bool> esBajoStock(String key, double minimo) async {
    final prefs = await SharedPreferences.getInstance();
    final cantidad = prefs.getDouble('stock_$key') ?? 0.0;
    return cantidad < minimo;
  }

  static Future<bool> necesitaReabastecerUltimoUso(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final actual = prefs.getDouble('stock_$key') ?? 0.0;
    final ultimoUso = prefs.getDouble('uso_$key') ?? 0.0;
    return actual < ultimoUso;
  }

  static double? obtenerStock(String key) {
    final keyMap = {
      'Cloro libre': 'cloro_liquido',
      'pH': 'acido_muriatico',
      'pH bajo': 'ph_increaser',
      'Alcalinidad': 'alcalinidad',
      'CYA': 'estabilizador',
      'Dureza': 'dureza',
      'Salinidad': 'sal',
    };
    final mappedKey = keyMap[key];
    if (mappedKey == null) return 0.0;
    return _stockCache[mappedKey] ?? 0.0;
  }

  static double? estimarCantidadNecesaria(String producto) {
    final estimaciones = {
      'cloro_liquido': 1.5,
      'acido_muriatico': 1.0,
      'ph_increaser': 1.0,
      'estabilizador': 4.0,
      'alcalinidad': 5.0,
      'dureza': 6.0,
      'sal': 40.0,
    };

    return estimaciones[producto];
  }

  // ✅ Método agregado
  static double obtenerStockSeguro(String key) {
    return _stockCache[key] ?? 0.0;
  }
}
