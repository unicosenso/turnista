// Ricostruisce la tabella del foglio a partire dalle parole lette da ML Kit:
// trova i giorni, segue righe e colonne come si farebbe col dito, e mette ogni sigla nella sua casella.
// Dart puro, provato con i test automatici.

import 'dart:math' as math;

import 'sigle.dart';

/// Una parola letta da ML Kit: testo e i 4 angoli del suo riquadro nella foto.
class ParolaLetta {
  final String testo;
  final List<math.Point<double>> angoli;
  const ParolaLetta(this.testo, this.angoli);
}

/// Una parola "di lavoro": centro, bordo sinistro e destro, e la riga a cui viene assegnata.
class _Parola {
  String t;
  final double x, y, x0;
  double x1;
  int? k; // indice del giorno (riga), null se non appartiene alla tabella
  bool unita = false;
  _Parola(this.t, this.x, this.y, this.x0, this.x1);
}

/// Il risultato: i giorni, le caselle lette e dove sta ogni casella nella foto.
class TabellaLetta {
  final List<DateTime> giorni;
  final List<List<Lettura>> celle; // [giorno][colonna]
  final List<List<double>> colonneX; // [colonna][giorno] = bordo sinistro della casella
  final double rigaPx; // distanza tra due righe, in pixel
  final double Function(int giorno, double x) rigaY; // altezza della riga in un punto
  TabellaLetta(this.giorni, this.celle, this.colonneX, this.rigaPx, this.rigaY);
  int get colonne => colonneX.length;
}

const _mesi = {
  'gen': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'mag': 5, 'giu': 6,
  'lug': 7, 'ago': 8, 'set': 9, 'ott': 10, 'nov': 11, 'dic': 12,
};
final _reData = RegExp(r'(\d{1,2})-([a-z]{3})-(\d{2})');

// ---------- piccoli strumenti di calcolo ----------

double _mediana(List<double> v) {
  final s = [...v]..sort();
  final n = s.length;
  if (n == 0) return 0;
  return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}

/// Retta che passa "il più vicino possibile" ai punti: restituisce [pendenza, quota].
List<double> _retta(List<double> xs, List<double> ys) {
  final n = xs.length;
  final mx = xs.reduce((a, b) => a + b) / n, my = ys.reduce((a, b) => a + b) / n;
  var sxy = 0.0, sxx = 0.0;
  for (var i = 0; i < n; i++) {
    sxy += (xs[i] - mx) * (ys[i] - my);
    sxx += (xs[i] - mx) * (xs[i] - mx);
  }
  final p = sxx == 0 ? 0.0 : sxy / sxx;
  return [p, my - p * mx];
}

/// Valore di una linea spezzata nel punto x (fuori dagli estremi resta il valore estremo).
double _interp(double x, List<double> xs, List<double> ys) {
  if (x <= xs.first) return ys.first;
  if (x >= xs.last) return ys.last;
  var i = 1;
  while (xs[i] < x) {
    i++;
  }
  final t = (x - xs[i - 1]) / (xs[i] - xs[i - 1]);
  return ys[i - 1] + t * (ys[i] - ys[i - 1]);
}

double _clip(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

// ---------- i passi del lettore ----------

/// 1) Le parole, con le sigle attaccate ("CONP1") divise in due.
List<_Parola> _preparaParole(List<ParolaLetta> lette) {
  final out = <_Parola>[];
  for (final w in lette) {
    if (w.angoli.isEmpty) continue;
    final xs = w.angoli.map((p) => p.x).toList(), ys = w.angoli.map((p) => p.y).toList();
    final cx = xs.reduce((a, b) => a + b) / xs.length, cy = ys.reduce((a, b) => a + b) / ys.length;
    final x0 = xs.reduce(math.min), x1 = xs.reduce(math.max);
    final parti = eSigla(w.testo) ? null : dividi(w.testo);
    if (parti != null) {
      // si divide il riquadro in proporzione alla lunghezza delle sigle
      final tot = parti.fold<int>(0, (a, p) => a + p.length);
      var pos = 0;
      for (final p in parti) {
        final xa = x0 + (x1 - x0) * pos / tot;
        pos += p.length;
        final xb = x0 + (x1 - x0) * pos / tot;
        out.add(_Parola(p, (xa + xb) / 2, cy, xa, xb));
      }
    } else {
      out.add(_Parola(w.testo, cx, cy, x0, x1));
    }
  }
  return out;
}

/// 2) Le etichette dei giorni ("lun,12-ott-26"); scarta le date lette male.
List<MapEntry<DateTime, _Parola>> _trovaDate(List<_Parola> parole) {
  final date = <MapEntry<DateTime, _Parola>>[];
  for (final w in parole) {
    final m = _reData.firstMatch(w.t.toLowerCase());
    final mese = m == null ? null : _mesi[m.group(2)];
    if (m != null && mese != null) {
      date.add(MapEntry(DateTime.utc(2000 + int.parse(m.group(3)!), mese, int.parse(m.group(1)!)), w));
    }
  }
  if (date.isEmpty) return date;
  final ordinate = date.map((e) => e.key).toList()..sort();
  final mediana = ordinate[ordinate.length ~/ 2];
  return date.where((e) => e.key.difference(mediana).inDays.abs() <= 20).toList();
}

/// 3) Segue ogni riga partendo dalla data e andando verso destra; poi la corregge
/// guardando le righe vicine (la deformazione della foto cambia gradualmente).
Map<int, List<math.Point<double>>> _seguiRighe(
    List<MapEntry<int, _Parola>> date, List<_Parola> cand, double b) {
  final percorsi = <int, List<math.Point<double>>>{};
  final ordinate = [...cand]..sort((a, c) => a.x.compareTo(c.x));
  for (final d in date) {
    final w0 = d.value;
    final pts = <math.Point<double>>[math.Point(w0.x, w0.y)];
    percorsi[d.key] = pts;
    var pend = 0.0;
    for (final w in ordinate) {
      if (w.x0 < w0.x1 - 5) continue;
      final ul = pts.last;
      final prev = ul.y + pend * (w.x - ul.x);
      if ((w.y - prev).abs() < 0.33 * b) {
        pts.add(math.Point(w.x, w.y));
        if (pts.length >= 3) {
          final ult = pts.sublist(math.max(0, pts.length - 8));
          pend = _clip(_retta(ult.map((p) => p.x).toList(), ult.map((p) => p.y).toList())[0], -0.15, 0.15);
        }
      }
    }
  }
  // La "forma" di ogni riga seguita bene: quanto sale o scende rispetto alla sua data.
  final forma = <int, List<List<double>>>{};
  percorsi.forEach((k, pts) {
    if (pts.length >= 6) {
      final s = [...pts]..sort((a, c) => a.x != c.x ? a.x.compareTo(c.x) : a.y.compareTo(c.y));
      forma[k] = [s.map((p) => p.x).toList(), s.map((p) => p.y - s.first.y).toList()];
    }
  });
  final yData = {for (final d in date) d.key: d.value.y};
  double yPrevista(int k, double x) {
    // (a parità di distanza vince la riga che viene prima: Dart non garantisce l'ordine)
    final chiavi = forma.keys.toList();
    final vicine = [...chiavi]..sort((a, c) {
        final d = (a - k).abs().compareTo((c - k).abs());
        return d != 0 ? d : chiavi.indexOf(a).compareTo(chiavi.indexOf(c));
      });
    final scosti = <double>[];
    for (final kk in vicine.take(4)) {
      final f = forma[kk]!;
      if (f[0].first <= x && x <= f[0].last + 3 * b) scosti.add(_interp(x, f[0], f[1]));
    }
    return yData[k]! + (scosti.isEmpty ? 0.0 : _mediana(scosti));
  }

  for (final w in cand) {
    double? migliore;
    int? kMigliore;
    for (final d in date) {
      final dist = (w.y - yPrevista(d.key, w.x)).abs();
      if (dist < 0.4 * b && (migliore == null || dist < migliore)) {
        migliore = dist;
        kMigliore = d.key;
      }
    }
    w.k = kMigliore;
  }
  // I percorsi definitivi: 40 punti lungo ogni riga.
  final xMin = date.map((d) => d.value.x).reduce(math.min);
  final xMax = cand.map((w) => w.x).reduce(math.max);
  for (final d in date) {
    percorsi[d.key] = [
      for (var i = 0; i < 40; i++)
        () {
          final x = xMin + (xMax - xMin) * i / 39;
          return math.Point(x, yPrevista(d.key, x));
        }(),
    ];
  }
  return percorsi;
}

/// 4) Riattacca le sigle spezzate da ML Kit ("INT" + "2", "P" + "FF").
void _unisciSpezzate(List<_Parola> cand, double b) {
  final righe = cand.where((w) => w.k != null).map((w) => w.k!).toSet();
  for (final k in righe) {
    final riga = cand.where((w) => w.k == k).toList()..sort((a, c) => a.x0.compareTo(c.x0));
    for (var i = 0; i + 1 < riga.length; i++) {
      final a = riga[i], c = riga[i + 1];
      if (c.unita || c.x0 - a.x1 > 0.45 * b) continue;
      final up = a.t.toUpperCase();
      if ((up.startsWith('INT') && c.t.replaceAll('.', '') == '2') ||
          ((up == 'P' || up == 'M') && c.t.toUpperCase() == 'FF')) {
        a.t = a.t + c.t;
        a.x1 = c.x1;
        c.k = null;
        c.unita = true;
      }
    }
  }
}

/// 5) Trova le colonne: parte dalle righe più piene e scende/sale riga per riga
/// seguendo la sigla allineata. Restituisce per ogni colonna la x del bordo sinistro in ogni riga.
List<List<double>> _seguiColonne(List<_Parola> cand, int ngiorni, double b) {
  final perRiga = {
    for (var k = 0; k < ngiorni; k++)
      k: (cand.where((w) => w.k == k).toList()..sort((a, c) => a.x0.compareTo(c.x0))),
  };
  final larg = b * 1.05;
  final piene = perRiga.keys.toList()
    ..sort((a, c) {
      final d = perRiga[c]!.length.compareTo(perRiga[a]!.length);
      return d != 0 ? d : a.compareTo(c);
    });
  final semi = <math.Point<double>>[]; // x = bordo sinistro, y = riga
  for (final k in piene.take(3)) {
    for (final w in perRiga[k]!) {
      if (semi.every((s) => (w.x0 - s.x).abs() > 0.5 * larg || (k - s.y).abs() > 3)) {
        semi.add(math.Point(w.x0, k.toDouble()));
      }
    }
  }
  final tracce = <List<double>>[];
  for (final seme in semi) {
    final kSeme = seme.y.toInt();
    final traccia = List<double>.filled(ngiorni, 0);
    traccia[kSeme] = seme.x;
    for (final direzione in [1, -1]) {
      final pts = <math.Point<double>>[math.Point(kSeme.toDouble(), seme.x)];
      var pend = 0.0;
      for (var k = kSeme + direzione; k >= 0 && k < ngiorni; k += direzione) {
        final ul = pts.last;
        final prev = ul.y + pend * (k - ul.x);
        final vicine = perRiga[k]!.where((w) => (w.x0 - prev).abs() < 0.4 * larg).toList();
        if (vicine.isNotEmpty) {
          vicine.sort((a, c) => (a.x0 - prev).abs().compareTo((c.x0 - prev).abs()));
          final w = vicine.first;
          pts.add(math.Point(k.toDouble(), w.x0));
          if (pts.length >= 3) {
            final ult = pts.sublist(math.max(0, pts.length - 8));
            pend = _clip(_retta(ult.map((p) => p.x).toList(), ult.map((p) => p.y).toList())[0], -15, 15);
          }
          traccia[k] = w.x0;
        } else {
          traccia[k] = prev;
        }
      }
    }
    tracce.add(traccia);
  }
  double media(List<double> t) => t.reduce((a, b) => a + b) / t.length;
  tracce.sort((a, c) => media(a).compareTo(media(c)));
  final uniche = <List<double>>[];
  for (final t in tracce) {
    if (uniche.isEmpty ||
        _mediana([for (var k = 0; k < ngiorni; k++) (t[k] - uniche.last[k]).abs()]) > 0.5 * larg) {
      uniche.add(t);
    }
  }
  return uniche;
}

/// Il lettore completo della tabella (senza guardare i pixel).
/// Restituisce null se il foglio non sembra quello dei turni (es. date non trovate).
TabellaLetta? leggiTabella(List<ParolaLetta> lette) {
  final parole = _preparaParole(lette);
  final dateG = _trovaDate(parole);
  if (dateG.length < 5) return null;
  // Il foglio va sempre da un lunedì a una domenica: se la prima o l'ultima data non si
  // sono lette, si allarga lo stesso a settimane intere (le righe mancanti si ricostruiscono).
  var primo = dateG.map((e) => e.key).reduce((a, c) => a.isBefore(c) ? a : c);
  primo = primo.subtract(Duration(days: primo.weekday - 1));
  var ultimo = dateG.map((e) => e.key).reduce((a, c) => a.isAfter(c) ? a : c);
  ultimo = ultimo.add(Duration(days: 7 - ultimo.weekday));
  var date = [for (final e in dateG) MapEntry(e.key.difference(primo).inDays, e.value)];
  final ks = date.map((d) => d.key.toDouble()).toList(), yd = date.map((d) => d.value.y).toList();
  var r = _retta(ks, yd);
  final res = [for (var i = 0; i < ks.length; i++) (yd[i] - (r[1] + r[0] * ks[i])).abs()];
  final soglia = [_mediana(res) * 3, 5.0, 0.2 * r[0]].reduce(math.max);
  final buone = [for (var i = 0; i < ks.length; i++) res[i] < soglia];
  r = _retta([for (var i = 0; i < ks.length; i++) if (buone[i]) ks[i]],
      [for (var i = 0; i < ks.length; i++) if (buone[i]) yd[i]]);
  final b = r[0];
  if (b <= 0) return null;
  date = [for (var i = 0; i < date.length; i++) if (buone[i]) date[i]];
  final ngiorni = ultimo.difference(primo).inDays + 1;
  // Giorni la cui data non si è letta: un'etichetta "finta" a metà tra le vicine.
  final presenti = {for (final d in date) d.key: d.value};
  final fineMediana = _mediana(presenti.values.map((w) => w.x1).toList());
  for (var kk = 0; kk < ngiorni; kk++) {
    if (presenti.containsKey(kk)) continue;
    final prima = presenti.keys.where((p) => p < kk).fold<int?>(null, (a, p) => a == null || p > a ? p : a);
    final dopo = presenti.keys.where((p) => p > kk).fold<int?>(null, (a, p) => a == null || p < a ? p : a);
    double x, y;
    if (prima != null && dopo != null) {
      final t = (kk - prima) / (dopo - prima);
      y = presenti[prima]!.y + t * (presenti[dopo]!.y - presenti[prima]!.y);
      x = presenti[prima]!.x + t * (presenti[dopo]!.x - presenti[prima]!.x);
    } else {
      final vic = prima ?? dopo!;
      y = presenti[vic]!.y + (kk - vic) * b;
      x = presenti[vic]!.x;
    }
    date.add(MapEntry(kk, _Parola('', x, y, x, fineMediana)));
  }
  date.sort((a, c) => a.key.compareTo(c.key));
  final fineDate = date.map((d) => d.value.x1).reduce(math.max);
  final tutteY = date.map((d) => d.value.y);
  final yMin = tutteY.reduce(math.min) - 0.6 * b, yMax = tutteY.reduce(math.max) + 0.6 * b;
  final etichette = date.map((d) => d.value).toSet();
  // Una parola fa parte della tabella se sta a destra dell'etichetta della SUA riga
  // (non di tutte: con la foto storta le etichette in basso finiscono più a sinistra).
  double fineEtichetta(double y) {
    var vicina = date.first.value;
    for (final d in date) {
      if ((d.value.y - y).abs() < (vicina.y - y).abs()) vicina = d.value;
    }
    return vicina.t.isEmpty ? fineDate : vicina.x1;
  }

  final cand = parole
      .where((w) =>
          w.y > yMin && w.y < yMax + 0.2 * b && w.x0 > fineEtichetta(w.y) - 5 && !etichette.contains(w))
      .toList();
  if (cand.isEmpty) return null;

  // Le etichette dei giorni sono scritte un po' più in alto delle sigle della stessa riga:
  // si misura di quanto (guardando le prime caselle) e si spostano le etichette di conseguenza.
  final scarti = <double>[];
  for (final w in cand.where((w) => w.x0 < fineDate + 3 * b)) {
    var d = double.infinity;
    for (final e in date) {
      final v = w.y - e.value.y;
      if (v.abs() < d.abs()) d = v;
    }
    if (d.abs() < 0.5 * b) scarti.add(d);
  }
  final spost = scarti.length >= 5 ? _mediana(scarti) : 0.0;
  date = [for (final e in date) MapEntry(e.key, _Parola(e.value.t, e.value.x, e.value.y + spost, e.value.x0, e.value.x1))];
  final percorsi = _seguiRighe(date, cand, b);
  _unisciSpezzate(cand, b);
  final colonne = _seguiColonne(cand.where((w) => w.k != null).toList(), ngiorni, b);

  // Ogni parola nella sua casella.
  final larg = b * 1.05;
  final griglia = List.generate(ngiorni, (_) => List.generate(colonne.length, (_) => <_Parola>[]));
  for (final w in cand) {
    if (w.k == null || colonne.isEmpty) continue;
    var j = 0;
    var dmin = double.infinity;
    for (var c = 0; c < colonne.length; c++) {
      final d = (w.x0 - colonne[c][w.k!]).abs();
      if (d < dmin) {
        dmin = d;
        j = c;
      }
    }
    if (dmin < 0.45 * larg) griglia[w.k!][j].add(w);
  }
  final celle = [
    for (final riga in griglia)
      [
        for (final cella in riga)
          () {
            final testo = (cella..sort((a, c) => a.x.compareTo(c.x))).map((w) => w.t).join();
            final l = normalizza(testo);
            // Casella vuota: quasi sempre un riposo "r" non letto. Lo si propone, da controllare.
            return l.sigla.isEmpty ? const Lettura('r', false) : l;
          }(),
      ],
  ];

  // Altezza di una riga in un punto x, seguendo il suo percorso.
  double rigaY(int k, double x) {
    final pts = percorsi[k];
    if (pts == null || pts.length < 2) {
      final chiavi = percorsi.keys.where((kk) => percorsi[kk]!.length >= 2).toList();
      final vic = [...chiavi]
        ..sort((a, c) {
          final d = (a - k).abs().compareTo((c - k).abs());
          return d != 0 ? d : chiavi.indexOf(a).compareTo(chiavi.indexOf(c));
        });
      final kk = vic.first;
      return rigaY(kk, x) + (k - kk) * b;
    }
    final s = [...pts]..sort((a, c) => a.x.compareTo(c.x));
    final xs = s.map((p) => p.x).toList(), ys = s.map((p) => p.y).toList();
    if (x > xs.last) {
      final p = xs.length >= 4 ? _retta(xs.sublist(xs.length - 4), ys.sublist(ys.length - 4))[0] : 0.0;
      return ys.last + p * (x - xs.last);
    }
    return _interp(x, xs, ys);
  }

  final giorni = [for (var i = 0; i < ngiorni; i++) primo.add(Duration(days: i))];
  return TabellaLetta(giorni, celle, colonne, b, rigaY);
}

/// Altezza tipica delle sigle maiuscole (es. "M1"), presa dai riquadri di ML Kit:
/// serve a capire quanto è grande una lettera in questa foto.
double altezzaLettere(List<ParolaLetta> lette) {
  const tipiche = {'M1', 'M2', 'M3', 'P0', 'P1', 'P2', 'P3', 'N1', 'N2', 'N3', 'PR'};
  final alt = <double>[];
  for (final w in lette) {
    if (tipiche.contains(w.testo.toUpperCase()) && w.angoli.isNotEmpty) {
      final ys = w.angoli.map((p) => p.y);
      alt.add(ys.reduce(math.max) - ys.reduce(math.min));
    }
  }
  return alt.isEmpty ? 0 : _mediana(alt);
}
