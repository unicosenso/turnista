import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'editors.dart';
import 'home.dart' show fixPermissions;
import 'models.dart';
import 'prova_lettore.dart';
import 'store.dart';
import 'ui.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 26, 4, 10),
        child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      );

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final data = store.data;
    final s = data.settings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        const Text('Impostazioni', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),

        _section('Sveglia'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(18, 6, 10, 6),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.alarm, color: Palette.primary),
                title: const Text('Sveglie attive', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Interruttore generale per tutte le sveglie'),
                value: s.alarmsEnabled,
                onChanged: (v) => store.updateSettings((x) => x.alarmsEnabled = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.vibration, color: Palette.primary),
                title: const Text('Vibrazione', style: TextStyle(fontWeight: FontWeight.w700)),
                value: s.vibrate,
                onChanged: (v) => store.updateSettings((x) => x.vibrate = v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.snooze, color: Palette.primary),
                title: const Text('Rimanda di', style: TextStyle(fontWeight: FontWeight.w700)),
                trailing: DropdownButton<int>(
                  value: const [5, 10, 15, 20].contains(s.snoozeMinutes) ? s.snoozeMinutes : 10,
                  underline: const SizedBox.shrink(),
                  items: const [5, 10, 15, 20]
                      .map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) store.updateSettings((x) => x.snoozeMinutes = v);
                  },
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_circle_outline, color: Palette.primary),
                title: const Text('Prova la sveglia', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Suona tra 10 secondi: blocca il telefono per provarla'),
                onTap: () async {
                  await AlarmBridge.testAlarm(10, s);
                  if (context.mounted) toast(context, 'La sveglia di prova suona tra 10 secondi');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(store.permissionsOk ? Icons.verified_outlined : Icons.error_outline,
                    color: store.permissionsOk ? Palette.primary : const Color(0xFFC62828)),
                title: const Text('Permessi', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(store.permissionsOk
                    ? 'Tutto a posto'
                    : 'Manca qualcosa: tocca per sistemare'),
                onTap: () => store.permissionsOk
                    ? AlarmBridge.call('openAppSettings')
                    : fixPermissions(context),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(6, 10, 6, 0),
          child: MutedText(
            'Su alcuni telefoni (Xiaomi, Huawei, Oppo…) conviene anche togliere le restrizioni '
            'della batteria per TurniRSP e attivare l\'avvio automatico, così la sveglia '
            'torna attiva da sola dopo un riavvio.',
            size: 13,
          ),
        ),

        _section('Turni'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(18, 6, 10, 6),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.loop, color: Palette.primary),
            title: const Text('Rotazione', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(data.hasRotation
                ? 'Ciclo di ${data.rotation.length} giorni, dal ${shortDate(data.rotationStart!)}'
                : 'Nessuna rotazione: turni inseriti a mano'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const RotationEditorPage())),
          ),
        ),
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: MutedText('Tipi di turno: orari e anticipo della sveglia', size: 14),
        ),
        const TypesList(),

        _section('TurniRSP (prova)'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(18, 6, 10, 6),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.document_scanner_outlined, color: Palette.primary),
            title: const Text('Prova lettura foglio', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Fotografa il foglio dei garagisti e guarda cosa legge l\'app'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const ProvaLettorePage())),
          ),
        ),

        _section('Profilo'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(18, 6, 10, 6),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline, color: Palette.primary),
            title: const Text('Il tuo nome', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(s.name.isEmpty ? 'Non impostato' : s.name),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () async {
              final v = await _askText(context, 'Il tuo nome', s.name);
              if (v != null) await store.updateSettings((x) => x.name = v.trim());
            },
          ),
        ),

        _section('Backup'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(18, 6, 10, 6),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.upload_outlined, color: Palette.primary),
                title: const Text('Copia backup', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Copia tutti i dati: incollali in una nota o in un messaggio'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: store.exportJson()));
                  if (context.mounted) toast(context, 'Backup copiato negli appunti');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.download_outlined, color: Palette.primary),
                title: const Text('Ripristina backup', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Incolla un backup copiato prima'),
                onTap: () async {
                  final clip = await Clipboard.getData(Clipboard.kTextPlain);
                  if (!context.mounted) return;
                  final v = await _askText(context, 'Incolla il backup', clip?.text ?? '', lines: 6);
                  if (v == null || v.trim().isEmpty) return;
                  final ok = await store.importJson(v);
                  if (context.mounted) {
                    toast(context, ok ? 'Backup ripristinato' : 'Backup non valido');
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restart_alt, color: Color(0xFFC62828)),
                title: const Text('Ricomincia da zero', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Cancella tutto e rifà la configurazione iniziale'),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Cancellare tutto?'),
                      content: const Text(
                          'Turni, rotazione e modifiche verranno cancellati. Fai prima un backup se ti serve.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancella')),
                      ],
                    ),
                  );
                  if (ok == true) await store.resetAll();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Center(child: MutedText('TurniRSP 0.1 · by Mastro · i dati restano solo sul telefono', size: 13)),
      ],
    );
  }
}

Future<String?> _askText(BuildContext context, String title, String initial, {int lines = 1}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: lines,
        minLines: 1,
        textCapitalization: lines == 1 ? TextCapitalization.words : TextCapitalization.none,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
        TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('OK')),
      ],
    ),
  );
}
