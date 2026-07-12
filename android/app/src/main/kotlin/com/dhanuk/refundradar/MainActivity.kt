package com.dhanuk.refundradar

import android.content.Context
import android.content.IntentFilter
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "refund_radar/sms_inbox"
    private val smsEventsChannelName = "refund_radar/sms_events"

    /// Live SMS receiver toggled via [listening]. Registered in
    /// [configureFlutterEngine] and unregistered in [onDestroy] so an
    /// arriving SMS after teardown is a no-op.
    private var smsReceiver: SmsReceiver? = null
    private var listening: Boolean = true

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Existing inbox query channel (bulk inbox prefill for the form).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "queryInbox" -> {
                        val limit = (call.argument<Int>("limit") ?: 50).coerceIn(1, 100)
                        try {
                            result.success(querySmsInbox(limit))
                        } catch (e: SecurityException) {
                            result.error("PERMISSION", e.message, null)
                        } catch (e: Exception) {
                            result.error("QUERY_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // New live SMS events channel (Task C2). The receiver forwards each
        // arriving SMS as an `onSmsReceived` method invocation; the Dart
        // side parses + filters with [SmsParser]. We keep a single channel
        // instance here so [SmsReceiver] can reuse it for every message.
        val smsEventsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            smsEventsChannelName,
        )
        smsReceiver = SmsReceiver(
            isListening = { listening },
            onSms = { sender, body, timestamp ->
                smsEventsChannel.invokeMethod(
                    "onSmsReceived",
                    mapOf(
                        "sender" to sender,
                        "body" to body,
                        "timestamp" to timestamp,
                    ),
                )
            },
        )

        // Dynamic registration (manifest-registered receivers for
        // SMS_RECEIVED are disallowed for background-safety on modern
        // Android; an in-app receiver is the supported pattern). API 33+
        // requires the RECEIVER_NOT_EXPORTED flag so a non-exported dynamic
        // receiver isn't misattributed to the system.
        val filter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(smsReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(smsReceiver, filter)
        }
    }

    override fun onDestroy() {
        // Stop forwarding before tearing down so a late SMS doesn't invoke
        // a method on a dead Flutter engine.
        listening = false
        try {
            smsReceiver?.let { unregisterReceiver(it) }
        } catch (_: Exception) {
            // Already unregistered / never registered — safe to ignore.
        }
        smsReceiver = null
        super.onDestroy()
    }

    private fun querySmsInbox(limit: Int): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>(limit)
        val uri: Uri = Telephony.Sms.Inbox.CONTENT_URI
        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
        )
        val cursor: Cursor? = contentResolver.query(
            uri,
            projection,
            null,
            null,
            "${Telephony.Sms.DATE} DESC",
        )
        cursor?.use { c ->
            val idIdx = c.getColumnIndex(Telephony.Sms._ID)
            val addrIdx = c.getColumnIndex(Telephony.Sms.ADDRESS)
            val bodyIdx = c.getColumnIndex(Telephony.Sms.BODY)
            val dateIdx = c.getColumnIndex(Telephony.Sms.DATE)
            var n = 0
            while (c.moveToNext() && n < limit) {
                out.add(
                    mapOf(
                        "id" to if (idIdx >= 0) c.getString(idIdx) else "",
                        "address" to if (addrIdx >= 0) c.getString(addrIdx) else "",
                        "body" to if (bodyIdx >= 0) c.getString(bodyIdx) else "",
                        "date" to if (dateIdx >= 0) c.getLong(dateIdx) else null,
                    ),
                )
                n++
            }
        }
        return out
    }
}
