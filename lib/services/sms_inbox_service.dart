import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:refund_radar/services/sms_parser.dart';

/// One SMS row from the device inbox (on-device only — never uploaded).
@immutable
class InboxSms {
  final String id;
  final String address;
  final String body;
  final DateTime? date;

  const InboxSms({
    required this.id,
    required this.address,
    required this.body,
    this.date,
  });
}

abstract class SmsInboxBackend {
  Future<List<InboxSms>> queryRecent({int limit = 50});
}

/// Android `content://sms/inbox` via platform channel.
class MethodChannelSmsInboxBackend implements SmsInboxBackend {
  MethodChannelSmsInboxBackend([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel('refund_radar/sms_inbox');

  final MethodChannel _channel;

  @override
  Future<List<InboxSms>> queryRecent({int limit = 50}) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'queryInbox',
        {'limit': limit},
      );
      if (result == null) return const [];
      return result.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return InboxSms(
          id: '${m['id'] ?? ''}',
          address: '${m['address'] ?? ''}',
          body: '${m['body'] ?? ''}',
          date: m['date'] is int
              ? DateTime.fromMillisecondsSinceEpoch(m['date'] as int)
              : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('MethodChannelSmsInboxBackend: $e');
      return const [];
    }
  }
}

/// Test double.
class ListSmsInboxBackend implements SmsInboxBackend {
  ListSmsInboxBackend(this.messages);
  final List<InboxSms> messages;

  @override
  Future<List<InboxSms>> queryRecent({int limit = 50}) async =>
      messages.take(limit).toList();
}

class SmsInboxService {
  SmsInboxService({SmsInboxBackend? backend})
      : _backend = backend ?? MethodChannelSmsInboxBackend();

  final SmsInboxBackend _backend;

  Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<bool> get hasPermission async {
    final s = await Permission.sms.status;
    return s.isGranted;
  }

  /// Recent bank/UPI-like messages for form prefill.
  Future<List<InboxSms>> queryBankLikeMessages({int limit = 40}) async {
    if (!await hasPermission) return const [];
    try {
      final raw = await _backend.queryRecent(limit: limit * 2);
      return raw.where(looksLikeBankSms).take(limit).toList();
    } catch (e) {
      debugPrint('SmsInboxService.query failed: $e');
      return const [];
    }
  }

  /// Exposed for unit tests.
  static bool looksLikeBankSms(InboxSms m) {
    final b = m.body;
    if (b.length < 12) return false;
    final parsed = SmsParser.parse(b);
    final upper = b.toUpperCase();
    return parsed.utr != null ||
        parsed.amount != null ||
        b.contains('Rs') ||
        b.contains('₹') ||
        upper.contains('UTR') ||
        upper.contains('UPI');
  }
}

final smsInboxServiceProvider = Provider<SmsInboxService>((ref) {
  return SmsInboxService();
});
