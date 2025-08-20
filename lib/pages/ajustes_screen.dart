import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:piscina_app/controllers/settings_controller.dart';
import 'package:piscina_app/utils/notification_service.dart';
import 'package:piscina_app/utils/mantenimiento_fisico.dart';
import 'package:piscina_app/utils/calendar_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;




class AjustesScreen extends StatefulWidget {
  const AjustesScreen({Key? key}) : super(key: key);

  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  bool _mensualActivado = false;
  bool _semanalActivado = false;
  int _diaMesSeleccionado = 1;
  int _diaSemanaSeleccionado = DateTime.friday;
  TextEditingController _volumenController = TextEditingController();
  double _volumenPorDefectoGalones = 13000;

  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
    _cargarVolumen();
  }

  Future<void> _cargarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mensualActivado = prefs.getBool('recordatorio_mensual') ?? false;
      _semanalActivado = prefs.getBool('recordatorio_semanal') ?? false;
      _diaMesSeleccionado = prefs.getInt('dia_mes_recordatorio') ?? 1;
      _diaSemanaSeleccionado = prefs.getInt('dia_semana_recordatorio') ?? DateTime.friday;
    });
  }

  Future<void> _cargarVolumen() async {
    final prefs = await SharedPreferences.getInstance();
    double? volumen = prefs.getDouble('volumen_piscina');
    final settingsController = Provider.of<SettingsController>(context, listen: false);
    final esMetrico = settingsController.unidadSistema == 'metrico';
    final volumenMostrar = volumen ?? _volumenPorDefectoGalones;
    _volumenController.text = esMetrico
        ? (volumenMostrar * 3.785).toStringAsFixed(0)
        : volumenMostrar.toStringAsFixed(0);
  }

  Future<void> _guardarVolumen(String unidadSistema) async {
    final prefs = await SharedPreferences.getInstance();
    final input = double.tryParse(_volumenController.text);
    if (input != null) {
      double volumenGalones = unidadSistema == 'metrico' ? input / 3.785 : input;
      await prefs.setDouble('volumen_piscina', volumenGalones);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.volumenGuardado)),
      );
    }
  }

  String _weekdayLabel(int weekday, AppLocalizations loc) {
    switch (weekday) {
      case DateTime.monday:
        return loc.monday;
      case DateTime.tuesday:
        return loc.tuesday;
      case DateTime.wednesday:
        return loc.wednesday;
      case DateTime.thursday:
        return loc.thursday;
      case DateTime.friday:
        return loc.friday;
      case DateTime.saturday:
        return loc.saturday;
      case DateTime.sunday:
        return loc.sunday;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final settingsController = Provider.of<SettingsController>(context);
    final esMetrico = settingsController.unidadSistema == 'metrico';

    return Scaffold(
      appBar: AppBar(title: Text(localizations.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SwitchListTile(
            title: Text(localizations.poolTypeLabel),
            subtitle: Text(
              settingsController.esAguaSalada
                  ? localizations.poolTypeSalt
                  : localizations.poolTypeFresh,
            ),
            value: settingsController.esAguaSalada,
            onChanged: (value) {
              settingsController.setTipoPileta(value);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    value
                        ? localizations.poolTypeSaltSelected
                        : localizations.poolTypeFreshSelected,
                  ),
                ),
              );
            },
          ),

          TextField(
            controller: _volumenController,
            keyboardType: TextInputType.numberWithOptions(decimal: false),
            decoration: InputDecoration(
              labelText: localizations.poolVolumeLabel,
              suffixText: esMetrico ? localizations.unidadLitro : localizations.unidadGalon,
            ),
            onSubmitted: (_) => _guardarVolumen(settingsController.unidadSistema),
          ),



          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => _guardarVolumen(settingsController.unidadSistema),
            child: Text(localizations.saveVolumeButton),
          ),
          const Divider(),
          // ▼▼▼ NUEVO: selector % de cloro líquido ▼▼▼
          DropdownButtonFormField<double>(
            value: settingsController.porcentajeCloroLiquido, // viene del SettingsController
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Cloro líquido (% NaOCl)',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 10.0,  child: Text('10%')),
              DropdownMenuItem(value: 12.5, child: Text('12.5% (pool shock)')),
            ],
            onChanged: (v) {
              if (v != null) {
                settingsController.setPorcentajeCloroLiquido(v); // guarda en SharedPreferences y notifica
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Concentración guardada: $v%')),
                );
              }
            },
          ),
// ▲▲▲ FIN NUEVO ▲▲▲
          ListTile(
            title: Text(localizations.unitSystem),
            trailing: DropdownButton<String>(
              value: settingsController.unidadSistema,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  settingsController.updateUnidadSistema(newValue);
                  _cargarVolumen();
                }
              },
              items: [
                DropdownMenuItem(
                  value: 'imperial',
                  child: Text(localizations.imperialLabel),
                ),
                DropdownMenuItem(
                  value: 'metrico',
                  child: Text(localizations.metricLabel),
                ),
              ],
            ),
          ),
          const Divider(),


          DropdownButtonFormField<int>(
            value: _diaSemanaSeleccionado,
            decoration: InputDecoration(labelText: localizations.selectWeekday),
            items: List.generate(7, (i) {
              final weekday = i + 1;
              return DropdownMenuItem(
                value: weekday,
                child: Text(_weekdayLabel(weekday, localizations)),
              );
            }),
            onChanged: (value) async {
              if (value != null) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('dia_semana_recordatorio', value);
                setState(() => _diaSemanaSeleccionado = value);
              }
            },
          ),
          ListTile(
            title: Text('${localizations.activateWeeklyReminder} (${_weekdayLabel(_diaSemanaSeleccionado, localizations)})'),
            subtitle: Text(localizations.reminderDescription),
            trailing: Icon(
              Icons.notifications_active,
              color: _semanalActivado ? Colors.blue : Colors.black,
            ),
            onTap: () async => await _activarRecordatorioSemanal(localizations),
          ),
          const Divider(),
          DropdownButtonFormField<int>(
            value: _diaMesSeleccionado,
            decoration: InputDecoration(labelText: localizations.selectMonthDay),
            items: List.generate(28, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
            onChanged: (value) async {
              if (value != null) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('dia_mes_recordatorio', value);
                setState(() => _diaMesSeleccionado = value);
              }
            },
          ),
          ListTile(
            title: Text('${localizations.activateMonthlyReminder} (${localizations.day} $_diaMesSeleccionado)'),
            subtitle: Text(localizations.monthlyReminderDescription),
            trailing: Icon(
              _mensualActivado ? Icons.event_available : Icons.event_note,
              color: _mensualActivado ? Colors.blue : Colors.black,
            ),
            onTap: () async => await _activarRecordatorioMensual(localizations),
          ),
          const Divider(),
          ListTile(
            title: Text(localizations.registerFilterCleaning),
            subtitle: const Text('Filtro de cartucho Jandy CS'),
            trailing: const Icon(Icons.cleaning_services),
            onTap: () async {
              await MantenimientoFisico.registrarLimpieza('filtro');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localizations.filterCleaningSaved)),
              );
            },
          ),
          ListTile(
            title: Text(localizations.scheduleFilterCleaningCalendar),
            trailing: const Icon(Icons.event),
            onTap: () async {
              final now = DateTime.now();
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: now.add(const Duration(days: 30)),
                firstDate: now,
                lastDate: now.add(const Duration(days: 365)),
              );
              if (selectedDate != null) {
                await CalendarUtils.agregarEvento(
                  titulo: localizations.filterCleaningTitle,
                  descripcion: localizations.filterCleaningDescription,
                  fecha: selectedDate,
                );
              }
            },
          ),
          const Divider(),
          ListTile(
            title: Text(localizations.registerCellCleaning),
            subtitle: const Text('Jandy TruClear'),
            trailing: const Icon(Icons.flash_on),
            onTap: () async {
              await MantenimientoFisico.registrarLimpieza('celda');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localizations.cellCleaningSaved)),
              );
            },
          ),
          ListTile(
            title: Text(localizations.scheduleCellCleaningCalendar),
            trailing: const Icon(Icons.event_note),
            onTap: () async {
              final now = DateTime.now();
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: now.add(const Duration(days: 30)),
                firstDate: now,
                lastDate: now.add(const Duration(days: 365)),
              );
              if (selectedDate != null) {
                await CalendarUtils.agregarEvento(
                  titulo: localizations.cellCleaningTitle,
                  descripcion: localizations.cellCleaningDescription,
                  fecha: selectedDate,
                );
              }
            },
          ),
          const Divider(),
          SwitchListTile(
            title: Text(localizations.darkMode),
            value: settingsController.themeMode == ThemeMode.dark,
            onChanged: (value) {
              settingsController.updateThemeMode(value ? ThemeMode.dark : ThemeMode.light);
            },
          ),
          ListTile(
            title: Text(localizations.language),
            trailing: DropdownButton<Locale>(
              value: settingsController.locale,
              onChanged: (Locale? newLocale) {
                if (newLocale != null) {
                  settingsController.updateLocale(newLocale);
                }
              },
              items: const [
                DropdownMenuItem(value: Locale('es'), child: Text('Español')),
                DropdownMenuItem(value: Locale('en'), child: Text('English')),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            title: Text(localizations.resetAll),
            trailing: const Icon(Icons.delete_forever),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(localizations.confirmResetTitle),
                  content: Text(localizations.confirmResetContent),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(localizations.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(localizations.confirm),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('test_completo');
                await prefs.remove('test_individual');
                await prefs.remove('test_registros');
                await prefs.remove('limpieza_filtro');
                await prefs.remove('limpieza_celda');
                await prefs.remove('volumen_piscina');

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(localizations.borradoExitoso)),
                  );
                }
              }
            },
          ),
          ListTile(
            title: Text(localizations.resetGraphs),
            trailing: const Icon(Icons.show_chart),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(localizations.confirmResetTitle),
                  content: Text(localizations.confirmResetGraphsContent),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(localizations.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(localizations.confirm),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                settingsController.resetCharts(context);
              }
            },
          ),

          const Divider(),
          ListTile(
            title: Text(AppLocalizations.of(context)!.legalInfo),
            subtitle: Text(AppLocalizations.of(context)!.legalNowInTutorial),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.legalInTutorialMessage),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
          ),
          // 👇 Aquí el botón de debug
          if (!kReleaseMode)
            ListTile(
              title: const Text('Dev: Smoke test cálculos'),
              trailing: const Icon(Icons.science),
              onTap: () => Navigator.of(context).pushNamed('/dev/smoke'),
            ),
        ],
      ),
    );
  }

  Future<void> _activarRecordatorioMensual(AppLocalizations localizations) async {
    final prefs = await SharedPreferences.getInstance();
    if (_mensualActivado) {
      await NotificationService.cancelNotification(2);
      await prefs.setBool('recordatorio_mensual', false);
      setState(() => _mensualActivado = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(localizations.monthlyReminderDeactivated)));
    } else {
      final now = DateTime.now();
      final proximo = DateTime(now.year, now.month + 1, _diaMesSeleccionado, 9);
      await NotificationService.scheduleMonthlyNotification(
        id: 2,
        title: '📅 ${localizations.monthlyReminderTitle}',
        body: localizations.monthlyReminderBody,
        scheduledTime: proximo,
      );
      await prefs.setBool('recordatorio_mensual', true);
      setState(() => _mensualActivado = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(localizations.monthlyReminderActivated)));
    }
  }

  Future<void> _activarRecordatorioSemanal(AppLocalizations localizations) async {
    final prefs = await SharedPreferences.getInstance();
    if (_semanalActivado) {
      await NotificationService.cancelNotification(1);
      await prefs.setBool('recordatorio_semanal', false);
      setState(() => _semanalActivado = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(localizations.reminderDeactivated)));
    } else {
      final now = DateTime.now();
      final daysToAdd = (_diaSemanaSeleccionado - now.weekday + 7) % 7;
      final nextScheduled = now.add(Duration(days: daysToAdd));
      final reminderTime = DateTime(nextScheduled.year, nextScheduled.month, nextScheduled.day, 9);
      await NotificationService.scheduleWeeklyNotification(
        id: 1,
        title: '🧪 ${localizations.testReminderTitle}',
        body: localizations.testReminderBody,
        scheduledTime: reminderTime,
      );
      await prefs.setBool('recordatorio_semanal', true);
      setState(() => _semanalActivado = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(localizations.reminderActivated)));
    }
  }
}
