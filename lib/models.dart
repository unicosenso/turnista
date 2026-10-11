// Modelli dati e logica pura (niente Flutter qui dentro).

/// Orario "HH:MM" in minuti dalla mezzanotte.
int parseHm(String hm) {
  final parts = hm.split(':');
  if (parts.length != 2) return 0;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  final v = h * 60 + m;
  if (v < 0) return 0;
  if (v > 24 * 60 - 1) return 24 * 60 - 1;
  return v;
}

String formatHm(int minutes) {
  final m = ((minutes % (24 * 60)) + 24 * 60) % (24 * 60);
  final h = m ~/ 60;
  final mm = m % 60;
  return '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
}

String two(int n) => n.toString().padLeft(2, '0');

/// Chiave di un giorno: "aaaa-mm-gg".
String dayKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime? parseDayKey(String? key) {
  if (key == null) return null;
  final p = key.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// Giorni di calendario tra due date (senza problemi di ora legale).
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// Durata "1 h 15 min".
String formatDuration(int minutes) {
  if (minutes <= 0) return '0 min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}

class ShiftType {
  String id;
  String code; // sigla breve mostrata nel badge, es. "M"
  String name; // es. "Mattina"
  int color; // ARGB
  bool isRest; // riposo / giorno libero: niente orari e niente sveglia
  String start; // "HH:MM"
  String end; // "HH:MM" (se <= inizio, finisce il giorno dopo)
  bool alarm; // sveglia attiva per questo tipo
  int alarmOffset; // minuti prima dell'inizio

  ShiftType({
    required this.id,
    required this.code,
    required this.name,
    required this.color,
    this.isRest = false,
    this.start = '06:00',
    this.end = '14:00',
    this.alarm = true,
    this.alarmOffset = 60,
  });

  /// Durata in minuti con orari dati (gestisce il turno a cavallo della mezzanotte).
  static int durationOf(String start, String end) {
    final s = parseHm(start);
    var e = parseHm(end);
    if (e <= s) e += 24 * 60;
    return e - s;
  }

  int get durationMinutes => isRest ? 0 : durationOf(start, end);

  /// Turno di notte: inizia dalle 20 in poi oppure finisce il giorno dopo.
  bool get isNight {
    if (isRest) return false;
    return parseHm(start) >= 20 * 60 || parseHm(end) <= parseHm(start);
  }

  ShiftType copy() => ShiftType.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'color': color,
        'isRest': isRest,
        'start': start,
        'end': end,
        'alarm': alarm,
        'alarmOffset': alarmOffset,
      };

  factory ShiftType.fromJson(Map<String, dynamic> j) => ShiftType(
        id: j['id'] as String,
        code: (j['code'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        color: (j['color'] ?? 0xFF0F6E63) as int,
        isRest: (j['isRest'] ?? false) as bool,
        start: (j['start'] ?? '06:00') as String,
        end: (j['end'] ?? '14:00') as String,
        alarm: (j['alarm'] ?? true) as bool,
        alarmOffset: (j['alarmOffset'] ?? 60) as int,
      );
}

/// Modifica di un singolo giorno rispetto alla rotazione.
class DayOverride {
  /// null = segui la rotazione; [noShift] = nessun turno; altrimenti id del tipo.
  String? typeId;
  String? start; // orario personalizzato per quel giorno
  String? end;
  bool skipAlarm;
  String note;

  static const String noShift = '_none';

  DayOverride({this.typeId, this.start, this.end, this.skipAlarm = false, this.note = ''});

  bool get isEmpty =>
      typeId == null && start == null && end == null && !skipAlarm && note.trim().isEmpty;

  Map<String, dynamic> toJson() => {
        if (typeId != null) 'typeId': typeId,
        if (start != null) 'start': start,
        if (end != null) 'end': end,
        if (skipAlarm) 'skipAlarm': true,
        if (note.trim().isNotEmpty) 'note': note,
      };

  factory DayOverride.fromJson(Map<String, dynamic> j) => DayOverride(
        typeId: j['typeId'] as String?,
        start: j['start'] as String?,
        end: j['end'] as String?,
        skipAlarm: (j['skipAlarm'] ?? false) as bool,
        note: (j['note'] ?? '') as String,
      );
}

/// Il turno "risolto" di un giorno, pronto da mostrare.
class DayShift {
  final DateTime date;
  final ShiftType? type; // null = nessun turno
  final String? start;
  final String? end;
  final bool fromOverride; // il giorno è stato modificato a mano
  final bool skipAlarm;
  final String note;

  DayShift({
    required this.date,
    required this.type,
    this.start,
    this.end,
    this.fromOverride = false,
    this.skipAlarm = false,
    this.note = '',
  });

  bool get isWork => type != null && !type!.isRest;

  int get durationMinutes {
    if (!isWork || start == null || end == null) return 0;
    return ShiftType.durationOf(start!, end!);
  }

  String get timesLabel => isWork && start != null && end != null ? '$start–$end' : '';
}

class AlarmEntry {
  final DateTime at;
  final DayShift shift;
  AlarmEntry(this.at, this.shift);
}

class Settings {
  String name;
  bool alarmsEnabled;
  int snoozeMinutes;
  bool vibrate;
  bool setupDone;

  Settings({
    this.name = '',
    this.alarmsEnabled = true,
    this.snoozeMinutes = 10,
    this.vibrate = true,
    this.setupDone = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'alarmsEnabled': alarmsEnabled,
        'snoozeMinutes': snoozeMinutes,
        'vibrate': vibrate,
        'setupDone': setupDone,
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        name: (j['name'] ?? '') as String,
        alarmsEnabled: (j['alarmsEnabled'] ?? true) as bool,
        snoozeMinutes: (j['snoozeMinutes'] ?? 10) as int,
        vibrate: (j['vibrate'] ?? true) as bool,
        setupDone: (j['setupDone'] ?? false) as bool,
      );
}

/// Tutti i dati dell'app.
class AppData {
  List<ShiftType> types;
  List<String?> rotation; // id del tipo per ogni posizione (null = nessun turno)
  DateTime? rotationStart; // giorno in cui parte la posizione 1
  Map<String, DayOverride> overrides;
  Settings settings;

  AppData({
    required this.types,
    required this.rotation,
    this.rotationStart,
    required this.overrides,
    required this.settings,
  });

  factory AppData.defaults() => AppData(
        types: [
          ShiftType(id: 't_m', code: 'M', name: 'Mattina', color: 0xFF1E88E5, start: '06:00', end: '14:00', alarmOffset: 60),
          ShiftType(id: 't_p', code: 'P', name: 'Pomeriggio', color: 0xFFF59E0B, start: '14:00', end: '22:00', alarmOffset: 90),
          ShiftType(id: 't_n', code: 'N', name: 'Notte', color: 0xFF7C3AED, start: '22:00', end: '06:00', alarmOffset: 60),
          ShiftType(id: 't_r', code: 'R', name: 'Riposo', color: 0xFF9AA19D, isRest: true, alarm: false),
        ],
        rotation: [],
        rotationStart: null,
        overrides: {},
        settings: Settings(),
      );

  ShiftType? typeById(String? id) {
    if (id == null) return null;
    for (final t in types) {
      if (t.id == id) return t;
    }
    return null;
  }

  bool get hasRotation => rotation.isNotEmpty && rotationStart != null;

  /// Tipo previsto dalla rotazione per quel giorno.
  ShiftType? rotationTypeFor(DateTime day) {
    if (!hasRotation) return null;
    final n = rotation.length;
    final diff = daysBetween(rotationStart!, day);
    final idx = ((diff % n) + n) % n;
    return typeById(rotation[idx]);
  }

  DayShift shiftFor(DateTime day) {
    final d = dateOnly(day);
    final ov = overrides[dayKey(d)];
    ShiftType? type;
    if (ov != null && ov.typeId != null) {
      type = ov.typeId == DayOverride.noShift ? null : typeById(ov.typeId);
    } else {
      type = rotationTypeFor(d);
    }
    String? start;
    String? end;
    if (type != null && !type.isRest) {
      start = ov?.start ?? type.start;
      end = ov?.end ?? type.end;
    }
    return DayShift(
      date: d,
      type: type,
      start: start,
      end: end,
      fromOverride: ov != null && !ov.isEmpty,
      skipAlarm: ov?.skipAlarm ?? false,
      note: ov?.note ?? '',
    );
  }

  /// Orario della sveglia per un giorno, oppure null.
  DateTime? alarmTimeFor(DayShift s) {
    if (!settings.alarmsEnabled) return null;
    final t = s.type;
    if (t == null || t.isRest || !t.alarm || s.skipAlarm || s.start == null) return null;
    final startMin = parseHm(s.start!);
    final begin = DateTime(s.date.year, s.date.month, s.date.day, startMin ~/ 60, startMin % 60);
    return begin.subtract(Duration(minutes: t.alarmOffset));
  }

  /// Sveglie future nei prossimi [days] giorni, in ordine.
  List<AlarmEntry> upcomingAlarms(DateTime now, {int days = 60}) {
    final out = <AlarmEntry>[];
    final today = dateOnly(now);
    // Si parte da ieri: un turno di oggi alle 00:30 con anticipo può avere la sveglia "ieri sera",
    // e un turno di domani può avere la sveglia oggi.
    for (var i = -1; i <= days; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      final s = shiftFor(day);
      final at = alarmTimeFor(s);
      if (at != null && at.isAfter(now)) out.add(AlarmEntry(at, s));
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'types': types.map((t) => t.toJson()).toList(),
        'rotation': rotation,
        'rotationStart': rotationStart == null ? null : dayKey(rotationStart!),
        'overrides': overrides.map((k, v) => MapEntry(k, v.toJson())),
        'settings': settings.toJson(),
      };

  factory AppData.fromJson(Map<String, dynamic> j) {
    final types = ((j['types'] ?? []) as List)
        .map((e) => ShiftType.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final rotation = ((j['rotation'] ?? []) as List).map((e) => e as String?).toList();
    final ovRaw = Map<String, dynamic>.from((j['overrides'] ?? {}) as Map);
    final overrides = ovRaw.map(
        (k, v) => MapEntry(k, DayOverride.fromJson(Map<String, dynamic>.from(v as Map))));
    return AppData(
      types: types,
      rotation: rotation,
      rotationStart: parseDayKey(j['rotationStart'] as String?),
      overrides: overrides,
      settings: Settings.fromJson(Map<String, dynamic>.from((j['settings'] ?? {}) as Map)),
    );
  }
}

/// Statistiche di un intervallo di giorni.
class PeriodStats {
  int workDays = 0;
  int restDays = 0;
  int emptyDays = 0;
  int nights = 0;
  int minutes = 0;
  final Map<String, int> countByType = {};
  final Map<String, int> minutesByType = {};
}

PeriodStats statsFor(AppData data, DateTime from, DateTime toInclusive) {
  final st = PeriodStats();
  var d = dateOnly(from);
  final last = dateOnly(toInclusive);
  while (!d.isAfter(last)) {
    final s = data.shiftFor(d);
    final t = s.type;
    if (t == null) {
      st.emptyDays++;
    } else if (t.isRest) {
      st.restDays++;
      st.countByType[t.id] = (st.countByType[t.id] ?? 0) + 1;
    } else {
      st.workDays++;
      final m = s.durationMinutes;
      st.minutes += m;
      if (t.isNight) st.nights++;
      st.countByType[t.id] = (st.countByType[t.id] ?? 0) + 1;
      st.minutesByType[t.id] = (st.minutesByType[t.id] ?? 0) + m;
    }
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return st;
}

const List<String> giorniLunghi = [
  'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'
];
const List<String> giorniBrevi = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
const List<String> mesi = [
  'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
  'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre'
];

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "Domenica 11 ottobre"
String longDate(DateTime d) => '${giorniLunghi[d.weekday - 1]} ${d.day} ${mesi[d.month - 1]}';

/// "Dom 11 ott"
String shortDate(DateTime d) =>
    '${giorniBrevi[d.weekday - 1]} ${d.day} ${mesi[d.month - 1].substring(0, 3)}';

String hmOf(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

/// "oggi", "domani" o "Lun 12 ott"
String relativeDay(DateTime d, DateTime now) {
  final diff = daysBetween(now, d);
  if (diff == 0) return 'oggi';
  if (diff == 1) return 'domani';
  if (diff == -1) return 'ieri';
  return shortDate(d);
}
