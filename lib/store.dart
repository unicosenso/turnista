import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Ponte verso la sveglia nativa Android (vedi AlarmScheduler.kt).
class AlarmBridge {
  static const MethodChannel _ch = MethodChannel('turnista/alarm');

  static Future<void> schedule(List<AlarmEntry> alarms, Settings s) async {
    final list = alarms
        .map((a) => {
              'at': a.at.millisecondsSinceEpoch,
              'title': a.shift.type == null
                  ? 'Sveglia'
                  : 'Turno ${a.shift.type!.code} alle ${a.shift.start ?? ''}',
              'body': '${capitalize(longDate(a.shift.date))} · ${a.shift.timesLabel}',
            })
        .toList();
    try {
      await _ch.invokeMethod('schedule', {
        'alarms': jsonEncode(list),
        'snooze': s.snoozeMinutes,
        'vibrate': s.vibrate,
      });
    } catch (e) {
      debugPrint('Sveglia non programmata: $e');
    }
  }

  static Future<Map<String, bool>> permissions() async {
    try {
      final r = await _ch.invokeMethod('permissions');
      final m = Map<String, dynamic>.from(r as Map);
      return m.map((k, v) => MapEntry(k, v == true));
    } catch (_) {
      return {'notifications': true, 'exact': true, 'fullScreen': true};
    }
  }

  static Future<void> call(String method) async {
    try {
      await _ch.invokeMethod(method);
    } catch (e) {
      debugPrint('$method: $e');
    }
  }

  static Future<void> testAlarm(int seconds, Settings s) async {
    try {
      await _ch.invokeMethod('test', {
        'seconds': seconds,
        'snooze': s.snoozeMinutes,
        'vibrate': s.vibrate,
      });
    } catch (e) {
      debugPrint('test: $e');
    }
  }
}

/// Stato dell'app: carica, salva e riprogramma le sveglie a ogni modifica.
class AppStore extends ChangeNotifier {
  static const _key = 'turnista_data_v1';

  AppData data = AppData.defaults();
  bool loaded = false;
  Map<String, bool> perms = {'notifications': true, 'exact': true, 'fullScreen': true};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        data = AppData.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (e) {
        debugPrint('Dati non leggibili, uso i predefiniti: $e');
        data = AppData.defaults();
      }
    }
    loaded = true;
    notifyListeners();
    await refreshPermissions();
    await reschedule();
  }

  Future<void> refreshPermissions() async {
    perms = await AlarmBridge.permissions();
    notifyListeners();
  }

  bool get permissionsOk => perms.values.every((v) => v);

  Future<void> save() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.toJson()));
    await reschedule();
  }

  Future<void> reschedule() async {
    final alarms = data.upcomingAlarms(DateTime.now());
    await AlarmBridge.schedule(alarms, data.settings);
  }

  AlarmEntry? get nextAlarm {
    final a = data.upcomingAlarms(DateTime.now(), days: 60);
    return a.isEmpty ? null : a.first;
  }

  // ---------- modifiche ----------

  Future<void> upsertType(ShiftType t) async {
    final i = data.types.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      data.types[i] = t;
    } else {
      data.types.add(t);
    }
    await save();
  }

  Future<void> deleteType(String id) async {
    data.types.removeWhere((t) => t.id == id);
    data.rotation = data.rotation.map((r) => r == id ? null : r).toList();
    data.overrides.removeWhere((k, v) => v.typeId == id);
    await save();
  }

  Future<void> setRotation(List<String?> rotation, DateTime? start) async {
    data.rotation = rotation;
    data.rotationStart = start == null ? null : dateOnly(start);
    await save();
  }

  Future<void> setOverride(DateTime day, DayOverride? ov) async {
    final k = dayKey(day);
    if (ov == null || ov.isEmpty) {
      data.overrides.remove(k);
    } else {
      data.overrides[k] = ov;
    }
    await save();
  }

  /// Assegna velocemente un tipo a un giorno (modalità rapida del calendario).
  Future<void> paintDay(DateTime day, String? typeId) async {
    final k = dayKey(day);
    final old = data.overrides[k];
    if (typeId == null) {
      // "Da rotazione": tolgo solo il tipo, tengo il resto.
      if (old != null) {
        old.typeId = null;
        old.start = null;
        old.end = null;
        if (old.isEmpty) data.overrides.remove(k);
      }
    } else {
      final ov = old ?? DayOverride();
      ov.typeId = typeId;
      ov.start = null;
      ov.end = null;
      data.overrides[k] = ov;
      // Se coincide con la rotazione non serve salvarlo come modifica.
      final rot = data.rotationTypeFor(day);
      if (rot != null && rot.id == typeId && !ov.skipAlarm && ov.note.trim().isEmpty) {
        data.overrides.remove(k);
      }
    }
    await save();
  }

  Future<void> toggleSkipAlarm(DateTime day) async {
    final k = dayKey(day);
    final ov = data.overrides[k] ?? DayOverride();
    ov.skipAlarm = !ov.skipAlarm;
    if (ov.isEmpty) {
      data.overrides.remove(k);
    } else {
      data.overrides[k] = ov;
    }
    await save();
  }

  Future<void> updateSettings(void Function(Settings s) change) async {
    change(data.settings);
    await save();
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert(data.toJson());

  Future<bool> importJson(String raw) async {
    try {
      final d = AppData.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      if (d.types.isEmpty) return false;
      d.settings.setupDone = true;
      data = d;
      await save();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> resetAll() async {
    data = AppData.defaults();
    await save();
  }
}
