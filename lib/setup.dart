import 'package:flutter/material.dart';

import 'editors.dart';
import 'home.dart' show fixPermissions;
import 'store.dart';
import 'ui.dart';

/// Configurazione iniziale in 4 passi.
class SetupFlow extends StatefulWidget {
  const SetupFlow({super.key});

  @override
  State<SetupFlow> createState() => _SetupFlowState();
}

class _SetupFlowState extends State<SetupFlow> with WidgetsBindingObserver {
  int step = 0;
  final nameCtrl = TextEditingController();
  static const steps = 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    nameCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      StoreScope.read(context).refreshPermissions();
    }
  }

  Future<void> _next() async {
    final store = StoreScope.read(context);
    if (step == 0) {
      await store.updateSettings((s) => s.name = nameCtrl.text.trim());
    }
    if (step < steps - 1) {
      setState(() => step++);
    } else {
      await store.updateSettings((s) => s.setupDone = true);
    }
  }

  Widget _title(String t, String sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.15)),
          const SizedBox(height: 10),
          MutedText(sub, size: 17),
          const SizedBox(height: 24),
        ],
      );

  Widget _stepWelcome() => ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: Palette.primary, borderRadius: BorderRadius.circular(22)),
            child: const Icon(Icons.alarm, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 24),
          _title('Benvenuto in TurniRSP',
              'I tuoi turni sempre sotto controllo, e una sveglia che si regola da sola in base al turno.'),
          TextField(
            controller: nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Come ti chiami? (facoltativo)',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
          ),
        ],
      );

  Widget _stepTypes() => ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        children: [
          _title('I tuoi tipi di turno',
              'Per ognuno imposta orari e quanto prima deve suonare la sveglia. '
                  'Ne abbiamo messi alcuni di esempio: toccali per modificarli o eliminarli.'),
          const TypesList(),
        ],
      );

  Widget _stepEntry() {
    final data = StoreScope.of(context).data;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      children: [
        _title('Come inserisci i turni?',
            'Puoi usare entrambi i modi: una rotazione che si ripete, e le modifiche a mano '
                'sui singoli giorni (ferie, cambi turno) direttamente dal calendario.'),
        AppCard(
          border: data.hasRotation ? Palette.primary : null,
          onTap: () async {
            await Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const RotationEditorPage(inSetup: true)));
            if (mounted) setState(() {});
          },
          child: Row(
            children: [
              const Icon(Icons.loop, color: Palette.primary, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ho una rotazione fissa',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    MutedText(
                        data.hasRotation
                            ? 'Impostata: ciclo di ${data.rotation.length} giorni ✓'
                            : 'Es. M M P P N R R che si ripete',
                        size: 15),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Palette.muted),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const AppCard(
          child: Row(
            children: [
              Icon(Icons.edit_calendar_outlined, color: Palette.primary, size: 32),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Li segno a mano', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    MutedText(
                        'Dal Calendario, con l\'inserimento rapido: scegli il turno e tocchi i giorni.',
                        size: 15),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepAlarm() {
    final store = StoreScope.of(context);
    final p = store.perms;
    Widget row(String label, bool ok) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: ok ? Palette.primary : Palette.muted),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
            ],
          ),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      children: [
        _title('Ultimo passo: la sveglia',
            'Perché la sveglia suoni anche a telefono bloccato, Android chiede alcuni permessi.'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row('Notifiche', p['notifications'] != false),
              row('Sveglie e promemoria', p['exact'] != false),
              row('Mostra a schermo intero', p['fullScreen'] != false),
              const SizedBox(height: 8),
              if (!store.permissionsOk)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => fixPermissions(context),
                    child: const Text('Concedi permessi'),
                  ),
                )
              else
                const MutedText('Tutto pronto ✓'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          onTap: () async {
            await AlarmBridge.testAlarm(10, store.data.settings);
            if (mounted) toast(context, 'La sveglia di prova suona tra 10 secondi');
          },
          child: const Row(
            children: [
              Icon(Icons.play_circle_outline, color: Palette.primary, size: 32),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prova la sveglia', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    MutedText('Suona tra 10 secondi: blocca il telefono e aspetta', size: 15),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_stepWelcome, _stepTypes, _stepEntry, _stepAlarm];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
              child: Row(
                children: [
                  for (var i = 0; i < steps; i++)
                    Expanded(
                      child: Container(
                        height: 5,
                        margin: EdgeInsets.only(right: i == steps - 1 ? 0 : 6),
                        decoration: BoxDecoration(
                          color: i <= step ? Palette.primary : Palette.line,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: pages[step]()),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
              child: Row(
                children: [
                  if (step > 0)
                    TextButton(onPressed: () => setState(() => step--), child: const Text('Indietro')),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Text(step == steps - 1 ? 'Inizia' : 'Avanti'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
