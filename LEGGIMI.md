# Turnista

App Android per i turni di lavoro, con sveglia che si imposta da sola in base al turno.
Stile grafico ripreso da MF Life. Tutti i dati restano sul telefono: niente server, niente account.

## Cosa fa
- **Tipi di turno** con sigla, colore, orari e **anticipo della sveglia** impostato a mano per ognuno.
- **Rotazione** che si ripete (es. M M P P N R R) + **modifiche a mano** sui singoli giorni
  (cambio turno, orari diversi, nota, sveglia saltata).
- **Calendario** mensile con inserimento rapido: scegli un turno e tocchi i giorni.
- **Sveglia propria**: suona a schermo intero anche a telefono bloccato, con Rimanda e Ferma.
  Si ricalcola da sola a ogni modifica e torna attiva dopo il riavvio del telefono.
- **Statistiche** per mese e anno: ore, turni, riposi, notti, conteggio per tipo.
- **Backup** copia/incolla di tutti i dati.

## Come ottenere l'APK
1. Su GitHub crea un repository **privato** nuovo (es. `turnista`).
2. Carica tutto il contenuto di questa cartella, **compresa la cartella `.github`**
   (con "Add file → Upload files" puoi trascinare le cartelle).
3. Vai in **Actions**: parte da solo "Compila APK" (5–10 minuti).
4. A fine lavoro trovi `Turnista.apk` nella pagina **Releases** del repository
   (oppure in Actions, in fondo alla pagina dell'esecuzione).

Ogni volta che carichi modifiche su `main` viene compilato un nuovo APK, che si installa sopra il vecchio senza perdere i dati.

## La chiave di firma (importante)
In `keystore/` c'è la chiave con cui viene firmata l'app, e la sua password.
- Tieni il repository **privato**.
- Conservane una copia: se la perdi, i futuri aggiornamenti non si installeranno sopra
  la versione esistente (dovresti disinstallare e reinstallare, perdendo i dati non salvati col backup).

## Al primo avvio
La configurazione guidata chiede: nome, tipi di turno (con anticipo sveglia), rotazione, permessi.
Su Xiaomi/Redmi conviene anche: Impostazioni → App → Turnista → **Avvio automatico** attivo e
**Risparmio batteria: Nessuna restrizione**.
Poi usa **Prova la sveglia** (Impostazioni) bloccando il telefono.

## Struttura
- `lib/models.dart` – dati e logica (rotazione, sveglie, statistiche)
- `lib/store.dart` – salvataggio e collegamento con la sveglia Android
- `lib/home.dart`, `lib/settings_tab.dart`, `lib/editors.dart`, `lib/setup.dart` – schermate
- `android/app/src/main/kotlin/.../` – sveglia nativa (AlarmScheduler, AlarmReceiver, AlarmService, AlarmActivity)
