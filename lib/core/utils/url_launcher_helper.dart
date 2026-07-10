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
    final params = <String, String>{};
    if (subject != null) params['subject'] = subject;
    if (body != null) params['body'] = body;
    if (cc != null && cc.isNotEmpty) params['cc'] = cc;
    return Uri(scheme: 'mailto', path: email, queryParameters: params);
  }
}
