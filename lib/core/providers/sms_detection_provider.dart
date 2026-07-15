import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the SMS auto-detect (UTR) feature is enabled by the user.
///
/// The stored boolean only takes effect when the SMS runtime permission is
/// granted; if the user revokes the permission we report `false` so the UI
/// toggle stays in sync with what the receiver can actually do. The native
/// [SmsReceiver] also reads this flag (via SharedPreferences) as a kill-switch
/// so an off-toggle stops forwarding SMS even while permission is still held.
const _kPrefSmsDetection = 'settings.sms_detection_enabled';

final smsDetectionEnabledProvider = StateProvider<bool>((ref) => false);

/// Load the persisted SMS-detect toggle, gated by the runtime permission.
/// Returns `false` when the permission is not granted so the UI never lies
/// about an enabling state the OS won't honour.
Future<bool> loadSmsDetectionEnabled() async {
  final granted = await Permission.sms.status.isGranted;
  if (!granted) return false;
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kPrefSmsDetection) ?? true;
}

/// Persist the SMS-detect toggle. Caller is responsible for updating the
/// provider state separately (so the UI update is synchronous).
Future<void> setSmsDetectionEnabled(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kPrefSmsDetection, value);
}
