# Refund Radar

> "Bank owes you. We track it." / "पैसा अटका है? हम वसूली का रास्ता दिखाएँगे।"

Refund Radar is an information & guidance tool that helps Indian users recover money stuck in:
- Failed UPI transactions (P2P, P2M, IMPS)
- Wrong/double FASTag toll deductions
- Wrong bank charges
- Wrong transfers

Under built per the Notion spec "Refund Radar — AI Agent Build Spec (Production-Ready, Flutter + Firebase)".

## Tech stack (all free)
- Flutter (Dart, latest stable)
- Firebase Spark plan (Auth, Cloud Firestore, Remote Config, Messaging, Analytics, Crashlytics)
- Riverpod state management
- GoRouter navigation
- flutter_local_notifications for reminders
- RevenueCat for monetization
- Bilingual EN + HI via custom AppLocalizations

## Project structure
```
lib/
  core/         - theme, router, providers, utils, events
  data/         - models, repositories (Firestore, rules engine, dispute_type_display)
  features/     - onboarding(3), home, dispute_create(type+form), dispute_detail, wizard, paywall, reminders, settings, ombudsman, templates
  services/     - compensation_calculator, sms_parser, fcm_topics, notification_service
  shared/       - 14 widgets: OwedCounterCard, DisputeCard, StepperTimeline(DangerBanner,PrimaryCTA)+ redesign set (AppBackButton, StatusPill, FilterPills, ToggleSwitch, RadioRow, InfoBanner, PageDots, HeroEmojiCircle, OnboardingStepHeader)
  l10n/         - app_en.arb + app_hi.arb (51 keys each, strict parity)
  firebase_options.dart  - Firebase config (REPLACE with real values)
assets/
  rules_engine.json     - source of truth for RBI/NPCI rules (Section 2 + 5); 7 disputeTypes, 18 FASTag issuers, 5 freeTemplateIds
  templates/            - (pending) 51 template JSON assets per spec §2.6.1
firestore.rules         - users/{uid}/** user-scoped + deny-all default
.github/workflows/
  android.yml           - debug APK CI build
```

## Build status

See **[PROGRESS.md](PROGRESS.md)** for the live build log, UI/UX redesign progress, and the prioritized backlog. The immutable spec is `Refund Plan.html` (Notion export — single source of truth; do not edit).

## Setup

### 1. Install dependencies
```bash
flutter pub get
```

### 2. Replace Firebase config
Edit `lib/firebase_options.dart` with real values from Firebase Console > Project settings.
Download `google-services.json` to `android/app/` and `GoogleService-Info.plist` to `ios/Runner/`.

### 3. Run
```bash
flutter run                 # debug
flutter build apk --debug   # debug APK
```

### 4. Run tests
```bash
flutter test
```

## GitHub Actions secrets required

The CI build workflow reads these secrets (all OPTIONAL — workflow uses placeholders when not set):

| Secret | Required? | Purpose |
|--------|-----------|---------|
| `FIREBASE_CONFIG_ANDROID` | Optional | Base64-encoded `google-services.json` for Firebase. If unset, builds with placeholder config (app will boot but Firebase calls fail until real values provided). |

To set:
```bash
base64 -i android/app/google-services.json | gh secret set FIREBASE_CONFIG_ANDROID
```

## Features
- Anonymous auth (zero-friction onboarding)
- 7 dispute types: upi_p2p, upi_p2m, atm, imps, fastag, bank_charge, wrong_transfer
- RBI TAT compensation calculator (₹100/day beyond deadline, capped at 90 days)
- 30-day FASTag dispute window countdown
- 45-day UPI chargeback window countdown
- Escalation ladder (level 1 bank, level 2 NPCI, level 3 RBI Ombudsman)
- Pre-filled complaint templates (19 built inline; target 51 JSON assets per spec §2.6.1 — see PROGRESS.md §3)
- Ombudsman letter generator (Premium)
- Paywall (RevenueCat): ₹99/mo, ₹499/yr (UI present; RevenueCat integration pending)
- Bilingual English + Hindi
- Light + dark themes
- FCM topic-based engagement campaigns (service present; wiring pending)
- Local scheduled notifications for deadlines
- Offline-first via Firestore
- SMS-paste parser (regex UTR/amount/date)

## SMS permission declaration guidance

Refund Radar uses `READ_SMS` for a core Android feature: importing refund-related bank or merchant SMS to prefill dispute forms with UTR/RRN, amount, and transaction date. Android grants inbox access when the user accepts; Refund Radar filters and parses candidate messages on-device for import. Users can skip SMS permission and paste a copied SMS or enter details manually.

Suggested Play Console declaration summary:

> Refund Radar reads SMS inbox messages after explicit user permission to detect likely failed-transaction/refund messages from banks or merchants and prefill refund dispute forms. SMS parsing happens on-device for this import workflow, reducing manual entry for UTR/RRN, amount, and transaction date. The app also provides a manual paste/data-entry fallback if SMS permission is denied.

## UI/UX redesign progress

13 HTML mockup screens approved by user (`ss/Screen01.png` … `ss/Screen13.png`); Flutter rewrite flown in passes:
- ✅ Pass 0 design tokens · Pass 1 nine shared widgets · Pass 2 onboarding · Pass 3 dispute type · Pass 4 settings · Pass 5 templates
- ⏳ Pass 6 home + cards · Pass 7 dispute detail + RBI timeline · Pass 8 dispute form · Pass 9 escalate page · Pass 10 history page · Pass 11 SMS permission + Add banks (+ fix `/onboard/sms` broken route) · Pass 12 sweep + full `flutter analyze`

Full pass schedule + per-file status in PROGRESS.md §4.

## Disclaimers
Refund Radar is an independent informational tool. It is not affiliated with RBI, NPCI, NHAI, IHMCL, or any bank. We never ask for banking passwords, OTPs, or PINs. Complaints are filed by you on official portals. Compensation estimates are based on published RBI/NPCI rules and actual outcomes depend on your bank/regulator.

## Rules engine source of truth
All regulatory facts are in `assets/rules_engine.json` and never hard-coded into widgets. Loaded from the bundled asset with Remote Config override support.

## License
Proprietary (c) 2026 Refund Radar. All rights reserved.
