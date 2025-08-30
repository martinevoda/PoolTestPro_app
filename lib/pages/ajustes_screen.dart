import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:piscina_app/controllers/settings_controller.dart';
import 'package:piscina_app/utils/notification_service.dart';
import 'package:piscina_app/utils/mantenimiento_fisico.dart';
import 'package:piscina_app/utils/calendar_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final TextEditingController _volumenController = TextEditingController();
  final double _volumenPorDefectoGalones = 13000;

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
      _diaSemanaSeleccionado =
          prefs.getInt('dia_semana_recordatorio') ?? DateTime.friday;
    });
  }

  Future<void> _cargarVolumen() async {
    final prefs = await SharedPreferences.getInstance();
    final volumen = prefs.getDouble('volumen_piscina');
    final settingsController =
    Provider.of<SettingsController>(context, listen: false);
    final esMetrico = settingsController.unidadSistema == 'metrico';
    final volumenMostrar = volumen ?? _volumenPorDefectoGalones;
    _volumenController.text = esMetrico
        ? (volumenMostrar * 3.785).toStringAsFixed(0)
        : volumenMostrar.toStringAsFixed(0);
  }

  Future<void> _guardarVolumen(String unidadSistema) async {
    final prefs = await SharedPreferences.getInstance();
    final input = double.tryParse(_volumenController.text.trim());
    if (input != null) {
      final volumenGalones =
      unidadSistema == 'metrico' ? input / 3.785 : input;
      await prefs.setDouble('volumen_piscina', volumenGalones);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.volumenGuardado)),
        );
      }
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
    }
    return '';
  }

  // ----------------------------
  // Acciones de reseteo
  // ----------------------------

  /// SOLO gráficos: elimina la fuente estandarizada para los charts.
  Future<void> _resetGraphsOnly() async {
    final prefs = await SharedPreferences.getInstance();

    // Fuente de datos de gráficos
    await prefs.remove('test_registros');

    // (Opcional) caches por parámetro si existen en tu app:
    // await prefs.remove('grafico_cache_fc');
    // await prefs.remove('grafico_cache_ph');
    // await prefs.remove('grafico_cache_alk');
    // await prefs.remove('grafico_cache_cya');
    // await prefs.remove('grafico_cache_ch');
    // await prefs.remove('grafico_cache_salt');

    if (context.mounted) {
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.resetGraphsSuccess)),
      );
    }
  }

  /// Reset TOTAL: historial, gráficos, volumen, mantenimiento, recordatorios, preferencias.
  Future<void> _resetAllData(SettingsController settingsController) async {
    final prefs = await SharedPreferences.getInstance();

    // Historial y gráficos
    await prefs.remove('registros');        // historial visible
    await prefs.remove('test_completo');    // por si lo usas
    await prefs.remove('test_individual');  // por si lo usas
    await prefs.remove('test_registros');   // charts

    // Mantenimiento
    await prefs.remove('limpieza_filtro');
    await prefs.remove('limpieza_celda');

    // Preferencias
    await prefs.remove('volumen_piscina');
    await prefs.remove('recordatorio_mensual');
    await prefs.remove('recordatorio_semanal');
    await prefs.remove('dia_semana_recordatorio');
    await prefs.remove('dia_mes_recordatorio');

    // Ajustes (según tu SettingsController)
    await prefs.remove('unidadSistema');
    await prefs.remove('esAguaSalada');
    await prefs.remove('locale');
    await prefs.remove('themeMode');
    await prefs.remove('porcentajeCloroLiquido');

    // (Opcional) caches gráficos
    // await prefs.remove('grafico_cache_*');

    // Notificaciones
    await NotificationService.cancelNotification(1); // semanal
    await NotificationService.cancelNotification(2); // mensual

    // Estado local
    setState(() {
      _mensualActivado = false;
      _semanalActivado = false;
      _diaMesSeleccionado = 1;
      _diaSemanaSeleccionado = DateTime.friday;
    });

    // Defaults razonables en SettingsController
    settingsController.setTipoPileta(false); // agua dulce
    settingsController.updateUnidadSistema('imperial');
    settingsController.setPorcentajeCloroLiquido(12.5);
    settingsController.updateThemeMode(ThemeMode.light);
    // Idioma lo dejamos según tu flujo (no lo forzamos)

    if (context.mounted) {
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.borradoExitoso)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final settings = Provider.of<SettingsController>(context);
    final esMetrico = settings.unidadSistema == 'metrico';

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tipo de pileta
          SwitchListTile(
            title: Text(l.poolTypeLabel),
            subtitle:
            Text(settings.esAguaSalada ? l.poolTypeSalt : l.poolTypeFresh),
            value: settings.esAguaSalada,
            onChanged: (value) {
              settings.setTipoPileta(value);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    value ? l.poolTypeSaltSelected : l.poolTypeFreshSelected,
                  ),
                ),
              );
            },
          ),

          // Volumen
          TextField(
            controller: _volumenController,
            keyboardType:
            const TextInputType.numberWithOptions(decimal: false),
            decoration: InputDecoration(
              labelText: l.poolVolumeLabel,
              suffixText: esMetrico ? l.unidadLitro : l.unidadGalon,
            ),
            onSubmitted: (_) => _guardarVolumen(settings.unidadSistema),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => _guardarVolumen(settings.unidadSistema),
            child: Text(l.saveVolumeButton),
          ),

          const Divider(),

          // % Cloro líquido
          DropdownButtonFormField<double>(
            value: settings.porcentajeCloroLiquido,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Cloro líquido (% NaOCl)',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 10.0, child: Text('10%')),
              DropdownMenuItem(value: 12.5, child: Text('12.5% (pool shock)')),
            ],
            onChanged: (v) {
              if (v != null) {
                settings.setPorcentajeCloroLiquido(v);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Concentración guardada: $v%')),
                );
              }
            },
          ),

          // Sistema de unidades
          ListTile(
            title: Text(l.unitSystem),
            trailing: DropdownButton<String>(
              value: settings.unidadSistema,
              onChanged: (value) {
                if (value != null) {
                  settings.updateUnidadSistema(value);
                  _cargarVolumen();
                }
              },
              items: [
                DropdownMenuItem(value: 'imperial', child: Text(l.imperialLabel)),
                DropdownMenuItem(value: 'metrico', child: Text(l.metricLabel)),
              ],
            ),
          ),

          const Divider(),

          // Recordatorio semanal
          DropdownButtonFormField<int>(
            value: _diaSemanaSeleccionado,
            decoration: InputDecoration(labelText: l.selectWeekday),
            items: List.generate(7, (i) {
              final weekday = i + 1;
              return DropdownMenuItem(
                value: weekday,
                child: Text(_weekdayLabel(weekday, l)),
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
            title: Text(
                '${l.activateWeeklyReminder} (${_weekdayLabel(_diaSemanaSeleccionado, l)})'),
            subtitle: Text(l.reminderDescription),
            trailing: Icon(
              Icons.notifications_active,
              color: _semanalActivado ? Colors.blue : Colors.black,
            ),
            onTap: () async => await _activarRecordatorioSemanal(l),
          ),

          const Divider(),

          // Recordatorio mensual
          DropdownButtonFormField<int>(
            value: _diaMesSeleccionado,
            decoration: InputDecoration(labelText: l.selectMonthDay),
            items: List.generate(
              28,
                  (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
            ),
            onChanged: (value) async {
              if (value != null) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('dia_mes_recordatorio', value);
                setState(() => _diaMesSeleccionado = value);
              }
            },
          ),
          ListTile(
            title: Text('${l.activateMonthlyReminder} (${l.day} $_diaMesSeleccionado)'),
            subtitle: Text(l.monthlyReminderDescription),
            trailing: Icon(
              _mensualActivado ? Icons.event_available : Icons.event_note,
              color: _mensualActivado ? Colors.blue : Colors.black,
            ),
            onTap: () async => await _activarRecordatorioMensual(l),
          ),

          const Divider(),

          // Mantenimiento filtro
          ListTile(
            title: Text(l.registerFilterCleaning),
            subtitle: Text(l.filterSubtitle),
            trailing: const Icon(Icons.cleaning_services),
            onTap: () async {
              await MantenimientoFisico.registrarLimpieza('filtro');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.filterCleaningSaved)),
                );
              }
            },
          ),
          ListTile(
            title: Text(l.scheduleFilterCleaningCalendar),
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
                  titulo: l.filterCleaningTitle,
                  descripcion: l.filterCleaningDescription,
                  fecha: selectedDate,
                );
              }
            },
          ),

          const Divider(),

          // Mantenimiento celda
          ListTile(
            title: Text(l.registerCellCleaning),
            subtitle: Text(l.cellSubtitle),
            trailing: const Icon(Icons.flash_on),
            onTap: () async {
              await MantenimientoFisico.registrarLimpieza('celda');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.cellCleaningSaved)),
                );
              }
            },
          ),
          ListTile(
            title: Text(l.scheduleCellCleaningCalendar),
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
                  titulo: l.cellCleaningTitle,
                  descripcion: l.cellCleaningDescription,
                  fecha: selectedDate,
                );
              }
            },
          ),

          const Divider(),

          // Tema
          SwitchListTile(
            title: Text(l.darkMode),
            value: settings.themeMode == ThemeMode.dark,
            onChanged: (value) {
              settings.updateThemeMode(value ? ThemeMode.dark : ThemeMode.light);
            },
          ),

          // Idioma
          ListTile(
            title: Text(l.language),
            trailing: DropdownButton<Locale>(
              value: settings.locale,
              onChanged: (newLocale) {
                if (newLocale != null) {
                  settings.updateLocale(newLocale);
                }
              },
              items: const [
                DropdownMenuItem(value: Locale('es'), child: Text('Español')),
                DropdownMenuItem(value: Locale('en'), child: Text('English')),
              ],
            ),
          ),

          const Divider(),

          // Reset total
          ListTile(
            title: Text(l.resetAll),
            trailing: const Icon(Icons.delete_forever),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(l.confirmResetTitle),
                  content: Text(l.confirmResetContent),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l.confirm),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _resetAllData(settings);
              }
            },
          ),

          // Reset solo gráficos
          ListTile(
            title: Text(l.resetGraphs),
            trailing: const Icon(Icons.show_chart),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(l.confirmResetTitle),
                  content: Text(l.confirmResetGraphsContent),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l.confirm),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _resetGraphsOnly();
              }
            },
          ),

          const Divider(),

          // Legal
          ListTile(
            title: Text(l.legalInfo),
            subtitle: Text(l.legalNowInTutorial),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l.legalInTutorialMessage),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _activarRecordatorioMensual(AppLocalizations l) async {
    final prefs = await SharedPreferences.getInstance();
    if (_mensualActivado) {
      await NotificationService.cancelNotification(2);
      await prefs.setBool('recordatorio_mensual', false);
      setState(() => _mensualActivado = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.monthlyReminderDeactivated)),
        );
      }
    } else {
      final now = DateTime.now();
      final proximo = DateTime(now.year, now.month + 1, _diaMesSeleccionado, 9);
      await NotificationService.scheduleMonthlyNotification(
        id: 2,
        title: '📅 ${l.monthlyReminderTitle}',
        body: l.monthlyReminderBody,
        scheduledTime: proximo,
      );
      await prefs.setBool('recordatorio_mensual', true);
      setState(() => _mensualActivado = true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.monthlyReminderActivated)),
        );
      }
    }
  }

  Future<void> _activarRecordatorioSemanal(AppLocalizations l) async {
    final prefs = await SharedPreferences.getInstance();
    if (_semanalActivado) {
      await NotificationService.cancelNotification(1);
      await prefs.setBool('recordatorio_semanal', false);
      setState(() => _semanalActivado = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.reminderDeactivated)),
        );
      }
    } else {
      final now = DateTime.now();
      final daysToAdd = (_diaSemanaSeleccionado - now.weekday + 7) % 7;
      final nextScheduled = now.add(Duration(days: daysToAdd));
      final reminderTime =
      DateTime(nextScheduled.year, nextScheduled.month, nextScheduled.day, 9);
      await NotificationService.scheduleWeeklyNotification(
        id: 1,
        title: '🧪 ${l.testReminderTitle}',
        body: l.testReminderBody,
        scheduledTime: reminderTime,
      );
      await prefs.setBool('recordatorio_semanal', true);
      setState(() => _semanalActivado = true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.reminderActivated)),
        );
      }
    }
  }
}
