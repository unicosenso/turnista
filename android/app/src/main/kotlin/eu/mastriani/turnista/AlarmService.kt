package eu.mastriani.turnista

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/** Suona la sveglia (suono + vibrazione) finché non la fermi o la rimandi. */
class AlarmService : Service() {

    companion object {
        const val ACTION_START = "eu.mastriani.turnista.START"
        const val ACTION_STOP = "eu.mastriani.turnista.STOP"
        const val ACTION_SNOOZE = "eu.mastriani.turnista.SNOOZE"
        const val CHANNEL_ID = "turnista_sveglia"
        const val NOTIF_ID = 4242
        private const val MAX_RING_MS = 10 * 60 * 1000L

        @Volatile var running = false
        @Volatile var title: String = "Sveglia"
        @Volatile var body: String = ""
        /** La schermata della sveglia si registra qui per chiudersi quando la sveglia smette. */
        var onStopped: (() -> Unit)? = null

        fun ensureChannel(ctx: Context) {
            if (Build.VERSION.SDK_INT < 26) return
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) != null) return
            val ch = NotificationChannel(CHANNEL_ID, "Sveglia turni", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "La sveglia prima dei turni"
                setSound(null, null) // il suono lo gestisce il servizio
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setBypassDnd(true)
            }
            nm.createNotificationChannel(ch)
        }

        private fun activityIntent(ctx: Context, t: String, b: String): PendingIntent {
            val i = Intent(ctx, AlarmActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION)
                putExtra(AlarmScheduler.EXTRA_TITLE, t)
                putExtra(AlarmScheduler.EXTRA_BODY, b)
            }
            return PendingIntent.getActivity(
                ctx, 2001, i,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun serviceIntent(ctx: Context, action: String, req: Int): PendingIntent {
            val i = Intent(ctx, AlarmService::class.java).setAction(action)
            return PendingIntent.getService(
                ctx, req, i,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        @Suppress("DEPRECATION")
        fun buildNotification(ctx: Context, t: String, b: String, withActions: Boolean): Notification {
            ensureChannel(ctx)
            val builder = if (Build.VERSION.SDK_INT >= 26) {
                Notification.Builder(ctx, CHANNEL_ID)
            } else {
                Notification.Builder(ctx).setPriority(Notification.PRIORITY_MAX)
            }
            val full = activityIntent(ctx, t, b)
            builder
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle(t)
                .setContentText(b)
                .setCategory(Notification.CATEGORY_ALARM)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setContentIntent(full)
                .setFullScreenIntent(full, true)
                .setOngoing(withActions)
                .setAutoCancel(!withActions)
            if (withActions) {
                val snoozeMin = AlarmScheduler.snoozeMinutes(ctx)
                builder.addAction(
                    Notification.Action.Builder(
                        android.R.drawable.ic_media_pause, "Rimanda $snoozeMin min",
                        serviceIntent(ctx, ACTION_SNOOZE, 2002)
                    ).build()
                )
                builder.addAction(
                    Notification.Action.Builder(
                        android.R.drawable.ic_menu_close_clear_cancel, "Ferma",
                        serviceIntent(ctx, ACTION_STOP, 2003)
                    ).build()
                )
            }
            return builder.build()
        }

        fun showFallbackNotification(ctx: Context, t: String, b: String) {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            try {
                nm.notify(NOTIF_ID + 1, buildNotification(ctx, t, b, false))
            } catch (e: SecurityException) {
                // notifiche non permesse
            }
        }
    }

    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable { stopRinging() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopRinging()
            }
            ACTION_SNOOZE -> {
                AlarmScheduler.scheduleSnooze(this, title, body)
                stopRinging()
            }
            else -> {
                title = intent?.getStringExtra(AlarmScheduler.EXTRA_TITLE) ?: "Sveglia"
                body = intent?.getStringExtra(AlarmScheduler.EXTRA_BODY) ?: ""
                startRinging()
            }
        }
        return START_NOT_STICKY
    }

    private fun startRinging() {
        val notif = buildNotification(this, title, body, true)
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIF_ID, notif)
        }
        running = true

        stopSoundAndVibration()

        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "turnista:sveglia").apply {
            acquire(MAX_RING_MS + 5_000L)
        }

        playSound()
        if (AlarmScheduler.vibrate(this)) vibrate()

        handler.removeCallbacks(timeout)
        handler.postDelayed(timeout, MAX_RING_MS)

        // Se il telefono è sbloccato e in uso, la notifica a schermo intero diventa un banner:
        // proviamo comunque ad aprire la schermata della sveglia.
        try {
            val i = Intent(this, AlarmActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                putExtra(AlarmScheduler.EXTRA_TITLE, title)
                putExtra(AlarmScheduler.EXTRA_BODY, body)
            }
            startActivity(i)
        } catch (e: Exception) {
            // Android può bloccarlo: resta la notifica con i tasti Rimanda / Ferma
        }
    }

    private fun playSound() {
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            ?: return
        try {
            player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(this@AlarmService, uri)
                isLooping = true
                prepare()
                start()
            }
        } catch (e: Exception) {
            player = null
        }
    }

    @Suppress("DEPRECATION")
    private fun vibrate() {
        val v: Vibrator = if (Build.VERSION.SDK_INT >= 31) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        vibrator = v
        val pattern = longArrayOf(0, 800, 600)
        if (Build.VERSION.SDK_INT >= 26) {
            v.vibrate(VibrationEffect.createWaveform(pattern, 0))
        } else {
            v.vibrate(pattern, 0)
        }
    }

    private fun stopSoundAndVibration() {
        try {
            player?.stop()
        } catch (e: Exception) {
        }
        player?.release()
        player = null
        vibrator?.cancel()
        vibrator = null
    }

    private fun stopRinging() {
        handler.removeCallbacks(timeout)
        stopSoundAndVibration()
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        running = false
        onStopped?.invoke()
        if (Build.VERSION.SDK_INT >= 24) {
            stopForeground(Service.STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        handler.removeCallbacks(timeout)
        stopSoundAndVibration()
        wakeLock?.let { if (it.isHeld) it.release() }
        running = false
        super.onDestroy()
    }
}
