package it.mastro.provalettura

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ImageDecoder
import android.graphics.Matrix
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
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * App di PROVA (da buttare dopo): legge una foto del foglio turni con ML Kit,
 * colora in verde le sigle riconosciute e in arancio il resto,
 * e permette di esportare tutto quello che ha letto (con le posizioni) per studiarlo al computer.
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
    private lateinit var condividi: Button
    private var uriScatto: Uri? = null
    private val lettore = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    // Quello che verrà esportato: la foto dritta e il file con le parole lette.
    private var fileFoto: File? = null
    private var fileDati: File? = null

    private val scegliFoto = registerForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) leggi(uri)
    }
    private val scattaFoto = registerForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        if (ok) uriScatto?.let { leggi(it) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
        condividi = Button(this).apply {
            text = "Invia foto + dati letti a Claude"
            isEnabled = false
            setOnClickListener { condividiRisultato() }
        }
        colonna.addView(condividi)
        stato = TextView(this).apply { textSize = 16f; setPadding(0, 24, 0, 24); text = "Scegli o scatta una foto del foglio turni." }
        foto = ImageView(this).apply { adjustViewBounds = true }
        testo = TextView(this).apply { textSize = 12f; setPadding(0, 24, 0, 0); setTextIsSelectable(true) }
        colonna.addView(stato)
        colonna.addView(foto)
        colonna.addView(testo)
        setContentView(ScrollView(this).apply { addView(colonna) })
    }

    private fun cartella(): File = File(cacheDir, "foto").apply { mkdirs() }

    private fun nuovoUriScatto(): Uri =
        FileProvider.getUriForFile(this, "$packageName.fileprovider", File(cartella(), "scatto.jpg"))

    // 1) apre la foto dritta; 2) la legge così com'è; 3) la legge anche girata di 90°,
    // perché i nomi dei colleghi in intestazione sono scritti in verticale.
    private fun leggi(uri: Uri) {
        stato.text = "Lettura in corso…"
        condividi.isEnabled = false
        Thread {
            val immagine = ImageDecoder.decodeBitmap(ImageDecoder.createSource(contentResolver, uri)) { decoder, _, _ ->
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                decoder.isMutableRequired = true
            }
            val girata = Bitmap.createBitmap(immagine, 0, 0, immagine.width, immagine.height, Matrix().apply { postRotate(90f) }, true)
            val pulita = immagine.copy(Bitmap.Config.ARGB_8888, false)
            runOnUiThread {
                val inizio = SystemClock.elapsedRealtime()
                lettore.process(InputImage.fromBitmap(immagine, 0)).addOnSuccessListener { dritto ->
                    val tempo = SystemClock.elapsedRealtime() - inizio
                    lettore.process(InputImage.fromBitmap(girata, 0)).addOnSuccessListener { ruotato ->
                        mostra(immagine, dritto, tempo)
                        salvaPerEsportare(pulita, dritto, ruotato, girata.width, girata.height)
                    }.addOnFailureListener { e -> stato.text = "Errore di lettura (girata): ${e.message}" }
                }.addOnFailureListener { e -> stato.text = "Errore di lettura: ${e.message}" }
            }
        }.start()
    }

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

    // Trasforma ciò che ML Kit ha letto in un elenco: per ogni parola il testo e i 4 angoli del suo riquadro.
    private fun inJson(risultato: Text, rotazione: Int, larghezza: Int, altezza: Int): JSONObject {
        val parole = JSONArray()
        for (blocco in risultato.textBlocks) for ((nRiga, riga) in blocco.lines.withIndex()) for (parola in riga.elements) {
            val angoli = JSONArray()
            parola.cornerPoints?.forEach { p -> angoli.put(JSONArray().put(p.x).put(p.y)) }
            parole.put(JSONObject().put("t", parola.text).put("angoli", angoli).put("riga", riga.text))
        }
        return JSONObject().put("rotazione", rotazione).put("larghezza", larghezza).put("altezza", altezza).put("parole", parole)
    }

    private fun salvaPerEsportare(pulita: Bitmap, dritto: Text, ruotato: Text, lg: Int, ag: Int) {
        Thread {
            val nome = "foglio-" + System.currentTimeMillis()
            val f = File(cartella(), "$nome.jpg")
            f.outputStream().use { pulita.compress(Bitmap.CompressFormat.JPEG, 92, it) }
            val dati = JSONObject()
                .put("app", "prova-lettura 0.2")
                .put("passate", JSONArray()
                    .put(inJson(dritto, 0, pulita.width, pulita.height))
                    .put(inJson(ruotato, 90, lg, ag)))
            val j = File(cartella(), "$nome.json")
            j.writeText(dati.toString())
            fileFoto = f
            fileDati = j
            runOnUiThread { condividi.isEnabled = true }
        }.start()
    }

    // Apre il menu "Condividi" di Android con i due file: li puoi mandare a te stesso o allegarli in chat.
    private fun condividiRisultato() {
        val uris = arrayListOf<Uri>()
        listOfNotNull(fileFoto, fileDati).forEach { uris.add(FileProvider.getUriForFile(this, "$packageName.fileprovider", it)) }
        val intent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
            type = "*/*"
            putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, "Invia foto e dati letti"))
    }
}
