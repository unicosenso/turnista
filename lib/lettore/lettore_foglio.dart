// Il lettore completo del foglio turni: unisce la tabella ricostruita dalle parole di ML Kit
// con il controllo dei pixel (riposi non letti e correzioni a penna).

import 'geometria.dart';
import 'pixel.dart';
import 'sigle.dart';

export 'geometria.dart' show ParolaLetta, TabellaLetta;
export 'pixel.dart' show Immagine;
export 'sigle.dart' show Lettura, sigleValide;

class FoglioLetto {
  final List<DateTime> giorni;
  final List<List<Lettura>> celle; // [giorno][colonna]
  FoglioLetto(this.giorni, this.celle);
  int get colonne => celle.isEmpty ? 0 : celle.first.length;

  int get totale => giorni.length * colonne;
  int get daControllare => celle.expand((r) => r).where((c) => !c.sicura).length;
}

/// [parole]: quello che ML Kit ha letto nella foto [img] (stesse coordinate).
FoglioLetto? leggiFoglio(List<ParolaLetta> parole, Immagine img) {
  final t = leggiTabella(parole);
  if (t == null) return null;
  final b = t.rigaPx;
  final hc = altezzaLettere(parole);
  final celle = <List<Lettura>>[];

  // 1) Caselle in cui ML Kit non ha letto niente: si guardano i pixel.
  for (var k = 0; k < t.giorni.length; k++) {
    final riga = <Lettura>[];
    for (var j = 0; j < t.colonne; j++) {
      final l = t.celle[k][j];
      if (l.sigla == 'r' && !l.sicura && hc > 0) {
        final cx0 = t.colonneX[j][k];
        final esito = guardaCasella(img, cx0, t.rigaY(k, cx0 + 0.3 * b), b, hc);
        riga.add(esito == Contenuto.riposo ? const Lettura('r', true) : const Lettura('?', false));
      } else {
        riga.add(l);
      }
    }
    celle.add(riga);
  }

  // 2) Cifre confuse da ML Kit (capita che legga "N2" dove c'è "N3"): si ritaglia l'ultima
  // cifra di ogni sigla e la si confronta con la "cifra media" di ogni numero nella stessa foto.
  // Se somiglia molto di più a un altro numero, si propone quello, ma come da controllare.
  if (hc > 0) {
    final reSigla = RegExp(r'^[MPN][0-3]$');
    final glifi = <(int, int), List<double>>{};
    final perCifra = <String, List<List<double>>>{};
    for (var k = 0; k < t.giorni.length; k++) {
      for (var j = 0; j < t.colonne; j++) {
        final l = celle[k][j];
        if (!l.sicura || !reSigla.hasMatch(l.sigla)) continue;
        final cx0 = t.colonneX[j][k];
        final g = cifra(img, cx0, t.rigaY(k, cx0 + 0.3 * b), b, hc);
        if (g == null) continue;
        glifi[(k, j)] = g;
        perCifra.putIfAbsent(l.sigla[1], () => []).add(g);
      }
    }
    final modelli = <String, List<double>>{
      for (final e in perCifra.entries)
        if (e.value.length >= 3)
          e.key: [for (var i = 0; i < 192; i++) e.value.fold<double>(0, (a, g) => a + g[i]) / e.value.length],
    };
    double distanza(List<double> a, List<double> c) {
      var s = 0.0;
      for (var i = 0; i < 192; i++) {
        s += (a[i] - c[i]).abs();
      }
      return s / 192;
    }
    glifi.forEach((pos, g) {
      final l = celle[pos.$1][pos.$2];
      final mia = modelli[l.sigla[1]];
      if (mia == null) return;
      final dMia = distanza(g, mia);
      String? meglio;
      var dMeglio = dMia;
      for (final e in modelli.entries) {
        final d = distanza(g, e.value);
        if (d < dMeglio) {
          dMeglio = d;
          meglio = e.key;
        }
      }
      if (meglio != null && dMeglio < 0.85 * dMia) {
        celle[pos.$1][pos.$2] = Lettura(l.sigla[0] + meglio, false);
      }
    });
  }

  // 3) Correzioni a penna: una casella con molto più inchiostro del solito per quella sigla,
  // o con inchiostro blu, diventa "da controllare" anche se la sigla stampata è stata letta.
  if (hc > 0) {
    final misure = <(int, int), ({int totale, int blu})>{};
    final perSigla = <String, List<int>>{};
    for (var k = 0; k < t.giorni.length; k++) {
      for (var j = 0; j < t.colonne; j++) {
        final cx0 = t.colonneX[j][k];
        final m = inchiostro(img, cx0, t.rigaY(k, cx0 + 0.3 * b), b);
        misure[(k, j)] = m;
        perSigla.putIfAbsent(celle[k][j].sigla, () => []).add(m.totale);
      }
    }
    final tipico = <String, double>{};
    perSigla.forEach((s, v) {
      if (v.length >= 3) {
        v.sort();
        tipico[s] = v.length.isOdd ? v[v.length ~/ 2].toDouble() : (v[v.length ~/ 2 - 1] + v[v.length ~/ 2]) / 2;
      }
    });
    final area = hc * hc;
    misure.forEach((pos, m) {
      final l = celle[pos.$1][pos.$2];
      if (!l.sicura) return;
      final rif = tipico[l.sigla];
      if (m.blu > 0.25 * area || (rif != null && rif > 0 && m.totale > 1.7 * rif + 0.083 * area)) {
        celle[pos.$1][pos.$2] = Lettura(l.sigla, false);
      }
    });
  }
  // 4) Caselle dubbie con una sigla a metà ("M" senza numero): si propone la sigla della stessa
  // lettera la cui forma, in questa foto, somiglia di più. Resta comunque da controllare.
  if (hc > 0) {
    final perSigla = <String, List<List<double>>>{};
    final glifi = <(int, int), List<double>>{};
    final reSigla = RegExp(r'^[MPN][0-3]$'), reDubbia = RegExp(r'^([MPN][0-3]|PR)$');
    for (var k = 0; k < t.giorni.length; k++) {
      for (var j = 0; j < t.colonne; j++) {
        final l = celle[k][j];
        final utile = l.sicura ? reSigla.hasMatch(l.sigla) : reDubbia.hasMatch(l.sigla);
        if (!utile) continue;
        final cx0 = t.colonneX[j][k];
        final g = cifra(img, cx0, t.rigaY(k, cx0 + 0.3 * b), b, hc);
        if (g == null) continue;
        if (l.sicura) {
          perSigla.putIfAbsent(l.sigla, () => []).add(g);
        } else {
          glifi[(k, j)] = g;
        }
      }
    }
    final forme = {
      for (final e in perSigla.entries)
        if (e.value.length >= 3)
          e.key: [for (var i = 0; i < 192; i++) e.value.fold<double>(0, (a, g) => a + g[i]) / e.value.length],
    };
    glifi.forEach((pos, g) {
      final lettera = celle[pos.$1][pos.$2].sigla[0];
      String? meglio;
      var dMeglio = double.infinity;
      forme.forEach((s, f) {
        if (s[0] != lettera) return;
        var d = 0.0;
        for (var i = 0; i < 192; i++) {
          d += (g[i] - f[i]).abs();
        }
        if (d < dMeglio) {
          dMeglio = d;
          meglio = s;
        }
      });
      if (meglio != null) celle[pos.$1][pos.$2] = Lettura(meglio!, false);
    });
  }
  return FoglioLetto(t.giorni, celle);
}
