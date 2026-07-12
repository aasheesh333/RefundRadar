import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:refund_radar/data/models/utr_detection.dart';
import 'package:refund_radar/services/sms_parser.dart';

/// MethodChannel that [SmsReceiver] (MainActivity.kt) invokes with
/// `onSmsReceived` for every incoming SMS while the Flutter engine is alive.
/// Kept as a top-level constant for the listener and tests to reference.
const MethodChannel smsEventsChannel = MethodChannel('refund_radar/sms_events');

/// A stream-of-events provider for live UTR auto-detect (Task C4).
///
/// Each incoming SMS handled by the Kotlin `SmsReceiver` arrives here as an
/// `onSmsReceived` method call; we run [SmsParser] and, when the body
/// contains a UTR, emit a [UtrDetection]. Non-bank SMS are dropped silently
/// (no UTR match) so the UI only reacts to actionable messages.
///
/// On non-Android platforms the channel never receives calls, so we yield
/// an empty stream and keep the handler attached harmlessly. The stream
/// stays open for the whole session (the receiver lifetime equals the
/// Flutter engine lifetime). Closing is handled by Riverpod once all
/// listeners go away.
final utrDetectionProvider = StreamProvider<UtrDetection>((ref) async* {
  if (defaultTargetPlatform != TargetPlatform.android) {
    yield* const Stream<UtrDetection>.empty();
    return;
  }

  final controller = StreamController<UtrDetection>.broadcast();

  smsEventsChannel.setMethodCallHandler((call) async {
    if (call.method != 'onSmsReceived') return null;
    final args = call.arguments;
    if (args is! Map) return null;
    final map = Map<String, dynamic>.from(args);
    final sender = map['sender'] as String? ?? '';
    final body = map['body'] as String? ?? '';
    if (body.trim().isEmpty) return null;
    final timestamp = (map['timestamp'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;

    final parsed = SmsParser.parse(body);
    final utr = parsed.utr;
    if (utr == null || utr.isEmpty) return null;

    controller.add(UtrDetection(
      utr: utr,
      amount: parsed.amount,
      date: parsed.date,
      sender: sender,
      smsBody: body,
      detectedAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
    ));
    return null;
  });

  ref.onDispose(() {
    // Detach the handler so a restart of the provider doesn't leave two
    // handlers attached to the same channel.
    smsEventsChannel.setMethodCallHandler(null);
    controller.close();
  });

  yield* controller.stream;
});

/// Hot list of all detections seen this session (Task C8 accumulator).
///
/// The [utrDetectionProvider] stream is one-at-a-time; for a persistent
/// "Detected transactions" banner the home page needs the full set. This
/// notifier subscribes to the stream once and appends every new detection
/// (de-duped by UTR — repeats for the same UTR within a short window don't
/// stack up as duplicate cards). Marking a detection `claimed` removes the
/// banner; the list is cleared on logout/dispose.
final utrDetectionsProvider =
    StateNotifierProvider<UtrDetectionsNotifier, List<UtrDetection>>((ref) {
  return UtrDetectionsNotifier(ref);
});

class UtrDetectionsNotifier extends StateNotifier<List<UtrDetection>> {
  UtrDetectionsNotifier(this._ref) : super(const []) {
    _subscription = _ref.listen<AsyncValue<UtrDetection>>(
      utrDetectionProvider,
      (_, next) {
        next.whenData(_append);
      },
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AsyncValue<UtrDetection>> _subscription;

  void _append(UtrDetection detection) {
    // De-duplicate by UTR — a sender re-sending the same confirmation SMS
    // (or the SMS arriving in two PDU parts) mustn't stack duplicates.
    if (state.any((d) => d.utr == detection.utr)) return;
    state = [...state, detection];
  }

  /// Mark a detection claimed — the home banner for it disappears. Called
  /// when the user taps the card (deep-link into the form) or dismisses it.
  void markClaimed(String utr) {
    state = state.where((d) => d.utr != utr).toList(growable: false);
  }

  /// Remove all detections (used on logout / sign-out).
  void clear() => state = const [];

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
