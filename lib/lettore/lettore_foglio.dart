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

  // 2) Correzioni a penna: una casella con molto più inchiostro del solito per quella sigla,
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
  return FoglioLetto(t.giorni, celle);
}
