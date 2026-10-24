// Test del lettore del foglio: le parole lette da ML Kit su due foto vere devono dare
// esattamente la stessa tabella del prototipo collaudato al computer.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;
import 'package:turnista/lettore/geometria.dart';
import 'package:turnista/lettore/lettore_foglio.dart' show leggiFoglio;
import 'package:turnista/lettore/pixel.dart';
import 'package:turnista/lettore/sigle.dart';

List<ParolaLetta> caricaParole(String nome) {
  final j = jsonDecode(File('test/fixtures/${nome}_parole.json').readAsStringSync());
  return [
    for (final w in j['parole'] as List)
      ParolaLetta(w['t'] as String, [
        for (final a in w['angoli'] as List) math.Point((a[0] as num).toDouble(), (a[1] as num).toDouble()),
      ]),
  ];
}

void confronta(String nome) {
  final righe = File('test/fixtures/${nome}_atteso.txt').readAsLinesSync();
  final intest = righe.first.split(' ');
  final t = leggiTabella(caricaParole(nome))!;
  expect(t.giorni.first.toIso8601String().substring(0, 10), intest[0]);
  expect(t.giorni.length, int.parse(intest[1]));
  expect(t.colonne, int.parse(intest[2]));
  var diverse = 0;
  for (var k = 0; k < t.giorni.length; k++) {
    final attese = righe[k + 1].split(' ');
    final lette = t.celle[k].map((c) => c.toString()).toList();
    for (var j = 0; j < attese.length; j++) {
      if (lette[j] != attese[j]) {
        diverse++;
        // ignore: avoid_print
        print('$nome giorno $k colonna $j: letto ${lette[j]} atteso ${attese[j]}');
      }
    }
  }
  expect(diverse, 0);
}

void main() {
  test('sigle: correzioni tipiche', () {
    expect(normalizza('M1').toString(), 'M1');
    expect(normalizza('Mi').toString(), 'M1?');
    expect(normalizza('INT.2').toString(), 'INT2');
    expect(normalizza('').sigla, '');
    expect(dividi('CONP1'), ['CON', 'P1']);
    expect(dividi('M1'), null);
    expect(dividi('CONCONr'), ['CON', 'CON', 'r']);
    expect(dividi('CONCONP'), ['CON', 'CON', 'P']);
    expect(dividi('rls'), null);
    expect(normalizza('PO').toString(), 'P0');
  });

  test('foglio in bacheca (gennaio)', () => confronta('bacheca'));
  test('foglio sul tavolo (settembre)', () => confronta('settembre'));
  test('foglio di agosto (prima riga senza data, sigle attaccate)', () => confronta('agosto'));
  test('agosto letto dal telefono (sigle spezzate, niente colonna fantasma)', () => confronta('agosto2'));

  test('agosto dal telefono, lettura completa coi pixel: nessuna casella sbagliata data per sicura', () {
    // la foto vera, portata alle stesse misure su cui ML Kit ha letto le parole
    final j = jsonDecode(File('test/fixtures/agosto2_parole.json').readAsStringSync());
    var foto = im.decodeJpg(File('test/fixtures/agosto2_foto.jpg').readAsBytesSync())!;
    foto = im.copyResize(foto, width: j['larghezza'] as int, height: j['altezza'] as int);
    final img = Immagine(foto.width, foto.height, foto.convert(numChannels: 3).getBytes(order: im.ChannelOrder.rgb));
    final f = leggiFoglio(caricaParole('agosto2'), img)!;
    final verita = File('test/fixtures/agosto2_verita.txt').readAsLinesSync().map((r) => r.split(' ')).toList();
    var sicureGiuste = 0, nascoste = 0;
    for (var k = 0; k < f.giorni.length; k++) {
      for (var c = 0; c < f.colonne; c++) {
        final l = f.celle[k][c];
        if (!l.sicura) continue;
        if (l.sigla == verita[k][c]) {
          sicureGiuste++;
        } else {
          nascoste++;
          // ignore: avoid_print
          print('errore nascosto giorno $k colonna ${c + 1}: letto ${l.sigla} vero ${verita[k][c]}');
        }
      }
    }
    // ignore: avoid_print
    print('agosto2 completo: sicure giuste $sicureGiuste su ${f.totale}, errori nascosti $nascoste');
    expect(f.colonne, 18);
    expect(nascoste, 0);
    expect(sicureGiuste, greaterThan(380));
  });

  test('pixel: riconosce una "r" e ignora le linee della tabella', () {
    // Immagine finta 200x100 bianca, con una linea orizzontale e una "r" disegnata a mano.
    const w = 200, h = 100;
    final rgb = Uint8List(w * h * 3)..fillRange(0, w * h * 3, 240);
    void nero(int x, int y) {
      final i = (y * w + x) * 3;
      rgb[i] = rgb[i + 1] = rgb[i + 2] = 20;
    }
    for (var x = 0; x < w; x++) {
      nero(x, 20);
      nero(x, 80);
    }
    // la "r": asta verticale 3x12 e trattino in alto a destra
    for (var y = 44; y < 56; y++) {
      for (var x = 50; x < 53; x++) {
        nero(x, y);
      }
    }
    for (var x = 53; x < 57; x++) {
      for (var y = 44; y < 47; y++) {
        nero(x, y);
      }
    }
    final img = Immagine(w, h, rgb);
    expect(guardaCasella(img, 48, 50, 60, 16), Contenuto.riposo);
    expect(guardaCasella(img, 120, 50, 60, 16), Contenuto.vuota);
  });
}
