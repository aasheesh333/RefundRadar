import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> launchExternalUrl(String url) async {
  final uri = Uri.parse(url);
  return _tryLaunch(uri);
}

Future<bool> launchPhone(String phone) async {
  return _tryLaunch(Uri.parse('tel:$phone'));
}

Future<bool> launchEmail(
  String email, {
  String? subject,
  String? body,
  String? cc,
}) async {
  final uri = EmailUtil.build(email, subject: subject, body: body, cc: cc);
  return _tryLaunch(uri);
}

Future<bool> _tryLaunch(Uri uri) async {
  try {
    final launchable = await canLaunchUrl(uri);
    if (launchable ||
        uri.scheme == 'mailto' ||
        uri.scheme == 'tel' ||
        uri.scheme == 'https') {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (e, st) {
    debugPrint('_tryLaunch failed for ${uri.toString()}: $e\n$st');
  }
  return false;
}

class EmailUtil {
  static Uri build(
    String email, {
    String? subject,
    String? body,
    String? cc,
  }) {
    String enc(String? v) => v == null ? '' : Uri.encodeComponent(v);

    final parts = <String>[];
    if (subject != null) parts.add('subject=${enc(subject)}');
    if (body != null) parts.add('body=${enc(body)}');
    if (cc != null) parts.add('cc=${enc(cc)}');

    return Uri.parse('mailto:$email?${parts.join('&')}');
  }
}
