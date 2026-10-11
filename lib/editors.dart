import 'package:flutter/material.dart';

import 'models.dart';
import 'ui.dart';

// ======================= Tipi di turno =======================

/// Elenco dei tipi di turno, con aggiunta e modifica.
class TypesList extends StatelessWidget {
  const TypesList({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final types = store.data.types;
    return Column(
      children: [
        for (final t in types) ...[
          AppCard(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
            onTap: () => openTypeEditor(context, t),
            child: Row(
              children: [
                ShiftBadge(t),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name.isEmpty ? '(senza nome)' : t.name,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      MutedText(
                        t.isRest
                            ? 'Riposo · niente sveglia'
                            : '${t.start}–${t.end} · ${t.alarm ? 'sveglia ${formatDuration(t.alarmOffset)} prima' : 'senza sveglia'}',
                        size: 14,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Palette.muted),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Palette.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Palette.primary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: () => openTypeEditor(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi tipo di turno',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

Future<void> openTypeEditor(BuildContext context, ShiftType? existing) async {
  await Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => TypeEditorPage(existing: existing),
  ));
}

class TypeEditorPage extends StatefulWidget {
  final ShiftType? existing;
  const TypeEditorPage({super.key, this.existing});

  @override
  State<TypeEditorPage> createState() => _TypeEditorPageState();
}

class _TypeEditorPageState extends State<TypeEditorPage> {
  late ShiftType t;
  late TextEditingController codeCtrl;
  late TextEditingController nameCtrl;

  @override
  void initState() {
    super.initState();
    t = widget.existing?.copy() ??
        ShiftType(
          id: 't_${DateTime.now().microsecondsSinceEpoch}',
          code: '',
          name: '',
          color: Palette.shiftColors.first,
        );
    codeCtrl = TextEditingController(text: t.code);
    nameCtrl = TextEditingController(text: t.name);
  }

  @override
  void dispose() {
    codeCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    t.code = codeCtrl.text.trim();
    t.name = nameCtrl.text.trim();
    if (t.code.isEmpty) {
      toast(context, 'Scrivi una sigla (es. M, P, N, CM)');
      return;
    }
    if (t.name.isEmpty) t.name = t.code;
    final store = StoreScope.read(context);
    await store.upsertType(t);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare questo tipo?'),
        content: const Text(
            'Verrà tolto anche dalla rotazione e dai giorni dove l\'avevi messo a mano.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await StoreScope.read(context).deleteType(t.id);
    if (mounted) Navigator.of(context).pop();
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      );

  Widget _timeTile(String label, String value, ValueChanged<String> onPick) {
    return Expanded(
      child: AppCard(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: () async {
          final v = await pickHm(context, value, help: label);
          if (v != null) setState(() => onPick(v));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MutedText(label, size: 14),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    final preview = ShiftType.fromJson(t.toJson())
      ..code = codeCtrl.text.trim().isEmpty ? '?' : codeCtrl.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Nuovo tipo di turno' : 'Modifica turno'),
        actions: [
          if (!isNew)
            IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline), tooltip: 'Elimina'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Center(child: ShiftBadge(preview, fontSize: 26,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8))),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  controller: codeCtrl,
                  maxLength: 4,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _dec('Sigla').copyWith(counterText: ''),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _dec('Nome (es. Mattina)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const MutedText('Colore', size: 14),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: Palette.shiftColors
                .map((c) => GestureDetector(
                      onTap: () => setState(() => t.color = c),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: t.color == c ? Palette.text : Colors.transparent, width: 3),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 18),
          AppCard(
            radius: 20,
            padding: const EdgeInsets.fromLTRB(18, 4, 8, 4),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('È un riposo', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Giorno libero: niente orari e niente sveglia'),
              value: t.isRest,
              onChanged: (v) => setState(() {
                t.isRest = v;
                if (v) t.alarm = false;
              }),
            ),
          ),
          if (!t.isRest) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                _timeTile('Inizio', t.start, (v) => t.start = v),
                const SizedBox(width: 12),
                _timeTile('Fine', t.end, (v) => t.end = v),
              ],
            ),
            const SizedBox(height: 6),
            MutedText(
              'Durata ${formatDuration(t.durationMinutes)}'
              '${parseHm(t.end) <= parseHm(t.start) ? ' · finisce il giorno dopo' : ''}',
              size: 14,
            ),
            const SizedBox(height: 18),
            AppCard(
              radius: 20,
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sveglia', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Suona prima dell\'inizio di questo turno'),
                    value: t.alarm,
                    onChanged: (v) => setState(() => t.alarm = v),
                  ),
                  if (t.alarm) ...[
                    const SizedBox(height: 4),
                    OffsetStepper(
                      minutes: t.alarmOffset,
                      onChanged: (v) => setState(() => t.alarmOffset = v),
                    ),
                    const SizedBox(height: 12),
                    MutedText(
                      'Con inizio alle ${t.start} suona alle '
                      '${formatHm(parseHm(t.start) - t.alarmOffset)}',
                      size: 14,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: _save, child: const Text('Salva')),
        ),
      ),
    );
  }
}

// ======================= Rotazione =======================

class RotationEditorPage extends StatefulWidget {
  /// Se true è dentro la configurazione iniziale (cambia solo il testo del pulsante).
  final bool inSetup;
  const RotationEditorPage({super.key, this.inSetup = false});

  @override
  State<RotationEditorPage> createState() => _RotationEditorPageState();
}

class _RotationEditorPageState extends State<RotationEditorPage> {
  late List<String?> rot;
  DateTime? start;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final d = StoreScope.read(context).data;
    rot = List<String?>.from(d.rotation);
    start = d.rotationStart ?? dateOnly(DateTime.now());
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: start ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: 'Primo giorno della rotazione',
    );
    if (d != null) setState(() => start = d);
  }

  Future<void> _save() async {
    await StoreScope.read(context).setRotation(rot, rot.isEmpty ? null : start);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final data = store.data;
    final today = dateOnly(DateTime.now());

    // anteprima dei prossimi 14 giorni con la rotazione in modifica
    final previewData = AppData(
      types: data.types,
      rotation: rot,
      rotationStart: start,
      overrides: const {},
      settings: data.settings,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Rotazione')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          const MutedText(
              'Componi il ciclo dei tuoi turni nell\'ordine giusto, toccando i tipi qui sotto. '
              'Esempio: M M P P N R R. Il ciclo poi si ripete da solo.'),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Ciclo di ${rot.length} giorni',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    if (rot.isNotEmpty)
                      IconButton(
                        tooltip: 'Togli l\'ultimo',
                        onPressed: () => setState(() => rot.removeLast()),
                        icon: const Icon(Icons.backspace_outlined),
                      ),
                    if (rot.isNotEmpty)
                      IconButton(
                        tooltip: 'Svuota',
                        onPressed: () => setState(() => rot.clear()),
                        icon: const Icon(Icons.delete_sweep_outlined),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (rot.isEmpty)
                  const MutedText('Ancora vuoto. Tocca un turno qui sotto per aggiungerlo.')
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < rot.length; i++)
                        GestureDetector(
                          onTap: () => setState(() => rot.removeAt(i)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ShiftBadge(data.typeById(rot[i]), fontSize: 16),
                              const SizedBox(height: 2),
                              Text('${i + 1}',
                                  style: const TextStyle(fontSize: 11, color: Palette.muted)),
                            ],
                          ),
                        ),
                    ],
                  ),
                if (rot.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const MutedText('Tocca un turno del ciclo per toglierlo.', size: 13),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          const MutedText('Aggiungi al ciclo', size: 14),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final t in data.types)
                ActionChip(
                  avatar: CircleAvatar(backgroundColor: Color(t.color), radius: 8),
                  label: Text('${t.code} · ${t.name}'),
                  onPressed: () => setState(() => rot.add(t.id)),
                ),
              ActionChip(
                avatar: const Icon(Icons.remove, size: 16),
                label: const Text('Vuoto'),
                onPressed: () => setState(() => rot.add(null)),
              ),
            ],
          ),
          const SizedBox(height: 22),
          AppCard(
            onTap: _pickStart,
            child: Row(
              children: [
                const Icon(Icons.event, color: Palette.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MutedText('Il giorno 1 del ciclo è', size: 14),
                      Text(start == null ? '—' : capitalize(longDate(start!)),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const Icon(Icons.edit_outlined, color: Palette.muted),
              ],
            ),
          ),
          if (rot.isNotEmpty && start != null) ...[
            const SizedBox(height: 22),
            const CardHeader('Anteprima'),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < 14; i++)
                    Builder(builder: (_) {
                      final day = DateTime(today.year, today.month, today.day + i);
                      final s = previewData.shiftFor(day);
                      return SizedBox(
                        width: 42,
                        child: Column(
                          children: [
                            Text(giorniBrevi[day.weekday - 1],
                                style: const TextStyle(fontSize: 11, color: Palette.muted)),
                            Text('${day.day}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            ShiftBadge(s.type,
                                fontSize: 12,
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3)),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _save,
            child: Text(widget.inSetup ? 'Salva e continua' : 'Salva rotazione'),
          ),
        ),
      ),
    );
  }
}

// ======================= Singolo giorno =======================

Future<void> openDaySheet(BuildContext context, DateTime day) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DaySheet(day: dateOnly(day)),
  );
}

class DaySheet extends StatefulWidget {
  final DateTime day;
  const DaySheet({super.key, required this.day});

  @override
  State<DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<DaySheet> {
  late DayOverride ov;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final existing = StoreScope.read(context).data.overrides[dayKey(widget.day)];
    ov = existing == null ? DayOverride() : DayOverride.fromJson(existing.toJson());
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final data = store.data;
    final rotType = data.rotationTypeFor(widget.day);

    // turno risultante con le modifiche in corso
    final tmp = AppData(
      types: data.types,
      rotation: data.rotation,
      rotationStart: data.rotationStart,
      overrides: {dayKey(widget.day): ov},
      settings: data.settings,
    );
    final s = tmp.shiftFor(widget.day);
    final alarmAt = tmp.alarmTimeFor(s);
    final t = s.type;
    final canAlarm = t != null && !t.isRest && t.alarm && data.settings.alarmsEnabled;

    Widget chip(String label, String? value, {Color? color}) {
      final selected = ov.typeId == value;
      return ChoiceChip(
        avatar: color == null ? null : CircleAvatar(backgroundColor: color, radius: 8),
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() {
          ov.typeId = value;
          ov.start = null;
          ov.end = null;
        }),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(capitalize(longDate(widget.day)),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                ),
                ShiftBadge(t),
              ],
            ),
            const SizedBox(height: 4),
            MutedText(
              data.hasRotation
                  ? 'Da rotazione: ${rotType == null ? 'nessun turno' : '${rotType.code} · ${rotType.name}'}'
                  : 'Nessuna rotazione impostata',
              size: 14,
            ),
            const SizedBox(height: 18),
            const Text('Turno', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (data.hasRotation) chip('Da rotazione', null),
                for (final ty in data.types) chip(ty.code, ty.id, color: Color(ty.color)),
                chip('Nessuno', DayOverride.noShift),
              ],
            ),
            if (t != null && !t.isRest) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _TimeBox(
                      label: 'Inizio',
                      value: s.start ?? t.start,
                      changed: ov.start != null,
                      onTap: () async {
                        final v = await pickHm(context, s.start ?? t.start, help: 'Inizio turno');
                        if (v != null) {
                          setState(() {
                            ov.typeId ??= t.id;
                            ov.start = v;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeBox(
                      label: 'Fine',
                      value: s.end ?? t.end,
                      changed: ov.end != null,
                      onTap: () async {
                        final v = await pickHm(context, s.end ?? t.end, help: 'Fine turno');
                        if (v != null) {
                          setState(() {
                            ov.typeId ??= t.id;
                            ov.end = v;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (ov.start != null || ov.end != null)
                TextButton(
                  onPressed: () => setState(() {
                    ov.start = null;
                    ov.end = null;
                  }),
                  child: Text('Torna agli orari standard (${t.start}–${t.end})'),
                ),
            ],
            const SizedBox(height: 14),
            AppCard(
              radius: 20,
              padding: const EdgeInsets.fromLTRB(18, 4, 8, 4),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.alarm, color: Palette.primary),
                title: const Text('Sveglia', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(!canAlarm
                    ? 'Nessuna sveglia per questo turno'
                    : ov.skipAlarm
                        ? 'Saltata per questo giorno'
                        : alarmAt == null
                            ? '—'
                            : 'Suona ${relativeDay(alarmAt, DateTime.now())} alle ${hmOf(alarmAt)}'),
                value: canAlarm && !ov.skipAlarm,
                onChanged: canAlarm ? (v) => setState(() => ov.skipAlarm = !v) : null,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: ov.note,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                labelText: 'Nota (es. cambio con un collega)',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              onChanged: (v) => ov.note = v,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (data.overrides.containsKey(dayKey(widget.day)))
                  TextButton(
                    onPressed: () async {
                      await store.setOverride(widget.day, null);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Ripristina'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: () async {
                    // se il tipo scelto coincide con la rotazione non serve forzarlo
                    if (ov.typeId != null &&
                        rotType != null &&
                        ov.typeId == rotType.id &&
                        ov.start == null &&
                        ov.end == null) {
                      ov.typeId = null;
                    }
                    await store.setOverride(widget.day, ov);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Salva'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String label;
  final String value;
  final bool changed;
  final VoidCallback onTap;
  const _TimeBox(
      {required this.label, required this.value, required this.changed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: changed ? Palette.primary : null,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MutedText(changed ? '$label (modificato)' : label, size: 13),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
