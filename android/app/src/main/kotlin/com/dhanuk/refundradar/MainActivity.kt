package com.dhanuk.refundradar

import android.database.Cursor
import android.net.Uri
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "refund_radar/sms_inbox"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
