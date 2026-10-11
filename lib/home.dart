import 'package:flutter/material.dart';

import 'editors.dart';
import 'models.dart';
import 'settings_tab.dart';
import 'store.dart';
import 'ui.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // al ritorno nell'app: permessi aggiornati e sveglie ricalcolate (es. è cambiato il giorno)
      final store = StoreScope.read(context);
      store.refreshPermissions();
      store.reschedule();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayTab(onOpenCalendar: () => setState(() => tab = 1)),
      const CalendarTab(),
      const StatsTab(),
      const SettingsTab(),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Oggi'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendario'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Statistiche'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Impostazioni'),
        ],
      ),
    );
  }
}

// =========================== OGGI ===========================

class TodayTab extends StatelessWidget {
  final VoidCallback onOpenCalendar;
  const TodayTab({super.key, required this.onOpenCalendar});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final data = store.data;
    final now = DateTime.now();
    final today = dateOnly(now);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final sToday = data.shiftFor(today);
    final sTomorrow = data.shiftFor(tomorrow);
    final next = store.nextAlarm;
    final name = data.settings.name.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Text(capitalize(longDate(now)), style: const TextStyle(fontSize: 19, color: Palette.muted)),
        const SizedBox(height: 6),
        Text(name.isEmpty ? 'Ciao!' : 'Ciao $name',
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, height: 1.1)),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: _DayChip(label: 'Oggi', shift: sToday, onTap: () => openDaySheet(context, today))),
            const SizedBox(width: 12),
            Expanded(
                child: _DayChip(label: 'Domani', shift: sTomorrow, onTap: () => openDaySheet(context, tomorrow))),
          ],
        ),
        const SizedBox(height: 18),
        if (!store.permissionsOk) ...[
          WarningCard(
            text: 'La sveglia potrebbe non suonare: manca un permesso '
                '(${_missing(store.perms)}). Senza, Android può bloccarla.',
            action: 'Sistema ora',
            onAction: () => fixPermissions(context),
          ),
          const SizedBox(height: 18),
        ],
        _NextAlarmCard(next: next),
        const SizedBox(height: 18),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardHeader('Prossimi giorni', action: 'Calendario', onAction: onOpenCalendar),
              const SizedBox(height: 10),
              for (var i = 0; i < 7; i++)
                Builder(builder: (_) {
                  final d = DateTime(today.year, today.month, today.day + i);
                  final s = data.shiftFor(d);
                  return _WeekRow(shift: s, alarm: data.alarmTimeFor(s), now: now);
                }),
            ],
          ),
        ),
        if (!data.hasRotation && data.overrides.isEmpty) ...[
          const SizedBox(height: 18),
          AppCard(
            color: Palette.warmBg,
            border: Palette.warmBorder,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CardHeader('Nessun turno inserito'),
                const SizedBox(height: 8),
                const MutedText(
                    'Imposta la tua rotazione oppure segna i turni a mano dal calendario.'),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => const RotationEditorPage())),
                  child: const Text('Imposta la rotazione'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

String _missing(Map<String, bool> p) {
  final out = <String>[];
  if (p['notifications'] == false) out.add('notifiche');
  if (p['exact'] == false) out.add('sveglie e promemoria');
  if (p['fullScreen'] == false) out.add('schermo intero');
  return out.join(', ');
}

/// Apre le impostazioni giuste per il primo permesso mancante.
Future<void> fixPermissions(BuildContext context) async {
  final store = StoreScope.read(context);
  await store.refreshPermissions();
  final p = store.perms;
  if (p['notifications'] == false) {
    await AlarmBridge.call('requestNotifications');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await store.refreshPermissions();
    if (store.perms['notifications'] == false) {
      await AlarmBridge.call('openNotificationSettings');
    }
    return;
  }
  if (p['exact'] == false) {
    await AlarmBridge.call('openExactAlarmSettings');
    return;
  }
  if (p['fullScreen'] == false) {
    await AlarmBridge.call('openFullScreenSettings');
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final DayShift shift;
  final VoidCallback onTap;
  const _DayChip({required this.label, required this.shift, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = shift.type;
    final String detail;
    if (t == null) {
      detail = 'Nessun turno';
    } else if (t.isRest) {
      detail = t.name;
    } else {
      detail = shift.timesLabel;
    }
    return AppCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      onTap: onTap,
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 17, color: Palette.muted)),
          const SizedBox(width: 8),
          ShiftBadge(t, fontSize: 16, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _NextAlarmCard extends StatelessWidget {
  final AlarmEntry? next;
  const _NextAlarmCard({required this.next});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final n = next;
    if (!store.data.settings.alarmsEnabled) {
      return AppCard(
        child: Row(
          children: [
            const Icon(Icons.alarm_off, color: Palette.muted, size: 34),
            const SizedBox(width: 16),
            const Expanded(child: MutedText('Le sveglie sono spente')),
            TextButton(
              onPressed: () => store.updateSettings((s) => s.alarmsEnabled = true),
              child: const Text('Accendi'),
            ),
          ],
        ),
      );
    }
    if (n == null) {
      return const AppCard(
        child: Row(
          children: [
            Icon(Icons.alarm, color: Palette.muted, size: 34),
            SizedBox(width: 16),
            Expanded(child: MutedText('Nessuna sveglia in programma nei prossimi giorni')),
          ],
        ),
      );
    }
    final now = DateTime.now();
    final left = n.at.difference(now);
    final leftMin = left.inMinutes;
    final leftLabel = leftMin < 60 * 24
        ? 'tra ${formatDuration(leftMin < 1 ? 1 : leftMin)}'
        : relativeDay(n.at, now);
    return Material(
      color: Palette.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openDaySheet(context, n.shift.date),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 14, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.alarm, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Prossima sveglia',
                        style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                  Text(leftLabel, style: const TextStyle(fontSize: 15, color: Color(0xCCFFFFFF))),
                  const SizedBox(width: 8),
                ],
              ),
              const SizedBox(height: 6),
              Text(hmOf(n.at),
                  style: const TextStyle(
                      fontSize: 56, height: 1.05, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                '${capitalize(relativeDay(n.at, now))} · turno ${n.shift.type?.code ?? ''} '
                'alle ${n.shift.start ?? ''}',
                style: const TextStyle(fontSize: 16, color: Color(0xE6FFFFFF)),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () async {
                    await store.toggleSkipAlarm(n.shift.date);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text('Sveglia di ${shortDate(n.shift.date)} saltata'),
                          action: SnackBarAction(
                            label: 'Annulla',
                            onPressed: () => store.toggleSkipAlarm(n.shift.date),
                          ),
                        ));
                    }
                  },
                  icon: const Icon(Icons.alarm_off),
                  label: const Text('Salta questa'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  final DayShift shift;
  final DateTime? alarm;
  final DateTime now;
  const _WeekRow({required this.shift, required this.alarm, required this.now});

  @override
  Widget build(BuildContext context) {
    final t = shift.type;
    final isToday = daysBetween(now, shift.date) == 0;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => openDaySheet(context, shift.date),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 74,
              child: Text(
                isToday ? 'Oggi' : shortDate(shift.date).replaceFirst(RegExp(r' \w+$'), ''),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                  color: isToday ? Palette.primary : Palette.text,
                ),
              ),
            ),
            ShiftBadge(t, fontSize: 14, padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t == null ? '' : (t.isRest ? t.name : shift.timesLabel),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (shift.note.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.sticky_note_2_outlined, size: 18, color: Palette.muted),
              ),
            if (alarm != null) ...[
              const Icon(Icons.alarm, size: 18, color: Palette.primary),
              const SizedBox(width: 4),
              Text(hmOf(alarm!),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.primary)),
            ] else if (shift.skipAlarm)
              const Icon(Icons.alarm_off, size: 18, color: Palette.muted),
          ],
        ),
      ),
    );
  }
}

// =========================== CALENDARIO ===========================

class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  late DateTime month;
  bool quick = false; // modalità rapida: tocchi un giorno e gli assegni il tipo scelto
  String? brush; // tipo scelto per la modalità rapida (null = "da rotazione")
  bool brushSet = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    month = DateTime(now.year, now.month);
  }

  void _move(int delta) => setState(() => month = DateTime(month.year, month.month + delta));

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final data = store.data;
    final today = dateOnly(DateTime.now());

    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1; // lunedì = 0
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();

    final st = statsFor(data, first, DateTime(month.year, month.month, daysInMonth));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Row(
          children: [
            IconButton(onPressed: () => _move(-1), icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  final now = DateTime.now();
                  setState(() => month = DateTime(now.year, now.month));
                },
                child: Text('${capitalize(mesi[month.month - 1])} ${month.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              ),
            ),
            IconButton(onPressed: () => _move(1), icon: const Icon(Icons.chevron_right)),
          ],
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          child: Column(
            children: [
              Row(
                children: [
                  for (final g in giorniBrevi)
                    Expanded(
                      child: Text(g,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Palette.muted, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              for (var r = 0; r < rows; r++)
                Row(
                  children: [
                    for (var c = 0; c < 7; c++)
                      Expanded(
                        child: Builder(builder: (_) {
                          final idx = r * 7 + c - lead;
                          if (idx < 0 || idx >= daysInMonth) return const SizedBox(height: 64);
                          final day = DateTime(month.year, month.month, idx + 1);
                          return _DayCell(
                            shift: data.shiftFor(day),
                            isToday: day == today,
                            hasAlarm: data.alarmTimeFor(data.shiftFor(day)) != null,
                            onTap: () async {
                              if (quick && brushSet) {
                                await store.paintDay(day, brush);
                              } else {
                                await openDaySheet(context, day);
                              }
                            },
                          );
                        }),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(18, 6, 10, 6),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.brush_outlined, color: Palette.primary),
            title: const Text('Inserimento rapido', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Scegli un turno e tocca i giorni per segnarlo'),
            value: quick,
            onChanged: (v) => setState(() => quick = v),
          ),
        ),
        if (quick) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in data.types)
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: Color(t.color), radius: 8),
                  label: Text(t.code),
                  selected: brushSet && brush == t.id,
                  onSelected: (_) => setState(() {
                    brush = t.id;
                    brushSet = true;
                  }),
                ),
              ChoiceChip(
                label: const Text('Nessuno'),
                selected: brushSet && brush == DayOverride.noShift,
                onSelected: (_) => setState(() {
                  brush = DayOverride.noShift;
                  brushSet = true;
                }),
              ),
              if (data.hasRotation)
                ChoiceChip(
                  label: const Text('Da rotazione'),
                  selected: brushSet && brush == null,
                  onSelected: (_) => setState(() {
                    brush = null;
                    brushSet = true;
                  }),
                ),
            ],
          ),
          if (!brushSet)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: MutedText('Prima scegli quale turno segnare.', size: 14),
            ),
        ],
        const SizedBox(height: 14),
        AppCard(
          child: Row(
            children: [
              Expanded(child: _Mini(label: 'Ore', value: formatDuration(st.minutes))),
              Expanded(child: _Mini(label: 'Turni', value: '${st.workDays}')),
              Expanded(child: _Mini(label: 'Riposi', value: '${st.restDays}')),
              Expanded(child: _Mini(label: 'Notti', value: '${st.nights}')),
            ],
          ),
        ),
      ],
    );
  }
}

class _Mini extends StatelessWidget {
  final String label;
  final String value;
  const _Mini({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 13, color: Palette.muted)),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DayShift shift;
  final bool isToday;
  final bool hasAlarm;
  final VoidCallback onTap;
  const _DayCell({required this.shift, required this.isToday, required this.hasAlarm, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = shift.type;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 64,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: isToday ? Border.all(color: Palette.primary, width: 2) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${shift.date.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                      color: isToday ? Palette.primary : Palette.text,
                    )),
                if (shift.fromOverride)
                  Container(
                    margin: const EdgeInsets.only(left: 3),
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(color: Palette.primary, shape: BoxShape.circle),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (t != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: Color(t.color), borderRadius: BorderRadius.circular(7)),
                child: Text(
                  t.code,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              )
            else
              const SizedBox(height: 18),
            SizedBox(
              height: 12,
              child: hasAlarm ? const Icon(Icons.alarm, size: 11, color: Palette.primary) : null,
            ),
          ],
        ),
      ),
    );
  }
}

// =========================== STATISTICHE ===========================

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  bool yearly = false;
  late DateTime ref;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    ref = DateTime(now.year, now.month);
  }

  void _move(int d) => setState(() {
        ref = yearly ? DateTime(ref.year + d, ref.month) : DateTime(ref.year, ref.month + d);
      });

  @override
  Widget build(BuildContext context) {
    final data = StoreScope.of(context).data;
    final from = yearly ? DateTime(ref.year, 1, 1) : DateTime(ref.year, ref.month, 1);
    final to = yearly ? DateTime(ref.year, 12, 31) : DateTime(ref.year, ref.month + 1, 0);
    final st = statsFor(data, from, to);
    final title = yearly ? '${ref.year}' : '${capitalize(mesi[ref.month - 1])} ${ref.year}';
    final maxCount = st.countByType.values.fold<int>(0, (a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const Text('Statistiche', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Mese'), icon: Icon(Icons.calendar_view_month)),
            ButtonSegment(value: true, label: Text('Anno'), icon: Icon(Icons.calendar_today)),
          ],
          selected: {yearly},
          onSelectionChanged: (s) => setState(() => yearly = s.first),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(onPressed: () => _move(-1), icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            IconButton(onPressed: () => _move(1), icon: const Icon(Icons.chevron_right)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _StatTile(label: 'Ore lavorate', value: formatDuration(st.minutes), big: true)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatTile(label: 'Turni', value: '${st.workDays}')),
            const SizedBox(width: 12),
            Expanded(child: _StatTile(label: 'Riposi', value: '${st.restDays}')),
            const SizedBox(width: 12),
            Expanded(child: _StatTile(label: 'Notti', value: '${st.nights}')),
          ],
        ),
        if (st.workDays > 0) ...[
          const SizedBox(height: 12),
          _StatTile(
            label: 'Media per turno',
            value: formatDuration(st.minutes ~/ st.workDays),
          ),
        ],
        const SizedBox(height: 18),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CardHeader('Per tipo di turno'),
              const SizedBox(height: 14),
              if (st.countByType.isEmpty) const MutedText('Nessun turno in questo periodo'),
              for (final t in data.types)
                if ((st.countByType[t.id] ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 58,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ShiftBadge(t,
                                fontSize: 14,
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3)),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${t.name} · ${st.countByType[t.id]} '
                                '${st.countByType[t.id] == 1 ? 'giorno' : 'giorni'}'
                                '${t.isRest ? '' : ' · ${formatDuration(st.minutesByType[t.id] ?? 0)}'}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: maxCount == 0 ? 0 : (st.countByType[t.id]! / maxCount),
                                  minHeight: 10,
                                  backgroundColor: Palette.bg,
                                  color: Color(t.color),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const MutedText(
            'Le ore sono calcolate dagli orari dei turni, compresi quelli modificati a mano.',
            size: 13),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final bool big;
  const _StatTile({required this.label, required this.value, this.big = false});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MutedText(label, size: 14),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: big ? 34 : 24, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
