// Schermata di PROVA del lettore del foglio garagisti (TurniRSP):
// scatti o scegli una foto, l'app la legge e mostra la tabella con le caselle sicure e quelle da controllare.
// Toccando il numero di una colonna la si evidenzia ("questa è la mia").

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'lettore/da_foto.dart';
import 'lettore/lettore_foglio.dart';
import 'ui.dart';

class ProvaLettorePage extends StatefulWidget {
  const ProvaLettorePage({super.key});
  @override
  State<ProvaLettorePage> createState() => _ProvaLettorePageState();
}

class _ProvaLettorePageState extends State<ProvaLettorePage> {
  bool _inCorso = false;
  EsitoLettura? _esito;
  int? _mia; // colonna scelta

  Future<void> _carica(ImageSource da) async {
    final foto = await ImagePicker().pickImage(source: da);
    if (foto == null) return;
    setState(() {
      _inCorso = true;
      _esito = null;
    });
    final esito = await leggiFotoFoglio(foto.path);
    if (!mounted) return;
    setState(() {
      _inCorso = false;
      _esito = esito;
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = _esito?.foglio;
    return Scaffold(
      appBar: AppBar(title: const Text('Prova lettura foglio')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _inCorso ? null : () => _carica(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Scatta'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _inCorso ? null : () => _carica(ImageSource.gallery),
                icon: const Icon(Icons.image_outlined),
                label: const Text('Galleria'),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          if (_inCorso)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Column(children: [
                CircularProgressIndicator(color: Palette.primary),
                SizedBox(height: 12),
                Text('Sto leggendo il foglio…'),
              ]),
            ),
          if (_esito?.errore != null)
            AppCard(color: Palette.errorBg, child: Text(_esito!.errore!, style: const TextStyle(fontSize: 15))),
          if (_esito?.foto != null && _esito?.dati != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: () => Share.shareXFiles(
                    [XFile(_esito!.foto!, mimeType: 'image/jpeg'), XFile(_esito!.dati!, mimeType: 'application/json')],
                    subject: 'TurniRSP: foto e dati letti'),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Invia foto e dati (per controllo)'),
              ),
            ),
          if (f != null) ...[
            _Riepilogo(foglio: f, ms: _esito!.millisecondi),
            const SizedBox(height: 12),
            const MutedText('Arancio = da controllare. Tocca il numero di una colonna per evidenziarla.', size: 13),
            const SizedBox(height: 8),
            _Tabella(foglio: f, mia: _mia, scegli: (c) => setState(() => _mia = _mia == c ? null : c)),
          ],
        ],
      ),
    );
  }
}

class _Riepilogo extends StatelessWidget {
  final FoglioLetto foglio;
  final int ms;
  const _Riepilogo({required this.foglio, required this.ms});
  @override
  Widget build(BuildContext context) {
    final pct = foglio.totale == 0 ? 0 : (100 * foglio.daControllare / foglio.totale).round();
    String d(DateTime g) => '${g.day}/${g.month}';
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Text(
        'Dal ${d(foglio.giorni.first)} al ${d(foglio.giorni.last)} · ${foglio.colonne} colonne\n'
        'Da controllare: ${foglio.daControllare} caselle su ${foglio.totale} ($pct%)\n'
        'Tempo: ${(ms / 1000).toStringAsFixed(1)} s',
        style: const TextStyle(fontSize: 15, height: 1.4),
      ),
    );
  }
}

class _Tabella extends StatelessWidget {
  final FoglioLetto foglio;
  final int? mia;
  final ValueChanged<int> scegli;
  const _Tabella({required this.foglio, required this.mia, required this.scegli});

  static const _gg = ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'];

  @override
  Widget build(BuildContext context) {
    Widget cella(String testo, {Color? sfondo, bool grassetto = false, double larg = 44, VoidCallback? tap}) {
      final c = Container(
        width: larg,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: sfondo, border: Border.all(color: Palette.line, width: 0.5)),
        child: Text(testo,
            style: TextStyle(fontSize: 12, fontWeight: grassetto ? FontWeight.w800 : FontWeight.w500)),
      );
      return tap == null ? c : InkWell(onTap: tap, child: c);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          cella('', larg: 64),
          for (var c = 0; c < foglio.colonne; c++)
            cella('${c + 1}',
                grassetto: true,
                sfondo: c == mia ? Palette.primarySoft : null,
                tap: () => scegli(c)),
        ]),
        for (var k = 0; k < foglio.giorni.length; k++)
          Row(children: [
            cella('${_gg[foglio.giorni[k].weekday - 1]} ${foglio.giorni[k].day}', larg: 64, grassetto: true),
            for (var c = 0; c < foglio.colonne; c++)
              cella(
                foglio.celle[k][c].sicura ? foglio.celle[k][c].sigla : '${foglio.celle[k][c].sigla}?',
                sfondo: !foglio.celle[k][c].sicura
                    ? const Color(0xFFFFD8B0)
                    : (c == mia ? Palette.primarySoft : Colors.white),
                grassetto: c == mia,
              ),
          ]),
      ]),
    );
  }
}
