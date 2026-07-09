import 'package:url_launcher/url_launcher.dart';

Future<void> launchExternalUrl(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> launchPhone(String phone) async {
  await launchUrl(Uri.parse('tel:$phone'));
}

Future<bool> launchEmail(
  String email, {
  String? subject,
  String? body,
  String? cc,
}) async {
  final uri = EmailUtil.build(email, subject: subject, body: body, cc: cc);
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri);
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
