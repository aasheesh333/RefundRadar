import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);
  final Locale locale;
  static AppLocalizations? of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations);

  static const AppLocalizationsDelegate delegate = AppLocalizationsDelegate();
  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[delegate];

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  static const _strings = <String, Map<String, String>>{
    'appName': {'en': 'Refund Radar', 'hi': 'रिफंड रडार'},
    'tagline': {'en': 'Bank owes you. We track it.', 'hi': 'पैसा अटका है? हम वसूली का रास्ता दिखाएँगे।'},
    'onboardSkip': {'en': 'Skip', 'hi': 'स्किप'},
    'onboardCta': {'en': 'Start free', 'hi': 'मुफ़्त शुरू करें'},
    'onboardSlide1Title': {'en': '₹100/day — banks owe YOU\nfor failed UPI', 'hi': '₹100/दिन — बैंक आपको देता\nUPI फेल होने पर'},
    'onboardSlide1Desc': {'en': 'RBI rules make banks pay compensation for delayed refunds.', 'hi': 'RBI नियमों के तहत देरी पर बैंक देरता है।'},
    'onboardSlide2Title': {'en': 'FASTag double-cut?\n30 din ka window', 'hi': 'FASTag डबल कट?\n30 दिन की सीमा'},
    'onboardSlide2Desc': {'en': 'NPCI mandates 30 days to dispute toll deductions.', 'hi': 'NPCI 30 दिन में शिकायत करने देता है।'},
    'onboardSlide3Title': {'en': 'We guide, you claim\nRBI-rule backed', 'hi': 'हम रास्ता, आप दावा\nRBI नियम समर्थित'},
    'onboardSlide3Desc': {'en': 'Smart deadlines, pre-made complaints, escalation ladder.', 'hi': 'स्मार्ट समय-सीमा, तैयार शिकायतें, बढ़ते कदम।'},
    'homeOwedTitle': {'en': 'Total Owed', 'hi': 'कुल देय'},
    'homeOwedSubtitle': {'en': 'across {count} disputes, growing ₹{perDay}/day', 'hi': '{count} विवादों में, ₹{perDay}/दिन बढ़ रहा'},
    'homeNewDispute': {'en': 'New dispute', 'hi': 'नया विवाद'},
    'homeEmptyTitle': {'en': 'No disputes yet', 'hi': 'अभी कोई विवाद नहीं'},
    'homeEmptySubtitle': {'en': 'Add your first stuck transaction to start tracking compensation.', 'hi': 'पहला अटका पैसा जोड़कर वसूली शुरू करें।'},
    'homeAddDispute': {'en': 'Add dispute', 'hi': 'विवाद जोड़ें'},
    'disputeTypeUPI': {'en': 'Failed UPI / IMPS / ATM', 'hi': 'UPI / IMPS / ATM फेल'},
    'disputeTypeFastag': {'en': 'FASTag wrong deduction', 'hi': 'FASTag गलत कटौती'},
    'disputeTypeBankCharge': {'en': 'Wrong bank charge', 'hi': 'गलत बैंक शुल्क'},
    'disputeTypeWrongTransfer': {'en': 'Wrong transfer', 'hi': 'गलत ट्रांसफर'},
    'formAmountLabel': {'en': 'Amount (₹)', 'hi': 'राशि (₹)'},
    'formDateLabel': {'en': 'Transaction date', 'hi': 'लेनदेन तिथि'},
    'formTxnIdLabel': {'en': 'Transaction ID / UTR', 'hi': 'ट्रांजेक्शन आईडी / UTR'},
    'formEntityLabel': {'en': 'Bank / Issuer', 'hi': 'बैंक / जारीकर्ता'},
    'formPasteSms': {'en': 'Paste from SMS', 'hi': 'SMS से पेस्ट करें'},
    'formLiveChip': {'en': 'Deadline was {date} → Bank already owes you ₹{amount}', 'hi': 'सीमा {date} थी → बैंक ₹{amount} देने लायक'},
    'formCreateDispute': {'en': 'Create dispute', 'hi': 'विवाद बनाएं'},
    'detailCompensationCounter': {'en': 'Compensation owed', 'hi': 'देय मुआवजा'},
    'detailNextAction': {'en': 'Next action', 'hi': 'अगला कदम'},
    'detailMarkFiled': {'en': 'Mark as filed', 'hi': 'दर्ज चिह्नित करें'},
    'detailTicketNumber': {'en': 'Ticket number', 'hi': 'टिकट नंबर'},
    'detailOpenWizard': {'en': 'Open wizard', 'hi': 'विज़ार्ड खोलें'},
    'detailDangerWindowClosing': {'en': 'Dispute window closing soon!', 'hi': 'विवाद समय खत्म हो रहा!'},
    'wizardStepWhatToDo': {'en': 'What to do', 'hi': 'क्या करें'},
    'wizardStepWhereToGo': {'en': 'Where to go', 'hi': 'कहाँ जाएं'},
    'wizardCopyComplaint': {'en': 'Copy complaint text', 'hi': 'शिकायत कॉपी करें'},
    'wizardDocuments': {'en': 'Documents needed', 'hi': 'ज़रूरी दस्तावेज़'},
    'wizardDoneSetReminder': {'en': 'Done — set reminder', 'hi': 'हो गया — रिमाइंडर लगाएं'},
    'paywallHeadline': {'en': 'Recover more. Unlimited disputes + 50+ templates.', 'hi': 'और वसूली करें। असीमित विवाद + 50+ टेम्पलेट।'},
    'paywallMonthly': {'en': 'Monthly ₹99', 'hi': 'मासिक ₹99'},
    'paywallYearly': {'en': 'Yearly ₹499', 'hi': 'वार्षिक ₹499'},
    'paywallSave': {'en': 'Save 58%', 'hi': '58% बचाएं'},
    'paywallRestore': {'en': 'Restore purchases', 'hi': 'खरीद बहाल करें'},
    'paywallMaybeLater': {'en': 'Maybe later', 'hi': 'बाद में'},
    'paywallFreeRow': {'en': 'Free', 'hi': 'मुफ़्त'},
    'paywallPremiumRow': {'en': 'Premium', 'hi': 'प्रीमियम'},
    'paywallActiveDisputes': {'en': 'Active disputes', 'hi': 'सक्रिय विवाद'},
    'paywallTemplates': {'en': 'Templates', 'hi': 'टेम्पलेट'},
    'paywallOmbudsmanLetter': {'en': 'Ombudsman letter generator', 'hi': 'ऑम्बड्समैन पत्र जनरेटर'},
    'remindersTitle': {'en': 'Reminders', 'hi': 'रिमाइंडर'},
    'remindersEmpty': {'en': 'No upcoming reminders', 'hi': 'कोई रिमाइंडर नहीं'},
    'settingsLanguage': {'en': 'Language', 'hi': 'भाषा'},
    'settingsTheme': {'en': 'Theme', 'hi': 'थीम'},
    'settingsNotifications': {'en': 'Notifications', 'hi': 'सूचनाएं'},
    'settingsManageSubscription': {'en': 'Manage subscription', 'hi': 'सदस्यता प्रबंधित करें'},
    'settingsPrivacyPolicy': {'en': 'Privacy policy', 'hi': 'गोपनीयता नीति'},
    'settingsDisclaimers': {'en': 'Disclaimers', 'hi': 'अस्वीकरण'},
    'settingsDeleteData': {'en': 'Delete my data', 'hi': 'मेरा डेटा हटाएं'},
    'settingsDeleteConfirm': {'en': 'Delete all your data? This cannot be undone.', 'hi': 'सारा डेटा हटाएं? यह पूर्ववत नहीं।'},
    'disclaimerTitle': {'en': 'Disclaimer', 'hi': 'अस्वीकरण'},
    'disclaimerBody': {'en': 'Refund Radar is an independent informational tool. It is not affiliated with RBI, NPCI, NHAI, IHMCL, or any bank. We never ask for banking passwords, OTPs, or PINs. Complaints are filed by you on official portals. Compensation estimates are based on published RBI/NPCI rules and actual outcomes depend on your bank/regulator.', 'hi': 'रिफंड रडार एक स्वतंत्र जानकारी उपकरण है। यह RBI, NPCI, NHAI, IHMCL या किसी बैंक से संबद्ध नहीं है। हम कभी बैंकिंग पासवर्ड, OTP या PIN नहीं माँगते। शिकायतें आप आधिकारिक पोर्टल पर दर्ज करते हैं।'},
    'templatesTitle': {'en': 'Template Library', 'hi': 'टेम्पलेट लाइब्रेरी'},
    'templatesSearch': {'en': 'Search templates', 'hi': 'टेम्पलेट खोजें'},
    'templatesUnlock': {'en': 'Unlock 50+ templates', 'hi': '50+ टेम्पलेट अनलॉक करें'},
    'templatesLocked': {'en': 'Locked', 'hi': 'लॉक्ड'},
    'loading': {'en': 'Loading...', 'hi': 'लोड हो रहा...'},
    'errorGeneric': {'en': 'Something went wrong', 'hi': 'कुछ गलत हुआ'},
  };

  String _t(String key, {Map<String, String>? args}) {
    final map = _strings[key] ?? {'en': key, 'hi': key};
    var s = map[locale.languageCode] ?? map['en'] ?? key;
    args?.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  String get appName => _t('appName');
  String get tagline => _t('tagline');
  String get onboardSkip => _t('onboardSkip');
  String get onboardCta => _t('onboardCta');
  String get homeOwedTitle => _t('homeOwedTitle');
  String homeOwedSubtitle(int count, String perDay) =>
      _t('homeOwedSubtitle', args: {'count': '$count', 'perDay': perDay});
  String get homeNewDispute => _t('homeNewDispute');
  String get homeEmptyTitle => _t('homeEmptyTitle');
  String get homeEmptySubtitle => _t('homeEmptySubtitle');
  String get homeAddDispute => _t('homeAddDispute');
  String get disputeTypeUPI => _t('disputeTypeUPI');
  String get disputeTypeFastag => _t('disputeTypeFastag');
  String get disputeTypeBankCharge => _t('disputeTypeBankCharge');
  String get disputeTypeWrongTransfer => _t('disputeTypeWrongTransfer');
  String get formAmountLabel => _t('formAmountLabel');
  String get formDateLabel => _t('formDateLabel');
  String get formTxnIdLabel => _t('formTxnIdLabel');
  String get formEntityLabel => _t('formEntityLabel');
  String get formPasteSms => _t('formPasteSms');
  String formLiveChip(String date, String amount) =>
      _t('formLiveChip', args: {'date': date, 'amount': amount});
  String get formCreateDispute => _t('formCreateDispute');
  String get detailCompensationCounter => _t('detailCompensationCounter');
  String get detailNextAction => _t('detailNextAction');
  String get detailMarkFiled => _t('detailMarkFiled');
  String get detailTicketNumber => _t('detailTicketNumber');
  String get detailOpenWizard => _t('detailOpenWizard');
  String get detailDangerWindowClosing => _t('detailDangerWindowClosing');
  String get wizardCopyComplaint => _t('wizardCopyComplaint');
  String get wizardDoneSetReminder => _t('wizardDoneSetReminder');
  String get paywallHeadline => _t('paywallHeadline');
  String get paywallMonthly => _t('paywallMonthly');
  String get paywallYearly => _t('paywallYearly');
  String get paywallSave => _t('paywallSave');
  String get paywallRestore => _t('paywallRestore');
  String get paywallMaybeLater => _t('paywallMaybeLater');
  String get remindersTitle => _t('remindersTitle');
  String get remindersEmpty => _t('remindersEmpty');
  String get settingsLanguage => _t('settingsLanguage');
  String get settingsTheme => _t('settingsTheme');
  String get settingsNotifications => _t('settingsNotifications');
  String get settingsManageSubscription => _t('settingsManageSubscription');
  String get settingsPrivacyPolicy => _t('settingsPrivacyPolicy');
  String get settingsDisclaimers => _t('settingsDisclaimers');
  String get settingsDeleteData => _t('settingsDeleteData');
  String get settingsDeleteConfirm => _t('settingsDeleteConfirm');
  String get disclaimerBody => _t('disclaimerBody');
  String get templatesTitle => _t('templatesTitle');
  String get templatesSearch => _t('templatesSearch');
  String get templatesUnlock => _t('templatesUnlock');
  String get templatesLocked => _t('templatesLocked');
  String get loading => _t('loading');
  String get errorGeneric => _t('errorGeneric');
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) =>
      ['en', 'hi'].contains(locale.languageCode);
  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);
  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
