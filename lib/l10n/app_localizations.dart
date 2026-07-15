import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);
  final Locale locale;
  static AppLocalizations? of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations);

  static const AppLocalizationsDelegate delegate = AppLocalizationsDelegate();
  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
  ];

  static const supportedLocales = <Locale>[Locale('en'), Locale('hi')];

  static const _strings = <String, Map<String, String>>{
    'appName': {'en': 'Refund Radar', 'hi': 'रिफंड रडार'},
    'tagline': {
      'en': 'Bank owes you. We track it.',
      'hi': 'पैसा अटका है? हम वसूली का रास्ता दिखाएँगे।',
    },
    'onboardSkip': {'en': 'Skip', 'hi': 'स्किप'},
    'onboardCta': {'en': 'Start free', 'hi': 'मुफ़्त शुरू करें'},
    'onboardSlide1Title': {
      'en': '₹100/day — banks owe YOU\nfor failed UPI',
      'hi': '₹100/दिन — बैंक आपको देता\nUPI फेल होने पर',
    },
    'onboardSlide1Desc': {
      'en': 'RBI rules make banks pay compensation for delayed refunds.',
      'hi': 'RBI नियमों के तहत देरी पर बैंक देरता है।',
    },
    'onboardSlide2Title': {
      'en': 'FASTag double-cut?\n30 din ka window',
      'hi': 'FASTag डबल कट?\n30 दिन की सीमा',
    },
    'onboardSlide2Desc': {
      'en': 'NPCI mandates 30 days to dispute toll deductions.',
      'hi': 'NPCI 30 दिन में शिकायत करने देता है।',
    },
    'onboardSlide3Title': {
      'en': 'We guide, you claim\nRBI-rule backed',
      'hi': 'हम रास्ता, आप दावा\nRBI नियम समर्थित',
    },
    'onboardSlide3Desc': {
      'en': 'Smart deadlines, pre-made complaints, escalation ladder.',
      'hi': 'स्मार्ट समय-सीमा, तैयार शिकायतें, बढ़ते कदम।',
    },
    'homeOwedTitle': {'en': 'Total Owed', 'hi': 'कुल देय'},
    'homeOwedSubtitle': {
      'en': 'across {count} disputes, growing ₹{perDay}/day',
      'hi': '{count} विवादों में, ₹{perDay}/दिन बढ़ रहा',
    },
    'homeNewDispute': {'en': 'New dispute', 'hi': 'नया विवाद'},
    'homeEmptyTitle': {'en': 'No disputes yet', 'hi': 'अभी कोई विवाद नहीं'},
    'homeEmptySubtitle': {
      'en': 'Add your first stuck transaction to start tracking compensation.',
      'hi': 'पहला अटका पैसा जोड़कर वसूली शुरू करें।',
    },
    'homeAddDispute': {'en': 'Add dispute', 'hi': 'विवाद जोड़ें'},
    'homeActiveDisputes': {
      'en': '{count} active disputes',
      'hi': '{count} सक्रिय विवाद',
    },
    'homeActiveDisputeOne': {
      'en': '{count} active dispute',
      'hi': '{count} सक्रिय विवाद',
    },
    'homeYoureOwed': {'en': "YOU'RE OWED", 'hi': 'आपको मिलना है'},
    'homeDisputeCount': {'en': '{count} disputes', 'hi': '{count} विवाद'},
    'homeDisputeCountOne': {'en': '{count} dispute', 'hi': '{count} विवाद'},
    'cardDeadlineMissed': {
      'en': '⚠ Deadline missed — escalate now',
      'hi': '⚠ समय-सीमा चूकी — अभी बढ़ाएँ',
    },
    'cardDaysLeft': {'en': '{days} days left', 'hi': '{days} दिन बाकी'},
    'cardExpired': {'en': 'Expired', 'hi': 'समाप्त'},
    'cardGuidanceMode': {'en': 'Guidance mode', 'hi': 'मार्गदर्शन मोड'},
    'cardEscalateCta': {'en': 'Escalate →', 'hi': 'बढ़ाएँ →'},
    'cardViewCta': {'en': 'View →', 'hi': 'देखें →'},
    'settingsComingSoon': {'en': 'Coming soon', 'hi': 'जल्द आ रहा है'},
    'settingsDailyCompSoon': {
      'en': 'Daily comp clock (Coming soon)',
      'hi': 'दैनिक मुआवजा घड़ी (जल्द)',
    },
    'settingsWeeklyDigestSoon': {
      'en': 'Weekly digest (Coming soon)',
      'hi': 'साप्ताहिक सारांश (जल्द)',
    },
    'disputeTypeUPI': {
      'en': 'Failed UPI / IMPS / ATM',
      'hi': 'UPI / IMPS / ATM फेल',
    },
    'disputeTypeFastag': {
      'en': 'FASTag wrong deduction',
      'hi': 'FASTag गलत कटौती',
    },
    'disputeTypeBankCharge': {
      'en': 'Wrong bank charge',
      'hi': 'गलत बैंक शुल्क',
    },
    'disputeTypeWrongTransfer': {'en': 'Wrong transfer', 'hi': 'गलत ट्रांसफर'},
    'formAmountLabel': {'en': 'Amount (₹)', 'hi': 'राशि (₹)'},
    'formDateLabel': {'en': 'Transaction date', 'hi': 'लेनदेन तिथि'},
    'formTxnIdLabel': {
      'en': 'Transaction ID / UTR',
      'hi': 'ट्रांजेक्शन आईडी / UTR',
    },
    'formEntityLabel': {'en': 'Bank / Issuer', 'hi': 'बैंक / जारीकर्ता'},
    'formPasteSms': {'en': 'Paste from SMS', 'hi': 'SMS से पेस्ट करें'},
    'smsPermissionTitle': {
      'en': 'Use SMS import to fill disputes faster',
      'hi': 'विवाद जल्दी भरने के लिए SMS इम्पोर्ट करें',
    },
    'smsPermissionSubtitle': {
      'en':
          'RefundRadar reads your SMS inbox to auto-detect transaction references (UTR) and sends you instant notifications to claim or dispute your money. We never upload your SMS content — all detection happens on your device.',
      'hi':
          'RefundRadar आपके SMS इनबॉक्स को पढ़कर लेन-देन संदर्भ (UTR) स्वतः पहचानता है और आपको दावा करने या विवाद खोलने के लिए तुरंत सूचना भेजता है। हम कभी आपके SMS की सामग्री अपलोड नहीं करते — सभी पहचान आपके डिवाइस पर होती है।',
    },
    'smsPermissionHowItWorks1': {
      'en': 'You approve Android SMS inbox access',
      'hi': 'आप Android SMS इनबॉक्स एक्सेस मंजूर करते हैं',
    },
    'smsPermissionHowItWorks2': {
      'en': 'RefundRadar filters likely bank/refund messages on-device',
      'hi': 'RefundRadar फोन पर ही संभावित बैंक/रिफंड संदेश छांटता है',
    },
    'smsPermissionHowItWorks3': {
      'en': 'You choose a message to prefill the dispute form',
      'hi': 'फॉर्म भरने के लिए आप संदेश चुनते हैं',
    },
    'smsPermissionPrivacyNote': {
      'en':
          'SMS parsing stays on-device for import. You can skip this and paste an SMS manually later.',
      'hi':
          'SMS पार्सिंग इम्पोर्ट के लिए फोन पर ही रहती है। आप इसे छोड़कर बाद में SMS पेस्ट कर सकते हैं।',
    },
    'smsPermissionGrant': {
      'en': 'Allow SMS import',
      'hi': 'SMS इम्पोर्ट की अनुमति दें',
    },
    'smsPermissionSkip': {
      'en': 'Skip and paste manually',
      'hi': 'छोड़ें और मैन्युअल पेस्ट करें',
    },
    'formSmsPermissionDeniedAction': {
      'en':
          'SMS permission denied. Tap Paste to use a copied SMS, or enter details manually.',
      'hi':
          'SMS अनुमति नहीं मिली। कॉपी किया SMS उपयोग करने के लिए Paste दबाएं या विवरण मैन्युअल भरें।',
    },
    'formNoBankSmsAction': {
      'en':
          'No likely refund SMS found. Paste a copied SMS or enter details manually.',
      'hi':
          'संभावित रिफंड SMS नहीं मिला। कॉपी किया SMS पेस्ट करें या विवरण मैन्युअल भरें।',
    },
    'formSmsInboxFailed': {
      'en':
          'Could not read SMS inbox. Paste a copied SMS or enter details manually.',
      'hi':
          'SMS इनबॉक्स नहीं पढ़ सका। कॉपी किया SMS पेस्ट करें या विवरण मैन्युअल भरें।',
    },
    'formLiveChip': {
      'en': 'Deadline was {date} → Bank already owes you ₹{amount}',
      'hi': 'सीमा {date} थी → बैंक ₹{amount} देने लायक',
    },
    'formCreateDispute': {'en': 'Create dispute', 'hi': 'विवाद बनाएं'},
    'detailCompensationCounter': {
      'en': 'Compensation owed',
      'hi': 'देय मुआवजा',
    },
    'detailNextAction': {'en': 'Next action', 'hi': 'अगला कदम'},
    'detailMarkFiled': {'en': 'Mark as filed', 'hi': 'दर्ज चिह्नित करें'},
    'detailTicketNumber': {'en': 'Ticket number', 'hi': 'टिकट नंबर'},
    'detailOpenWizard': {'en': 'Open wizard', 'hi': 'विज़ार्ड खोलें'},
    'detailDangerWindowClosing': {
      'en': 'Dispute window closing soon!',
      'hi': 'विवाद समय खत्म हो रहा!',
    },
    'wizardStepWhatToDo': {'en': 'What to do', 'hi': 'क्या करें'},
    'wizardStepWhereToGo': {'en': 'Where to go', 'hi': 'कहाँ जाएं'},
    'wizardCopyComplaint': {
      'en': 'Copy complaint text',
      'hi': 'शिकायत कॉपी करें',
    },
    'wizardDocuments': {'en': 'Documents needed', 'hi': 'ज़रूरी दस्तावेज़'},
    'wizardDoneSetReminder': {
      'en': 'Done — set reminder',
      'hi': 'हो गया — रिमाइंडर लगाएं',
    },
    'paywallHeadline': {
      'en': 'Recover more. Unlimited disputes + 50+ templates.',
      'hi': 'और वसूली करें। असीमित विवाद + 50+ टेम्पलेट।',
    },
    'paywallHeadlineTemplate': {
      'en': 'Unlock “{title}” and 50+ premium templates.',
      'hi': '“{title}” और 50+ प्रीमियम टेम्पलेट अनलॉक करें।',
    },
    'paywallMonthly': {'en': 'Monthly ₹99', 'hi': 'मासिक ₹99'},
    'paywallYearly': {'en': 'Yearly ₹499', 'hi': 'वार्षिक ₹499'},
    'paywallSave': {'en': 'Save 58%', 'hi': '58% बचाएं'},
    'paywallRestore': {'en': 'Restore purchases', 'hi': 'खरीद बहाल करें'},
    'paywallMaybeLater': {'en': 'Maybe later', 'hi': 'बाद में'},
    'paywallFreeRow': {'en': 'Free', 'hi': 'मुफ़्त'},
    'paywallPremiumRow': {'en': 'Premium', 'hi': 'प्रीमियम'},
    'paywallActiveDisputes': {'en': 'Active disputes', 'hi': 'सक्रिय विवाद'},
    'paywallTemplates': {'en': 'Templates', 'hi': 'टेम्पलेट'},
    'paywallOmbudsmanLetter': {
      'en': 'Ombudsman letter generator',
      'hi': 'ऑम्बड्समैन पत्र जनरेटर',
    },
    'statusResolved': {'en': 'Resolved', 'hi': 'सुलझा'},
    'statusMissed': {'en': 'Missed', 'hi': 'छूटा'},
    'statusDayOf': {'en': 'Day {day} of {total}', 'hi': 'दिन {day}/{total}'},
    'typeUpiP2p': {'en': 'UPI / QR failed', 'hi': 'UPI / QR फेल'},
    'typeUpiP2m': {'en': 'Failed UPI refund', 'hi': 'UPI रिफंड नहीं मिला'},
    'typeAtm': {'en': 'ATM failed dispense', 'hi': 'ATM निकासी फेल'},
    'typeFastag': {'en': 'FASTag double-cut', 'hi': 'FASTag डबल कट'},
    'typeImps': {'en': 'IMPS / NEFT failed', 'hi': 'IMPS / NEFT फेल'},
    'typeBankCharge': {'en': 'Bank charge', 'hi': 'बैंक शुल्क'},
    'typeWrongTransfer': {'en': 'Wrong transfer', 'hi': 'गलत ट्रांसफर'},
    'typeSubUpiP2p': {
      'en': 'Debit, no credit · double debit',
      'hi': 'कटौती, क्रेडिट नहीं · डबल डेबिट',
    },
    'typeSubUpiP2m': {'en': 'Refund not received', 'hi': 'रिफंड नहीं मिला'},
    'typeSubAtm': {
      'en': 'Cash debited, not dispensed',
      'hi': 'पैसे कटे, निकले नहीं',
    },
    'typeSubFastag': {
      'en': 'Double debit · failed tag read',
      'hi': 'डबल डेबिट · टैग रीड फेल',
    },
    'typeSubImps': {
      'en': 'Money debited, not credited',
      'hi': 'पैसे कटे, जमा नहीं',
    },
    'typeSubBankCharge': {'en': 'Unauthorised debits', 'hi': 'अनधिकृत कटौती'},
    'typeSubWrongTransfer': {
      'en': 'Wrong-account guidance',
      'hi': 'गलत खाते की गाइड',
    },
    'typeCompPerDay': {
      'en': '₹{amount}/day compensation',
      'hi': '₹{amount}/दिन मुआवजा',
    },
    'wizardCallPrefix': {'en': 'Call', 'hi': 'कॉल'},
    'wizardLevel1Title': {
      'en': 'Level 1 - UPI app / bank',
      'hi': 'स्तर 1 - UPI ऐप / बैंक',
    },
    'wizardLevel1Body': {
      'en':
          'File complaint in your UPI app (GPay/PhonePe/Paytm) or your bank. Note the ticket number. Bank has up to 30 days to respond.',
      'hi':
          'अपने UPI ऐप (GPay/PhonePe/Paytm) या बैंक में शिकायत दर्ज करें। टिकट नंबर नोट करें। बैंक को 30 दिन तक जवाब देने का समय है।',
    },
    'wizardLevel2Title': {
      'en': 'Level 2 - NPCI portal',
      'hi': 'स्तर 2 - NPCI पोर्टल',
    },
    'wizardLevel2Body': {
      'en':
          'Visit NPCI Dispute Redressal portal. Needs UTR, amount, date, VPA, bank statement.',
      'hi':
          'NPCI Dispute Redressal पोर्टल पर जाएँ। UTR, राशि, तिथि, VPA, बैंक स्टेटमेंट चाहिए।',
    },
    'wizardLevel3Title': {
      'en': 'Level 3 - RBI Ombudsman',
      'hi': 'स्तर 3 - RBI ऑम्बड्समैन',
    },
    'wizardLevel3Body': {
      'en':
          'File at cms.rbi.org.in within 90 days of bank response window. Category: Deficiency in Service. Free.',
      'hi':
          'बैंक जवाब सीमा के 90 दिनों में cms.rbi.org.in पर दर्ज करें। श्रेणी: सेवा में कमी। मुफ़्त।',
    },
    'wizardSaveFailed': {
      'en': 'Could not save ticket. Try again.',
      'hi': 'टिकट सेव नहीं हुआ। फिर कोशिश करें।',
    },
    'detailTimelineFastagHeader': {
      'en': 'FASTag timeline (30-day window)',
      'hi': 'FASTag टाइमलाइन (30-दिन सीमा)',
    },
    'detailTimelineBankHeader': {
      'en': 'Bank timeline (30-day window)',
      'hi': 'बैंक टाइमलाइन (30-दिन सीमा)',
    },
    'detailTimelineRbiHeader': {
      'en': 'RBI timeline (T-day = 0)',
      'hi': 'RBI टाइमलाइन (T-दिन = 0)',
    },
    'detailTlWtRequest': {
      'en': 'Request to own bank',
      'hi': 'अपने बैंक को अनुरोध',
    },
    'detailTlWtRequestDetail': {
      'en': 'Contact your bank to reach the beneficiary',
      'hi': 'लाभार्थी तक पहुँचने के लिए बैंक से संपर्क करें',
    },
    'detailTlWtNpci': {'en': 'NPCI DRM entry', 'hi': 'NPCI DRM दर्ज'},
    'detailTlWtNpciDetail': {
      'en': 'Within 3 days — wrong-transfer portal',
      'hi': '3 दिनों में — गलत-ट्रांसफर पोर्टल',
    },
    'detailTlWtCyber': {'en': 'Cyber cell complaint', 'hi': 'साइबर सेल शिकायत'},
    'detailTlWtCyberDetail': {
      'en': 'If fraud suspected',
      'hi': 'यदि धोखाधड़ी संदेह हो',
    },
    'detailTlWtLegal': {'en': 'Legal notice', 'hi': 'कानूनी नोटिस'},
    'detailTlWtLegalDetail': {
      'en': 'Final escalation',
      'hi': 'अंतिम एस्केलेशन',
    },
    'detailTlFtReported': {'en': 'Reported', 'hi': 'रिपोर्ट किया'},
    'detailTlFtReportedDetail': {
      'en': 'Day 0 · transaction flagged',
      'hi': 'दिन 0 · लेनदेन चिह्नित',
    },
    'detailTlFtIssuer': {'en': 'Issuer bank', 'hi': 'जारीकर्ता बैंक'},
    'detailTlFtIssuerDetail': {
      'en': '{bank} dispute section · 7-10 days',
      'hi': '{bank} विवाद अनुभाग · 7-10 दिन',
    },
    'detailTlFtIssuerGeneric': {
      'en': 'Issuer bank · 7-10 days',
      'hi': 'जारीकर्ता बैंक · 7-10 दिन',
    },
    'detailTlFtHelpline': {'en': '1033 Helpline', 'hi': '1033 हेल्पलाइन'},
    'detailTlFtHelplineDetail': {
      'en': 'If no reply in 7 days',
      'hi': 'यदि 7 दिनों में जवाब नहीं',
    },
    'detailTlFtIhmcl': {
      'en': 'IHMCL false-deduction email',
      'hi': 'IHMCL गलत-कटौती ईमेल',
    },
    'detailTlFtIhmclDetail': {
      'en': 'falsededuction@ihmcl.com',
      'hi': 'falsededuction@ihmcl.com',
    },
    'detailTlFtOmbudsman': {'en': 'RBI Ombudsman', 'hi': 'RBI ऑम्बड्समैन'},
    'detailTlFtOmbudsmanDetail': {
      'en': 'If unresolved after 30 days',
      'hi': 'यदि 30 दिनों बाद भी अनसुलझा',
    },
    'remindersTitle': {'en': 'Reminders', 'hi': 'रिमाइंडर'},
    'remindersEmpty': {
      'en': 'No upcoming reminders',
      'hi': 'कोई रिमाइंडर नहीं',
    },
    'remindersDismissed': {
      'en': 'Reminder dismissed',
      'hi': 'रिमाइंडर हटाया गया',
    },
    'remindersDismissFailed': {
      'en': 'Could not dismiss reminder. Check connection and try again.',
      'hi': 'रिमाइंडर नहीं हट सका। कनेक्शन जांचें और फिर कोशिश करें।',
    },
    'settingsLanguage': {'en': 'Language', 'hi': 'भाषा'},
    'settingsTheme': {'en': 'Theme', 'hi': 'थीम'},
    'settingsNotifications': {'en': 'Notifications', 'hi': 'सूचनाएं'},
    'settingsManageSubscription': {
      'en': 'Manage subscription',
      'hi': 'सदस्यता प्रबंधित करें',
    },
    'settingsPrivacyPolicy': {'en': 'Privacy policy', 'hi': 'गोपनीयता नीति'},
    'settingsDisclaimers': {'en': 'Disclaimers', 'hi': 'अस्वीकरण'},
    'settingsDeleteData': {'en': 'Delete my data', 'hi': 'मेरा डेटा हटाएं'},
    'settingsDeleteConfirm': {
      'en': 'Delete all your data? This cannot be undone.',
      'hi': 'सारा डेटा हटाएं? यह पूर्ववत नहीं।',
    },
    'disclaimerTitle': {'en': 'Disclaimer', 'hi': 'अस्वीकरण'},
    'disclaimerBody': {
      'en':
          'Refund Radar is an independent informational tool. It is not affiliated with RBI, NPCI, NHAI, IHMCL, or any bank. We never ask for banking passwords, OTPs, or PINs. Complaints are filed by you on official portals. Compensation estimates are based on published RBI/NPCI rules and actual outcomes depend on your bank/regulator.',
      'hi':
          'रिफंड रडार एक स्वतंत्र जानकारी उपकरण है। यह RBI, NPCI, NHAI, IHMCL या किसी बैंक से संबद्ध नहीं है। हम कभी बैंकिंग पासवर्ड, OTP या PIN नहीं माँगते। शिकायतें आप आधिकारिक पोर्टल पर दर्ज करते हैं।',
    },
    'templatesTitle': {'en': 'Template Library', 'hi': 'टेम्पलेट लाइब्रेरी'},
    'templatesSearch': {'en': 'Search templates', 'hi': 'टेम्पलेट खोजें'},
    'templatesUnlock': {
      'en': 'Unlock 50+ templates',
      'hi': '50+ टेम्पलेट अनलॉक करें',
    },
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
      'hi': 'आप ऑफ़लाइन हैं — बदलाव बाद में सिंक होंगे।',
    },
    'commonCopied': {
      'en': 'Copied to clipboard',
      'hi': 'क्लिपबोर्ड पर कॉपी हुआ',
    },
    'commonClose': {'en': 'Close', 'hi': 'बंद करें'},
    // Screens still on hardcoded strings (Phase 3 background migration).
    'wizardTitle': {'en': 'Escalation steps', 'hi': 'बढ़ते कदम'},
    'wizardMarkFiled': {'en': 'Mark as filed', 'hi': 'दर्ज चिह्नित करें'},
    'wizardOpenPortal': {'en': 'Open portal', 'hi': 'पोर्टल खोलें'},
    'wizardTicketNumber': {
      'en': 'Ticket / complaint number',
      'hi': 'टिकट / शिकायत नंबर',
    },
    'paywallTitle': {'en': 'Go Premium', 'hi': 'प्रीमियम लें'},
    'ombudsmanLetterTitle': {'en': 'Ombudsman letter', 'hi': 'ओम्बड्समैन पत्र'},
    'ombudsmanGenerate': {'en': 'Generate letter', 'hi': 'पत्र बनाएं'},
    'ombudsmanCopy': {'en': 'Copy', 'hi': 'कॉपी'},
    'ombudsmanOpenCms': {
      'en': 'Open cms.rbi.org.in',
      'hi': 'cms.rbi.org.in खोलें',
    },
    'ombudsmanShareCopy': {
      'en': 'Share (copy to clipboard)',
      'hi': 'शेयर (क्लिपबोर्ड पर कॉपी)',
    },
    'disputeTypeContinue': {'en': 'Continue →', 'hi': 'जारी रखें →'},
    'remindersNoneUpcoming': {
      'en': 'No upcoming reminders',
      'hi': 'कोई आगामी रिमाइंडर नहीं',
    },
    'remindersTrackNew': {
      'en': 'Track a new dispute',
      'hi': 'नया विवाद ट्रैक करें',
    },
    'remindersEmptySubtitle': {
      'en':
          'Reminders appear when you create or escalate a dispute — '
          'so you never miss a 30-day follow-up window.',
      'hi':
          'विवाद बनाने या बढ़ाने पर रिमाइंडर आते हैं — ताकि 30-दिन '
          'फॉलो-अप सीमा न चूके।',
    },
    'addBanksSearchHint': {'en': 'Search your bank', 'hi': 'अपना बैंक खोजें'},
    'settingsDisclaimerTitle': {'en': 'Disclaimer', 'hi': 'अस्वीकरण'},
    // Settings page — fully i18n'd in Phase 3 follow-up.
    'settingsTitle': {'en': 'Settings', 'hi': 'सेटिंग्स'},
    'settingsSmsDetection': {'en': 'SMS detection', 'hi': 'SMS पहचान'},
    'settingsAutoDetectUtr': {'en': 'Auto-detect UTR', 'hi': 'UTR ऑटो-पहचान'},
    'settingsSmsPermissionHint': {
      'en': 'SMS permission manages under Android settings.',
      'hi': 'SMS अनुमति Android सेटिंग्स में मिलती है।',
    },
    'settingsOnDeviceLabel': {'en': 'On-device. ', 'hi': 'ऑन-डिवाइस। '},
    'settingsNothingLeaves': {
      'en': 'Nothing leaves your phone.',
      'hi': 'आपका फ़ोन से कुछ बाहर नहीं जाता।',
    },
    'settingsDeadlineReminders': {
      'en': 'Deadline reminders',
      'hi': 'समय-सीमा रिमाइंडर',
    },
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
      'hi': 'अस्वीकरण · गोपनीयता · डेटा हटाएं',
    },
    'settingsNotAffiliated': {
      'en': 'Not affiliated with RBI/NPCI/banks',
      'hi': 'RBI/NPCI/बैंक से संबद्ध नहीं',
    },
    'settingsSignOut': {'en': 'Sign out', 'hi': 'साइन आउट'},
    'settingsSignOutNotImplemented': {
      'en': 'Sign out not implemented.',
      'hi': 'साइन आउट लागू नहीं।',
    },
    'settingsProBadge': {'en': '⭐ Pro', 'hi': '⭐ प्रो'},
    'settingsLocalProfile': {'en': 'Local profile', 'hi': 'स्थानीय प्रोफ़ाइल'},
    'settingsRefundRadarUser': {
      'en': 'Refund Radar user',
      'hi': 'रिफंड रडार उपयोगकर्ता',
    },
    // Escalate page.
    'escalateAppBarTitle': {'en': 'Escalate', 'hi': 'कदम बढ़ाएं'},
    'escalateMaxClaim': {
      'en': 'Maximum you can claim',
      'hi': 'अधिकतम दावा राशि',
    },
    'escalateRefundPlusComp': {
      'en': '{refund} refund + {comp} comp ({days} days × ₹100/day)',
      'hi': '{refund} वापसी + {comp} मुआवजा ({days} दिन × ₹100/दिन)',
    },
    'escalateSendTo': {'en': 'SEND TO', 'hi': 'भेजें'},
    'escalateNodalOfficer': {'en': 'Nodal Officer', 'hi': 'नोडल अधिकारी'},
    'escalateSlaDays': {
      'en': '{email} · SLA 10d',
      'hi': '{email} · SLA 10 दिन',
    },
    'escalateCcOmbudsman': {
      'en': 'CC RBI Ombudsman',
      'hi': 'CC RBI ऑम्बड्समैन',
    },
    'escalateEmailPreview': {'en': 'EMAIL PREVIEW', 'hi': 'ईमेल पूर्वावलोकन'},
    'escalateEmailSubject': {
      'en': 'Subject: Escalation — UTR {txnId}',
      'hi': 'विषय: एस्केलेशन — UTR {txnId}',
    },
    'escalateEmailGreeting': {
      'en': 'Dear Nodal Officer,',
      'hi': 'प्रिय नोडल अधिकारी,',
    },
    'escalateEmailAutoDrafted': {
      'en': '[auto-drafted, tap to edit]',
      'hi': '[स्वतः तैयार, संपादित करें]',
    },
    'escalateStandardsCompliant': {
      'en': 'Standards-compliant · view source',
      'hi': 'मानक-अनुरूप · स्रोत देखें',
    },
    'escalateSendWithinPrefix': {'en': 'Send within ', 'hi': 'भेजें '},
    'escalateSendWithin24h': {'en': '24 hours', 'hi': '24 घंटे'},
    'escalateSendWithinSuffix': {
      'en': ' to claim full {comp} comp retroactively.',
      'hi': ' अनुपात में पूरा {comp} मुआवजा पाने के लिए।',
    },
    'escalateEdit': {'en': 'Edit', 'hi': 'संपादित करें'},
    'escalateSend': {'en': 'Send escalation →', 'hi': 'एस्केलेशन भेजें →'},
    'escalateCopiedToClipboard': {
      'en': 'Email copied to clipboard',
      'hi': 'ईमेल क्लिपबोर्ड पर कॉपी हुआ',
    },
    'escalateDrafted': {
      'en': 'Drafted — open your mail app: {url}',
      'hi': 'तैयार है — अपना मेल ऐप खोलें: {url}',
    },
    // Dispute detail activity log + timeline.
    'detailTimelineL1': {
      'en': 'File L1 complaint',
      'hi': 'L1 शिकायत दर्ज करें',
    },
    'detailTimelineReported': {'en': 'Reported', 'hi': 'रिपोर्ट किया'},
    'detailTimelineReportedDetail': {
      'en': 'T+0 · {date}',
      'hi': 'T+0 · {date}',
    },
    'detailTimelineAck': {'en': 'Bank must acknowledge', 'hi': 'बैंक पावती दे'},
    'detailTimelineAckDone': {
      'en': 'T+1 · acknowledged',
      'hi': 'T+1 · पावती मिली',
    },
    'detailTimelineAckPending': {'en': 'T+1 · by today', 'hi': 'T+1 · आज तक'},
    'detailTimelineRefund': {'en': 'Refund due', 'hi': 'वापसी देय'},
    'detailTimelineRefundDone': {
      'en': 'T+{tat} · refunded',
      'hi': 'T+{tat} · वापस हुई',
    },
    'detailTimelineRefundMissed': {
      'en': 'T+{tat} · deadline missed — escalate',
      'hi': 'T+{tat} · समय खत्म — बढ़ाएं',
    },
    'detailTimelineRefundPending': {
      'en': 'T+{tat} · {date} (in {days}d)',
      'hi': 'T+{tat} · {date} ({days}दिन में)',
    },
    'detailTimelineEscalate': {
      'en': 'Escalate to nodal officer',
      'hi': 'नोडल अधिकारी को भेजें',
    },
    'detailTimelineOmbudsman': {
      'en': 'RBI Banking Ombudsman',
      'hi': 'RBI बैंकिंग ऑम्बड्समैन',
    },
    'detailTimelineL2Detail': {
      'en': 'Filed · {ticket}',
      'hi': 'दर्ज · {ticket}',
    },
    'detailTimelineL2Pending': {
      'en': 'If no refund by T+{tat}',
      'hi': 'यदि T+{tat} तक वापसी नहीं',
    },
    'detailTimelineL3Detail': {
      'en': 'Filed · {ticket}',
      'hi': 'दर्ज · {ticket}',
    },
    'detailTimelineL3Pending': {
      'en': 'If unresolved after T+10 (30 days)',
      'hi': 'यदि T+10 (30 दिन) बाद भी अनसुलझा',
    },
    'detailActivityHeader': {
      'en': 'Activity · {count} events',
      'hi': 'गतिविधि · {count} घटनाएं',
    },
    'detailActivityTicket': {
      'en': 'Ticket {ticket} filed',
      'hi': 'टिकट {ticket} दर्ज',
    },
    'detailActivityTicketMeta': {
      'en': 'Auto-generated · {date}',
      'hi': 'स्वतः तैयार · {date}',
    },
    'detailActivityAutoUtr': {
      'en': 'Auto-detected UTR from SMS',
      'hi': 'SMS से UTR ऑटो-पहचान',
    },
    'detailActivityMarkedActive': {
      'en': 'Dispute marked active',
      'hi': 'विवाद सक्रिय चिह्नित',
    },
    'detailActivityResolved': {'en': 'Dispute resolved', 'hi': 'विवाद सुलझा'},
    // Track G — persisted activity log event labels.
    'activityDisputeCreated': {
      'en': 'Dispute created',
      'hi': 'विवाद दर्ज किया गया',
    },
    'activityEscalationSent': {
      'en': 'Escalation email sent',
      'hi': 'एस्कलेशन ईमेल भेजा गया',
    },
    'activityTemplateUsed': {
      'en': 'Template used',
      'hi': 'टेंपलेट उपयोग किया गया',
    },
    'activityResolved': {
      'en': 'Dispute resolved',
      'hi': 'विवाद हल हो गया',
    },
    'activityReminderFired': {
      'en': 'Deadline reminder fired',
      'hi': 'समयसीमा अनुस्मारक भेजा गया',
    },
    'activityUtrDetected': {
      'en': 'UTR auto-detected',
      'hi': 'UTR स्वतः पहचाना गया',
    },
    'activityStatusChanged': {
      'en': 'Status changed',
      'hi': 'स्थिति बदली गई',
    },
    // Dispute form labels + validation.
    'formEnterAmount': {
      'en': 'Enter the debited amount',
      'hi': 'कटी हुई राशि दर्ज करें',
    },
    'formLabelBank': {'en': 'Bank', 'hi': 'बैंक'},
    'formLabelUtr': {'en': 'UTR / RRN NUMBER', 'hi': 'UTR / RRN नंबर'},
    'formUtrFound': {'en': '✓ found', 'hi': '✓ मिला'},
    'formUtrHint12': {'en': '12 digits', 'hi': '12 अंक'},
    'formLabelAmountDebited': {'en': 'AMOUNT DEBITED', 'hi': 'कटी राशि'},
    'formLabelTxnDate': {'en': 'TXN DATE', 'hi': 'लेन-देन तिथि'},
    'formSelectDate': {'en': 'Select date', 'hi': 'तिथि चुनें'},
    'formAuthRequired': {
      'en': 'Could not sign in. Please restart the app and try again.',
      'hi': 'साइन इन नहीं हो सका। ऐप रीस्टार्ट करके फिर कोशिश करें।',
    },
    'formSelectBank': {'en': 'Select a bank', 'hi': 'बैंक चुनें'},
    'formLabelDescription': {
      'en': 'DESCRIPTION (optional)',
      'hi': 'विवरण (वैकल्पिक)',
    },
    'ombudsmanPremiumFeature': {
      'en': 'Premium feature',
      'hi': 'प्रीमियम सुविधा',
    },
    'ombudsmanPremiumBlurb': {
      'en':
          'Generate a pre-filled Template C complaint summary that you can paste into cms.rbi.org.in.',
      'hi':
          'cms.rbi.org.in में पेस्ट करने के लिए पहले से भरा Template C शिकायत सारांश बनाएं।',
    },
    'paywallUnlimited': {'en': 'Unlimited', 'hi': 'असीमित'},
    'paywallHindiTemplates': {
      'en': 'Hindi premium templates',
      'hi': 'हिंदी प्रीमियम टेम्पलेट',
    },
    'paywallRestored': {'en': 'Premium restored 🎉', 'hi': 'प्रीमियम बहाल 🎉'},
    'paywallNoPurchases': {
      'en': 'No purchases found.',
      'hi': 'कोई खरीद नहीं मिली।',
    },
    'paywallRestoreFailed': {
      'en': 'Restore failed: {error}',
      'hi': 'बहाली विफल: {error}',
    },
    'paywallRestoreFailedGeneric': {
      'en': 'Could not restore purchases. Check your connection and try again.',
      'hi': 'खरीद बहाल नहीं हो सकी। कनेक्शन जांचें और पुनः प्रयास करें।',
    },
    'settingsSessionRefreshed': {
      'en': 'Session refreshed.',
      'hi': 'सत्र रीफ़्रेश हो गया।',
    },
    // Home page remaining.
    'homeViewAllDisputes': {'en': 'View all disputes', 'hi': 'सभी विवाद देखें'},
    'homeBreakdownDisputed': {
      'en': '{disputed} disputed · {penalty} penalty accrued',
      'hi': '{disputed} विवादित · {penalty} जुर्माना अर्जित',
    },
    // Task C8: UTR auto-detect banner on Home.
    'homeDetectedTitle': {
      'en': 'Detected transactions',
      'hi': 'पहचाने गए लेनदेन',
    },
    'homeDetectedSubtitle': {
      'en': 'Auto-detected from incoming SMS — tap to claim or dismiss.',
      'hi': 'आने वाले SMS से स्वतः पहचाना गया — दावा करने या खारिज करने के लिए टैप करें।',
    },
    'homeDetectedCardAmount': {
      'en': '₹{amount} · {sender}',
      'hi': '₹{amount} · {sender}',
    },
    'homeDetectedCardUtr': {
      'en': 'UTR {utr}',
      'hi': 'UTR {utr}',
    },
    'homeDetectedClaim': {
      'en': 'Claim →',
      'hi': 'दावा करें →',
    },
    'homeDetectedDismiss': {
      'en': 'Dismiss',
      'hi': 'खारिज करें',
    },
    // History page.
    'historyTitle': {'en': 'History', 'hi': 'इतिहास'},
    'historyTotalWon': {'en': 'TOTAL WON', 'hi': 'कुल जीत'},
    'historyWinRate': {'en': 'WIN RATE', 'hi': 'जीत दर'},
    'historyEmptyTitle': {'en': 'No history yet', 'hi': 'अभी कोई इतिहास नहीं'},
    'historyEmptySubtitle': {
      'en': 'Resolved and expired disputes will appear here.',
      'hi': 'सुलझे और समाप्त विवाद यहाँ दिखेंगे।',
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
    'templateUnlockCta': {
      'en': 'Unlock with Premium',
      'hi': 'प्रीमियम से अनलॉक करें',
    },
    // Pass 2 residual i18n — dispute form / type page / escalate / wizard docs.
    'formClipboardEmpty': {
      'en': 'Clipboard empty — copy an SMS first.',
      'hi': 'क्लिपबोर्ड खाली — पहले एक SMS कॉपी करें।',
    },
    'formPickBankSms': {'en': 'Pick a bank SMS', 'hi': 'बैंक SMS चुनें'},
    'formInbox': {'en': 'Inbox', 'hi': 'इनबॉक्स'},
    'formPaste': {'en': 'Paste', 'hi': 'पेस्ट'},
    'formStep2Of4': {'en': 'STEP 2 OF 4', 'hi': 'चरण 2 / 4'},
    'formDisputeDetails': {'en': 'Dispute details', 'hi': 'विवाद विवरण'},
    'formEstimated': {'en': 'ESTIMATED', 'hi': 'अनुमानित'},
    'formAddAmountToEstimate': {
      'en': 'Add amount to estimate',
      'hi': 'अनुमान के लिए राशि दर्ज करें',
    },
    'formClaimAmount': {'en': 'Claim {amount}', 'hi': 'दावा {amount}'},
    'formClaimAmountCompo': {
      'en': 'Claim {amount} + compo',
      'hi': 'दावा {amount} + मुआवजा',
    },
    'formClaimAmountCompoDue': {
      'en': 'Claim {amount} + {comp} compo',
      'hi': 'दावा {amount} + {comp} मुआवजा',
    },
    'formWrongUpiNote': {
      'en':
          'Wrong UPI transfers are not covered by RBI compensation. Recovery depends on beneficiary consent via bank/NPCI.',
      'hi':
          'गलत UPI ट्रांसफर RBI मुआवजे में शामिल नहीं। वसूली बैंक/NPCI द्वारा लाभार्थी की सहमति पर निर्भर है।',
    },
    'formRbiCircularPrefix': {
      'en': 'RBI Circular DPSS/2018 — T+{days} refund rule applies. ',
      'hi': 'RBI परिपत्र DPSS/2018 — T+{days} वापसी नियम लागू होता है। ',
    },
    'formEligiblePerDayComp': {
      "en": "You're eligible for ₹100/day comp beyond T+{days}.",
      'hi': 'आप T+{days} के बाद ₹100/दिन मुआवजे के हक़दार हैं।',
    },
    'formSms': {'en': 'SMS', 'hi': 'SMS'},
    'formFreeLimitReached': {
      'en': 'Free plan allows 1 active dispute. Upgrade for unlimited.',
      'hi': 'मुफ़्त योजना में 1 सक्रिय विवाद है। असीमित के लिए अपग्रेड करें।',
    },
    'formUtrRequired': {
      'en': 'Enter the UTR / transaction ID',
      'hi': 'UTR दर्ज करें',
    },
    'formAmountCap': {
      'en': 'Amount must be ≤ ₹5,00,000',
      'hi': 'राशि ₹5,00,000 से कम होनी चाहिए',
    },
    'disputeTypeStep1Of4': {'en': 'Step 1 of 4', 'hi': 'चरण 1 / 4'},
    'disputeTypeWhatHappened': {'en': 'What happened?', 'hi': 'क्या हुआ?'},
    'disputeTypeChooseCategory': {
      'en': 'Choose dispute category',
      'hi': 'विवाद श्रेणी चुनें',
    },
    'disputeTypeSelectedDash': {'en': 'Selected: —', 'hi': 'चुना गया: —'},
    'disputeTypeSelectedName': {
      'en': 'Selected: {name}',
      'hi': 'चुना गया: {name}',
    },
    'escalateMaxPenaltyLabel': {
      'en': 'MAXIMUM PENALTY YOU CAN CLAIM',
      'hi': 'अधिकतम दंड जिसका दावा आप कर सकते हैं',
    },
    'escalateT5Missed': {'en': '⚠ T+5 missed', 'hi': '⚠ T+5 चूका'},
    'escalateDeadlineMissed': {
      'en': '⚠ {basis} missed',
      'hi': '⚠ {basis} चूका',
    },
    'escalateDeadlineIn': {
      'en': '{basis} deadline in {days} days',
      'hi': '{basis} समय-सीमा {days} दिन में',
    },
    'escalateDeadlineMissedPenalty': {
      'en': '{basis} deadline missed — claim full penalty',
      'hi': '{basis} समय-सीमा चूकी — पूरा दंड का दावा करें',
    },
    'escalateNoAmount': {
      'en': 'No transaction amount on this dispute',
      'hi': 'इस विवाद में कोई लेन-देन राशि नहीं',
    },
    'escalateTapToExpand': {
      'en': 'Tap to view full email',
      'hi': 'पूरा ईमेल देखने के लिए टैप करें',
    },
    'escalateEditTemplate': {
      'en': 'Pick template',
      'hi': 'टेंपलेट चुनें',
    },
    'escalatePickTemplate': {
      'en': 'Pick escalation template',
      'hi': 'एस्कलेशन टेंपलेट चुनें',
    },
    'escalateToLabel': {'en': 'TO:', 'hi': 'प्रति:'},
    'escalateCcLabel': {'en': 'CC:', 'hi': 'प्रतिलिपि:'},
    'escalateSubjectLabel': {'en': 'Subject:', 'hi': 'विषय:'},
    'escalateOpeningMail': {
      'en': 'Opening mail app…',
      'hi': 'मेल ऐप खोला जा रहा है…',
    },
    'escalateMailFailed': {
      'en': 'Could not open mail app — email copied instead.',
      'hi': 'मेल ऐप नहीं खुला — ईमेल कॉपी कर लिया गया।',
    },
    'escalateSlaDaysShort': {'en': 'SLA 10d', 'hi': 'SLA 10 दिन'},
    'wizardDocUtrTxnId': {
      'en': 'UTR / Transaction ID',
      'hi': 'UTR / लेन-देन आईडी',
    },
    'wizardDocAmount': {'en': 'Amount', 'hi': 'राशि'},
    'wizardDocDate': {'en': 'Date', 'hi': 'तिथि'},
    'wizardDocVpa': {'en': 'VPA', 'hi': 'VPA'},
    'wizardDocBankStatement': {
      'en': 'Bank statement screenshot',
      'hi': 'बैंक स्टेटमेंट स्क्रीनशॉट',
    },
    'wizardDocBankStatementShort': {
      'en': 'Bank statement',
      'hi': 'बैंक स्टेटमेंट',
    },
    'wizardDocTransactionProof': {
      'en': 'Transaction proof',
      'hi': 'लेन-देन प्रमाण',
    },
    'wizardDocComplaintAck': {
      'en': 'Complaint acknowledgement',
      'hi': 'शिकायत पावती',
    },
    'wizardDocBankReply': {
      'en': 'Bank reply (if any)',
      'hi': 'बैंक जवाब (यदि कोई)',
    },
    'wizardCouldNotLoadDispute': {
      'en': 'Could not load dispute. Check connection and try again.',
      'hi': 'विवाद लोड नहीं हो सका। कनेक्शन जांचें और फिर कोशिश करें।',
    },
    'wizardDisputeNotFound': {
      'en': 'Dispute not found.',
      'hi': 'विवाद नहीं मिला।',
    },
    'typeShortBank': {'en': 'Bank', 'hi': 'बैंक'},
    'typeShortWrong': {'en': 'Wrong', 'hi': 'गलत'},
    'formBankSearchHint': {'en': 'Search bank...', 'hi': 'बैंक खोजें...'},
    'formBankYourBanks': {'en': 'Your banks', 'hi': 'आपके बैंक'},
    'formBankAllBanks': {'en': 'All banks', 'hi': 'सभी बैंक'},
    'formBankSearchResults': {
      'en': 'Search results',
      'hi': 'खोज परिणाम',
    },
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
  String get smsPermissionTitle => _t('smsPermissionTitle');
  String get smsPermissionSubtitle => _t('smsPermissionSubtitle');
  String get smsPermissionHowItWorks1 => _t('smsPermissionHowItWorks1');
  String get smsPermissionHowItWorks2 => _t('smsPermissionHowItWorks2');
  String get smsPermissionHowItWorks3 => _t('smsPermissionHowItWorks3');
  String get smsPermissionPrivacyNote => _t('smsPermissionPrivacyNote');
  String get smsPermissionGrant => _t('smsPermissionGrant');
  String get smsPermissionSkip => _t('smsPermissionSkip');
  String get formSmsPermissionDeniedAction =>
      _t('formSmsPermissionDeniedAction');
  String get formNoBankSmsAction => _t('formNoBankSmsAction');
  String get formSmsInboxFailed => _t('formSmsInboxFailed');
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
  String paywallHeadlineTemplate(String title) =>
      _t('paywallHeadlineTemplate', args: {'title': title});
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
  String get remindersDismissed => _t('remindersDismissed');
  String get remindersDismissFailed => _t('remindersDismissFailed');
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
  String get settingsSignOutNotImplemented =>
      _t('settingsSignOutNotImplemented');
  String get settingsProBadge => _t('settingsProBadge');
  String get settingsLocalProfile => _t('settingsLocalProfile');
  String get settingsRefundRadarUser => _t('settingsRefundRadarUser');

  // Escalate page.
  String get escalateAppBarTitle => _t('escalateAppBarTitle');
  String get escalateMaxClaim => _t('escalateMaxClaim');
  String escalateRefundPlusComp(String refund, String comp, int days) => _t(
    'escalateRefundPlusComp',
    args: {'refund': refund, 'comp': comp, 'days': '$days'},
  );
  String get escalateSendTo => _t('escalateSendTo');
  String get escalateNodalOfficer => _t('escalateNodalOfficer');
  String escalateSlaDays(String email) =>
      _t('escalateSlaDays', args: {'email': email});
  String get escalateCcOmbudsman => _t('escalateCcOmbudsman');
  String get escalateEmailPreview => _t('escalateEmailPreview');
  String escalateEmailSubject(String txnId) =>
      _t('escalateEmailSubject', args: {'txnId': txnId});
  String get escalateEmailGreeting => _t('escalateEmailGreeting');
  String get escalateEmailAutoDrafted => _t('escalateEmailAutoDrafted');
  String get escalateStandardsCompliant => _t('escalateStandardsCompliant');
  String get escalateSendWithinPrefix => _t('escalateSendWithinPrefix');
  String get escalateSendWithin24h => _t('escalateSendWithin24h');
  String escalateSendWithinSuffix(String comp) =>
      _t('escalateSendWithinSuffix', args: {'comp': comp});
  String get escalateEdit => _t('escalateEdit');
  String get escalateSend => _t('escalateSend');
  String get escalateCopiedToClipboard => _t('escalateCopiedToClipboard');
  String escalateDrafted(String url) =>
      _t('escalateDrafted', args: {'url': url});

  // Dispute detail page activity log + timeline.
  String get detailTimelineL1 => _t('detailTimelineL1');
  String get detailTimelineReported => _t('detailTimelineReported');
  String detailTimelineReportedDetail(String date) =>
      _t('detailTimelineReportedDetail', args: {'date': date});
  String get detailTimelineAck => _t('detailTimelineAck');
  String get detailTimelineAckDone => _t('detailTimelineAckDone');
  String get detailTimelineAckPending => _t('detailTimelineAckPending');
  String get detailTimelineRefund => _t('detailTimelineRefund');
  String detailTimelineRefundDone(String tat) =>
      _t('detailTimelineRefundDone', args: {'tat': tat});
  String detailTimelineRefundMissed(String tat) =>
      _t('detailTimelineRefundMissed', args: {'tat': tat});
  String detailTimelineRefundPending(String tat, String date, int days) => _t(
    'detailTimelineRefundPending',
    args: {'tat': tat, 'date': date, 'days': '$days'},
  );
  String get detailTimelineEscalate => _t('detailTimelineEscalate');
  String get detailTimelineOmbudsman => _t('detailTimelineOmbudsman');
  String detailTimelineL2Detail(String ticket) =>
      _t('detailTimelineL2Detail', args: {'ticket': ticket});
  String detailTimelineL2Pending(String tat) =>
      _t('detailTimelineL2Pending', args: {'tat': tat});
  String detailTimelineL3Detail(String ticket) =>
      _t('detailTimelineL3Detail', args: {'ticket': ticket});
  String get detailTimelineL3Pending => _t('detailTimelineL3Pending');
  String detailActivityHeader(int count) =>
      _t('detailActivityHeader', args: {'count': '$count'});
  String detailActivityTicket(String ticket) =>
      _t('detailActivityTicket', args: {'ticket': ticket});
  String detailActivityTicketMeta(String date) =>
      _t('detailActivityTicketMeta', args: {'date': date});
  String get detailActivityAutoUtr => _t('detailActivityAutoUtr');
  String get detailActivityMarkedActive => _t('detailActivityMarkedActive');
  String get detailActivityResolved => _t('detailActivityResolved');

  // Track G — persisted activity log event labels.
  String get activityDisputeCreated => _t('activityDisputeCreated');
  String get activityEscalationSent => _t('activityEscalationSent');
  String get activityTemplateUsed => _t('activityTemplateUsed');
  String get activityResolved => _t('activityResolved');
  String get activityReminderFired => _t('activityReminderFired');
  String get activityUtrDetected => _t('activityUtrDetected');
  String get activityStatusChanged => _t('activityStatusChanged');

  // Dispute form validation + labels.
  String get formEnterAmount => _t('formEnterAmount');
  String get formLabelBank => _t('formLabelBank');
  String get formLabelUtr => _t('formLabelUtr');
  String get formUtrFound => _t('formUtrFound');
  String get formUtrHint12 => _t('formUtrHint12');
  String get formLabelAmountDebited => _t('formLabelAmountDebited');
  String get formLabelTxnDate => _t('formLabelTxnDate');
  String get formSelectDate => _t('formSelectDate');
  String get formAuthRequired => _t('formAuthRequired');
  String get formSelectBank => _t('formSelectBank');
  String get formLabelDescription => _t('formLabelDescription');
  String get ombudsmanPremiumFeature => _t('ombudsmanPremiumFeature');
  String get ombudsmanPremiumBlurb => _t('ombudsmanPremiumBlurb');
  String get paywallUnlimited => _t('paywallUnlimited');
  String get paywallHindiTemplates => _t('paywallHindiTemplates');
  String get paywallRestored => _t('paywallRestored');
  String get paywallNoPurchases => _t('paywallNoPurchases');
  String paywallRestoreFailed(String error) =>
      _t('paywallRestoreFailed', args: {'error': error});
  String get paywallRestoreFailedGeneric => _t('paywallRestoreFailedGeneric');
  String get settingsSessionRefreshed => _t('settingsSessionRefreshed');

  // Home page remaining strings.
  String get homeViewAllDisputes => _t('homeViewAllDisputes');
  String homeBreakdownDisputed(String disputed, String penalty) =>
      _t('homeBreakdownDisputed',
          args: {'disputed': disputed, 'penalty': penalty});

  // Task C8: UTR auto-detect banner getters.
  String get homeDetectedTitle => _t('homeDetectedTitle');
  String get homeDetectedSubtitle => _t('homeDetectedSubtitle');
  String homeDetectedCardAmount(String amount, String sender) =>
      _t('homeDetectedCardAmount', args: {'amount': amount, 'sender': sender});
  String homeDetectedCardUtr(String utr) =>
      _t('homeDetectedCardUtr', args: {'utr': utr});
  String get homeDetectedClaim => _t('homeDetectedClaim');
  String get homeDetectedDismiss => _t('homeDetectedDismiss');

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
  String get templateUnlockCta => _t('templateUnlockCta');

  // Status pills.
  String get statusResolved => _t('statusResolved');
  String get statusMissed => _t('statusMissed');
  String statusDayOf(int day, int total) =>
      _t('statusDayOf', args: {'day': '$day', 'total': '$total'});

  // Dispute type display names + subtitles.
  String get typeUpiP2p => _t('typeUpiP2p');
  String get typeUpiP2m => _t('typeUpiP2m');
  String get typeAtm => _t('typeAtm');
  String get typeFastag => _t('typeFastag');
  String get typeImps => _t('typeImps');
  String get typeBankCharge => _t('typeBankCharge');
  String get typeWrongTransfer => _t('typeWrongTransfer');
  String get typeSubUpiP2p => _t('typeSubUpiP2p');
  String get typeSubUpiP2m => _t('typeSubUpiP2m');
  String get typeSubAtm => _t('typeSubAtm');
  String get typeSubFastag => _t('typeSubFastag');
  String get typeSubImps => _t('typeSubImps');
  String get typeSubBankCharge => _t('typeSubBankCharge');
  String get typeSubWrongTransfer => _t('typeSubWrongTransfer');
  String typeCompPerDay(String amount) =>
      _t('typeCompPerDay', args: {'amount': amount});

  // Wizard step copy.
  String get wizardCopyComplaintLabel => _t('wizardCopyComplaint');
  String get wizardDocuments => _t('wizardDocuments');
  String get wizardDocumentsLabel => _t('wizardDocuments');
  String get wizardCallPrefix => _t('wizardCallPrefix');
  String get wizardLevel1Title => _t('wizardLevel1Title');
  String get wizardLevel1Body => _t('wizardLevel1Body');
  String get wizardLevel2Title => _t('wizardLevel2Title');
  String get wizardLevel2Body => _t('wizardLevel2Body');
  String get wizardLevel3Title => _t('wizardLevel3Title');
  String get wizardLevel3Body => _t('wizardLevel3Body');
  String get wizardSaveFailed => _t('wizardSaveFailed');

  // Detail timeline headers + FASTag / wrong-transfer.
  String get detailTimelineFastagHeader => _t('detailTimelineFastagHeader');
  String get detailTimelineBankHeader => _t('detailTimelineBankHeader');
  String get detailTimelineRbiHeader => _t('detailTimelineRbiHeader');
  String get detailTlWtRequest => _t('detailTlWtRequest');
  String get detailTlWtRequestDetail => _t('detailTlWtRequestDetail');
  String get detailTlWtNpci => _t('detailTlWtNpci');
  String get detailTlWtNpciDetail => _t('detailTlWtNpciDetail');
  String get detailTlWtCyber => _t('detailTlWtCyber');
  String get detailTlWtCyberDetail => _t('detailTlWtCyberDetail');
  String get detailTlWtLegal => _t('detailTlWtLegal');
  String get detailTlWtLegalDetail => _t('detailTlWtLegalDetail');
  String get detailTlFtReported => _t('detailTlFtReported');
  String get detailTlFtReportedDetail => _t('detailTlFtReportedDetail');
  String get detailTlFtIssuer => _t('detailTlFtIssuer');
  String detailTlFtIssuerDetail(String bank) =>
      _t('detailTlFtIssuerDetail', args: {'bank': bank});
  String get detailTlFtIssuerGeneric => _t('detailTlFtIssuerGeneric');
  String get detailTlFtHelpline => _t('detailTlFtHelpline');
  String get detailTlFtHelplineDetail => _t('detailTlFtHelplineDetail');
  String get detailTlFtIhmcl => _t('detailTlFtIhmcl');
  String get detailTlFtIhmclDetail => _t('detailTlFtIhmclDetail');
  String get detailTlFtOmbudsman => _t('detailTlFtOmbudsman');
  String get detailTlFtOmbudsmanDetail => _t('detailTlFtOmbudsmanDetail');
  String homeActiveDisputes(int count) => count == 1
      ? _t('homeActiveDisputeOne', args: {'count': '$count'})
      : _t('homeActiveDisputes', args: {'count': '$count'});
  String get homeYoureOwed => _t('homeYoureOwed');
  String homeDisputeCount(int count) => count == 1
      ? _t('homeDisputeCountOne', args: {'count': '$count'})
      : _t('homeDisputeCount', args: {'count': '$count'});
  String get cardDeadlineMissed => _t('cardDeadlineMissed');
  String cardDaysLeft(int days) => _t('cardDaysLeft', args: {'days': '$days'});
  String get cardExpired => _t('cardExpired');
  String get cardGuidanceMode => _t('cardGuidanceMode');
  String get cardEscalateCta => _t('cardEscalateCta');
  String get cardViewCta => _t('cardViewCta');
  String get settingsComingSoon => _t('settingsComingSoon');
  String get settingsDailyCompSoon => _t('settingsDailyCompSoon');
  String get settingsWeeklyDigestSoon => _t('settingsWeeklyDigestSoon');

  // Pass 2 residual i18n getters — dispute form / type page / escalate / wizard.
  String get formClipboardEmpty => _t('formClipboardEmpty');
  String get formPickBankSms => _t('formPickBankSms');
  String get formInbox => _t('formInbox');
  String get formPaste => _t('formPaste');
  String get formStep2Of4 => _t('formStep2Of4');
  String get formDisputeDetails => _t('formDisputeDetails');
  String get formEstimated => _t('formEstimated');
  String get formAddAmountToEstimate => _t('formAddAmountToEstimate');
  String formClaimAmount(String amount) =>
      _t('formClaimAmount', args: {'amount': amount});
  String formClaimAmountCompo(String amount) =>
      _t('formClaimAmountCompo', args: {'amount': amount});
  String formClaimAmountCompoDue(String amount, String comp) =>
      _t('formClaimAmountCompoDue', args: {'amount': amount, 'comp': comp});
  String get formWrongUpiNote => _t('formWrongUpiNote');
  String formRbiCircularPrefix(String days) =>
      _t('formRbiCircularPrefix', args: {'days': days});
  String formEligiblePerDayComp(String days) =>
      _t('formEligiblePerDayComp', args: {'days': days});
  String get formSms => _t('formSms');
  String get formFreeLimitReached => _t('formFreeLimitReached');
  String get formUtrRequired => _t('formUtrRequired');
  String get formAmountCap => _t('formAmountCap');

  String get disputeTypeStep1Of4 => _t('disputeTypeStep1Of4');
  String get disputeTypeWhatHappened => _t('disputeTypeWhatHappened');
  String get disputeTypeChooseCategory => _t('disputeTypeChooseCategory');
  String get disputeTypeSelectedDash => _t('disputeTypeSelectedDash');
  String disputeTypeSelectedName(String name) =>
      _t('disputeTypeSelectedName', args: {'name': name});

  String get escalateMaxPenaltyLabel => _t('escalateMaxPenaltyLabel');
  String get escalateT5Missed => _t('escalateT5Missed');
  String escalateDeadlineMissed(String basis) =>
      _t('escalateDeadlineMissed', args: {'basis': basis});
  String escalateDeadlineIn(String basis, int days) =>
      _t('escalateDeadlineIn', args: {'basis': basis, 'days': '$days'});
  String escalateDeadlineMissedPenalty(String basis) =>
      _t('escalateDeadlineMissedPenalty', args: {'basis': basis});
  String get escalateNoAmount => _t('escalateNoAmount');
  String get escalateTapToExpand => _t('escalateTapToExpand');
  String get escalateEditTemplate => _t('escalateEditTemplate');
  String get escalatePickTemplate => _t('escalatePickTemplate');
  String get escalateToLabel => _t('escalateToLabel');
  String get escalateCcLabel => _t('escalateCcLabel');
  String get escalateSubjectLabel => _t('escalateSubjectLabel');
  String get escalateOpeningMail => _t('escalateOpeningMail');
  String get escalateMailFailed => _t('escalateMailFailed');
  String get escalateSlaDaysShort => _t('escalateSlaDaysShort');

  String get wizardDocUtrTxnId => _t('wizardDocUtrTxnId');
  String get wizardDocAmount => _t('wizardDocAmount');
  String get wizardDocDate => _t('wizardDocDate');
  String get wizardDocVpa => _t('wizardDocVpa');
  String get wizardDocBankStatement => _t('wizardDocBankStatement');
  String get wizardDocBankStatementShort => _t('wizardDocBankStatementShort');
  String get wizardDocTransactionProof => _t('wizardDocTransactionProof');
  String get wizardDocComplaintAck => _t('wizardDocComplaintAck');
  String get wizardDocBankReply => _t('wizardDocBankReply');
  String get wizardCouldNotLoadDispute => _t('wizardCouldNotLoadDispute');
  String get wizardDisputeNotFound => _t('wizardDisputeNotFound');
  String get typeShortBank => _t('typeShortBank');
  String get typeShortWrong => _t('typeShortWrong');
  String get formBankSearchHint => _t('formBankSearchHint');
  String get formBankYourBanks => _t('formBankYourBanks');
  String get formBankAllBanks => _t('formBankAllBanks');
  String get formBankSearchResults => _t('formBankSearchResults');
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => ['en', 'hi'].contains(locale.languageCode);
  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);
  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
