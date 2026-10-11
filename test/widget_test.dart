import 'package:flutter_test/flutter_test.dart';
import 'package:turnista/models.dart';

void main() {
  test('rotazione e sveglia', () {
    final d = AppData.defaults();
    d.settings.setupDone = true;
    d.rotation = ['t_m', 't_p', 't_r'];
    d.rotationStart = DateTime(2026, 10, 12);

    expect(d.shiftFor(DateTime(2026, 10, 12)).type?.code, 'M');
    expect(d.shiftFor(DateTime(2026, 10, 13)).type?.code, 'P');
    expect(d.shiftFor(DateTime(2026, 10, 14)).type?.code, 'R');
    expect(d.shiftFor(DateTime(2026, 10, 15)).type?.code, 'M');
    expect(d.shiftFor(DateTime(2026, 10, 11)).type?.code, 'R'); // giorno prima dell'inizio

    // Mattina 06:00, sveglia 60 min prima
    final at = d.alarmTimeFor(d.shiftFor(DateTime(2026, 10, 12)));
    expect(at, DateTime(2026, 10, 12, 5, 0));

    // modifica a mano con orario personalizzato
    d.overrides[dayKey(DateTime(2026, 10, 12))] = DayOverride(start: '04:30', end: '12:00');
    expect(d.alarmTimeFor(d.shiftFor(DateTime(2026, 10, 12))), DateTime(2026, 10, 12, 3, 30));

    // notte 22:00-06:00 = 8 ore
    expect(d.typeById('t_n')!.durationMinutes, 480);

    final alarms = d.upcomingAlarms(DateTime(2026, 10, 11, 12), days: 6);
    expect(alarms.first.at, DateTime(2026, 10, 12, 3, 30));
  });
}
