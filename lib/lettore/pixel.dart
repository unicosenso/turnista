// Guarda direttamente i pixel di una casella: riconosce i riposi "r" che ML Kit non legge
// e si accorge delle correzioni a penna (inchiostro in più o blu).
// Dart puro: lavora su un'immagine già decodificata (un byte di grigio per pixel + colori).

import 'dart:typed_data';

/// Un'immagine semplice: larghezza, altezza e i pixel in RGB (3 byte per pixel).
class Immagine {
  final int larghezza, altezza;
  final Uint8List rgb;
  late final Uint8List grigio = _calcolaGrigio();
  Immagine(this.larghezza, this.altezza, this.rgb);

  Uint8List _calcolaGrigio() {
    final g = Uint8List(larghezza * altezza);
    for (var i = 0, j = 0; i < g.length; i++, j += 3) {
      // stessa formula di OpenCV per passare dal colore al grigio
      g[i] = (0.299 * rgb[j] + 0.587 * rgb[j + 1] + 0.114 * rgb[j + 2]).round();
    }
    return g;
  }
}

/// Un ritaglio in bianco e nero: true = inchiostro.
class _Ritaglio {
  final int x0, y0, w, h;
  final List<bool> nero;
  _Ritaglio(this.x0, this.y0, this.w, this.h, this.nero);
  bool at(int x, int y) => nero[y * w + x];
}

/// Ritaglia la zona e la trasforma in bianco e nero "adattivo": un pixel è inchiostro se è
/// più scuro di 12 rispetto alla media dei vicini (finestra 31×31). Così reggono ombre e caselle grigie.
/// Poi cancella le linee della tabella (tratti lunghi orizzontali o verticali).
_Ritaglio? _ritaglia(Immagine img, int x0, int y0, int x1, int y1) {
  if (x0 < 0 || y0 < 0 || x1 >= img.larghezza || y1 >= img.altezza || x1 <= x0 || y1 <= y0) return null;
  final w = x1 - x0, h = y1 - y0;
  // tabella delle somme per calcolare velocemente la media di ogni finestra (bordi "ripetuti")
  const r = 15;
  final pw = w + 2 * r, ph = h + 2 * r;
  final somme = Int32List((pw + 1) * (ph + 1));
  for (var y = 0; y < ph; y++) {
    final sy = y0 + (y - r).clamp(0, h - 1);
    var riga = 0;
    for (var x = 0; x < pw; x++) {
      final sx = x0 + (x - r).clamp(0, w - 1);
      riga += img.grigio[sy * img.larghezza + sx];
      somme[(y + 1) * (pw + 1) + x + 1] = somme[y * (pw + 1) + x + 1] + riga;
    }
  }
  final nero = List<bool>.filled(w * h, false);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final a = y * (pw + 1) + x, b = (y + 2 * r + 1) * (pw + 1) + x;
      final s = somme[b + 2 * r + 1] - somme[b] - somme[a + 2 * r + 1] + somme[a];
      final media = (s / ((2 * r + 1) * (2 * r + 1))).round();
      nero[y * w + x] = img.grigio[(y0 + y) * img.larghezza + x0 + x] <= media - 12;
    }
  }
  // Linee: un tratto continuo lungo almeno il 60% del ritaglio (o che tocca il bordo e
  // potrebbe continuare fuori) è una linea della tabella, non una lettera.
  final linea = List<bool>.filled(w * h, false);
  final lh = (0.6 * w).toInt().clamp(1, w), lv = (0.6 * h).toInt().clamp(1, h);
  for (var y = 0; y < h; y++) {
    var x = 0;
    while (x < w) {
      if (!nero[y * w + x]) {
        x++;
        continue;
      }
      var e = x;
      while (e < w && nero[y * w + e]) {
        e++;
      }
      if (e - x >= lh || x == 0 || e == w) {
        for (var i = x; i < e; i++) {
          linea[y * w + i] = true;
        }
      }
      x = e;
    }
  }
  for (var x = 0; x < w; x++) {
    var y = 0;
    while (y < h) {
      if (!nero[y * w + x]) {
        y++;
        continue;
      }
      var e = y;
      while (e < h && nero[e * w + x]) {
        e++;
      }
      if (e - y >= lv || y == 0 || e == h) {
        for (var i = y; i < e; i++) {
          linea[i * w + x] = true;
        }
      }
      y = e;
    }
  }
  for (var i = 0; i < nero.length; i++) {
    if (linea[i]) nero[i] = false;
  }
  return _Ritaglio(x0, y0, w, h, nero);
}

/// Una "macchia" d'inchiostro: un gruppo di pixel neri che si toccano.
class _Macchia {
  int x0 = 1 << 30, y0 = 1 << 30, x1 = -1, y1 = -1, area = 0;
  int get w => x1 - x0 + 1;
  int get h => y1 - y0 + 1;
}

List<_Macchia> _macchie(_Ritaglio r) {
  final visto = List<bool>.filled(r.w * r.h, false);
  final out = <_Macchia>[];
  final pila = <int>[];
  for (var i = 0; i < visto.length; i++) {
    if (!r.nero[i] || visto[i]) continue;
    final m = _Macchia();
    pila.add(i);
    visto[i] = true;
    while (pila.isNotEmpty) {
      final p = pila.removeLast();
      final x = p % r.w, y = p ~/ r.w;
      m.area++;
      if (x < m.x0) m.x0 = x;
      if (x > m.x1) m.x1 = x;
      if (y < m.y0) m.y0 = y;
      if (y > m.y1) m.y1 = y;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= r.w || ny >= r.h) continue;
          final q = ny * r.w + nx;
          if (r.nero[q] && !visto[q]) {
            visto[q] = true;
            pila.add(q);
          }
        }
      }
    }
    out.add(m);
  }
  return out;
}

enum Contenuto { riposo, vuota, altro, fuori }

/// Guarda una casella in cui ML Kit non ha letto niente e dice cosa contiene.
/// [cx0] bordo sinistro della casella, [cy] centro della riga, [b] altezza riga, [hc] altezza lettere.
Contenuto guardaCasella(Immagine img, double cx0, double cy, double b, double hc) {
  final larg = b * 1.05;
  final r = _ritaglia(img, (cx0 - 0.15 * larg).toInt(), (cy - 0.42 * b).toInt(),
      (cx0 + 0.75 * larg).toInt(), (cy + 0.42 * b).toInt());
  if (r == null) return Contenuto.fuori;
  final sottile = hc * 0.12 < 2 ? 2 : hc * 0.12;
  final macchie = _macchie(r)
      .where((m) => !(m.w <= sottile || m.h <= sottile) && m.area >= 0.08 * hc * hc)
      .toList();
  if (macchie.isEmpty) return Contenuto.vuota;
  // una "r": un segno solo, non tagliato dal bordo, alto poco meno di una maiuscola e stretto
  if (macchie.length == 1) {
    final m = macchie.first;
    final bordo = m.x0 == 0 || m.y0 == 0 || m.x1 >= r.w - 1 || m.y1 >= r.h - 1;
    if (!bordo &&
        m.h >= 0.6 * hc && m.h <= 1.0 * hc &&
        m.w >= 0.3 * hc && m.w <= 0.65 * hc &&
        m.area >= 0.12 * hc * hc && m.area <= 0.35 * hc * hc) {
      return Contenuto.riposo;
    }
  }
  return Contenuto.altro;
}

/// Quanto inchiostro c'è in una casella, e quanto di questo è blu (penna).
({int totale, int blu}) inchiostro(Immagine img, double cx0, double cy, double b) {
  final larg = b * 1.05;
  final r = _ritaglia(img, (cx0 - 0.15 * larg).toInt(), (cy - 0.5 * b).toInt(),
      (cx0 + 0.85 * larg).toInt(), (cy + 0.42 * b).toInt());
  if (r == null) return (totale: 0, blu: 0);
  var totale = 0, blu = 0;
  for (var y = 0; y < r.h; y++) {
    for (var x = 0; x < r.w; x++) {
      if (!r.at(x, y)) continue;
      totale++;
      final j = ((r.y0 + y) * img.larghezza + r.x0 + x) * 3;
      if (_eBlu(img.rgb[j], img.rgb[j + 1], img.rgb[j + 2])) blu++;
    }
  }
  return (totale: totale, blu: blu);
}

/// Blu "da penna": tinta tra 190° e 270° e colore abbastanza acceso (come in OpenCV: H 95–135, S > 70).
bool _eBlu(int r, int g, int b) {
  final mx = [r, g, b].reduce((a, c) => a > c ? a : c), mn = [r, g, b].reduce((a, c) => a < c ? a : c);
  if (mx == 0) return false;
  final s = 255 * (mx - mn) / mx;
  if (s <= 70 || mx == mn) return false;
  double h;
  if (mx == r) {
    h = 60 * (g - b) / (mx - mn);
  } else if (mx == g) {
    h = 120 + 60 * (b - r) / (mx - mn);
  } else {
    h = 240 + 60 * (r - g) / (mx - mn);
  }
  if (h < 0) h += 360;
  return h / 2 > 95 && h / 2 < 135;
}
