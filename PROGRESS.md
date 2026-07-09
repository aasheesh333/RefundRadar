# Refund Radar — Build Status & UI/UX Redesign Log

> Companion to `Refund Plan.html` (the Notion spec — unchanged, the single source of truth).
> This file tracks **what's done, what's changed, and what remains.** Re-read both before resuming work.

---

## 0. How to use this file

1. **Read `Refund Plan.html` first** — it is the immutable build spec (Sections 1–11). Do not edit it.
2. Then read this file — it records progress, deviations from the spec, and the live backlog.
3. Pick up work from the **Top backlog items** at the bottom. Work in passes (chunks), verify with `dart analyze` after each file.

---

## 1. UI/UX Redesign (the big change since spec)

The original spec (Section 6.2) called for 10 screens with OpenDesign MCP. The MCP generator failed (`AGENT_EXECUTION_FAILED` on every retry), so we switched to a **manual HTML→Playwright→Flutter pipeline** that's proven to work.

### What was built

**13 approved HTML mockup screens** — `ss/Screen01.png` … `ss/Screen13.png` (regenerable via `ss/build_all.py` + `ss/screenshot.py`):

| # | Screen | Mockup file | Flutter file | Status |
|---|--------|-------------|--------------|--------|
| 1 | Onboarding · 💸 UPI | `screen1.py` | `lib/features/onboarding/onboarding_page.dart` | ✅ rewritten |
| 2 | Onboarding · 🚗 FASTag | (slide 2) | (same file) | ✅ rewritten |
| 3 | Onboarding · ⚖️ Ombudsman | (slide 3) | (same file) | ✅ rewritten |
| 4 | Home dashboard | `screen4.py` | `lib/features/home/home_page.dart` | ⏳ pending |
| 5 | Dispute type picker | `screen5.py` | `lib/features/dispute_create/dispute_type_page.dart` | ✅ rewritten |
| 6 | Dispute form | `screen6.py` | `lib/features/dispute_create/dispute_form_page.dart` | ⏳ pending |
| 7 | Dispute detail + RBI timeline | `screen7.py` | `lib/features/dispute_detail/dispute_detail_page.dart` | ⏳ pending |
| 8 | Escalate (email builder) | `screen8.py` | `lib/features/escalate/escalate_page.dart` | ❌ new file |
| 9 | History (win-rate, filter pills) | `screen9.py` | `lib/features/history/history_page.dart` | ❌ new file |
| 10 | Templates | `screen10.py` | `lib/features/templates/template_library_page.dart` | ✅ rewritten |
| 11 | Settings | `screen11.py` | `lib/features/settings/settings_page.dart` | ✅ rewritten |
| 12 | SMS permission | `screen12.py` | `lib/features/sms_permission/sms_permission_page.dart` | ❌ new file |
| 13 | Add banks | `screen13.py` | `lib/features/add_banks/add_banks_page.dart` | ❌ new file |

### Design tokens added (Pass 0)

`lib/core/theme/app_tokens.dart`:
- `AppShadows` (card / fab / button)
- `AppColors.premiumGoldSoft`
- `AppTypography.counterMedium()` (tabular-number counter)

### 9 shared widgets created (Pass 1)

`lib/shared/widgets/`:
- `app_back_button.dart` · `status_pill.dart` · `filter_pills.dart` · `toggle_switch.dart` · `radio_row.dart` · `info_banner.dart` · `page_dots.dart` · `hero_emoji_circle.dart` · `onboarding_step_header.dart`

(Original widgets `owed_counter_card.dart` · `dispute_card.dart` · `stepper_timeline.dart` · `danger_banner.dart` · `primary_cta.dart` still used — will be restyled in Pass 6.)

### Deviation from spec (recorded, not a spec change)

- **13 screens** (not the original 10) — onboarding split into 3 slides + two post-setup screens (SMS permission, Add banks) added.
- **`/onboard/sms` route** is referenced by `onboarding_page.dart:30` but NOT registered in `app_router.dart` — **broken link, must fix in Pass 11.**
- Screen order: 1–3 onboarding carousel → 4 home → 5–8 dispute flow → 9 history → 10 templates → 11 settings → 12–13 post-setup.

---

## 2. Phase-by-phase audit (as of this writing)

Phase checklist cross-referenced to `Refund Plan.html` Section 7.

### Phase 0 — Setup ✅ ALL DONE
- Flutter project boots · `lib/main.dart`
- Firebase init · anonymous auth · `lib/core/providers/auth_provider.dart:11`
- ✅ **Crashlytics wired in Dart** — `lib/main.dart` now wraps the app in `runZonedGuarded` and forwards framework errors via `FlutterError.onError` + `PlatformDispatcher.onError` to `FirebaseCrashlytics.instance.recordError` / `recordFlutterFatalError`. Falls back to console-print when Firebase isn't initialised (placeholder config). **Backlog item B2 — DONE.**

### Phase 1 — Data & rules ⚠️ MOSTLY DONE
- ✅ `assets/rules_engine.json` — all 7 dispute types, 18 FASTag issuers, 5 escalation targets, `freeTemplateIds` (5).
- ⚠️ `lib/data/repositories/rules_engine_repository.dart` loads from `rootBundle` only — **no Remote Config overlay** (`firebase_remote_config` declared in `pubspec.yaml` but unused). **Backlog item B7.**
- ⚠️ `lib/data/repositories/firestore_dispute_repository.dart` CRUD + `deleteAllUserData` — but **no `enablePersistence()` / cache size set**. **Backlog item B8.**
- ✅ `firestore.rules` — user-scoped + deny-all default.
- ✅ `lib/services/compensation_calculator.dart` — TAT + ₹100/day + 90-day cap + escalate threshold + Indian-grouping formatter.
- ✅ `test/widget_test.dart` — 6 compensation tests (T+1, T+5, FASTag, 45-day window, 90-day cap, escalate). **Note: only tests CompensationCalculator + SmsParser — no widget tests.**

### Phase 2 — UI ⚠️ PARTIALLY DONE (UI redesign mid-flight)
- ✅ Theme (light+dark) · `lib/core/theme/app_theme.dart`, brand tokens (`app_tokens.dart`).
- ✅ Shared widgets (list above).
- ✅ Screens 1, 2, 3 (onboarding) · Screen 5 (dispute type) · Screen 10 (templates) · Screen 11 (settings) — **rewritten to match mockups.**
- ✅ Screens 14, 15, 16, 17 (home, dispute form, dispute detail, wizard) — **exist in original style, not yet redesigned.** See Passes 6–8 below.
- ⚠️ Screen 18 (paywall) — UI complete but no RevenueCat call (see Phase 3).
- ✅ Screen 19 (Ombudsman letter generator) — `lib/features/ombudsman/ombudsman_letter_page.dart` pre-fills Template C, copy + open cms.rbi.org.in.
- ❌ Screen 20 (reminders) — `lib/features/reminders/reminders_page.dart` is a static "No upcoming reminders" placeholder. No `Reminder` model / repo. **Backlog item B6.**
- ✅ Screen 21 (settings) — rewritten.
- ✅ Localization EN + HI — `lib/l10n/app_en.arb` (51 keys), `app_hi.arb` (51 keys), strict parity.
- ✅ Screens 8, 9, 12, 13 from redesign — `escalate_page.dart` (Pass 9), `history_page.dart` (Pass 10), `sms_permission_page.dart` + `add_banks_page.dart` + new `bank_catalog.dart` (Pass 11). Routes `/escalate/:id`, `/history`, `/onboard/sms`, `/onboard/banks` registered; onboarding `_next()` broken link fixed.
- ✅ **Pass 12 — full `flutter analyze` clean (0 issues), debug APK builds** (`build/app/outputs/flutter-apk/app-debug.apk`, ~159 MB). Pre-existing lints (_rot helper, dart:ui redundant import, deprecated Color getters, missing RulesEngine type, FCM curly braces) all fixed.
- 📊 **UI/UX redesign of all 13 mockup screens: 100% complete.**

### Phase 3 — Monetization & polish ✅ COMPLETE (B1/B2/B3/B4/B5/B6/B7/B8 + OneSignal done)
- ✅ **B2 Crashlytics wired** — `lib/main.dart` async error-zone + `FlutterError.onError` + `PlatformDispatcher.onError` forwarding to `FirebaseCrashlytics.instance.recordError` / `recordFlutterFatalError`. Falls back to console-print when Firebase isn't initialised.
- ✅ **B4 AnalyticsService** — `lib/services/analytics_service.dart` typed surface for `dispute_created` / `wizard_completed` / `paywall_view` / `purchase` + `premium` user property + `app_open`. Provider `analyticsServiceProvider`. Resilient to missing Firebase. **Call-sites wired**:
  - `paywall_view` → `lib/features/paywall/paywall_page.dart:64` `_logView()` (post-frame on first build, trigger from query param)
  - `purchase` → `lib/services/revenue_cat_service.dart:104` `purchasePackage()` (logs planId + price + source='paywall')
  - `dispute_created` → `lib/features/dispute_create/dispute_form_page.dart:114` after `saveDispute()` (logs disputeType + isPremium)
  - `wizard_completed` → `lib/features/wizard/wizard_page.dart:118` "Done - set reminder" button (outcome ∈ {escalate, ombudsman}, daysOpen=0, wasWon=false)
- ✅ **B5 FCM reevaluator** — `lib/core/providers/fcm_reevaluater.dart` (`FcmReevaluator` ConsumerWidget) mounted via `MaterialApp.builder` Stack; listens to uid + disputes + premium + locale and triggers `FcmTopicService.reevaluate(...)`. New `lib/core/providers/app_state_provider.dart` (`isPremiumProvider`, `installedHoursProvider`, `freeDisputesUsedProvider`, `hydratePersistedAppState`, `persistPremium`).
- ✅ **B3 RevenueCat wired end-to-end** — RevenueCat project "Refund Radar" (id `145b7bb9`) created at `app.revenuecat.com`, Finance category, Flutter platform. Entitlement Identifier **`Premium`** (capital P) created with default offering (Monthly `monthly` + Yearly `yearly` + Lifetime `lifetime`, all on Test Store). REST API identifier `entlfb6da037aa`. `lib/services/revenue_cat_service.dart` checks `info.entitlements.active.containsKey('Premium')` (case-sensitive — Dart code must match the actual RevenueCat identifier). `lib/features/paywall/paywall_page.dart` rewritten as `ConsumerStatefulWidget`: fetches offerings → renders live price strings from `pkg.storeProduct.title` / `priceString`, plan card onTap → `revenueCatServiceProvider.purchasePackage()`. Loading spinner on the card being purchased; success → snackbar "Premium unlocked 🎉" + `context.go(returnPath)`; failure → snackbar with reason. Restore button → `restorePurchases()`. `paywall_view` logged on init (post-frame), `purchase` logged from `purchasePackage()`. SDK key: `REVENUECAT_SDK_KEY` GitHub secret (release builds); **debug builds fall back to the RevenueCat Test Store key** (`test_kLEeRaGzWFJaBEWdoztufhrpZCS`, baked into the binary) so dev/CI builds exercise the full purchase flow against sandbox. User will swap to the live Play Store SDK key in `REVENUECAT_SDK_KEY` GitHub secret later (only the secret changes; no code change).
- ✅ **B3 free-tier gates landed**:
  - 2nd-dispute block on `/disputes/form` → `lib/features/dispute_create/dispute_form_page.dart:64-83`. Free users (`!isPremium`) with ≥1 active dispute (status ∈ {draft, filed_l1, filed_l2, ombudsman}) get a snackbar + redirect to `/paywall?return=/home&trigger=free_second_dispute` (never write to Firestore). Premium users bypass the gate.
  - Ombudsman lock on dispute detail → `lib/features/dispute_detail/dispute_detail_page.dart:248`. Free users tapping the 📝 icon get a snackbar + redirect to `/paywall?return=/disputes/{id}&trigger=ombudsman_letter`. Premium users proceed to `/ombudsman/{id}`.
  - Pre-existing template-locked gate → `lib/features/templates/template_library_page.dart` (trigger=`template_locked`).
- ✅ `pubspec.yaml` declares `purchases_flutter: ^8.0.0` AND `package:purchases_flutter` IS imported in `lib/services/revenue_cat_service.dart:4` + `lib/features/paywall/paywall_page.dart:3`. RevenueCat configured in `main()` and offers a paywall purchase flow.
- ✅ Paywall UI complete and connected to RevenueCat — plan buttons call `purchasePackage(pkg)`, Restore calls `restorePurchases()`. Plan and lifetime options load dynamically from `Offerings.current.availablePackages` sorted by `PackageType` rank (monthly → annual → lifetime). Static placeholder prices (₹99/₹499) removed in favour of live store prices.
- ✅ SMS-paste parser — `lib/services/sms_parser.dart`, regex UTR/amount/date/VPA, wired in `DisputeFormPage._pasteFromSms()`. 1 unit test passes.
- ❌ **Template library as JSON assets (spec Section 2.6.1) — NOT DONE.** See §3 below. **Backlog item B1 (top priority).**
- ⚠️ `lib/services/fcm_topics.dart` defines `FcmTopicService.reevaluate()` with all 9 spec topics — **now called by `FcmReevaluator` ConsumerWidget** (mount-once effect in `RefundRadarApp.builder` Stack), which listens to `userIdProvider` + `disputesProvider(uid)` + `isPremiumProvider` + `localeProvider` and triggers reevaluation on any change. **Backlog item B5 — DONE.** New file: `lib/core/providers/fcm_reevaluater.dart`. App-level state provider added: `lib/core/providers/app_state_provider.dart` (`isPremiumProvider`, `installedHoursProvider`, `freeDisputesUsedProvider` + persist/hydrate helpers consumed by B3).
- ⚠️ Empty states exist · error/loading states are generic `Center(child: Text('Error'))` / `CircularProgressIndicator()` — no skeleton/shimmer. **Backlog item B8.**

### Phase 4 — QA & release ❌ NOT STARTED
- ❌ Full QA checklist (Section 9) not run.
- ❌ Widget/integration tests missing (only CompensationCalculator + SmsParser unit tests exist).
- ❌ Store submissions not started.

---

## 3. Template library — the focused re-read you asked for

This is the **most detailed backlog item.** Spec section `Refund Plan.html` Section 2.6.1 (re-read carefully).

### Spec requirement
> Expand base templates A/B/C into a library of **51 unique templates** stored as **JSON assets in `assets/templates/`** — each file:
> `{ id, titleEn, titleHi, category, escalationLevel, isPremium, bodyEn, bodyHi }` with the same `{PLACEHOLDER}` convention. Every template must exist in BOTH English and Hindi.

### Current state
- `assets/templates/` contains only `.gitkeep` + `free_templates_index.json` (5-entry ID/title list).
- `template_library_page.dart` hardcodes **19 templates** inline via `_generateTemplates()` (11 base + 8 advanced).
- `bodyEn` and `bodyHi` get the **same** string — Hindi bodies are **NOT translated** (only `titleHi` carries Devanagari).
- No `TemplateRepository` — not loaded from `rootBundle`.

### The 51-template catalog (spec table, build exactly this)

| Category | Count | Templates |
|----------|-------|-----------|
| **UPI / IMPS / ATM** | 16 | 4 dispute types (`upi_p2p`, `upi_p2m`, `atm`, `imps`) × 4 letters each: **(a)** Level-1 bank complaint (Template B base), **(b)** 30-day follow-up reminder, **(c)** NPCI portal escalation summary, **(d)** pre-Ombudsman final notice |
| **FASTag** | 17 | Issuer-specific dispute emails for top 10 issuers (merge contacts from §2.4 into greeting/recipient) · IHMCL false-deduction email in 3 variants (double deduction / deduction without crossing / wrong vehicle class — Template A base) · 1033 call script (what to say + info to keep ready) · Annual Pass / plaza monthly-pass wrong charge · tag closure balance refund claim · acquirer-bank escalation |
| **Bank charges** | 6 | Wrong/unknown charge reversal · hidden fee dispute · minimum-balance penalty waiver request · loan pre-closure charge dispute · 30-day follow-up · final notice before Ombudsman |
| **Wrong transfer** | 4 | Request to own bank to contact beneficiary bank · beneficiary-bank request letter · police cyber-cell complaint draft (fraud case) · NPCI DRM wrong-transfer entry guide |
| **Advanced / legal** | 8 | RBI Ombudsman complaint for UPI / FASTag / bank charges (Template C variants) · harassment + time-cost compensation demand (RB-IOS) · RTI application draft (toll plaza deduction records) · consumer court e-Jagriti complaint draft · legal notice draft · appeal against Ombudsman decision |

**Total = 16 + 17 + 6 + 4 + 8 = 51** ✓

### Free vs Premium gating (spec, hard rule)
- **Free** (exactly 5 starter templates — one basic Level-1 per dispute type): `upi_p2p_bank_complaint`, `fastag_ihmcl_false_deduction_generic`, `bank_charge_reversal_basic`, `wrong_transfer_bank_request`, `fastag_1033_call_script`. (Already listed in `rules_engine.json: freeTemplateIds`.)
- **Premium** (remaining 46): all follow-ups, final notices, issuer-specific FASTag emails, all Ombudsman/legal drafts, **and all Hindi versions of premium templates**.
- Locked templates appear in the library list with **blurred body preview + 🔒 badge + "Unlock 50+ templates" CTA → opens paywall.**
- The free-template ID list lives in `rules_engine.json: freeTemplateIds` so it can be tuned via Remote Config without an app update.
- Template picker UI: searchable list grouped by category, chips for language EN/हिन्दी, each template opens pre-filled from the selected dispute's data.

### Implementation plan (B1)
1. Create `assets/templates/upi_*.json` (16 files), `fastag_*.json` (17 files), `bank_charge_*.json` (6 files), `wrong_transfer_*.json` (4 files), `legal_*.json` (8 files). Each file has the 8-field schema, **with `bodyHi` genuinely translated**.
2. Create `lib/data/repositories/template_repository.dart` that loads all JSON from `rootBundle` (manifest list) + filters by `freeTemplateIds` from `RulesEngineRepository`.
3. Rewrite `template_library_page.dart` to consume `TemplateRepository` instead of `_generateTemplates()`. Keep the new card UI.
4. Add blur + 🔒 for locked previews.
5. Add language chips EN/हिन्दी to the picker.

---

## 4. UI/UX redesign — remaining passes (in order)

| Pass | Work | Files | Status |
|------|------|-------|--------|
| Pass 5 | Templates page rewrite | `template_library_page.dart` | ✅ done (B1 will refactor again to JSON assets) |
| Pass 6 | Home + OwedCounterCard + DisputeCard | `home_page.dart`, `owed_counter_card.dart`, `dispute_card.dart` | ⏳ next |
| Pass 7 | Dispute detail + RBI timeline + activity log | `dispute_detail_page.dart` + new `rbi_timeline.dart`, `activity_log.dart` | ⏳ |
| Pass 8 | Dispute form + form-field box + bank picker tile | `dispute_form_page.dart` + new `form_field_box.dart`, `bank_picker_tile.dart` | ⏳ |
| Pass 9 | Escalate page (email builder, ₹900 max claim) | new `features/escalate/escalate_page.dart` + route | ⏳ |
| Pass 10 | History page (win-rate header, filter pills, 5 cards) | new `features/history/history_page.dart` + route | ⏳ |
| Pass 11 | SMS permission + Add banks pages + routes (fix `/onboard/sms` broken link) | new `features/sms_permission/`, `features/add_banks/` + `app_router.dart` | ⏳ |
| Pass 12 | Sweep raw color literals across `lib/` + full `flutter analyze` | all | ⏳ |

---

## 5. Top backlog items (ordered by importance)

### Build-critical (block release)
- ✅ **B1** — Template library: 51 JSON assets (EN+HI) live under `assets/templates/{upi,fastag,bank_charges,wrong_transfer,advanced}/`; `lib/data/models/template.dart` immutable model with `fromJson`/`titleFor`/`bodyFor`/`fill`; `lib/data/repositories/template_repository.dart` with `templatesProvider` + `isLocked()`; `template_library_page.dart` rewritten to consume `templatesProvider`. Done Jul 8 2026.
- ✅ **B2** — Crashlytics wiring in `main.dart`: `FlutterError.onError`, `PlatformDispatcher.instance.onError`, async zone wrapper.
- ✅ **OneSignal** — `lib/services/onesignal_service.dart` configure()/syncTags()/subscriptionId; init in `main.dart` via `ONESIGNAL_APP_ID` + `ONESIGNAL_API_KEY` dart-defines; tag sync mirrors FCM 9 topics in `fcm_reevaluater.dart`. Package `onesignal_flutter ^5.2.2` (resolved 5.6.3). Coexists with FCM (FCM primary, OneSignal secondary). Done Jul 8 2026.
- ✅ **Release APK** — GitHub Actions release job built signed `app-release.apk` (60.3MB) at run [28970645413](https://github.com/aasheesh333/RefundRadar/actions/runs/28970645413) on Jul 8 2026 using env-based release-keystore signing + all 14 GitHub secrets (5 Firebase + RevenueCat + 4 keystore + 2 OneSignal + VERSION_CODE/N). Commit `826c9a0` on `main`. Workflow name is "Build Debug APK" (legacy name; rename later if needed); dispatch input `build_type=release` triggers signed release job.

### Monetization (Phase 3 🔑 ASK USER for RevenueCat keys)
- **B3** — RevenueCat end-to-end: import `purchases_flutter`, `Purchases.configure()` with keys from user, fetch Offerings, wire paywall plan cards to `purchasePackage()`, persist `isPremium`, restore purchases. Add missing gates: 2nd-dispute block on `/disputes/form`, lock Ombudsman letter generator for free users. 🔑 Needs public SDK keys from user (RevenueCat dashboard).

### Observability & engagement
- **B4** — Analytics events: `firebase_analytics` import + `logEvent('dispute_created' / 'wizard_completed' / 'paywall_view' / 'purchase')` at call-sites. Set user properties `disputes_count`, `is_premium`, `last_active_days`.
- **B5** — FCM wiring: add a `Provider` that watches `userIdProvider` + `disputesProvider` + `isPremiumProvider` + `localeProvider` and calls `FcmTopicService.reevaluate(...)` on every change. Already implemented — just needs dispatch.

### UX gaps
- ✅ **B6** — Real reminders implementation: `Reminder` model + `ReminderStage` enum (4 stages); `FirestoreReminderRepository` (CRUD + idempotent `syncForDispute`); `ReminderGenerator.forDispute()` derives reminders from dispute's `filedDates` + RBI TAT (30-day L1 → 7-day L2 → 30-day ombudsman follow-up, plus 7-day draft-L1 nudge); `remindersProvider` StreamProvider.family live Firestore stream; notifications scheduled via existing `NotificationService.scheduleDeadlineReminder`. Wired: `dispute_form_page.dart` after save, `dispute_detail_page.dart` on `_toggleResolved`, `wizard_page.dart` "Done - set reminder" button. Page rewritten: `reminders_page.dart` is now a `ConsumerWidget` with cards (emoji tile, title, body, overdue/due-today/in-N-days badge, Dismiss + Open actions, empty state). Done Jul 8 2026.
- ✅ **B8** — Loading skeletons (`skeleton.dart` with `SkeletonBox` + `SkeletonList` shimmer) + retry-able branded error banners (`branded_error_banner.dart`). Wired into `home_page.dart`, `template_library_page.dart`, `dispute_detail_page.dart`. Done Jul 8 2026.

### Data robustness
- ✅ **B7** — Remote Config overlay in `RulesEngineRepository`: `FirebaseRemoteConfig.fetchAndActivate()` overlays the bundled `rules_engine.json` with a `rules_engine_override` Remote Config key (string-encoded JSON) — applied only when the Remote Config value's `version` is strictly greater than the bundled version. Failures fall back to the bundled baseline (debug builds without Firebase never break). Added `invalidate()` for "Refresh rules" actions. Done Jul 8 2026.
- ✅ **B8** — `FirebaseFirestore.instance.settings` with `persistenceEnabled: true` + `cacheSizeBytes: 50 MB` set in `_initFirebase()` (only when Firebase really initialised, since `Settings` would throw on a no-op Firebase). Done Jul 8 2026.

### UI redesign (Passes 6–12 listing above)
- Each pass should land ~1–3 files, run `dart analyze <file>` after each, full `flutter analyze` at end of Pass 12.

---

## 6. Key project facts (verify before resuming)

- **Flutter SDK**: `/home/ubuntu/flutter-sdk/bin/flutter` (v3.44.4 stable, Dart 3.12.2). Run `dart analyze <file>` after every edit.
- **Build verification**: `/home/ubuntu/flutter-sdk/bin/dart analyze lib/<path>` per-file; `/home/ubuntu/flutter-sdk/bin/flutter analyze` for full sweep.
- **Tests**: `test/widget_test.dart` — only compensation + SMS parser unit tests. No widget/integration tests; add them in Phase 4.
- **Mockup pipeline**: `ss/mockup-all-screens.html` (82KB single-file); `ss/build_mockup.py` + `ss/screen1.py` … `ss/screen11.py` for individual screens; `ss/build_all.py` ordered runner; `ss/screenshot.py` regenerates PNGs.
- **Pre-existing lint issues** (NOT introduced by us, don't fix unless asked): `app_theme.dart`, `dispute_form_page.dart`, `wizard_page.dart`.
- **User preferences**: write in chunks ("chunks me code write kiya kro"), light theme default, bilingual EN+HI, app is info/guidance only (never handles money), build debug APK on GitHub Actions, don't ask questions — push through to production ready.

---

## 7. GitHub Actions secret catalog (🔑 USER ACTION REQUIRED)

User must add these as **Repository Secrets** in:
**GitHub → Repo → Settings → Secrets and variables → Actions → New repository secret**.

The release-build job (`.github/workflows/android.yml` → `release`) refuses to
run if any of the **required** secrets are missing — see its `Verify required
secrets are present` step. The debug-build job uses **only optional** secrets;
it runs without any of these set (placeholder Firebase + placeholder RevenueCat).

### 7.1 — REQUIRED for `release` build (signed APK with real backend)

| Secret name                       | What it is                                              | How to get it                                                                                                            |
|---------------------------------|---------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------|
| `FB_ANDROID_API_KEY`             | Firebase Android API key (`AIzaSy…`)                    | Firebase Console → Project settings → your Android app → "Download google-services.json" reveals the `current_key`; OR Console → Project settings → Web API Key (Android key) |
| `FB_ANDROID_APP_ID`              | Firebase Android app ID (`1:NNN:android:xxx`)           | Same source as the API key — `google-services.json` → `mobilesdk_app_id` (e.g. `1:1003426392779:android:6340b17ed306276e18c94e`) |
| `FB_MESSAGING_SENDER_ID`         | Firebase Messaging Sender ID (12-digit number)          | Equals the Firebase **project number** (visible on Project settings → General). For this project: `1003426392779`        |
| `FB_PROJECT_ID`                  | Firebase project ID                                     | Firebase Console → Project settings → Project ID. For this project: `refund-radar-9eb75`                                  |
| `FB_STORAGE_BUCKET`              | Firebase Storage bucket                                 | Firebase Console → Project settings → Storage bucket. For this project: `refund-radar-9eb75.firebasestorage.app`           |
| `REVENUECAT_SDK_KEY`             | RevenueCat **public** (not secret) Android SDK key     | RevenueCat dashboard → Project settings → API keys → **PUBLIC Android SDK key** (`goog_…` for Google Play, `PUBLIC_ANDROID_KEY` for Amazon). Note: "secret" is a GitHub naming convention; the RevenueCat value itself is designed to ship in the binary. |
| `KEYSTORE_BASE64`                | Release keystore (`keystore.jks`), **base64-encoded**  | Generate once: `keytool -genkey -v -keystore keystore.jks -alias refund -keyalg RSA -keysize 2048 -validity 10000`. Then `base64 -w 0 keystore.jks`. **Keep the original .jks private — do NOT commit it.** |
| `KEYSTORE_PASSWORD`              | Password for `keystore.jks` above                       | The password you set during `keytool -genkey`.                                                                            |
| `KEY_ALIAS`                      | Key alias inside the keystore                           | The `-alias refund` value (or whatever you used).                                                                          |
| `KEY_PASSWORD`                   | Password for that key                                   | The `-keypass` value (or same as `KEYSTORE_PASSWORD`).                                                                    |

> **No `google-services.json` is committed or injected.** We deliberately
> avoid the single-blob `FIREBASE_CONFIG_ANDROID` secret pattern. Firebase
> is configured purely via the five Dart-side `--dart-define` flags above
> (`FB_ANDROID_API_KEY`, `FB_ANDROID_APP_ID`, `FB_MESSAGING_SENDER_ID`,
> `FB_PROJECT_ID`, `FB_STORAGE_BUCKET`) read by
> `lib/firebase_options.dart` → `DefaultFirebaseOptions.currentPlatform`,
> which is passed to `Firebase.initializeApp()` in `lib/main.dart`.
> The FlutterFire plugins resolve everything else at runtime from
> `firebase_core` — no Google Services Gradle plugin or JSON file required.

### 7.2 — Optional for `debug` build (leave unset to keep using placeholders)

None — the debug job uses only placeholder Firebase + placeholder RevenueCat,
so it works without any secret. If you DO want the debug CI build to talk to
real Firebase + RevenueCat, you can reuse seven of the `release` secrets
(`FIREBASE_CONFIG_ANDROID`, `FB_ANDROID_API_KEY`, `FB_ANDROID_APP_ID`,
`FB_MESSAGING_SENDER_ID`, `FB_PROJECT_ID`, `REVENUECAT_SDK_KEY`) plus the
following extra ones — they're already wired but only consumed by the
debug path if you also tweak `android.yml` to pass `--dart-define` in
the Build debug APK step. Currently the workflow passes NO `--dart-define`
in debug, so these are read as the placeholder constants. Leave alone.

### 7.3 — Keeping the keystore safe

- **Never commit `keystore.jks` to the repo.** The `release` job decodes
  `KEYSTORE_BASE64` into `android/app/keystore.jks` at build time and
  deletes it in a final `if: always()` step.
- GitHub Secrets are write-only from the Actions UI; the values can be
  read by the workflow only.
- Once `KEYSTORE_BASE64` is set, rotate it only if the original .jks file
  is leaked (which would compromise all updates to the published app).

### 7.4 — Build triggers

- Every `push` to `main`/`master` and every PR: runs the **debug** job (no secrets needed).
- Manual: **Actions tab → Build Debug APK → Run workflow → `build_type` = `release`**: runs only the **release** job. Stops with an annotated error if any required secret is missing.

### 7.5 — Once secrets are set, the AI agent will (no user input needed beyond this)

- Re-run workflow on `main` once with `build_type=release` to verify a clean signed release APK builds.
- Continue B3: rewire `paywall_page.dart` to `revenueCatServiceProvider.purchasePackage()`, add 2nd-dispute block + Ombudsman gate.
- B6 / B7 / B8 — independent of user input.

## 8. Other 🔑 ASK USER gates (Phase 4 — not required for release APK on Google Play)

- 🔑 **Google Play Console access + AAB upload** — needed to publish to Play Store. (Phase 4)
- 🔑 **Apple Developer access (Mac or Codemagic)** — needed only for any iOS build. (Phase 4)
- 🔑 **GitHub repo hosting** — optional, user's call.

## 9. Firebase Console provisioning — ✅ ALL DONE (2026-07-08)

Provisioned in the Firebase Console at
`https://console.firebase.google.com/project/refund-radar-9eb75`,
logged in as `aasheeshkatheriya@gmail.com`:

| Product            | Status     | Notes |
|--------------------|------------|-------|
| Project            | ✅ Created | ID `refund-radar-9eb75`, project number `1003426392779`, Spark plan, GA enabled with "Default Account for Firebase" |
| Android app        | ✅ Registered | Package `com.dhanuk.refundradar`, nickname "Refund Radar", App ID `1:1003426392779:android:6340b17ed306276e18c94e`, API key `AIzaSyBCa0iNVDGHCpHycfJNeKfh_BLLz1Ep_PY` |
| Authentication    | ✅ Anonymous enabled | Sign-in method tab → Anonymous provider → toggle ON + Save. Anonymous row now shows "Enabled". Guest users can be scoped by Security Rules without credentials. |
| Firestore          | ✅ Created | `(default)` database, location `asia-south1` (Mumbai), production mode (rules deny-all by default; `firestore.rules` in repo grants user-scoped access by uid) |
| Crashlytics        | ✅ Activated | Visible in sidebar; dashboard populates automatically after the first crash is recorded by the FlutterFire SDK (no manual "enable" step on the console — the SDK registers on first launch). |
| Cloud Messaging    | ✅ Activated | Onboarding page visible; Sender ID = project number `1003426392779`. Used by `lib/services/fcm_topics.dart` + `FcmReevaluator`. |
| Remote Config      | ✅ Activated | Page ready for parameters — no parameters created yet (will be created during B7). |
| Analytics          | ✅ Linked | Linked to GA "Default Account for Firebase" during project creation — events flow automatically once SDK is initialised (which happens via `FirebaseAnalytics` instance from `firebase_analytics` package, surfaced by `AnalyticsService`). |

### 9.1 — RevenueCat project — ✅ DONE (2026-07-08)

Project "Refund Radar" (id `145b7bb9`) created at
`https://app.revenuecat.com`, Finance category, Flutter platform:

| Item                  | Value                                             |
|-----------------------|---------------------------------------------------|
| Project name          | Refund Radar                                      |
| Project id (URL)      | `145b7bb9`                                        |
| Entitlement Identifier | `Premium` (case-sensitive; Dart code matches)     |
| Entitlement REST ID   | `entlfb6da037aa`                                  |
| Default offering      | `default` with 3 packages                         |
| Packages attached     | Monthly (`monthly`), Yearly (`yearly`), Lifetime (`lifetime`) — all on the Test Store |
| Public SDK key (Test Store) | `test_kLEeRaGzWFJaBEWdoztufhrpZCS` (baked into debug builds) |
| Public SDK key (Play Store) | 🔑 **user must set later** as the `REVENUECAT_SDK_KEY` GitHub secret — once the live Google Play app is registered in RevenueCat (requires Play Console service-account JSON) |

**Migration path from test → live:** user only needs to update the
`REVENUECAT_SDK_KEY` GitHub secret from `test_kLEeRaGzWFJaBEWdoztufhrpZCS`
to the live Play Store SDK key. The Dart code stays untouched because
the entitlement Identifier (`Premium`) is server-side identity stored at
RevenueCat — it doesn't change between sandbox and live.

### 9.2 — Remaining console-side steps ( Remote Config only — Phase 4 )

- ⚠️ **Remote Config parameters** (B7) — once we ship the Remote Config
  overlay in `RulesEngineRepository`, we'll come back to the Remote Config
  page and create the tuning parameters. Until then, the page can stay empty.

- 🔑 **RevenueCat live Google Play Store app** — when the app is ready to
  publish to Play Store for real charges, register a real "Google Play
  Store" app in RevenueCat (requires a Play Console service-account JSON).
  The resulting public SDK key becomes the new `REVENUECAT_SDK_KEY`
  GitHub secret value. (Phase 4 gate.)

---

## 10. Production-readiness sweep (2026-07-09) — Phase 1 + Phase 2 + Phase 4-B1

> Driven by three parallel audit reports cataloguing ~70 items across UI/UX,
> data/state, and platform. Order of execution: Phase 1 (data correctness) →
> Phase 2 (test infra) → Phase 4 B-P1 (CI gate) → Phase 3 (UI/UX) →
> Phase 4 (platform/release) → Phase 5 (observability).

### Phase 1 — Data correctness (commit `de41371`) ✅ DONE

10 fixes committed and pushed; `flutter analyze` 0 issues; CI run `29008212593` green.

| ID   | Fix                                                                                                                                                       |
|------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| B-D1 | `deleteDispute` cascades to reminder subcollection + cancels notifications via provider-injected hooks                                                    |
| B-D2 | `deleteAllUserData` also deletes all reminders + `cancelAll` notifications                                                                                |
| B-D3 | Auth-race retry ported to `FirestoreReminderRepository` (`_ensureAuthToken` + `_withAuthRetry` for every op)                                               |
| B-D4 | `syncRemindersForDispute` schedules notifications per-reminder with try/catch (atomic Firestore batch, best-effort notifications)                          |
| B-D5 | `FcmReevaluator._reeval` wrapped in try/catch; errors recorded as non-fatal Crashlytics                                                                    |
| B-D6 | `firestore.rules` reminder `update` requires `resource.data.uid == uid && request.resource.data.uid == uid`                                                 |
| B-D7 | `free_limit_hit` FCM topic predicate fix: `!isPremium && freeDisputesUsed >= 1` (was just `!isPremium` — spammed new users)                                |
| B-D8 | `_saving` re-entrancy guard in `DisputeFormPage._save` (no duplicate disputes; submit button shows spinner + disables)                                    |
| B-D9 | Rollback on partial save failure — if reminders/analytics throw after `saveDispute`, dispute is deleted best-effort                                        |
| B-D10| `remindersProvider(uid)` invalidated on save (was only `disputesProvider`)                                                                                |
| —    | Stale-closure fix: isPremium/locale/freeDisputesUsed listeners moved inside `uid != null` block in `FcmReevaluator`                                        |
| —    | `OneSignal.syncTags` learned optional `freeLimitActive` flag + Crashlytics breadcrumb on failure                                                            |

### Phase 2 — Test infrastructure ✅ DONE (this commit)

- Added `mocktail: ^1.0.4` to dev_dependencies (no build_runner needed).
- Made `ReminderGenerator.forDispute` injectable via optional `now:` parameter (production default unchanged).
- Fixed the SMS parser `dd-MMM-yy` date bug (`m6`): `_tryParseFlexible` was reaching the 3rd format branch but `int.parse('Jan')` threw and was swallowed, silently returning null even though the regex had matched `10-Jan-25`. Now handled via a month-name lookup. Also pivots 2-digit years (`5/6/25` → 2025) in the dash/slash branch (same family of bug).
- Swapped `\u00A0` nbsp → space before regex matching (some bank SMSs send nbsp).
- 88 new tests across 4 files (95 total, up from 7):
  - `test/sms_parser_test.dart` — UTR/amount/date/VPA + the m6 bug regression
  - `test/dispute_model_test.dart` — toJson/fromJson round-trip, defensive parsing, copyWith, enum invariants
  - `test/reminder_generator_test.dart` — deterministic `now`-pinned coverage of L1/L2/ombudsman/draft branches + idempotency + entity-name fallbacks
  - `test/rules_engine_repository_test.dart` — defensive parsing + B7 shallow-merge semantics (Remote Config overlay path requires Firebase → integration test boundary)
  - `test/fcm_topics_test.dart` — mocktail-backed `_FakeFcm` coverage of every topic predicate incl. `free_limit_hit` gating + `DisputeStats.fromList`
- `flutter analyze`: 0 issues. `flutter test`: 95/95 pass.

### Phase 4 — B-P1 CI gate ✅ DONE (this commit)

`.github/workflows/android.yml` — both `continue-on-error: true` flags removed
from the `flutter analyze` and `flutter test` steps in the `debug` job, plus
the `continue-on-error: true` on `flutter test` in the `release` job. The CI
gate is now strict: any analyze error or test failure fails the build.

### Next (queued)

- Phase 3 (UI/UX): replace 5 raw `Center(child: Text('Error: $e'))` screens
  with `BrandedErrorBanner`; add skeletons everywhere; wire
  `AppLocalizations.of(context)` for the ~120 hardcoded strings; dark-mode
  token sweep; accessibility (Semantics/Tooltip/48dp); keyboard handling;
  fix dead UI affordances; FAB safe-area.
- Phase 4 (platform/release): `--split-per-abi`; `--obfuscate --split-debug-info`;
  version source of truth; ProGuard narrow keeps; pin dependency versions; SMS
  permission in AndroidManifest (with Play Store Permissions Declaration form);
  artifact retention 90 days.
- Phase 5 (observability): shallow-vs-deep merge in `RulesEngineRepository`;
  Crashlytics breadcrumbs for swallowed Analytics/FCM errors; `main.dart`
  `FlutterError.onError` silent-branch fix; release smoke test in CI.
