/// Centralized route paths to prevent typos in `context.push`/`context.go` calls.
///
/// Usage:
/// ```dart
/// context.push(AppRoutes.disputesCreate);
/// context.push(AppRoutes.disputeDetail(d.id));
/// context.push(AppRoutes.disputesForm(type: 'upi_p2p', utr: '12345'));
/// ```
class AppRoutes {
  AppRoutes._();

  static const onboard = '/onboard';
  static const onboardSms = '/onboard/sms';
  static const onboardBanks = '/onboard/banks';
  static const home = '/home';
  static const disputesCreate = '/disputes/create';
  static const disputesForm = '/disputes/form';
  static const reminders = '/reminders';
  static const settings = '/settings';
  static const templates = '/templates';
  static const history = '/history';
  static const paywall = '/paywall';

  static String disputeDetail(String id) => '/disputes/$id';
  static String escalate(String id) => '/escalate/$id';
  static String wizard(String disputeId) => '/wizard/$disputeId';
  static String ombudsman(String disputeId) => '/ombudsman/$disputeId';

  // Wave 4a — full-screen Template Picker + Preview.
  static const templatePicker = '/templates/picker';
  static const templatePreview = '/templates/preview';
  static String templatePickerWithDispute(String disputeId) =>
      Uri(path: templatePicker, queryParameters: {'disputeId': disputeId})
          .toString();
  static String templatePreviewWith({
    required String disputeId,
    required String templateId,
  }) =>
      Uri(
        path: templatePreview,
        queryParameters: {
          'disputeId': disputeId,
          'templateId': templateId,
        },
      ).toString();

  static String paywallWithReturn(String returnPath, String trigger) =>
      '$paywall?return=$returnPath&trigger=$trigger';

  static String paywallWithParams({
    required String trigger,
    String? returnPath,
    String? templateId,
    String? templateTitle,
  }) {
    final qp = <String, String>{'trigger': trigger};
    if (returnPath != null) qp['return'] = returnPath;
    if (templateId != null) qp['templateId'] = templateId;
    if (templateTitle != null) qp['templateTitle'] = templateTitle;
    return Uri(path: paywall, queryParameters: qp).toString();
  }

  static String disputesFormWithParams({
    String type = 'upi_p2p',
    String? utr,
    String? amount,
    String? sender,
  }) {
    final qp = <String, String>{'type': type};
    if (utr != null) qp['utr'] = utr;
    if (amount != null) qp['amount'] = amount;
    if (sender != null) qp['sender'] = sender;
    return Uri(path: disputesForm, queryParameters: qp).toString();
  }
}
