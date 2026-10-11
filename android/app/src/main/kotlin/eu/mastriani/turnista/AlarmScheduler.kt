package eu.mastriani.turnista

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray

/**
 * Tiene la lista delle prossime sveglie (scritta dall'app Flutter) e programma
 * nel sistema SOLO la più vicina. Quando suona, si programma la successiva.
 * Così le sveglie sopravvivono anche al riavvio del telefono.
 */
object AlarmScheduler {
    const val PREFS = "turnista_alarm"
    const val KEY_ALARMS = "alarms"
    const val KEY_SNOOZE = "snooze"
    const val KEY_VIBRATE = "vibrate"
    const val KEY_NEXT = "next_at"

    const val ACTION_FIRE = "eu.mastriani.turnista.FIRE"
    const val EXTRA_TITLE = "title"
    const val EXTRA_BODY = "body"

    private const val REQ_MAIN = 1001
    const val REQ_SNOOZE = 1002
    private const val REQ_TEST = 1003
    private const val REQ_SHOW = 1004

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun save(ctx: Context, alarmsJson: String, snooze: Int, vibrate: Boolean) {
        prefs(ctx).edit()
            .putString(KEY_ALARMS, alarmsJson)
            .putInt(KEY_SNOOZE, snooze)
            .putBoolean(KEY_VIBRATE, vibrate)
            .apply()
    }

    fun snoozeMinutes(ctx: Context): Int = prefs(ctx).getInt(KEY_SNOOZE, 10)
    fun vibrate(ctx: Context): Boolean = prefs(ctx).getBoolean(KEY_VIBRATE, true)

    private fun firePendingIntent(ctx: Context, req: Int, title: String, body: String): PendingIntent {
        val i = Intent(ctx, AlarmReceiver::class.java).apply {
            action = ACTION_FIRE
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
        }
        return PendingIntent.getBroadcast(
            ctx, req, i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun showPendingIntent(ctx: Context): PendingIntent {
        val i = Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return PendingIntent.getActivity(
            ctx, REQ_SHOW, i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun canExact(ctx: Context): Boolean {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
    }

    private fun setAt(ctx: Context, req: Int, at: Long, title: String, body: String) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = firePendingIntent(ctx, req, title, body)
        try {
            // setAlarmClock: la sveglia "vera", esatta anche in risparmio energetico,
            // e mostra l'icona della sveglia nella barra di stato.
            am.setAlarmClock(AlarmManager.AlarmClockInfo(at, showPendingIntent(ctx)), pi)
        } catch (e: SecurityException) {
            // Permesso sveglie esatte negato: meglio una sveglia un po' imprecisa che nessuna.
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        }
    }

    /** Programma la prossima sveglia futura della lista (e cancella la precedente). */
    fun scheduleNext(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(firePendingIntent(ctx, REQ_MAIN, "", ""))

        val now = System.currentTimeMillis()
        var bestAt = Long.MAX_VALUE
        var bestTitle = "Sveglia"
        var bestBody = ""
        try {
            val arr = JSONArray(prefs(ctx).getString(KEY_ALARMS, "[]"))
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                val at = o.optLong("at", 0L)
                // margine di qualche secondo: la sveglia appena suonata non va ripresa
                if (at > now + 5_000 && at < bestAt) {
                    bestAt = at
                    bestTitle = o.optString("title", "Sveglia")
                    bestBody = o.optString("body", "")
                }
            }
        } catch (e: Exception) {
            // lista non valida: nessuna sveglia
        }

        if (bestAt == Long.MAX_VALUE) {
            prefs(ctx).edit().remove(KEY_NEXT).apply()
            return
        }
        prefs(ctx).edit().putLong(KEY_NEXT, bestAt).apply()
        setAt(ctx, REQ_MAIN, bestAt, bestTitle, bestBody)
    }

    fun scheduleSnooze(ctx: Context, title: String, body: String) {
        val at = System.currentTimeMillis() + snoozeMinutes(ctx) * 60_000L
        setAt(ctx, REQ_SNOOZE, at, title, body)
    }

    fun scheduleTest(ctx: Context, seconds: Int) {
        val at = System.currentTimeMillis() + seconds * 1000L
        setAt(ctx, REQ_TEST, at, "Prova sveglia", "Se la vedi e la senti, la sveglia funziona")
    }
}
