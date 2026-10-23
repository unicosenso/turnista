// Dal file della foto al foglio letto: prepara l'immagine, la fa leggere a ML Kit (sul telefono,
// senza internet) e passa il risultato al lettore. I lavori pesanti girano in un "isolate",
// cioè in parallelo, così l'app non si blocca mentre legge.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as im;

import 'lettore_foglio.dart';

class EsitoLettura {
  final FoglioLetto? foglio;
  final String? errore;
  final int millisecondi;
  final String? foto; // la foto esattamente come l'ha vista ML Kit
  final String? dati; // le parole lette, per studiarle al computer
  const EsitoLettura({this.foglio, this.errore, required this.millisecondi, this.foto, this.dati});
}

/// Raddrizza la foto secondo come era tenuto il telefono. La si rimpicciolisce solo se è
/// davvero enorme: ML Kit legge meglio le sigle piccole a piena risoluzione.
/// Restituisce la foto pronta (in JPEG, per ML Kit) e i suoi pixel (per il controllo delle caselle).
Map<String, Object> _preparaImmagine(Uint8List byte) {
  var foto = im.decodeImage(byte);
  if (foto == null) throw const FormatException('Foto non leggibile');
  foto = im.bakeOrientation(foto);
  const massimo = 4096;
  if (math.max(foto.width, foto.height) > massimo) {
    foto = foto.width >= foto.height ? im.copyResize(foto, width: massimo) : im.copyResize(foto, height: massimo);
  }
  final rgb = foto.convert(numChannels: 3).getBytes(order: im.ChannelOrder.rgb);
  return {
    'jpg': Uint8List.fromList(im.encodeJpg(foto, quality: 92)),
    'w': foto.width,
    'h': foto.height,
    'rgb': rgb,
  };
}

FoglioLetto? _leggi(Map<String, Object> dati) {
  return leggiFoglio(dati['parole'] as List<ParolaLetta>,
      Immagine(dati['w'] as int, dati['h'] as int, dati['rgb'] as Uint8List));
}

Future<EsitoLettura> leggiFotoFoglio(String percorso) async {
  final inizio = DateTime.now();
  int ms() => DateTime.now().difference(inizio).inMilliseconds;
  final lettore = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final pronta = await compute(_preparaImmagine, await File(percorso).readAsBytes());
    final tmp = File('${Directory.systemTemp.path}/foglio_pronto.jpg');
    await tmp.writeAsBytes(pronta['jpg'] as Uint8List, flush: true);

    final testo = await lettore.processImage(InputImage.fromFilePath(tmp.path));
    final parole = <ParolaLetta>[
      for (final blocco in testo.blocks)
        for (final riga in blocco.lines)
          for (final parola in riga.elements)
            ParolaLetta(parola.text, [
              for (final p in parola.cornerPoints) math.Point(p.x.toDouble(), p.y.toDouble()),
            ]),
    ];
    final foglio = await compute(_leggi, {
      'parole': parole,
      'w': pronta['w']!,
      'h': pronta['h']!,
      'rgb': pronta['rgb']!,
    });
    // Si salvano anche le parole lette, nello stesso formato della vecchia app di prova.
    final datiFile = File('${Directory.systemTemp.path}/foglio_dati.json');
    await datiFile.writeAsString(jsonEncode({
      'app': 'TurniRSP',
      'passate': [
        {
          'rotazione': 0,
          'larghezza': pronta['w'],
          'altezza': pronta['h'],
          'parole': [
            for (final w in parole)
              {
                't': w.testo,
                'angoli': [for (final p in w.angoli) [p.x.round(), p.y.round()]],
              },
          ],
        },
      ],
    }));
    if (foglio == null) {
      return EsitoLettura(
          errore: 'Non trovo le date del foglio turni. Prova con una foto più dritta e più vicina.',
          millisecondi: ms(),
          foto: tmp.path,
          dati: datiFile.path);
    }
    return EsitoLettura(foglio: foglio, millisecondi: ms(), foto: tmp.path, dati: datiFile.path);
  } catch (e) {
    return EsitoLettura(errore: 'Errore durante la lettura: $e', millisecondi: ms());
  } finally {
    await lettore.close();
  }
}
