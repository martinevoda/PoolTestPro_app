import 'package:add_2_calendar/add_2_calendar.dart';

class CalendarUtils {
  static Future<void> agregarEvento({
    required String titulo,
    required String descripcion,
    required DateTime fecha,
  }) async {
    final evento = Event(
      title: titulo,
      description: descripcion,
      location: 'Piscina de tu casa 🏡',
      startDate: fecha,
      endDate: fecha.add(const Duration(hours: 1)),
      allDay: false,
      iosParams: const IOSParams(reminder: Duration(minutes: 30)),
      androidParams: const AndroidParams(emailInvites: []),
    );

    await Add2Calendar.addEvent2Cal(evento);
  }
}