// Le sigle del foglio garagisti e il modo di "aggiustare" il testo letto da ML Kit.
// Dart puro: niente Flutter qui dentro, così si può provare con i test automatici.

/// Tutte le sigle valide, scritte come compaiono sul foglio.
const sigleValide = [
  'M1', 'M2', 'M3', 'P0', 'P1', 'P2', 'P3', 'N1', 'N2', 'N3', 'PR', 'INT2', 'r', 'ris',
  'CON', 'c.par', 'DIST', 'MAL', 'corso', 'MFF', 'PFF', 'NFF', 'IG', 'AVIS', r'\',
];

/// Le stesse sigle in maiuscolo, per confrontarle senza badare a maiuscole/minuscole.
final Map<String, String> _maiuscole = {for (final s in sigleValide) s.toUpperCase(): s};

bool eSigla(String testo) => _maiuscole.containsKey(testo.toUpperCase().replaceAll('INT.2', 'INT2'));

/// Il risultato di una casella: la sigla e se siamo sicuri della lettura.
class Lettura {
  final String sigla;
  final bool sicura;
  const Lettura(this.sigla, this.sicura);
  @override
  String toString() => sicura ? sigla : '$sigla?';
}

/// Da testo letto a sigla valida. Se la lettura è esatta è "sicura";
/// se l'abbiamo dovuta correggere (es. "Mi" → "M1") è "da controllare".
Lettura normalizza(String testo) {
  var t = testo.trim().replaceAll('|', '').replaceAll(' ', '');
  if (t.isEmpty) return const Lettura('', false);
  var up = t.toUpperCase().replaceAll('INT.2', 'INT2');
  final esatta = _maiuscole[up];
  if (esatta != null) return Lettura(esatta, true);
  // "PO" con la lettera O: nelle sigle M/P/N dopo la lettera c'è solo una cifra, quindi la O
  // è sicuramente uno zero (l'errore più frequente di ML Kit): correzione sicura.
  if (up.length == 2 && 'MPN'.contains(up[0]) && up[1] == 'O' && _maiuscole.containsKey('${up[0]}0')) {
    return Lettura(_maiuscole['${up[0]}0']!, true);
  }
  // Correzioni tipiche dei lettori: O al posto di 0, I o L al posto di 1.
  var alt = up;
  if (alt.isNotEmpty && 'MPN'.contains(alt[0])) {
    alt = alt.replaceAll('O', '0').replaceAll('I', '1');
    if (alt.length == 2) alt = alt.replaceAll('L', '1');
  }
  final corretta = _maiuscole[alt];
  if (corretta != null) return Lettura(corretta, false);
  // Ultima possibilità: la sigla "più somigliante", se abbastanza vicina.
  String? migliore;
  var punteggio = 0.5;
  for (final s in _maiuscole.keys) {
    final r = somiglianza(alt, s);
    // a pari somiglianza vince la sigla "alfabeticamente più grande", come nel prototipo
    if (r >= punteggio && (migliore == null || r > punteggio || s.compareTo(migliore) > 0)) {
      migliore = s;
      punteggio = r;
    }
  }
  return Lettura(migliore != null ? _maiuscole[migliore]! : '?$t', false);
}

/// Se ML Kit ha attaccato più sigle ("CONP1", "CONCONr"), le separa; altrimenti null.
/// Cerca la scomposizione in sigle valide con meno pezzi; un pezzo finale non valido
/// (sigla tagliata, es. "CONCONP") resta a parte e verrà segnato da controllare.
List<String>? dividi(String testo) {
  final up = testo.toUpperCase().replaceAll('INT.2', 'INT2');
  // se "INT.2" è diventato "INT2" le posizioni cambiano: in quel caso si lavora sul testo già corretto
  final base = up.length == testo.length ? testo : up;
  final n = up.length;
  final migliore = <int, List<List<int>>>{0: []};
  for (var i = 0; i < n; i++) {
    final da = migliore[i];
    if (da == null) continue;
    for (var j = i + 1; j <= n; j++) {
      if (_maiuscole.containsKey(up.substring(i, j)) &&
          (!migliore.containsKey(j) || da.length + 1 < migliore[j]!.length)) {
        migliore[j] = [...da, [i, j]];
      }
    }
  }
  List<List<int>> pezzi;
  if (migliore.containsKey(n) && migliore[n]!.length >= 2) {
    pezzi = migliore[n]!;
  } else {
    final fini = migliore.keys.where((j) => j > 0 && j < n).toList();
    if (fini.isEmpty) return null;
    final fine = fini.reduce((a, c) => a > c ? a : c);
    if (fine < 3 || n - fine > 3) return null;
    pezzi = [...migliore[fine]!, [fine, n]];
  }
  return [for (final p in pezzi) base.substring(p[0], p[1])];
}

/// Quanto si somigliano due parole, da 0 a 1 (stesso calcolo di Python "difflib"):
/// si cerca il pezzo comune più lungo, poi si ripete a sinistra e a destra.
double somiglianza(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1;
  return 2 * _comuni(a, b) / (a.length + b.length);
}

int _comuni(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  var lung = 0, ia = 0, ib = 0;
  for (var i = 0; i < a.length; i++) {
    for (var j = 0; j < b.length; j++) {
      var k = 0;
      while (i + k < a.length && j + k < b.length && a[i + k] == b[j + k]) {
        k++;
      }
      if (k > lung) {
        lung = k;
        ia = i;
        ib = j;
      }
    }
  }
  if (lung == 0) return 0;
  return lung +
      _comuni(a.substring(0, ia), b.substring(0, ib)) +
      _comuni(a.substring(ia + lung), b.substring(ib + lung));
}
