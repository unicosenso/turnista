package eu.mastriani.turnista

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "turnista/alarm")
            .setMethodCallHandler { call, result ->
                val ctx: Context = this
                try {
                    when (call.method) {
                        "schedule" -> {
                            val alarms = call.argument<String>("alarms") ?: "[]"
                            val snooze = call.argument<Int>("snooze") ?: 10
                            val vibrate = call.argument<Boolean>("vibrate") ?: true
                            AlarmScheduler.save(ctx, alarms, snooze, vibrate)
                            AlarmScheduler.scheduleNext(ctx)
                            result.success(true)
                        }
                        "test" -> {
                            val seconds = call.argument<Int>("seconds") ?: 5
                            val snooze = call.argument<Int>("snooze") ?: 10
                            val vibrate = call.argument<Boolean>("vibrate") ?: true
                            val sp = ctx.getSharedPreferences(AlarmScheduler.PREFS, Context.MODE_PRIVATE)
                            sp.edit()
                                .putInt(AlarmScheduler.KEY_SNOOZE, snooze)
                                .putBoolean(AlarmScheduler.KEY_VIBRATE, vibrate)
                                .apply()
                            AlarmScheduler.scheduleTest(ctx, seconds)
                            result.success(true)
                        }
                        "permissions" -> result.success(permissionMap())
                        "requestNotifications" -> {
                            if (Build.VERSION.SDK_INT >= 33) {
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 77)
                            }
                            result.success(true)
                        }
                        "openNotificationSettings" -> {
                            openSettings(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            })
                            result.success(true)
                        }
                        "openExactAlarmSettings" -> {
                            if (Build.VERSION.SDK_INT >= 31) {
                                openSettings(
                                    Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName"))
                                )
                            }
                            result.success(true)
                        }
                        "openFullScreenSettings" -> {
                            if (Build.VERSION.SDK_INT >= 34) {
                                openSettings(
                                    Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName"))
                                )
                            }
                            result.success(true)
                        }
                        "openAppSettings" -> {
                            openSettings(
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                            )
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("ERR", e.message, null)
                }
            }
    }

    private fun openSettings(i: Intent) {
        try {
            startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (e: Exception) {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }

    private fun permissionMap(): Map<String, Boolean> {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notifications = if (Build.VERSION.SDK_INT >= 33) {
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED &&
                nm.areNotificationsEnabled()
        } else {
            nm.areNotificationsEnabled()
        }
        val fullScreen = if (Build.VERSION.SDK_INT >= 34) nm.canUseFullScreenIntent() else true
        return mapOf(
            "notifications" to notifications,
            "exact" to AlarmScheduler.canExact(this),
            "fullScreen" to fullScreen
        )
    }
}
