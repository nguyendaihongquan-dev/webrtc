package com.example.qgim_client_flutter

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.qgim/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "openChannelNotificationSettings" -> {
                    val channelId = call.argument<String>("channelId")
                    openChannelSettings(channelId, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openChannelSettings(channelId: String?, result: MethodChannel.Result) {
        try {
            val intent = Intent()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                intent.action = Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS
                intent.putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                intent.putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
            } else {
                intent.action = "android.settings.APP_NOTIFICATION_SETTINGS"
                intent.putExtra("app_package", packageName)
                intent.putExtra("app_uid", applicationInfo.uid)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("OPEN_SETTINGS_FAILED", e.localizedMessage, null)
        }
    }
}
