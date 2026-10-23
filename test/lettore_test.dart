// Test del lettore del foglio: le parole lette da ML Kit su due foto vere devono dare
// esattamente la stessa tabella del prototipo collaudato al computer.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:turnista/lettore/geometria.dart';
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
