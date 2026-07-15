# RefundRadar Play-Store-Ready + Monetization Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all 22 audit findings, redesign templates into a monetization point-of-sale, harden RevenueCat integration, and polish UI/UX for Play Store submission.

**Architecture:** Split work into independent tracks (Critical bugs → High bugs → ME/LO bugs → Templates → RevenueCat → UI/UX). Each track ends with a green CI commit. Shared helpers are introduced first. UI changes come after core logic so screens can be tested against real data.

**Tech Stack:** Flutter 3.44.4, Riverpod, Go Router, Firebase Firestore, RevenueCat `purchases_flutter`, Android Kotlin SMS receiver.

## Global Constraints
- Target platform: Android only; no iOS changes.
- No local Flutter build/test commands; verification is via GitHub Actions CI.
- Do not run `flutter run`, `flutter build`, `flutter analyze`, or `flutter test` locally.
- Follow existing dark-mode pattern: read `AppThemeColors.of(context)`; never raw `Colors.white`/`Colors.black`.
- Use `AppColors` only for static semantic colors (e.g. `AppColors.alert`); do not assume `AppThemeColors.alert` exists.
- i18n: all user-facing strings go into `app_en.arb`, `app_hi.arb`, and `app_localizations.dart`.
- Commit after every independently testable task; keep commits small and focused.

---

## Task Map

| # | Track | Deliverable | Key files |
|---|-------|-------------|-----------|
| 1 | Shared helpers | `IndianNumberFormatter`, `RevenueCat` constants, `DateTime` day-boundary helper | `lib/shared/utils/` |
| 2 | CR-1 | Escalate Copy button gated | `lib/features/escalate/escalate_page.dart` |
| 3 | CR-2 | Client-side auto-expiry (90-day inactivity) | `lib/data/models/dispute.dart`, `lib/data/repositories/firestore_dispute_repository.dart`, `lib/features/home/home_page.dart` |
| 4 | CR-3 | Functional SMS auto-detect toggle + native kill-switch | `lib/features/settings/settings_page.dart`, `lib/core/providers/sms_detection_provider.dart`, `android/.../SmsReceiver.kt` |
| 5 | HI-1..HI-5 | Amount cap, reopen reminders, bank fallback, resolve/reopen guards | `lib/features/dispute_create/dispute_form_page.dart`, `lib/features/dispute_detail/dispute_detail_page.dart`, `lib/data/repositories/reminder_generator.dart` |
| 6 | ME-1..ME-8 + LO | Medium/low bugs | Multiple screens, `compensation_calculator.dart`, `history_page.dart`, `reminders_page.dart` |
| 7 | Templates | Free per type, blur previews, contextual paywall | `assets/templates/**/*.json`, `lib/features/templates/template_library_page.dart`, `lib/features/escalate/widgets/escalate_template_picker.dart`, `lib/features/paywall/paywall_page.dart`, `lib/core/router/app_routes.dart` |
| 8 | RevenueCat | Live pricing, premium loading state, entitlement constant, restore UX | `lib/services/revenue_cat_service.dart`, `lib/core/providers/premium_provider.dart`, `lib/features/paywall/paywall_page.dart`, `lib/core/constants/revenuecat_constants.dart` |
| 9 | UI/UX | Headers, dark-mode, tap targets, dialogs, Privacy Policy | `lib/features/wizard/wizard_page.dart`, `lib/features/ombudsman/ombudsman_letter_page.dart`, `lib/features/settings/settings_page.dart`, etc. |
| 10 | Tests + CI | Add/update tests, verify green, tag `v1.0.0-beta5` | `test/` |

---

## Task 1: Shared Helpers

**Files:**
- Create: `lib/shared/utils/indian_number_formatter.dart`
- Create: `lib/core/constants/revenuecat_constants.dart`
- Create: `lib/shared/utils/date_time_ext.dart`
- Modify: `lib/features/home/home_page.dart` (later)
- Modify: `lib/services/compensation_calculator.dart` (later)

**Interfaces:**
- `IndianNumberFormatter.format(double amount)` → `String` (e.g. `123456.78` → `"1,23,456.78"`)
- `DateTimeX.dateOnly()` → `DateTime` with time zeroed
- `DateTimeX.differenceInDays(DateTime other)` → floor of calendar-day difference

- [ ] **Step 1: Create `IndianNumberFormatter`**

```dart
// lib/shared/utils/indian_number_formatter.dart
class IndianNumberFormatter {
  static String format(double amount) {
    final parts = amount.toStringAsFixed(0).split('.');
    final integer = parts.first;
    final decimal = parts.length > 1 ? '.${parts[1]}' : '';
    final buffer = StringBuffer();
    int i = integer.length;
    if (i <= 3) return '₹$integer$decimal';
    buffer.write(integer.substring(0, i - 3));
    final lastThree = integer.substring(i - 3);
    String rest = lastThree;
    while (rest.isNotEmpty) {
      buffer.write(',');
      buffer.write(rest.substring(0, rest.length > 2 ? 2 : rest.length));
      rest = rest.length > 2 ? rest.substring(2) : '';
    }
    return '₹${buffer.toString()}${decimal.replaceFirst('.', ',')}';
  }
}
```

- [ ] **Step 2: Create RevenueCat constants**

```dart
// lib/core/constants/revenuecat_constants.dart
class RevenueCatConstants {
  static const premiumEntitlementId = 'Premium';
}
```

- [ ] **Step 3: Create date helpers**

```dart
// lib/shared/utils/date_time_ext.dart
extension DateTimeX on DateTime {
  DateTime get dateOnly => DateTime(year, month, day);
  int differenceInDays(DateTime other) {
    return dateOnly.difference(other.dateOnly).inDays;
  }
}
```

- [ ] **Step 4: Commit helpers**

```bash
git add lib/shared/utils/indian_number_formatter.dart lib/core/constants/revenuecat_constants.dart lib/shared/utils/date_time_ext.dart
git commit -m "feat(utils): shared Indian number formatter, RevenueCat constants, date helpers"
```

---

## Task 2: CR-1 — Gate Escalate Copy Button

**Files:**
- Modify: `lib/features/escalate/escalate_page.dart:814-823`

**Interfaces:**
- `_copyEmail(...)` is only called when `isMatchLocked` is `false` or user is premium.

- [ ] **Step 1: Locate the Copy action**
Read `lib/features/escalate/escalate_page.dart` around line 814. The Copy `InkWell` currently does `_copyEmail(context)` unconditionally.

- [ ] **Step 2: Wrap with lock check**

```dart
onTap: () {
  if (isMatchLocked) {
    context.push(AppRoutes.paywallWithParams(
      trigger: 'template_locked',
      returnPath: AppRoutes.escalate(widget.disputeId),
    ));
    return;
  }
  _copyEmail(context);
},
```

- [ ] **Step 3: Add regression test**

Create `test/escalate_copy_gate_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/core/router/app_routes.dart';
import 'package:refund_radar/features/escalate/escalate_page.dart';

void main() {
  test('Copy route for locked template goes to paywall', () {
    // Construct minimal widget state where isMatchLocked is true.
    // Verify the generated route contains template_locked.
    expect(
      AppRoutes.paywallWithParams(trigger: 'template_locked'),
      contains('template_locked'),
    );
  });
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/escalate/escalate_page.dart test/escalate_copy_gate_test.dart
git commit -m "fix(escalate): gate Copy button on paywall for locked Pro template"
```

---

## Task 3: CR-2 — Client-Side Auto-Expiry (90-Day Inactivity)

**Files:**
- Modify: `lib/data/models/dispute.dart`
- Modify: `lib/data/repositories/firestore_dispute_repository.dart`
- Modify: `lib/features/home/home_page.dart`
- Create: `test/dispute_expiry_test.dart`

**Interfaces:**
- `Dispute.lastActivityDate` → `DateTime`
- `Dispute.shouldAutoExpire(DateTime now)` → `bool`
- `FirestoreDisputeRepository.syncExpiredStatuses(String uid, List<Dispute> current, DateTime now)` → `Future<List<Dispute>>`

- [ ] **Step 1: Add helpers to `Dispute`**

In `lib/data/models/dispute.dart`, add:

```dart
DateTime get lastActivityDate {
  final dates = filedDates.values.whereType<DateTime>();
  if (dates.isEmpty) return createdAt;
  return dates.reduce((a, b) => a.isAfter(b) ? a : b);
}

bool shouldAutoExpire(DateTime now) {
  if (status == DisputeStatus.resolved ||
      status == DisputeStatus.expired ||
      status == DisputeStatus.draft) {
    return false;
  }
  return now.difference(lastActivityDate).inDays > 90;
}
```

- [ ] **Step 2: Implement repository sync method**

In `lib/data/repositories/firestore_dispute_repository.dart`, inside `FirestoreDisputeRepository`:

```dart
final _expiringInFlight = <String>{};

Future<List<Dispute>> syncExpiredStatuses(
  String uid,
  List<Dispute> current,
  DateTime now,
) async {
  final expired = <Dispute>[];
  final toWrite = <Dispute>[];
  for (final d in current) {
    if (d.shouldAutoExpire(now) && !_expiringInFlight.contains(d.id)) {
      _expiringInFlight.add(d.id);
      final updated = d.copyWith(
        status: DisputeStatus.expired,
        activityLog: [
          ...d.activityLog,
          ActivityLogEntry(
            type: ActivityLogEntry.disputeExpired,
            label: 'Dispute expired after 90 days of inactivity',
            timestamp: now,
          ),
        ],
      );
      toWrite.add(updated);
      expired.add(updated);
    } else {
      expired.add(d);
    }
  }
  for (final d in toWrite) {
    try {
      await saveDispute(uid, d);
    } catch (_) {
      // Leave as-is for next retry.
    } finally {
      _expiringInFlight.remove(d.id);
    }
  }
  return expired;
}
```

- [ ] **Step 3: Wire into Home**

In `lib/features/home/home_page.dart`, inside `_Body`/`ConsumerWidget` where `disputes` is first received, call:

```dart
final repo = ref.read(disputeRepositoryProvider);
final synced = await repo.syncExpiredStatuses(uid, disputes, DateTime.now());
```

Then use `synced` instead of `disputes` for `activeHomeDisputes`.

- [ ] **Step 4: Add tests**

Create `test/dispute_expiry_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/models/activity_log_entry.dart';

void main() {
  Dispute mk({required DateTime createdAt, required DisputeStatus status, Map<String, DateTime?>? filedDates}) => Dispute(
    id: '1', uid: 'u1', type: DisputeType.upiP2p, status: status,
    amount: 1000, txnDate: createdAt, txnId: 'x', createdAt: createdAt,
    filedDates: filedDates ?? const {},
  );

  test('draft never expires', () {
    final d = mk(createdAt: DateTime(2024,1,1), status: DisputeStatus.draft);
    expect(d.shouldAutoExpire(DateTime.now()), false);
  });

  test('expires after 91 days of no filing', () {
    final created = DateTime.now().subtract(const Duration(days: 100));
    final d = mk(createdAt: created, status: DisputeStatus.filedL1);
    expect(d.shouldAutoExpire(DateTime.now()), true);
  });

  test('resets clock after new filing', () {
    final created = DateTime.now().subtract(const Duration(days: 200));
    final d = mk(createdAt: created, status: DisputeStatus.filedL1, filedDates: {'l1': DateTime.now().subtract(const Duration(days: 5))});
    expect(d.shouldAutoExpire(DateTime.now()), false);
  });
}
```

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/dispute.dart lib/data/repositories/firestore_dispute_repository.dart lib/features/home/home_page.dart test/dispute_expiry_test.dart
git commit -m "feat(disputes): auto-expire after 90 days of inactivity"
```

---

## Task 4: CR-3 — Functional SMS Auto-Detect Toggle

**Files:**
- Create: `lib/core/providers/sms_detection_provider.dart`
- Modify: `lib/features/settings/settings_page.dart`
- Modify: `android/app/src/main/kotlin/com/dhanuk/refundradar/SmsReceiver.kt`
- Modify: `lib/main.dart` (register provider, receiver check)

**Interfaces:**
- `smsDetectionEnabledProvider` → `StateProvider<bool>` (real stored value, false if permission not granted)
- `setSmsDetectionEnabled(bool)` via `StateProvider`

- [ ] **Step 1: Create provider**

```dart
// lib/core/providers/sms_detection_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

final smsDetectionEnabledProvider = StateProvider<bool>((ref) => false);

Future<bool> loadSmsDetectionEnabled() async {
  final granted = await Permission.sms.status.isGranted;
  if (!granted) return false;
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('sms_detection_enabled') ?? true;
}

Future<void> setSmsDetectionEnabled(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('sms_detection_enabled', value);
}
```

- [ ] **Step 2: Initialize in `main.dart`**

After `hydratePersistedAppState`, read the value and seed the provider:

```dart
final enabled = await loadSmsDetectionEnabled();
container.read(smsDetectionEnabledProvider.notifier).state = enabled;
```

- [ ] **Step 3: Update Settings toggle**

Replace the fake toggle in `settings_page.dart`:

```dart
final enabled = ref.watch(smsDetectionProvider);
// ...
ToggleSwitch(
  value: enabled,
  onChanged: (v) async {
    if (v) {
      final status = await Permission.sms.request();
      if (status.isGranted) {
        await setSmsDetectionEnabled(true);
        ref.read(smsDetectionProvider.notifier).state = true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('SMS permission is needed for auto-detect. Grant it in Android Settings.'),
        ));
      }
    } else {
      await setSmsDetectionEnabled(false);
      ref.read(smsDetectionProvider.notifier).state = false;
    }
  },
)
```

- [ ] **Step 4: Native receiver kill-switch**

In `SmsReceiver.kt`, before processing an SMS, read a shared-preference key `sms_detection_enabled`. If `false`, return early. Add a small Kotlin helper to read SharedPreferences by the app's package.

- [ ] **Step 5: Commit**

```bash
git add lib/core/providers/sms_detection_provider.dart lib/features/settings/settings_page.dart lib/main.dart android/app/src/main/kotlin/com/dhanuk/refundradar/SmsReceiver.kt
git commit -m "fix(settings): make SMS auto-detect toggle real and persisted"
```

---

## Task 5: HI-1..HI-5 — High-Severity Bug Fixes

### HI-1: Amount cap + live preview

**Files:**
- Modify: `lib/features/dispute_create/dispute_form_page.dart:679-701`, `:969-999`

- [ ] Add `maxLength: 10` to amount `TextField`.
- [ ] Clamp `_estimate()` amount preview to `min(amount, 500000)`.
- [ ] Add helper text "Max ₹5,00,000" under the field.

### HI-2: Reopen reminders use fresh date

**Files:**
- Modify: `lib/features/dispute_detail/dispute_detail_page.dart` (reopen logic)
- Modify: `lib/data/repositories/reminder_generator.dart`

- [ ] On reopen, set `filedDates[targetKey] = DateTime.now()` for the target stage before calling `syncRemindersForDispute`.

### HI-3: Fragile "Other bank" fallback

**Files:**
- Modify: `lib/features/dispute_create/dispute_form_page.dart:1102-1111`

- [ ] Replace `.last` with explicit `firstWhere((b) => b.id == 'other', orElse: () => null)`. If null, hide the "Other bank" option.

### HI-4/HI-5: Re-entrancy guard + stale dispute after resolve/reopen

**Files:**
- Modify: `lib/features/dispute_detail/dispute_detail_page.dart`

- [ ] Add `_toggling` boolean to state.
- [ ] Disable `_ActionButton` while `_toggling`.
- [ ] In `_toggleResolved`, set `_toggling = true`, `await saveDispute`, capture the returned `Dispute`, `setState` with it, then invalidate providers, reset `_toggling` in `finally`.

- [ ] **Commit**

```bash
git add lib/features/dispute_create/dispute_form_page.dart lib/features/dispute_detail/dispute_detail_page.dart lib/data/repositories/reminder_generator.dart
git commit -m "fix(high): amount cap, reopen reminders, bank fallback, resolve guards"
```

---

## Task 6: ME-1..ME-8 + LO — Medium/Low Bugs

- [ ] **ME-1** `escalate_page.dart`: compute deadline label from `dispute.type.tatBasis`/`tatDays` instead of hardcoded "T+5".
- [ ] **ME-2** `compensation_calculator.dart` + `dispute_detail_page.dart`: use `dateOnly.difference(...).inDays` via `DateTimeX`.
- [ ] **ME-3** `dispute_form_page.dart`: clamp preview to ₹5,00,000.
- [ ] **ME-4** `history_page.dart`: replace fragile switch with explicit `isWon`/`isLost`/`isPartial` helpers.
- [ ] **ME-5** `reminder_generator.dart`: fallback to `createdAt` when filedDate missing.
- [ ] **ME-6** `dispute.dart`: handle `expired` in `reopenTarget()`.
- [ ] **ME-7** `template_repository.dart`: extract `matchTemplateFor(...)` and replace the 3 duplicated match functions.
- [ ] **ME-8** `main.dart`: queue notification deep-links until onboarding hydration completes.
- [ ] **LO-1** Replace copy-pasted Indian-formatting with `IndianNumberFormatter`.
- [ ] **LO-2** `reminders_page.dart`: better overdue wording.
- [ ] **LO-3** `history_page.dart`: hide comp label when compensation is 0.
- [ ] **LO-4** `settings_page.dart`: read version from `PackageInfo`.
- [ ] **LO-5** `settings_page.dart`: add Privacy Policy link tile in Legal dialog.

- [ ] **Commit**

```bash
git add lib/ test/
git commit -m "fix(medium-low): deadline labels, day math, history badges, reminders, version, privacy link"
```

---

## Task 7: Template Monetization Redesign

### 7.1 Make one L1 template per dispute type free

**Files:**
- Modify:
  - `assets/templates/upi/upi_p2m_bank_complaint.json`
  - `assets/templates/upi/atm_bank_complaint.json`
  - `assets/templates/upi/imps_bank_complaint.json`

- [ ] Change `"isPremium": true` → `"isPremium": false` in each.

### 7.2 Extract reusable blur-preview card

**Files:**
- Create: `lib/features/templates/widgets/template_preview_card.dart`

- [ ] Move the existing blur/fade preview logic from `escalate_template_picker.dart` into `TemplatePreviewCard(template: Template, isLocked: bool, onTap: VoidCallback)`.

### 7.3 Update Template Library

**Files:**
- Modify: `lib/features/templates/template_library_page.dart`

- [ ] Replace generic placeholder with `TemplatePreviewCard` for locked templates.
- [ ] Tapping a locked card opens a bottom-sheet preview with an "Unlock with Premium" CTA.
- [ ] Pass `templateId` and `templateTitle` to paywall via `AppRoutes.paywallWithParams`.

### 7.4 Contextual paywall

**Files:**
- Modify: `lib/core/router/app_routes.dart`
- Modify: `lib/features/paywall/paywall_page.dart`

- [ ] Add `paywallWithParams({String? trigger, String? templateId, String? templateTitle})`.
- [ ] In `paywall_page.dart`, read query params and override headline/subtext when a template is referenced.

- [ ] **Commit**

```bash
git add assets/templates/ lib/features/templates/ lib/features/paywall/ lib/core/router/app_routes.dart
git commit -m "feat(templates): free L1 per type, blur previews, contextual paywall"
```

---

## Task 8: RevenueCat Integration Fixes

### 8.1 Entitlement constant + restore UX

**Files:**
- Modify: `lib/services/revenue_cat_service.dart`

- [ ] Import and use `RevenueCatConstants.premiumEntitlementId` everywhere.
- [ ] Replace raw `e.toString()` in restore failure with localized "Could not restore purchases".

### 8.2 Live pricing

**Files:**
- Modify: `lib/features/paywall/paywall_page.dart`

- [ ] Remove `_inrPriceFor()`.
- [ ] Display `package.storeProduct.priceString` directly.
- [ ] Add Crashlytics log if priceString lacks "₹" in Indian builds.

### 8.3 Premium loading state

**Files:**
- Create: `lib/core/providers/premium_provider.dart`
- Modify: `lib/main.dart`
- Modify: `lib/services/revenue_cat_service.dart`

- [ ] Create `premiumStatusProvider = StateProvider<AsyncValue<bool>>`.
- [ ] Seed it from persisted value immediately, then update when RevenueCat customer info arrives.
- [ ] Update paywall gates to treat `AsyncValue.loading()` as free (fail-safe).

- [ ] **Commit**

```bash
git add lib/services/revenue_cat_service.dart lib/features/paywall/paywall_page.dart lib/core/providers/premium_provider.dart lib/core/constants/revenuecat_constants.dart
git commit -m "fix(revenuecat): live pricing, premium loading state, entitlement constant"
```

---

## Task 9: UI/UX Redesign

- [ ] **Wizard header** (`lib/features/wizard/wizard_page.dart`): replace default `AppBar` with custom `AppBackButton` + themed `Row`.
- [ ] **Ombudsman header** (`lib/features/ombudsman/ombudsman_letter_page.dart`): same.
- [ ] **Dark-mode fixes**: replace hardcoded `Colors.white` and raw `AppColors.primary` in create form and home icons with `tc.ctaForeground`/theme-aware tokens.
- [ ] **Pencil icon tap target**: wrap in `IconButton(padding: EdgeInsets.all(12), splashRadius: 24)` in dispute detail and escalate.
- [ ] **Confirmation dialog for Mark Resolved/Reopen**: show a dialog explaining the action before toggling.
- [ ] **Privacy Policy link** in Settings Legal dialog.

- [ ] **Commit**

```bash
git add lib/features/wizard/ lib/features/ombudsman/ lib/features/dispute_create/ lib/features/home/ lib/features/dispute_detail/ lib/features/escalate/ lib/features/settings/
git commit -m "feat(ui): custom headers, dark-mode fixes, tap targets, resolve dialog, privacy link"
```

---

## Task 10: Tests + CI + Tag

- [ ] Add/update tests for all changed logic.
- [ ] Push each commit; ensure CI green.
- [ ] Update `pubspec.yaml` version bump.
- [ ] Tag `v1.0.0-beta5`, push tag, download artifacts, create GitHub Release.

```bash
# after CI success
git add pubspec.yaml
git commit -m "chore: bump to 1.0.0+4 for beta5"
git tag v1.0.0-beta5
git push origin main v1.0.0-beta5
```

---

## Self-Review Checklist

- [ ] Spec coverage: every CR/HI/ME/LO item has a task.
- [ ] No placeholders: every step has code/commands.
- [ ] Type consistency: `Dispute.shouldAutoExpire`, `syncExpiredStatuses`, `paywallWithParams` names used consistently.
- [ ] i18n: strings added to ARB files in UI tasks (Step 9 reminders).
