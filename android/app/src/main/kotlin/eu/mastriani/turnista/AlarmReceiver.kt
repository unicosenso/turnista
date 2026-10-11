package eu.mastriani.turnista

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            AlarmScheduler.ACTION_FIRE -> {
                val svc = Intent(context, AlarmService::class.java).apply {
                    action = AlarmService.ACTION_START
                    putExtra(AlarmScheduler.EXTRA_TITLE, intent.getStringExtra(AlarmScheduler.EXTRA_TITLE) ?: "Sveglia")
                    putExtra(AlarmScheduler.EXTRA_BODY, intent.getStringExtra(AlarmScheduler.EXTRA_BODY) ?: "")
                }
                try {
                    if (Build.VERSION.SDK_INT >= 26) {
                        context.startForegroundService(svc)
                    } else {
                        context.startService(svc)
                    }
                } catch (e: Exception) {
                    // ultima spiaggia: almeno la notifica
                    AlarmService.showFallbackNotification(
                        context,
                        intent.getStringExtra(AlarmScheduler.EXTRA_TITLE) ?: "Sveglia",
                        intent.getStringExtra(AlarmScheduler.EXTRA_BODY) ?: ""
                    )
                }
                // programma già la sveglia successiva
                AlarmScheduler.scheduleNext(context)
            }
            else -> {
                // riavvio, aggiornamento app, cambio ora/fuso: riprogramma
                AlarmScheduler.scheduleNext(context)
            }
        }
    }
}
