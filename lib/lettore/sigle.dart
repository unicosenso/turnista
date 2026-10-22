// Le sigle del foglio garagisti e il modo di "aggiustare" il testo letto da ML Kit.
// Dart puro: niente Flutter qui dentro, così si può provare con i test automatici.

/// Tutte le sigle valide, scritte come compaiono sul foglio.
const sigleValide = [
  'M1', 'M2', 'M3', 'P0', 'P1', 'P2', 'P3', 'N1', 'N2', 'N3', 'PR', 'INT2', 'r', 'ris',
  'CON', 'c.par', 'DIST', 'MAL', 'corso', 'MFF', 'PFF', r'\',
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
    if (r >= punteggio && (migliore == null || r > punteggio)) {
      migliore = s;
      punteggio = r;
    }
  }
  return Lettura(migliore != null ? _maiuscole[migliore]! : '?$t', false);
}

/// Se ML Kit ha attaccato due sigle ("CONP1"), restituisce le due parti; altrimenti null.
List<String>? dividi(String testo) {
  final up = testo.toUpperCase().replaceAll('INT.2', 'INT2');
  for (var i = 1; i < up.length; i++) {
    final a = up.substring(0, i), b = up.substring(i);
    if (_maiuscole.containsKey(a) && _maiuscole.containsKey(b) && a != 'R' && b != 'R') {
      return [testo.substring(0, i), testo.substring(i)];
    }
  }
  return null;
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
