package it.mastro.provalettura

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ImageDecoder
import android.graphics.Paint
import android.net.Uri
import android.os.Bundle
import android.os.SystemClock
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.io.File

/**
 * App di PROVA (da buttare dopo): legge una foto del foglio turni con ML Kit
 * e colora in verde le sigle riconosciute e in arancio tutto il resto.
 */
class MainActivity : ComponentActivity() {

    // Le sigle valide del foglio garagisti, scritte in maiuscolo per il confronto.
    private val sigle = setOf(
        "M1", "M2", "M3", "P0", "P1", "P2", "P3", "N1", "N2", "N3", "PR",
        "INT", "INT.2", "R", "RIS", "CON", "C.PAR", "DIST", "MAL", "CORSO", "MFF", "PFF", "\\"
    )

    private lateinit var stato: TextView
    private lateinit var foto: ImageView
    private lateinit var testo: TextView
    private var uriScatto: Uri? = null

    // Due "lanciatori": uno apre la galleria, l'altro la fotocamera. Quando l'utente ha finito, chiamano leggi().
    private val scegliFoto = registerForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) leggi(uri)
    }
    private val scattaFoto = registerForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        if (ok) uriScatto?.let { leggi(it) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // La schermata, costruita nel codice: due tasti, una riga di risultato, la foto e il testo letto.
        val colonna = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 96, 32, 64)
        }
        colonna.addView(Button(this).apply {
            text = "Scegli una foto o un PDF convertito"
            setOnClickListener { scegliFoto.launch("image/*") }
        })
        colonna.addView(Button(this).apply {
            text = "Scatta una foto al foglio"
            setOnClickListener {
                uriScatto = nuovoUriScatto()
                scattaFoto.launch(uriScatto!!)
            }
        })
        stato = TextView(this).apply { textSize = 16f; setPadding(0, 24, 0, 24); text = "Scegli o scatta una foto del foglio turni." }
        foto = ImageView(this).apply { adjustViewBounds = true }
        testo = TextView(this).apply { textSize = 12f; setPadding(0, 24, 0, 0); setTextIsSelectable(true) }
        colonna.addView(stato)
        colonna.addView(foto)
        colonna.addView(testo)
        setContentView(ScrollView(this).apply { addView(colonna) })
    }

    // Prepara un file vuoto in cui la fotocamera salverà lo scatto.
    private fun nuovoUriScatto(): Uri {
        val file = File(cacheDir, "foto/scatto.jpg")
        file.parentFile?.mkdirs()
        return FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
    }

    // Apre l'immagine (già raddrizzata secondo come è stato tenuto il telefono) e la passa a ML Kit.
    private fun leggi(uri: Uri) {
        stato.text = "Lettura in corso…"
        Thread {
            val immagine = ImageDecoder.decodeBitmap(ImageDecoder.createSource(contentResolver, uri)) { decoder, _, _ ->
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                decoder.isMutableRequired = true
            }
            runOnUiThread {
                val inizio = SystemClock.elapsedRealtime()
                TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                    .process(InputImage.fromBitmap(immagine, 0))
                    .addOnSuccessListener { risultato -> mostra(immagine, risultato, SystemClock.elapsedRealtime() - inizio) }
                    .addOnFailureListener { e -> stato.text = "Errore di lettura: ${e.message}" }
            }
        }.start()
    }

    // Disegna un riquadro attorno a ogni parola letta: verde se è una sigla valida, arancio se no.
    private fun mostra(immagine: Bitmap, risultato: Text, millisecondi: Long) {
        val tratto = (immagine.width / 400f).coerceAtLeast(2f)
        val verde = Paint().apply { style = Paint.Style.STROKE; strokeWidth = tratto; color = Color.rgb(22, 163, 74) }
        val arancio = Paint().apply { style = Paint.Style.STROKE; strokeWidth = tratto; color = Color.rgb(234, 88, 12) }
        val tela = Canvas(immagine)
        var parole = 0
        var sigleTrovate = 0
        for (blocco in risultato.textBlocks) for (riga in blocco.lines) for (parola in riga.elements) {
            val box = parola.boundingBox ?: continue
            parole++
            val eSigla = parola.text.trim().uppercase() in sigle
            if (eSigla) sigleTrovate++
            tela.drawRect(box, if (eSigla) verde else arancio)
        }
        foto.setImageBitmap(immagine)
        stato.text = "Parole lette: $parole · Sigle riconosciute: $sigleTrovate · Tempo: $millisecondi ms\n" +
            "Riquadri verdi = sigle valide, arancio = altro testo."
        testo.text = risultato.text
    }
}
