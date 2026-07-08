import 'package:url_launcher/url_launcher.dart';

Future<void> launchExternalUrl(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> launchPhone(String phone) async {
  await launchUrl(Uri.parse('tel:$phone'));
}

Future<void> launchEmail(String email, {String? subject, String? body}) async {
  final uri = EmailUtil.build(email, subject: subject, body: body);
  await launchUrl(uri);
}

class EmailUtil {
  static Uri build(String email, {String? subject, String? body}) {
    final params = <String, String>{};
    if (subject != null) params['subject'] = subject;
    if (body != null) params['body'] = body;
    return Uri(scheme: 'mailto', path: email, queryParameters: params);
  }
}
