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
    // Common error / retry / etc — used by BrandedErrorBanner and several
    // dialogues. Previously dead code in app_en.arb (53 keys present there
    // but no getters in AppLocalizations). Phase 3 wires them.
    'commonError': {'en': 'Something went wrong', 'hi': 'कुछ गलत हुआ'},
    'commonRetry': {'en': 'Retry', 'hi': 'पुनः प्रयास'},
    'commonCancel': {'en': 'Cancel', 'hi': 'रद्द करें'},
    'commonOk': {'en': 'OK', 'hi': 'ओके'},
    'commonOffline': {
      'en': 'You are offline — changes will sync later.',
      'hi': 'आप ऑफ़लाइन हैं — बदलाव बाद में सिंक होंगे।'
    },
    'commonCopied': {'en': 'Copied to clipboard', 'hi': 'क्लिपबोर्ड पर कॉपी हुआ'},
    'commonClose': {'en': 'Close', 'hi': 'बंद करें'},
    // Screens still on hardcoded strings (Phase 3 background migration).
    'wizardTitle': {'en': 'Escalation steps', 'hi': 'बढ़ते कदम'},
    'wizardMarkFiled': {'en': 'Mark as filed', 'hi': 'दर्ज चिह्नित करें'},
    'wizardOpenPortal': {'en': 'Open portal', 'hi': 'पोर्टल खोलें'},
    'wizardTicketNumber': {'en': 'Ticket / complaint number', 'hi': 'टिकट / शिकायत नंबर'},
    'paywallTitle': {'en': 'Go Premium', 'hi': 'प्रीमियम लें'},
    'ombudsmanLetterTitle': {'en': 'Ombudsman letter', 'hi': 'ओम्बड्समैन पत्र'},
    'ombudsmanGenerate': {'en': 'Generate letter', 'hi': 'पत्र बनाएं'},
    'ombudsmanCopy': {'en': 'Copy', 'hi': 'कॉपी'},
    'ombudsmanOpenCms': {'en': 'Open cms.rbi.org.in', 'hi': 'cms.rbi.org.in खोलें'},
    'ombudsmanShareCopy': {'en': 'Share (copy to clipboard)', 'hi': 'शेयर (क्लिपबोर्ड पर कॉपी)'},
    'disputeTypeContinue': {'en': 'Continue →', 'hi': 'जारी रखें →'},
    'remindersNoneUpcoming': {'en': 'No upcoming reminders', 'hi': 'कोई आगामी रिमाइंडर नहीं'},
    'remindersTrackNew': {'en': 'Track a new dispute', 'hi': 'नया विवाद ट्रैक करें'},
    'remindersEmptySubtitle': {
      'en':
          'Reminders appear when you create or escalate a dispute — '
          'so you never miss a 30-day follow-up window.',
      'hi':
          'विवाद बनाने या बढ़ाने पर रिमाइंडर आते हैं — ताकि 30-दिन '
          'फॉलो-अप सीमा न चूके।'
    },
    'addBanksSearchHint': {'en': 'Search your bank', 'hi': 'अपना बैंक खोजें'},
    'settingsDisclaimerTitle': {'en': 'Disclaimer', 'hi': 'अस्वीकरण'},
    // Settings page — fully i18n'd in Phase 3 follow-up.
    'settingsTitle': {'en': 'Settings', 'hi': 'सेटिंग्स'},
    'settingsSmsDetection': {'en': 'SMS detection', 'hi': 'SMS पहचान'},
    'settingsAutoDetectUtr': {'en': 'Auto-detect UTR', 'hi': 'UTR ऑटो-पहचान'},
    'settingsSmsPermissionHint': {
      'en': 'SMS permission manages under Android settings.',
      'hi': 'SMS अनुमति Android सेटिंग्स में मिलती है।'
    },
    'settingsOnDeviceLabel': {'en': 'On-device. ', 'hi': 'ऑन-डिवाइस। '},
    'settingsNothingLeaves': {
      'en': 'Nothing leaves your phone.',
      'hi': 'आपका फ़ोन से कुछ बाहर नहीं जाता।'
    },
    'settingsDeadlineReminders': {'en': 'Deadline reminders', 'hi': 'समय-सीमा रिमाइंडर'},
    'settingsDailyComp': {'en': 'Daily comp clock', 'hi': 'दैनिक मुआवजा घड़ी'},
    'settingsWeeklyDigest': {'en': 'Weekly digest', 'hi': 'साप्ताहिक सारांश'},
    'settingsEnglish': {'en': 'English', 'hi': 'अंग्रेज़ी'},
    'settingsHindi': {'en': 'हिन्दी', 'hi': 'हिन्दी'},
    'settingsAppearance': {'en': 'Appearance', 'hi': 'दिखावट'},
    'settingsLight': {'en': 'Light', 'hi': 'लाइट'},
    'settingsDark': {'en': 'Dark', 'hi': 'डार्क'},
    'settingsSystemDefault': {'en': 'System default', 'hi': 'सिस्टम डिफ़ॉल्ट'},
    'settingsAbout': {'en': 'About', 'hi': 'बारे में'},
    'settingsVersion': {'en': 'Version', 'hi': 'संस्करण'},
    'settingsRbiSources': {'en': 'RBI sources', 'hi': 'RBI स्रोत'},
    'settingsLegal': {'en': 'Legal', 'hi': 'क़ानूनी'},
    'settingsLegalRow': {
      'en': 'Disclaimer · Privacy · Delete data',
      'hi': 'अस्वीकरण · गोपनीयता · डेटा हटाएं'
    },
    'settingsNotAffiliated': {
      'en': 'Not affiliated with RBI/NPCI/banks',
      'hi': 'RBI/NPCI/बैंक से संबद्ध नहीं'
    },
    'settingsSignOut': {'en': 'Sign out', 'hi': 'साइन आउट'},
    'settingsSignOutNotImplemented': {
      'en': 'Sign out not implemented.',
      'hi': 'साइन आउट लागू नहीं।'
    },
    'settingsProBadge': {'en': '⭐ Pro', 'hi': '⭐ प्रो'},
    'settingsLocalProfile': {'en': 'Local profile', 'hi': 'स्थानीय प्रोफ़ाइल'},
    'settingsRefundRadarUser': {'en': 'Refund Radar user', 'hi': 'रिफंड रडार उपयोगकर्ता'},
    // Escalate page.
    'escalateAppBarTitle': {'en': 'Escalate', 'hi': 'कदम बढ़ाएं'},
    'escalateMaxClaim': {'en': 'Maximum you can claim', 'hi': 'अधिकतम दावा राशि'},
    'escalateRefundPlusComp': {
      'en': '{refund} refund + {comp} comp ({days} days × ₹100/day)',
      'hi': '{refund} वापसी + {comp} मुआवजा ({days} दिन × ₹100/दिन)'
    },
    'escalateSendTo': {'en': 'SEND TO', 'hi': 'भेजें'},
    'escalateNodalOfficer': {'en': 'Nodal Officer', 'hi': 'नोडल अधिकारी'},
    'escalateSlaDays': {'en': '{email} · SLA 10d', 'hi': '{email} · SLA 10 दिन'},
    'escalateCcOmbudsman': {'en': 'CC RBI Ombudsman', 'hi': 'CC RBI ऑम्बड्समैन'},
    'escalateEmailPreview': {'en': 'EMAIL PREVIEW', 'hi': 'ईमेल पूर्वावलोकन'},
    'escalateEmailSubject': {'en': 'Subject: Escalation — UTR {txnId}', 'hi': 'विषय: एस्केलेशन — UTR {txnId}'},
    'escalateEmailGreeting': {'en': 'Dear Nodal Officer,', 'hi': 'प्रिय नोडल अधिकारी,'},
    'escalateEmailAutoDrafted': {'en': '[auto-drafted, tap to edit]', 'hi': '[स्वतः तैयार, संपादित करें]'},
    'escalateStandardsCompliant': {'en': 'Standards-compliant · view source', 'hi': 'मानक-अनुरूप · स्रोत देखें'},
    'escalateSendWithinPrefix': {'en': 'Send within ', 'hi': 'भेजें '},
    'escalateSendWithin24h': {'en': '24 hours', 'hi': '24 घंटे'},
    'escalateSendWithinSuffix': {
      'en': ' to claim full {comp} comp retroactively.',
      'hi': ' अनुपात में पूरा {comp} मुआवजा पाने के लिए।'
    },
    'escalateEdit': {'en': 'Edit', 'hi': 'संपादित करें'},
    'escalateSend': {'en': 'Send escalation →', 'hi': 'एस्केलेशन भेजें →'},
    'escalateCopiedToClipboard': {'en': 'Email copied to clipboard', 'hi': 'ईमेल क्लिपबोर्ड पर कॉपी हुआ'},
    'escalateDrafted': {'en': 'Drafted — open your mail app: {url}', 'hi': 'तैयार है — अपना मेल ऐप खोलें: {url}'},
    // Dispute detail activity log + timeline.
    'detailTimelineL1': {'en': 'File L1 complaint', 'hi': 'L1 शिकायत दर्ज करें'},
    'detailTimelineReported': {'en': 'Reported', 'hi': 'रिपोर्ट किया'},
    'detailTimelineReportedDetail': {'en': 'T+0 · {date}', 'hi': 'T+0 · {date}'},
    'detailTimelineAck': {'en': 'Bank must acknowledge', 'hi': 'बैंक पावती दे'},
    'detailTimelineAckDone': {'en': 'T+1 · acknowledged', 'hi': 'T+1 · पावती मिली'},
    'detailTimelineAckPending': {'en': 'T+1 · by today', 'hi': 'T+1 · आज तक'},
    'detailTimelineRefund': {'en': 'Refund due', 'hi': 'वापसी देय'},
    'detailTimelineRefundDone': {'en': 'T+{tat} · refunded', 'hi': 'T+{tat} · वापस हुई'},
    'detailTimelineRefundMissed': {'en': 'T+{tat} · deadline missed — escalate', 'hi': 'T+{tat} · समय खत्म — बढ़ाएं'},
    'detailTimelineRefundPending': {'en': 'T+{tat} · {date} (in {days}d)', 'hi': 'T+{tat} · {date} ({days}दिन में)'},
    'detailTimelineEscalate': {'en': 'Escalate to nodal officer', 'hi': 'नोडल अधिकारी को भेजें'},
    'detailTimelineOmbudsman': {'en': 'RBI Banking Ombudsman', 'hi': 'RBI बैंकिंग ऑम्बड्समैन'},
    'detailTimelineL2Detail': {'en': 'Filed · {ticket}', 'hi': 'दर्ज · {ticket}'},
    'detailTimelineL2Pending': {'en': 'If no refund by T+{tat}', 'hi': 'यदि T+{tat} तक वापसी नहीं'},
    'detailTimelineL3Detail': {'en': 'Filed · {ticket}', 'hi': 'दर्ज · {ticket}'},
    'detailTimelineL3Pending': {'en': 'If unresolved after T+10 (30 days)', 'hi': 'यदि T+10 (30 दिन) बाद भी अनसुलझा'},
    'detailActivityHeader': {'en': 'Activity · {count} events', 'hi': 'गतिविधि · {count} घटनाएं'},
    'detailActivityTicket': {'en': 'Ticket {ticket} filed', 'hi': 'टिकट {ticket} दर्ज'},
    'detailActivityTicketMeta': {'en': 'Auto-generated · {date}', 'hi': 'स्वतः तैयार · {date}'},
    'detailActivityAutoUtr': {'en': 'Auto-detected UTR from SMS', 'hi': 'SMS से UTR ऑटो-पहचान'},
    'detailActivityMarkedActive': {'en': 'Dispute marked active', 'hi': 'विवाद सक्रिय चिह्नित'},
    'detailActivityResolved': {'en': 'Dispute resolved', 'hi': 'विवाद सुलझा'},
    // Dispute form labels + validation.
    'formEnterAmount': {'en': 'Enter the debited amount', 'hi': 'कटी हुई राशि दर्ज करें'},
    'formLabelBank': {'en': 'Bank', 'hi': 'बैंक'},
    'formLabelUtr': {'en': 'UTR / RRN NUMBER', 'hi': 'UTR / RRN नंबर'},
    'formUtrFound': {'en': '✓ found', 'hi': '✓ मिला'},
    'formUtrHint12': {'en': '12 digits', 'hi': '12 अंक'},
    'formLabelAmountDebited': {'en': 'AMOUNT DEBITED', 'hi': 'कटी राशि'},
    'formLabelTxnDate': {'en': 'TXN DATE', 'hi': 'लेन-देन तिथि'},
    'formSelectDate': {'en': 'Select date', 'hi': 'तिथि चुनें'},
    'formLabelDescription': {'en': 'DESCRIPTION (optional)', 'hi': 'विवरण (वैकल्पिक)'},
    // Home page remaining.
    'homeViewAllDisputes': {'en': 'View all disputes', 'hi': 'सभी विवाद देखें'},
    // History page.
    'historyTitle': {'en': 'History', 'hi': 'इतिहास'},
    'historyTotalWon': {'en': 'TOTAL WON', 'hi': 'कुल जीत'},
    'historyWinRate': {'en': 'WIN RATE', 'hi': 'जीत दर'},
    'historyEmptyTitle': {'en': 'No history yet', 'hi': 'अभी कोई इतिहास नहीं'},
    'historyEmptySubtitle': {
      'en': 'Resolved and expired disputes will appear here.',
      'hi': 'सुलझे और समाप्त विवाद यहाँ दिखेंगे।'
    },
    'historyThisYear': {'en': 'This year', 'hi': 'इस वर्ष'},
    'historyFilterAll': {'en': 'All', 'hi': 'सभी'},
    'historyFilterWon': {'en': 'Won', 'hi': 'जीते'},
    'historyFilterLost': {'en': 'Lost', 'hi': 'हारे'},
    'historyFilterEscalated': {'en': 'Escalated', 'hi': 'बढ़ाए'},
    // Add banks page.
    'addBanksTitle': {'en': 'Add your bank', 'hi': 'अपना बैंक जोड़ें'},
    'addBanksSearchLabel': {'en': 'Search', 'hi': 'खोजें'},
    'addBanksEmpty': {'en': 'No bank found', 'hi': 'कोई बैंक नहीं मिला'},
    // Template library.
    'templateLevelLabel': {'en': 'Level {level}', 'hi': 'स्तर {level}'},
    'templateProBadge': {'en': 'Pro', 'hi': 'प्रो'},
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
  String get onboardSlide1Title => _t('onboardSlide1Title');
  String get onboardSlide1Desc => _t('onboardSlide1Desc');
  String get onboardSlide2Title => _t('onboardSlide2Title');
  String get onboardSlide2Desc => _t('onboardSlide2Desc');
  String get onboardSlide3Title => _t('onboardSlide3Title');
  String get onboardSlide3Desc => _t('onboardSlide3Desc');
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
  String get paywallFreeRow => _t('paywallFreeRow');
  String get paywallPremiumRow => _t('paywallPremiumRow');
  String get paywallActiveDisputes => _t('paywallActiveDisputes');
  String get paywallTemplates => _t('paywallTemplates');
  String get paywallOmbudsmanLetter => _t('paywallOmbudsmanLetter');
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

  // Phase 3 — common strings (BrandedErrorBanner + dialogs):
  String get commonError => _t('commonError');
  String get commonRetry => _t('commonRetry');
  String get commonCancel => _t('commonCancel');
  String get commonOk => _t('commonOk');
  String get commonOffline => _t('commonOffline');
  String get commonCopied => _t('commonCopied');
  String get commonClose => _t('commonClose');

  // Phase 3 — per-screen strings (one-off migrations):
  String get wizardTitle => _t('wizardTitle');
  String get wizardMarkFiled => _t('wizardMarkFiled');
  String get wizardOpenPortal => _t('wizardOpenPortal');
  String get wizardTicketNumber => _t('wizardTicketNumber');
  String get paywallTitle => _t('paywallTitle');
  String get ombudsmanLetterTitle => _t('ombudsmanLetterTitle');
  String get ombudsmanGenerate => _t('ombudsmanGenerate');
  String get ombudsmanCopy => _t('ombudsmanCopy');
  String get ombudsmanOpenCms => _t('ombudsmanOpenCms');
  String get ombudsmanShareCopy => _t('ombudsmanShareCopy');
  String get disputeTypeContinue => _t('disputeTypeContinue');
  String get remindersNoneUpcoming => _t('remindersNoneUpcoming');
  String get remindersTrackNew => _t('remindersTrackNew');
  String get remindersEmptySubtitle => _t('remindersEmptySubtitle');
  String get addBanksSearchHint => _t('addBanksSearchHint');
  String get settingsDisclaimerTitle => _t('settingsDisclaimerTitle');

  // Settings page full i18n.
  String get settingsTitle => _t('settingsTitle');
  String get settingsSmsDetection => _t('settingsSmsDetection');
  String get settingsAutoDetectUtr => _t('settingsAutoDetectUtr');
  String get settingsSmsPermissionHint => _t('settingsSmsPermissionHint');
  String get settingsOnDeviceLabel => _t('settingsOnDeviceLabel');
  String get settingsNothingLeaves => _t('settingsNothingLeaves');
  String get settingsDeadlineReminders => _t('settingsDeadlineReminders');
  String get settingsDailyComp => _t('settingsDailyComp');
  String get settingsWeeklyDigest => _t('settingsWeeklyDigest');
  String get settingsEnglish => _t('settingsEnglish');
  String get settingsHindi => _t('settingsHindi');
  String get settingsAppearance => _t('settingsAppearance');
  String get settingsLight => _t('settingsLight');
  String get settingsDark => _t('settingsDark');
  String get settingsSystemDefault => _t('settingsSystemDefault');
  String get settingsAbout => _t('settingsAbout');
  String get settingsVersion => _t('settingsVersion');
  String get settingsRbiSources => _t('settingsRbiSources');
  String get settingsLegal => _t('settingsLegal');
  String get settingsLegalRow => _t('settingsLegalRow');
  String get settingsNotAffiliated => _t('settingsNotAffiliated');
  String get settingsSignOut => _t('settingsSignOut');
  String get settingsSignOutNotImplemented => _t('settingsSignOutNotImplemented');
  String get settingsProBadge => _t('settingsProBadge');
  String get settingsLocalProfile => _t('settingsLocalProfile');
  String get settingsRefundRadarUser => _t('settingsRefundRadarUser');

  // Escalate page.
  String get escalateAppBarTitle => _t('escalateAppBarTitle');
  String get escalateMaxClaim => _t('escalateMaxClaim');
  String escalateRefundPlusComp(String refund, String comp, int days) =>
      _t('escalateRefundPlusComp', args: {'refund': refund, 'comp': comp, 'days': '$days'});
  String get escalateSendTo => _t('escalateSendTo');
  String get escalateNodalOfficer => _t('escalateNodalOfficer');
  String escalateSlaDays(String email) => _t('escalateSlaDays', args: {'email': email});
  String get escalateCcOmbudsman => _t('escalateCcOmbudsman');
  String get escalateEmailPreview => _t('escalateEmailPreview');
  String escalateEmailSubject(String txnId) => _t('escalateEmailSubject', args: {'txnId': txnId});
  String get escalateEmailGreeting => _t('escalateEmailGreeting');
  String get escalateEmailAutoDrafted => _t('escalateEmailAutoDrafted');
  String get escalateStandardsCompliant => _t('escalateStandardsCompliant');
  String get escalateSendWithinPrefix => _t('escalateSendWithinPrefix');
  String get escalateSendWithin24h => _t('escalateSendWithin24h');
  String escalateSendWithinSuffix(String comp) => _t('escalateSendWithinSuffix', args: {'comp': comp});
  String get escalateEdit => _t('escalateEdit');
  String get escalateSend => _t('escalateSend');
  String get escalateCopiedToClipboard => _t('escalateCopiedToClipboard');
  String escalateDrafted(String url) => _t('escalateDrafted', args: {'url': url});

  // Dispute detail page activity log + timeline.
  String get detailTimelineL1 => _t('detailTimelineL1');
  String get detailTimelineReported => _t('detailTimelineReported');
  String detailTimelineReportedDetail(String date) => _t('detailTimelineReportedDetail', args: {'date': date});
  String get detailTimelineAck => _t('detailTimelineAck');
  String get detailTimelineAckDone => _t('detailTimelineAckDone');
  String get detailTimelineAckPending => _t('detailTimelineAckPending');
  String get detailTimelineRefund => _t('detailTimelineRefund');
  String detailTimelineRefundDone(String tat) => _t('detailTimelineRefundDone', args: {'tat': tat});
  String detailTimelineRefundMissed(String tat) => _t('detailTimelineRefundMissed', args: {'tat': tat});
  String detailTimelineRefundPending(String tat, String date, int days) =>
      _t('detailTimelineRefundPending', args: {'tat': tat, 'date': date, 'days': '$days'});
  String get detailTimelineEscalate => _t('detailTimelineEscalate');
  String get detailTimelineOmbudsman => _t('detailTimelineOmbudsman');
  String detailTimelineL2Detail(String ticket) => _t('detailTimelineL2Detail', args: {'ticket': ticket});
  String detailTimelineL2Pending(String tat) => _t('detailTimelineL2Pending', args: {'tat': tat});
  String detailTimelineL3Detail(String ticket) => _t('detailTimelineL3Detail', args: {'ticket': ticket});
  String get detailTimelineL3Pending => _t('detailTimelineL3Pending');
  String detailActivityHeader(int count) => _t('detailActivityHeader', args: {'count': '$count'});
  String detailActivityTicket(String ticket) => _t('detailActivityTicket', args: {'ticket': ticket});
  String detailActivityTicketMeta(String date) => _t('detailActivityTicketMeta', args: {'date': date});
  String get detailActivityAutoUtr => _t('detailActivityAutoUtr');
  String get detailActivityMarkedActive => _t('detailActivityMarkedActive');
  String get detailActivityResolved => _t('detailActivityResolved');

  // Dispute form validation + labels.
  String get formEnterAmount => _t('formEnterAmount');
  String get formLabelBank => _t('formLabelBank');
  String get formLabelUtr => _t('formLabelUtr');
  String get formUtrFound => _t('formUtrFound');
  String get formUtrHint12 => _t('formUtrHint12');
  String get formLabelAmountDebited => _t('formLabelAmountDebited');
  String get formLabelTxnDate => _t('formLabelTxnDate');
  String get formSelectDate => _t('formSelectDate');
  String get formLabelDescription => _t('formLabelDescription');

  // Home page remaining strings.
  String get homeViewAllDisputes => _t('homeViewAllDisputes');

  // History page.
  String get historyTitle => _t('historyTitle');
  String get historyTotalWon => _t('historyTotalWon');
  String get historyWinRate => _t('historyWinRate');
  String get historyEmptyTitle => _t('historyEmptyTitle');
  String get historyEmptySubtitle => _t('historyEmptySubtitle');
  String get historyThisYear => _t('historyThisYear');
  String get historyFilterAll => _t('historyFilterAll');
  String get historyFilterWon => _t('historyFilterWon');
  String get historyFilterLost => _t('historyFilterLost');
  String get historyFilterEscalated => _t('historyFilterEscalated');

  // Add banks page.
  String get addBanksTitle => _t('addBanksTitle');
  String get addBanksSearchLabel => _t('addBanksSearchLabel');
  String get addBanksEmpty => _t('addBanksEmpty');

  // Template library page.
  String templateLevelLabel(int level) =>
      _t('templateLevelLabel', args: {'level': '$level'});
  String get templateProBadge => _t('templateProBadge');
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
