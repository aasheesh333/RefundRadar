package com.dhanuk.refundradar

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/// Live SMS receiver (Task C2). Registered dynamically inside
/// [MainActivity] so it only forwards SMS while the Flutter engine is alive.
/// Each parsed SMS is sent to the Dart side via the
/// `refund_radar/sms_events` MethodChannel as a single `onSmsReceived` call
/// containing `sender`, `body`, and `timestamp`. The Dart side runs
/// [SmsParser] on the body and emits a [UtrDetection] only when a UTR is
/// present — non-bank SMS are dropped silently on the Kotlin side (we
/// still forward them so the Dart filter stays the source of truth).
///
/// `isListening` is toggled false in `onDestroy` so late deliveries after
/// teardown become a no-op instead of crashing the engine with a dangling
/// receiver invocation.
///
/// CR-3 kill-switch: before forwarding, we also consult the shared
/// preference `settings.sms_detection_enabled`. When the user toggles the
/// feature off in Settings, the Dart side writes that key to `false`; the
/// receiver reads it on every incoming SMS and short-circuits. This keeps
/// the off-toggle authoritative even while the SMS permission is still
/// held and the Flutter engine is alive.
class SmsReceiver(
    private val isListening: () -> Boolean,
    private val onSms: (sender: String, body: String, timestamp: Long) -> Unit,
) : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (!isListening()) return
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        // CR-3 kill-switch: honour the persisted user toggle.
        // Flutter's shared_preferences Android plugin stores values in a
        // file named "FlutterSharedPreferences", with bool keys written raw
        // (no prefix). Singleton caching makes this read effectively free.
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        val enabled = prefs.getBoolean("settings.sms_detection_enabled", true)
        if (!enabled) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        for (sms in messages) {
            val sender = sms.displayOriginatingAddress ?: ""
            val body = sms.messageBody ?: ""
            if (body.isBlank()) continue
            val timestamp = sms.timestampMillis.takeIf { it > 0 }
                ?: System.currentTimeMillis()
            onSms(sender, body, timestamp)
        }
    }
}
