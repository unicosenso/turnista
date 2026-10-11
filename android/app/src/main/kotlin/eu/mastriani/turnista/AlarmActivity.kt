package eu.mastriani.turnista

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Schermata a tutto schermo della sveglia, nello stile dell'app. */
class AlarmActivity : Activity() {

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var clock: TextView
    private val tick = object : Runnable {
        override fun run() {
            clock.text = SimpleDateFormat("HH:mm", Locale.ITALY).format(Date())
            handler.postDelayed(this, 10_000L)
        }
    }

    private val teal = Color.parseColor("#0F6E63")
    private val tealDark = Color.parseColor("#0B5149")

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    @Suppress("DEPRECATION")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.statusBarColor = teal
        window.navigationBarColor = teal

        buildUi()
        fill(intent)

        AlarmService.onStopped = { runOnUiThread { finish() } }
        if (!AlarmService.running) {
            // la sveglia è già stata fermata (es. dalla notifica)
            finish()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        fill(intent)
    }

    private lateinit var titleView: TextView
    private lateinit var bodyView: TextView

    private fun fill(i: Intent?) {
        titleView.text = i?.getStringExtra(AlarmScheduler.EXTRA_TITLE) ?: AlarmService.title
        bodyView.text = i?.getStringExtra(AlarmScheduler.EXTRA_BODY) ?: AlarmService.body
    }

    private fun pill(text: String, filled: Boolean, onClick: () -> Unit): TextView {
        return TextView(this).apply {
            this.text = text
            textSize = 20f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setTextColor(if (filled) teal else Color.WHITE)
            background = GradientDrawable().apply {
                cornerRadius = dp(32).toFloat()
                if (filled) {
                    setColor(Color.WHITE)
                } else {
                    setColor(tealDark)
                    setStroke(dp(2), Color.parseColor("#66FFFFFF"))
                }
            }
            setPadding(dp(16), dp(20), dp(16), dp(20))
            isClickable = true
            setOnClickListener { onClick() }
        }
    }

    private fun buildUi() {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setBackgroundColor(teal)
            setPadding(dp(28), dp(72), dp(28), dp(40))
        }

        val label = TextView(this).apply {
            text = "SVEGLIA"
            textSize = 15f
            letterSpacing = 0.2f
            setTextColor(Color.parseColor("#B3FFFFFF"))
            gravity = Gravity.CENTER
        }
        clock = TextView(this).apply {
            textSize = 84f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
        }
        titleView = TextView(this).apply {
            textSize = 26f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, dp(8), 0, 0)
        }
        bodyView = TextView(this).apply {
            textSize = 17f
            setTextColor(Color.parseColor("#D9FFFFFF"))
            gravity = Gravity.CENTER
            setPadding(0, dp(8), 0, 0)
        }

        root.addView(label)
        root.addView(clock)
        root.addView(titleView)
        root.addView(bodyView)

        val spacer = android.view.View(this)
        root.addView(spacer, LinearLayout.LayoutParams(1, 0, 1f))

        val snoozeMin = AlarmScheduler.snoozeMinutes(this)
        val full = ViewGroup.LayoutParams.MATCH_PARENT
        val wrap = ViewGroup.LayoutParams.WRAP_CONTENT
        root.addView(
            pill("Rimanda $snoozeMin min", false) { send(AlarmService.ACTION_SNOOZE) },
            LinearLayout.LayoutParams(full, wrap).apply { bottomMargin = dp(14) }
        )
        root.addView(
            pill("Ferma", true) { send(AlarmService.ACTION_STOP) },
            LinearLayout.LayoutParams(full, wrap)
        )

        setContentView(root)
    }

    private fun send(action: String) {
        try {
            startService(Intent(this, AlarmService::class.java).setAction(action))
        } catch (e: Exception) {
        }
        finish()
    }

    override fun onResume() {
        super.onResume()
        handler.post(tick)
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(tick)
    }

    override fun onDestroy() {
        if (AlarmService.onStopped != null) AlarmService.onStopped = null
        super.onDestroy()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // il tasto indietro non spegne la sveglia: usa Ferma o Rimanda
    }
}
