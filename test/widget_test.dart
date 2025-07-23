import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piscina_app/main.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:piscina_app/controllers/settings_controller.dart';

void main() {
  testWidgets('App test básico', (WidgetTester tester) async {
    final settingsController = SettingsController();
    await settingsController.loadSettings();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settingsController,
        child: const PiscinaApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
