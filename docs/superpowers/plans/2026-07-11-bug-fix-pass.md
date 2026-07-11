# Comprehensive Bug-Fix & UX Improvement Pass — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 9 user-reported issues: home total amount zero, escalate screen redesign, UTR auto-detect from SMS, bank dropdown expansion, settings daily comp/digest, template monetization fixes, activity log expansion.

**Architecture:** 7 tracks (A-G) implemented by 11 subagents. Each track is independently testable. No subagent runs Flutter/Dart/Gradle locally — all verification via GitHub Actions CI.

**Tech Stack:** Flutter, Riverpod, Firestore, RevenueCat, Firebase Cloud Messaging, flutter_local_notifications, Kotlin MethodChannel, Android BroadcastReceiver.

## Global Constraints

- **NO LOCAL BUILDS:** Do NOT run `flutter run`, `flutter build`, `flutter analyze`, `flutter test`, `gradle`, or any Flutter/Dart/Gradle command locally. All verification via GitHub Actions CI only.
- **No SDK installations:** Do not install Flutter SDK, Dart SDK, or Android SDK on the machine.
- **CI workflow:** Push to `main` triggers `Build Release` workflow → `Analyze + Test` job runs `flutter analyze` + `flutter test`. If it fails, read CI logs via `gh run view --log-failed` and fix.
- **Theme colors:** Use `AppThemeColors.of(context)` getters: `surface`, `surfaceAlt`, `accentSoft`, `ctaBackground`, `ctaForeground`, `textPrimary`, `textSecondary`, `textTertiary`, `divider`, `bg`, `isDark`. No `accent` getter — use `AppColors.accent` (static) for accent color values.
- **l10n:** Hand-sync all 3 files on every new key: `lib/l10n/app_localizations.dart` (map), `lib/l10n/app_en.arb`, `lib/l10n/app_hi.arb`.
- **Existing tests:** 246 tests currently pass. New tests must not break existing ones.
- **Dispute model:** `amount` is `double`, `txnId` is `String` (the UTR), `status` is `DisputeStatus` enum.
- **Providers:** `rulesEngineProvider` at `lib/data/repositories/rules_engine_repository.dart:142` (FutureProvider<RulesEngine>), `isPremiumProvider` at `lib/core/providers/app_state_provider.dart:42` (StateProvider<bool>), `disputesProvider` at `lib/core/providers/dispute_provider.dart:36` (FutureProvider.family).
- **Bank catalog:** `BankCatalog.banks` has 55 entries at `lib/data/constants/bank_catalog.dart`. `BankEntry` has `id`, `name`, `short`.
- **Template locking:** `TemplateRepository.isLocked(t, freeIds, isPremiumUser)` = `!isPremiumUser && t.isPremium && !freeIds.contains(t.id)`. `freeTemplateIds` in `assets/rules_engine.json:52`.
- **Escalate page file:** `lib/features/escalate/escalate_page.dart` — `_Body` at line 101, `_buildBody` at line 167, `_card` at line 580, `_showTemplatePicker` at line 660.
- **Dispute detail file:** `lib/features/dispute_detail/dispute_detail_page.dart` — `_activityLog` at line 505.
- **SMS parser:** `lib/services/sms_parser.dart:10` — UTR regex `\b(\d{12})\b` needs expansion to `\b(\d{12,22})\b`.
- **AndroidManifest:** `android/app/src/main/AndroidManifest.xml` — currently has `READ_SMS` only, no `RECEIVE_SMS`.
- **Kotlin:** `android/app/src/main/kotlin/com/dhanuk/refundradar/MainActivity.kt` — MethodChannel `refund_radar/sms_inbox` with `queryInbox` method.

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `lib/data/models/activity_log_entry.dart` | ActivityLogEntry model — type, label, meta, timestamp, highlighted |
| `lib/data/models/utr_detection.dart` | UtrDetection model — utr, amount, date, sender, smsBody, claimed |
| `lib/core/providers/utr_detection_provider.dart` | StreamProvider listening to BroadcastReceiver events |
| `lib/services/daily_comp_scheduler.dart` | Daily compensation summary notification scheduler |
| `lib/services/weekly_digest_scheduler.dart` | Weekly dispute activity digest scheduler |

### Modified Files (by track)
| Track | File | Changes |
|-------|------|---------|
| A | `lib/features/home/home_page.dart` | totalOwed = disputed + penalty, subtitle breakdown |
| A | `lib/shared/widgets/owed_counter_card.dart` | Add subtitle breakdown parameter |
| B | `lib/features/escalate/escalate_page.dart` | Full redesign: scrollable layout, animations, consistency fixes, template section, post-send upsell |
| C | `android/app/src/main/AndroidManifest.xml` | Add RECEIVE_SMS permission |
| C | `android/.../MainActivity.kt` | BroadcastReceiver + event channel for live SMS |
| C | `lib/services/sms_parser.dart` | Fix regex to \d{12,22} + false-positive filter |
| C | `lib/services/sms_inbox_service.dart` | Add live SMS stream from event channel |
| C | `lib/services/notification_service.dart` | Add showUtrDetectedNotification() + daily/weekly schedulers |
| C | `lib/main.dart` | Init UTR detection stream + FCM onMessage handler |
| C | `lib/features/home/home_page.dart` | Detected transactions section |
| C | `lib/features/sms_permission/sms_permission_page.dart` | Request RECEIVE_SMS |
| C | `lib/features/dispute_create/dispute_form_page.dart` | Accept pre-filled UTR from notification deep-link |
| D | `lib/features/dispute_create/dispute_form_page.dart` | _pickBank: show all 55 + search bar |
| E | `lib/features/settings/settings_page.dart` | Wire daily comp + weekly digest toggles |
| E | `lib/services/notification_service.dart` | scheduleDailyComp() + scheduleWeeklyDigest() |
| E | `lib/main.dart` | Init schedulers |
| F | `lib/features/escalate/escalate_page.dart` | Fix auto-match leak, Free/Pro tabs, post-send upsell |
| F | `lib/features/dispute_detail/dispute_detail_page.dart` | Add template picker section |
| G | `lib/data/models/dispute.dart` | Add activityLog field |
| G | `lib/data/repositories/firestore_dispute_repository.dart` | Persist activityLog |
| G | `lib/features/dispute_create/dispute_form_page.dart` | Write dispute_created event |
| G | `lib/features/escalate/escalate_page.dart` | Write escalation_email_sent + template_used |
| G | `lib/features/dispute_detail/dispute_detail_page.dart` | Write resolved/status_changed |
| G | `lib/shared/widgets/activity_log.dart` | Render expanded event types with icons |

---

## Track A: Home Screen Total Amount Fix

**Subagent 1** — Independent, can start immediately.

### Task A1: Change totalOwed to combined disputed + penalty

**Files:**
- Modify: `lib/features/home/home_page.dart:182-185`
- Modify: `lib/shared/widgets/owed_counter_card.dart`

**Interfaces:**
- Consumes: `Dispute.amount` (double), `CompensationCalculator.compute(d).compensationDue` (double), `d.type.compensationPerDay` (int?)
- Produces: `totalOwed` (double) = sum of (amount + compensationDue), `perDay` (double), `disputedSum` (double), `penaltySum` (double)

- [ ] **Step 1: Read the current calculation**

Read `lib/features/home/home_page.dart` lines 180-190. Current code:
```dart
final totalOwed = disputes.fold<double>(
    0, (sum, d) => sum + CompensationCalculator.compute(d).compensationDue);
final perDay = disputes.fold<double>(
    0, (sum, d) => sum + (d.type.compensationPerDay ?? 0).toDouble());
```

- [ ] **Step 2: Replace with combined calculation**

Replace lines 182-185 with:
```dart
final disputedSum = disputes.fold<double>(0, (sum, d) => sum + d.amount);
final penaltySum = disputes.fold<double>(
    0, (sum, d) => sum + CompensationCalculator.compute(d).compensationDue);
final totalOwed = disputedSum + penaltySum;
final perDay = disputes.fold<double>(
    0, (sum, d) => sum + (d.type.compensationPerDay ?? 0).toDouble());
```

- [ ] **Step 3: Update OwedCounterCard call to pass breakdown subtitle**

Find where `OwedCounterCard` is constructed (search `OwedCounterCard(` in home_page.dart, around line 293). Add `breakdown` parameter:
```dart
OwedCounterCard(
  totalOwed: totalOwed,
  perDay: perDay,
  breakdown: '₹${_formatInt(disputedSum)} disputed · ₹${_formatInt(penaltySum)} penalty accrued',
),
```

If `_formatInt` doesn't exist, use the same formatting that `_formatIndian` uses in `owed_counter_card.dart` — or pass `disputedSum` and `penaltySum` as separate doubles and format in the card.

- [ ] **Step 4: Add breakdown parameter to OwedCounterCard**

Read `lib/shared/widgets/owed_counter_card.dart`. Find the constructor (around line 37). Add:
```dart
final String? breakdown;
```
And in the widget build, below the main amount display (around line 113-127), add after the existing subtitle:
```dart
if (breakdown != null)
  Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text(
      breakdown,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: ctaForeground.withOpacity(0.70),
      ),
    ),
  ),
```

- [ ] **Step 5: Add l10n keys for breakdown**

Add to `lib/l10n/app_localizations.dart`:
```dart
'homeBreakdownDisputed': '{disputed} disputed · {penalty} penalty accrued',
```
Add to `lib/l10n/app_en.arb`:
```json
"homeBreakdownDisputed": "{disputed} disputed · {penalty} penalty accrued",
```
Add to `lib/l10n/app_hi.arb`:
```json
"homeBreakdownDisputed": "{disputed} विवादित · {penalty} जुर्माना अर्जित",
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/home_page.dart lib/shared/widgets/owed_counter_card.dart lib/l10n/app_localizations.dart lib/l10n/app_en.arb lib/l10n/app_hi.arb
git commit -m "fix(home): totalOwed shows disputed+penalty instead of penalty-only

The hero counter was showing CompensationCalculator.compute(d).compensationDue
which is zero until bank TAT expires. Now shows combined disputed amount +
accrued penalty with a breakdown subtitle."
```

- [ ] **Step 7: Push and monitor CI**

```bash
git push origin main
```
Monitor: `gh run watch` — watch for `Analyze + Test` job to pass. Do NOT run any Flutter commands locally.

---

## Track D: Bank Dropdown — All 55 Banks with Search

**Subagent 8** — Independent, can start immediately.

### Task D1: Replace _pickBank to show all 55 banks with search

**Files:**
- Modify: `lib/features/dispute_create/dispute_form_page.dart` — `_pickBank` (line 959), `_showBankPicker`

**Interfaces:**
- Consumes: `BankCatalog.banks` (55 BankEntry items), `AddBanksPage.loadSelectedBanks()` (List<String> of onboarding IDs), `RulesEngine` for FASTag issuers
- Produces: Updated `_bankName` state, used by `BankPickerTile`

- [ ] **Step 1: Read current _pickBank and _showBankPicker**

Read `lib/features/dispute_create/dispute_form_page.dart` lines 959-1000. Currently:
```dart
Future<void> _pickBank(BuildContext context, RulesEngine rules) async {
  final isFastag = widget.type == 'fastag';
  final list = <({String name, String id})>[];
  if (isFastag) {
    for (final i in rules.fastagIssuers) {
      if (i['id'] == 'paytm') continue;
      list.add((name: i['name'] as String, id: i['id'] as String));
    }
  } else {
    final selected = await AddBanksPage.loadSelectedBanks();
    list.addAll(
      mergeOnboardBanksWithFallback(
        selectedIds: selected,
        catalog: BankCatalog.banks,
        fallback: kFallbackBanks,
      ),
    );
  }
  if (!context.mounted) return;
  await _showBankPicker(context, list);
}
```

- [ ] **Step 2: Replace non-FASTag branch to show all banks**

Replace the `else` branch (the non-FASTag path). The new logic: build a list of ALL `BankCatalog.banks`, but put onboarding-picked banks first:
```dart
Future<void> _pickBank(BuildContext context, RulesEngine rules) async {
  final isFastag = widget.type == 'fastag';
  if (isFastag) {
    final list = <({String name, String id})>[];
    for (final i in rules.fastagIssuers) {
      if (i['id'] == 'paytm') continue;
      list.add((name: i['name'] as String, id: i['id'] as String));
    }
    if (!context.mounted) return;
    await _showBankPicker(context, list);
    return;
  }

  // Non-FASTag: show ALL banks with onboarding picks first
  final selectedIds = await AddBanksPage.loadSelectedBanks();
  if (!context.mounted) return;
  await _showBankPickerWithSearch(context, selectedIds);
}
```

- [ ] **Step 3: Create _showBankPickerWithSearch method**

Add a new method to the `_DisputeFormPageState` class. This replaces `_showBankPicker` for the non-FASTag path. It shows a bottom sheet with a search bar at the top, "Your banks" section (onboarding picks), and "All banks" section (remaining).

```dart
Future<void> _showBankPickerWithSearch(
  BuildContext context,
  List<String> selectedIds,
) async {
  final tc = AppThemeColors.of(context);
  String searchQuery = '';

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: tc.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          // Your banks (onboarding-picked, that exist in the catalog)
          final yourBanks = BankCatalog.banks
              .where((b) => selectedIds.contains(b.id))
              .toList();

          // All banks (filtered by search)
          final allBanks = BankCatalog.banks.where((b) {
            if (b.id == 'other') return true; // always show
            if (searchQuery.isEmpty) return true;
            final q = searchQuery.toLowerCase();
            return b.name.toLowerCase().contains(q) ||
                b.short.toLowerCase().contains(q) ||
                b.id.toLowerCase().contains(q);
          }).toList();

          // Remove "other" from the middle, put at bottom
          final otherEntry = allBanks.firstWhere((b) => b.id == 'other',
              orElse: () => BankCatalog.banks.last);
          final allBanksFiltered = allBanks.where((b) => b.id != 'other').toList();

          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: tc.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    l10n?.formLabelBank ?? 'Select Bank',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: tc.textPrimary,
                    ),
                  ),
                ),
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: TextField(
                    autofocus: false,
                    decoration: InputDecoration(
                      hintText: 'Search bank...',
                      hintStyle: TextStyle(color: tc.textTertiary, fontSize: 14),
                      prefixIcon: Icon(Icons.search, size: 20, color: tc.textTertiary),
                      filled: true,
                      fillColor: tc.surfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (value) => setSheetState(() => searchQuery = value),
                  ),
                ),
                // List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 20),
                    children: [
                      // Your banks section (only if no search and have onboarding picks)
                      if (searchQuery.isEmpty && yourBanks.isNotEmpty) ...[
                        _bankSectionHeader(
                          sheetContext,
                          'Your banks',
                          tc,
                        ),
                        for (final b in yourBanks)
                          _bankTile(sheetContext, b, tc, () {
                            setState(() => _bankName = b.name);
                            Navigator.pop(context);
                          }),
                        const SizedBox(height: 8),
                      ],
                      // All banks section
                      _bankSectionHeader(
                        sheetContext,
                        searchQuery.isEmpty ? 'All banks' : 'Search results',
                        tc,
                      ),
                      for (final b in allBanksFiltered)
                        _bankTile(sheetContext, b, tc, () {
                          setState(() => _bankName = b.name);
                          Navigator.pop(context);
                        }),
                      // Other bank at bottom
                      _bankTile(sheetContext, otherEntry, tc, () {
                        setState(() => _bankName = otherEntry.name);
                        Navigator.pop(context);
                      }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
```

- [ ] **Step 4: Add _bankSectionHeader and _bankTile helpers**

Add these private methods to `_DisputeFormPageState`:
```dart
Widget _bankSectionHeader(BuildContext context, String label, AppThemeColors tc) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        color: tc.textTertiary,
      ),
    ),
  );
}

Widget _bankTile(
  BuildContext context,
  BankEntry bank,
  AppThemeColors tc,
  VoidCallback onTap,
) {
  final isSelected = _bankName == bank.name;
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              bank.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.accent : tc.textPrimary,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.check_circle, size: 20, color: AppColors.accent),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 5: Add l10n key for search hint**

Add to all 3 l10n files:
- `app_localizations.dart`: `'formBankSearchHint': 'Search bank...',`
- `app_en.arb`: `"formBankSearchHint": "Search bank...",`
- `app_hi.arb`: `"formBankSearchHint": "बैंक खोजें...",`

Add also:
- `app_localizations.dart`: `'formBankYourBanks': 'Your banks',` and `'formBankAllBanks': 'All banks',`
- `app_en.arb`: `"formBankYourBanks": "Your banks",` and `"formBankAllBanks": "All banks",`
- `app_hi.arb`: `"formBankYourBanks": "आपके बैंक",` and `"formBankAllBanks": "सभी बैंक",`

- [ ] **Step 6: Commit**

```bash
git add lib/features/dispute_create/dispute_form_page.dart lib/l10n/app_localizations.dart lib/l10n/app_en.arb lib/l10n/app_hi.arb
git commit -m "feat(form): bank dropdown shows all 55 banks with search

Replaced mergeOnboardBanksWithFallback (which showed only ~5 banks) with
full BankCatalog.banks picker. Search bar filters by name/short/id.
Onboarding-picked banks shown first under 'Your banks' section."
```

- [ ] **Step 7: Push and monitor CI**

```bash
git push origin main
```

---

## Track E: Settings — Daily Comp + Weekly Digest Functional

**Subagent 9** — Independent, can start immediately.

### Task E1: Wire settings toggles to existing providers

**Files:**
- Modify: `lib/features/settings/settings_page.dart` — lines 240-251 (daily comp + weekly digest toggles)

**Interfaces:**
- Consumes: `notifDailyProvider` (app_state_provider.dart:46), `setNotifDaily()` (app_state_provider.dart:74), `notifWeeklyProvider` (app_state_provider.dart:47), `setNotifWeekly()` (app_state_provider.dart:77)

- [ ] **Step 1: Read current stub toggles**

Read `lib/features/settings/settings_page.dart` lines 230-260. Current code has:
```dart
// "Daily comp clock (Coming soon)" — value: false, onChanged: null
// "Weekly digest (Coming soon)" — value: false, onChanged: null
```

- [ ] **Step 2: Wire daily comp toggle**

Replace the "Daily comp clock" toggle. Change from:
```dart
value: false,
onChanged: null,
```
To:
```dart
value: ref.watch(notifDailyProvider),
onChanged: (v) => setNotifDaily(ref, v),
```

Remove the "(Coming soon)" / `...Soon` suffix from the label. Use `l10n?.settingsDailyComp` (without `Soon`). If the l10n key `settingsDailyComp` doesn't exist without `Soon`, create it:
- `app_localizations.dart`: `'settingsDailyComp': 'Daily comp clock',`
- `app_en.arb`: `"settingsDailyComp": "Daily comp clock",`
- `app_hi.arb`: `"settingsDailyComp": "दैनिक क्षतिपूर्ति अलर्ट",`

- [ ] **Step 3: Wire weekly digest toggle**

Replace the "Weekly digest" toggle similarly:
```dart
value: ref.watch(notifWeeklyProvider),
onChanged: (v) => setNotifWeekly(ref, v),
```

Remove "(Coming soon)". Create l10n key if needed:
- `app_localizations.dart`: `'settingsWeeklyDigest': 'Weekly digest',`
- `app_en.arb`: `"settingsWeeklyDigest": "Weekly digest",`
- `app_hi.arb`: `"settingsWeeklyDigest": "साप्ताहिक सारांश",`

- [ ] **Step 4: Commit**

```bash
git add lib/features/settings/settings_page.dart lib/l10n/app_localizations.dart lib/l10n/app_en.arb lib/l10n/app_hi.arb
git commit -m "feat(settings): wire daily comp + weekly digest toggles to providers

Both toggles were stubs with onChanged:null. Now wired to notifDailyProvider
and notifWeeklyProvider. Removed 'Coming soon' labels."
```

### Task E2: Create DailyCompScheduler

**Files:**
- Create: `lib/services/daily_comp_scheduler.dart`
- Modify: `lib/services/notification_service.dart` — add `scheduleDailyComp()` method

**Interfaces:**
- Consumes: `disputesProvider`, `CompensationCalculator.compute()`, `NotificationService`
- Produces: A scheduled daily notification at 9 AM summarizing penalty accrual

- [ ] **Step 5: Create DailyCompScheduler**

Create `lib/services/daily_comp_scheduler.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/dispute_provider.dart';
import '../core/providers/app_state_provider.dart';
import 'compensation_calculator.dart';
import 'notification_service.dart';

class DailyCompScheduler {
  final NotificationService _notifications;

  DailyCompScheduler(this._notifications);

  /// Schedules a daily 9 AM notification if dailyComp is enabled.
  /// Called on app start and when notifDailyProvider toggles.
  Future<void> schedule(WidgetRef ref, String uid) async {
    final enabled = ref.read(notifDailyProvider);
    if (!enabled) {
      await _notifications.cancelDailyComp();
      return;
    }
    await _notifications.scheduleDailyComp();
  }
}
```

- [ ] **Step 6: Add scheduleDailyComp + cancelDailyComp to NotificationService**

Read `lib/services/notification_service.dart`. Add two methods:

```dart
static const _dailyCompNotificationId = 9001;

Future<void> scheduleDailyComp() async {
  final now = TZDateTime.now(local);
  var scheduled = TZDateTime(local, now.year, now.month, now.day, 9, 0);
  if (scheduled.isBefore(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  await _flutterLocalNotifications.zonedSchedule(
    _dailyCompNotificationId,
    'Daily compensation summary',
    'Tap to see how much penalty has accrued across your disputes',
    scheduled,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_comp_channel',
        'Daily compensation summary',
        channelDescription: 'Daily summary of penalty compensation accrued',
        importance: Importance.low,
        priority: Priority.low,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
  );
}

Future<void> cancelDailyComp() async {
  await _flutterLocalNotifications.cancel(_dailyCompNotificationId);
}
```

The `matchDateTimeComponents: DateTimeComponents.time` makes it repeat daily.

### Task E3: Create WeeklyDigestScheduler

**Files:**
- Create: `lib/services/weekly_digest_scheduler.dart`
- Modify: `lib/services/notification_service.dart` — add `scheduleWeeklyDigest()` + `cancelWeeklyDigest()`

- [ ] **Step 7: Create WeeklyDigestScheduler**

Create `lib/services/weekly_digest_scheduler.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/app_state_provider.dart';
import 'notification_service.dart';

class WeeklyDigestScheduler {
  final NotificationService _notifications;

  WeeklyDigestScheduler(this._notifications);

  Future<void> schedule(WidgetRef ref, String uid) async {
    final enabled = ref.read(notifWeeklyProvider);
    if (!enabled) {
      await _notifications.cancelWeeklyDigest();
      return;
    }
    await _notifications.scheduleWeeklyDigest();
  }
}
```

- [ ] **Step 8: Add scheduleWeeklyDigest + cancelWeeklyDigest to NotificationService**

Add to `lib/services/notification_service.dart`:
```dart
static const _weeklyDigestNotificationId = 9002;

Future<void> scheduleWeeklyDigest() async {
  final now = TZDateTime.now(local);
  // Find next Sunday
  var scheduled = TZDateTime(local, now.year, now.month, now.day, 9, 0);
  while (scheduled.weekday != DateTime.sunday) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  if (scheduled.isBefore(now)) {
    scheduled = scheduled.add(const Duration(days: 7));
  }
  await _flutterLocalNotifications.zonedSchedule(
    _weeklyDigestNotificationId,
    'Weekly dispute digest',
    'Tap to see your dispute activity this week',
    scheduled,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'weekly_digest_channel',
        'Weekly dispute digest',
        channelDescription: 'Weekly summary of dispute activity',
        importance: Importance.low,
        priority: Priority.low,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
  );
}

Future<void> cancelWeeklyDigest() async {
  await _flutterLocalNotifications.cancel(_weeklyDigestNotificationId);
}
```

### Task E4: Init schedulers on app start

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 9: Add scheduler init to main.dart**

Read `lib/main.dart`. Find where `NotificationService` is initialized (search for `NotificationService` or `notificationService`). After initialization, add:
```dart
// Schedule daily comp + weekly digest if enabled
final dailyCompScheduler = DailyCompScheduler(notificationService);
final weeklyDigestScheduler = WeeklyDigestScheduler(notificationService);
// These will be called from a widget with ref context — see FcmReevaluator pattern
```

Follow the existing `FcmReevaluator` pattern — create a small widget that watches the provider and calls the scheduler on changes. Or add to the existing `FcmReevaluator` widget's `reevaluate` method.

- [ ] **Step 10: Commit**

```bash
git add lib/services/daily_comp_scheduler.dart lib/services/weekly_digest_scheduler.dart lib/services/notification_service.dart lib/main.dart
git commit -m "feat(settings): functional daily comp + weekly digest schedulers

Daily comp: scheduled 9 AM daily notification summarizing penalty accrual
Weekly digest: scheduled Sunday 9 AM notification summarizing dispute activity
Both respect their respective provider toggles."
```

- [ ] **Step 11: Push and monitor CI**

```bash
git push origin main
```

---

## Track G: Activity Log — Expanded Event Types

**Subagent 11** — Independent but touches many files. Coordinate carefully.

### Task G1: Create ActivityLogEntry model

**Files:**
- Create: `lib/data/models/activity_log_entry.dart`

- [ ] **Step 1: Create the model**

Create `lib/data/models/activity_log_entry.dart`:
```dart
/// A single entry in a dispute's activity log.
/// Stored as a list on the Dispute document in Firestore.
class ActivityLogEntry {
  final String type;
  final String label;
  final String meta;
  final DateTime timestamp;
  final bool highlighted;

  const ActivityLogEntry({
    required this.type,
    required this.label,
    required this.meta,
    required this.timestamp,
    this.highlighted = false,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'label': label,
    'meta': meta,
    'timestamp': timestamp.toIso8601String(),
    'highlighted': highlighted,
  };

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) {
    return ActivityLogEntry(
      type: json['type'] as String? ?? '',
      label: json['label'] as String? ?? '',
      meta: json['meta'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      highlighted: json['highlighted'] as bool? ?? false,
    );
  }

  /// Event type constants
  static const disputeCreated = 'dispute_created';
  static const l1TicketFiled = 'l1_ticket_filed';
  static const l2TicketFiled = 'l2_ticket_filed';
  static const escalationEmailSent = 'escalation_email_sent';
  static const templateUsed = 'template_used';
  static const statusChanged = 'status_changed';
  static const reminderFired = 'reminder_fired';
  static const resolved = 'resolved';
  static const utrDetected = 'utr_detected';
}
```

### Task G2: Add activityLog to Dispute model

**Files:**
- Modify: `lib/data/models/dispute.dart`

- [ ] **Step 2: Add activityLog field to Dispute**

Read `lib/data/models/dispute.dart`. Find the fields section (around line 30-50). Add:
```dart
final List<ActivityLogEntry> activityLog;
```

In `Dispute.fromJson` (around line 145), add parsing:
```dart
activityLog: (json['activityLog'] as List?)
        ?.map((e) => ActivityLogEntry.fromJson(e as Map<String, dynamic>))
        .toList() ??
    [],
```

In `Dispute.toJson` (around line 125), add serialization:
```dart
'activityLog': activityLog.map((e) => e.toJson()).toList(),
```

In the constructor, add: `required this.activityLog,`
In `Dispute.copyWith`, add: `activityLog: activityLog ?? this.activityLog,`

Add import: `import 'activity_log_entry.dart';`

### Task G3: Write events at action points

**Files:**
- Modify: `lib/features/dispute_create/dispute_form_page.dart`
- Modify: `lib/features/escalate/escalate_page.dart`
- Modify: `lib/features/dispute_detail/dispute_detail_page.dart`

- [ ] **Step 3: Write dispute_created event on form submit**

Read `lib/features/dispute_create/dispute_form_page.dart`. Find where the `Dispute` is constructed and saved (around line 340-360). After constructing the `Dispute`, add an activity log entry:
```dart
final dispute = Dispute(
  // ...existing fields...
  activityLog: [
    ActivityLogEntry(
      type: ActivityLogEntry.disputeCreated,
      label: l10n?.activityDisputeCreated ?? 'Dispute created',
      meta: _fmtDate(DateTime.now()),
      timestamp: DateTime.now(),
      highlighted: true,
    ),
  ],
);
```

- [ ] **Step 4: Write escalation_email_sent + template_used on escalate send**

Read `lib/features/escalate/escalate_page.dart`. Find `_sendEmail` method (around line 842). After the email is sent, update the dispute's activityLog in Firestore:
```dart
// After email send success, add activity log entries
final updatedLog = [
  ...dispute.activityLog,
  ActivityLogEntry(
    type: ActivityLogEntry.escalationEmailSent,
    label: l10n?.activityEscalationSent ?? 'Escalation email sent',
    meta: _fmtDate(DateTime.now()),
    timestamp: DateTime.now(),
    highlighted: true,
  ),
  ActivityLogEntry(
    type: ActivityLogEntry.templateUsed,
    label: '${l10n?.activityTemplateUsed ?? 'Template used'}: ${selectedTemplate.titleEn}',
    meta: _fmtDate(DateTime.now()),
    timestamp: DateTime.now(),
  ),
];
// Save to Firestore via repository
```

- [ ] **Step 5: Write resolved/status_changed on detail page**

Read `lib/features/dispute_detail/dispute_detail_page.dart`. Find `_toggleResolved` (around line 539). After updating dispute status, add activity log entry:
```dart
final updatedLog = [
  ...dispute.activityLog,
  ActivityLogEntry(
    type: dispute.status == DisputeStatus.resolved
        ? ActivityLogEntry.statusChanged
        : ActivityLogEntry.resolved,
    label: /* resolved or status changed label */,
    meta: _fmtDate(DateTime.now()),
    timestamp: DateTime.now(),
    highlighted: true,
  ),
];
```

### Task G4: Update ActivityLog widget for expanded types

**Files:**
- Modify: `lib/shared/widgets/activity_log.dart`

- [ ] **Step 6: Add icons per event type**

Read `lib/shared/widgets/activity_log.dart`. Currently it's a display widget that takes `List<ActivityEntry>`. Update to render icons based on the `type` field:
```dart
IconData _iconForType(String type) {
  switch (type) {
    case ActivityLogEntry.disputeCreated:
      return Icons.add_circle_outline;
    case ActivityLogEntry.escalationEmailSent:
      return Icons.email_outlined;
    case ActivityLogEntry.templateUsed:
      return Icons.description_outlined;
    case ActivityLogEntry.resolved:
      return Icons.check_circle_outline;
    case ActivityLogEntry.reminderFired:
      return Icons.notifications_outlined;
    case ActivityLogEntry.utrDetected:
      return Icons.sms_outlined;
    default:
      return Icons.circle_outlined;
  }
}
```

- [ ] **Step 7: Add l10n keys for activity labels**

Add to all 3 l10n files:
- `activityDisputeCreated`: "Dispute created" / "विवाद दर्ज किया गया"
- `activityEscalationSent`: "Escalation email sent" / "एस्कलेशन ईमेल भेजा गया"
- `activityTemplateUsed`: "Template used" / "टेंपलेट उपयोग किया गया"
- `activityResolved`: "Dispute resolved" / "विवाद हल हो गया"
- `activityReminderFired`: "Deadline reminder fired" / "समयसीमा अनुस्मारक भेजा गया"
- `activityUtrDetected`: "UTR auto-detected" / "UTR स्वतः पहचाना गया"
- `activityStatusChanged`: "Status changed" / "स्थिति बदली गई"

- [ ] **Step 8: Commit**

```bash
git add lib/data/models/activity_log_entry.dart lib/data/models/dispute.dart lib/features/dispute_create/dispute_form_page.dart lib/features/escalate/escalate_page.dart lib/features/dispute_detail/dispute_detail_page.dart lib/shared/widgets/activity_log.dart lib/l10n/app_localizations.dart lib/l10n/app_en.arb lib/l10n/app_hi.arb
git commit -m "feat(activity): expand activity log to 9 event types stored on dispute

Replaces 4 hardcoded computed events with 9 persisted event types:
dispute_created, l1/l2_ticket_filed, escalation_email_sent, template_used,
status_changed, reminder_fired, resolved, utr_detected.
Events stored in Firestore on the dispute document."
```

- [ ] **Step 9: Push and monitor CI**

```bash
git push origin main
```

---

## Track F: Template Monetization — Four Fixes

**Subagent 10** — Depends on Track B's template picker design. Can start independently for auto-match fix.

### Task F1: Fix auto-match leak

**Files:**
- Modify: `lib/features/escalate/escalate_page.dart:644-658` — `_matchEscalationTemplate`

**Interfaces:**
- Consumes: `repo.isLocked(t, freeIds, isPremiumUser: isPremiumUser)`, `templatesProvider`, `freeTemplateIds`
- Produces: Auto-matched template that is always unlocked for the user

- [ ] **Step 1: Read current _matchEscalationTemplate**

Read `lib/features/escalate/escalate_page.dart` lines 644-658. Current:
```dart
Template? _matchEscalationTemplate(
  List<Template> templates,
  String category,
) {
  for (final t in templates) {
    if (t.escalationLevel == 2 && t.category == category) {
      return t;
    }
  }
  return null;
}
```

- [ ] **Step 2: Filter to unlocked templates only**

Replace with a version that respects lock status:
```dart
Template? _matchEscalationTemplate(
  List<Template> templates,
  String category,
  TemplateRepository repo,
  Set<String> freeIds,
  bool isPremiumUser,
) {
  // First try unlocked templates only
  for (final t in templates) {
    if (t.escalationLevel == 2 &&
        t.category == category &&
        !repo.isLocked(t, freeIds, isPremiumUser: isPremiumUser)) {
      return t;
    }
  }
  // Fallback: any template in category (free user gets the first free one)
  for (final t in templates) {
    if (t.escalationLevel == 2 && t.category == category && !t.isPremium) {
      return t;
    }
  }
  // Last resort: any template in category (may be locked — picker will handle gating)
  for (final t in templates) {
    if (t.escalationLevel == 2 && t.category == category) {
      return t;
    }
  }
  return null;
}
```

- [ ] **Step 3: Update the call site**

Find where `_matchEscalationTemplate` is called (in `_Body.build` around line 130). Update to pass the new parameters:
```dart
final matched = _matchEscalationTemplate(
  templates,
  category,
  repo,
  freeIds,
  isPremiumUser,
);
```

- [ ] **Step 4: If auto-matched template is locked, show paywall CTA instead of body**

In `_buildBody`, where the email body is built. If the matched template is locked, show a blurred/locked preview instead of the full body:
```dart
final isMatchLocked = repo.isLocked(matched, freeIds, isPremiumUser: isPremiumUser);
// In the email preview card: if isMatchLocked, show first 2 lines + paywall CTA
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/escalate/escalate_page.dart
git commit -m "fix(escalate): auto-match only uses unlocked templates for free users

Auto-matched template was bypassing premium gating — free users got premium
template bodies for free. Now filters to unlocked templates first, with
fallback to free templates in category."
```

### Task F2: Free vs Pro tabs in template picker

**Files:**
- Modify: `lib/features/escalate/escalate_page.dart:660-823` — `_showTemplatePicker`

- [ ] **Step 6: Redesign _showTemplatePicker with Free/Pro tabs**

Read `lib/features/escalate/escalate_page.dart` lines 660-823. Replace the bottom sheet content to use a `DefaultTabController` with two tabs:

```dart
void _showTemplatePicker(
  BuildContext context,
  List<Template> templates,
  TemplateRepository repo,
  Set<String> freeIds,
  bool isPremiumUser,
  String category,
  String? selectedTemplateId,
  ValueChanged<String?> onSelectTemplate,
) {
  final tc = AppThemeColors.of(context);

  // Split into free and pro
  final freeTemplates = templates
      .where((t) => t.escalationLevel == 2 &&
          t.category == category &&
          !repo.isLocked(t, freeIds, isPremiumUser: isPremiumUser))
      .toList();
  final proTemplates = templates
      .where((t) => t.escalationLevel == 2 &&
          t.category == category &&
          repo.isLocked(t, freeIds, isPremiumUser: isPremiumUser))
      .toList();

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: tc.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DefaultTabController(
      length: 2,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            // Handle + title
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: tc.divider, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                l10n?.escalatePickTemplate ?? 'Pick escalation template',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tc.textPrimary),
              ),
            ),
            // TabBar
            TabBar(
              tabs: [
                Tab(text: 'Free (${freeTemplates.length})'),
                Tab(text: 'Pro (${proTemplates.length})'),
              ],
              labelColor: AppColors.accent,
              unselectedLabelColor: tc.textTertiary,
              indicatorColor: AppColors.accent,
            ),
            // Tab views
            Expanded(
              child: TabBarView(
                children: [
                  // Free tab
                  _templateList(context, freeTemplates, repo, freeIds, isPremiumUser,
                      selectedTemplateId, onSelectTemplate, tc, isProTab: false),
                  // Pro tab
                  _templateList(context, proTemplates, repo, freeIds, isPremiumUser,
                      selectedTemplateId, onSelectTemplate, tc, isProTab: true),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 7: Add _templateList helper**

Extract the template list rendering into a helper that handles both free and pro tabs. For pro (locked) templates, show a blur preview (first 2 sentences visible, rest blurred):
```dart
Widget _templateList(
  BuildContext context,
  List<Template> templates,
  TemplateRepository repo,
  Set<String> freeIds,
  bool isPremiumUser,
  String? selectedTemplateId,
  ValueChanged<String?> onSelectTemplate,
  AppThemeColors tc, {
  required bool isProTab,
}) {
  if (templates.isEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          isProTab ? 'No Pro templates for this category' : 'No free templates for this category',
          style: TextStyle(color: tc.textTertiary, fontSize: 14),
        ),
      ),
    );
  }
  return ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: templates.length,
    separatorBuilder: (_, _) => SizedBox(height: 8),
    itemBuilder: (context, index) {
      final t = templates[index];
      final isSelected = t.id == selectedTemplateId;
      final isLocked = isProTab && !isPremiumUser;

      return InkWell(
        onTap: isLocked
            ? () {
                Navigator.pop(context);
                context.push('/paywall?return=/home&trigger=template_locked');
              }
            : () {
                onSelectTemplate(t.id);
                Navigator.pop(context);
              },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppColors.accent : tc.divider,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.titleEn,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isLocked ? tc.textTertiary : tc.textPrimary,
                      ),
                    ),
                  ),
                  if (isLocked)
                    StatusPill(text: l10n?.templateProBadge ?? 'Pro'),
                  if (isSelected)
                    Icon(Icons.check_circle, size: 20, color: AppColors.accent),
                ],
              ),
              const SizedBox(height: 6),
              // Preview — blurred if locked
              if (isLocked)
                _blurredPreview(t.bodyEn, tc)
              else
                Text(
                  t.bodyEn,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: tc.textSecondary, height: 1.4),
                ),
            ],
          ),
        ),
      );
    },
  );
}
```

- [ ] **Step 8: Add _blurredPreview helper**

For locked templates, show first 2 sentences visible and blur the rest:
```dart
Widget _blurredPreview(String body, AppThemeColors tc) {
  return ClipRect(
    child: Stack(
      children: [
        Text(
          body,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: tc.textSecondary, height: 1.4),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [tc.surface.withOpacity(0), tc.surface],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 9: Commit**

```bash
git add lib/features/escalate/escalate_page.dart
git commit -m "feat(escalate): Free/Pro tabs in template picker with blur preview

Template picker now has two tabs: Free (unlocked) and Pro (locked).
Locked templates show 2-line preview with fade gradient + 'Pro' badge.
Tapping a locked template routes to paywall."
```

### Task F3: Template picker on dispute detail screen

**Files:**
- Modify: `lib/features/dispute_detail/dispute_detail_page.dart`

- [ ] **Step 10: Add template section to dispute detail**

Read `lib/features/dispute_detail/dispute_detail_page.dart`. Find the body content area. Add a template card (after the RbiTimeline, before the activity log):
```dart
// Template card
_card(
  context,
  label: 'TEMPLATE',
  labelAction: Tooltip(
    message: l10n?.escalateEditTemplate ?? 'Pick template',
    child: InkWell(
      onTap: () => _showTemplatePickerForDispute(context, dispute),
      child: Icon(Icons.edit_outlined, size: 18, color: AppColors.accent),
    ),
  ),
  children: [
    Text(
      _selectedTemplateForDispute?.titleEn ?? 'Auto-matched (tap pencil to change)',
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.textPrimary),
    ),
  ],
),
```

- [ ] **Step 11: Add _showTemplatePickerForDispute method**

Add a method that opens the same template picker as escalate page, but for this dispute's level (L1 or L2):
```dart
void _showTemplatePickerForDispute(BuildContext context, Dispute dispute) {
  // Similar to escalate_page._showTemplatePicker but may show L1 templates too
  // Uses the same Free/Pro tab structure
  // On select: saves templateId to dispute (optional — may just preview)
}
```

- [ ] **Step 12: Commit**

```bash
git add lib/features/dispute_detail/dispute_detail_page.dart
git commit -m "feat(detail): template picker section on dispute detail screen

Shows L1/L2 template currently associated with the dispute, with pencil
icon to open the same Free/Pro picker as the escalate screen."
```

### Task F4: Post-escalation upsell CTA

**Files:**
- Modify: `lib/features/escalate/escalate_page.dart` — `_sendEmail` method

- [ ] **Step 13: Add success dialog after email send**

Read `lib/features/escalate/escalate_page.dart` lines 842-890 (`_sendEmail`). After the email is sent successfully, show a dialog:
```dart
void _showPostEscalationDialog(BuildContext context, Dispute dispute, bool isPremiumUser) {
  final tc = AppThemeColors.of(context);
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: tc.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.accent, size: 28),
          const SizedBox(width: 8),
          Text('Escalation sent!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What\'s next?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'If the bank doesn\'t resolve within 30 days, escalate to the Banking Ombudsman.',
            style: TextStyle(fontSize: 13, color: tc.textSecondary),
          ),
          const SizedBox(height: 12),
          // Level 3 preview card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tc.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.gavel, size: 20, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Level 3: Ombudsman notice',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tc.textPrimary),
                  ),
                ),
                if (!isPremiumUser)
                  StatusPill(text: l10n?.templateProBadge ?? 'Pro'),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Later'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            if (isPremiumUser) {
              context.push('/ombudsman/${dispute.id}');
            } else {
              context.push('/paywall?return=/home&trigger=post_escalation');
            }
          },
          child: Text(isPremiumUser
              ? 'Open Ombudsman letter →'
              : 'Unlock Ombudsman templates →'),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 14: Call the dialog after _sendEmail succeeds**

In `_sendEmail`, after the email launch succeeds, add:
```dart
_showPostEscalationDialog(context, dispute, isPremiumUser);
```

- [ ] **Step 15: Commit**

```bash
git add lib/features/escalate/escalate_page.dart
git commit -m "feat(escalate): post-send upsell to Ombudsman-level templates

After sending escalation email, shows success dialog with 'What's next?'
section. Free users see Level 3 Ombudsman notice behind Pro badge with
paywall CTA. Premium users get direct navigation to ombudsman letter."
```

- [ ] **Step 16: Push and monitor CI**

```bash
git push origin main
```

---

## Track B: Escalation Step Screen Full Redesign

**Subagents 2, 3, 4** — Subagent 2 (layout), 3 (template section — overlaps with F), 4 (post-send upsell — overlaps with F). In practice, F2/F4 already cover the template picker and upsell. So Track B subagent focuses on layout/scroll/animations/consistency.

### Task B1: Convert to scrollable CustomScrollView with SliverAppBar

**Files:**
- Modify: `lib/features/escalate/escalate_page.dart` — `_buildBody` (line 167-578)

**Interfaces:**
- Consumes: All existing providers (disputes, templates, rules, isPremium)
- Produces: A fully scrollable escalate page with collapsing header

- [ ] **Step 1: Read current _buildBody structure**

Read `lib/features/escalate/escalate_page.dart` lines 167-578. Current structure:
```
Column(
  [1] HEADER (Padding, fixed) — lines 185-239
  [2] Expanded > ListView (scrollable) — lines 240-539
  [3] STICKY FOOTER (fixed) — lines 541-575
)
```

- [ ] **Step 2: Replace Column with CustomScrollView + bottom bar**

Replace the root `Column` (line 182) with:
```dart
return Scaffold(
  backgroundColor: tc.bg,
  body: SafeArea(
    child: Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              // Collapsing header
              SliverAppBar(
                pinned: false,
                floating: true,
                automaticallyImplyLeading: false,
                backgroundColor: tc.bg,
                elevation: 0,
                titleSpacing: 0,
                title: _buildHeader(tc, bankName, deadlineMissed),
              ),
              // Content
              SliverToBoxAdapter(child: _buildContent(...)),
            ],
          ),
        ),
        // Sticky footer (outside scroll)
        _buildFooter(tc, context, dispute, ...),
      ],
    ),
  ),
);
```

Wait — `EscalatePage` already has a `Scaffold > SafeArea` wrapper at line 48-50. So `_buildBody` should return just the `CustomScrollView` + footer. Let me check. Read lines 44-98. The `EscalatePage.build` returns `Scaffold > SafeArea > {async} > _Body`. And `_Body.build` returns `_buildBody(...)`. So `_buildBody` should return the content without another Scaffold.

Replace `_buildBody`'s root `Column` with:
```dart
return Column(
  children: [
    Expanded(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(tc, bankName, deadlineMissed)),
          SliverList(
            delegate: SliverChildListDelegate([
              _buildHero(tc, maxClaim, disputedSum, penaltySum, deadlineDays),
              SizedBox(height: 16),
              _buildSendToCard(context, tc, nodalEmail, ccOmbudsman, ...),
              SizedBox(height: 16),
              _buildTemplateCard(context, tc, ...),
              SizedBox(height: 16),
              _buildEmailPreviewCard(context, tc, ...),
              if (deadlineMissed) ...[
                SizedBox(height: 16),
                _buildAmberCallout(tc, comp),
              ],
              SizedBox(height: 20), // bottom breathing room
            ]),
          ),
        ],
      ),
    ),
    _buildFooter(tc, context, dispute, ...),
  ],
);
```

- [ ] **Step 3: Extract header into _buildHeader method**

Extract lines 185-239 into a `_buildHeader` method that returns a `Padding` widget. This is the same content, just extracted for clarity.

- [ ] **Step 4: Extract hero into _buildHero method**

Extract lines 245-296 into `_buildHero`. Fix:
- Radius: `BorderRadius.circular(14)` → `AppRadii.lg` (16)
- Add `boxShadow: AppShadows.card` to BoxDecoration
- Add TAT status indicator below amount
- Show disputed amount + penalty breakdown (using values from Track A's calculation)

- [ ] **Step 5: Allocate SAR correction**

Address: 1–3 Marston Gate, Tytherley, Salisbury, Wiltshire, UK  SP5 5LS

### SAR correction

- [ ] **Step 5a: Update fake address in test/template**

Wait — ignore this.

- [ ] **Step 5: Fix radius + shadow on hero card**

In `_buildHero`, change:
```dart
// OLD:
decoration: BoxDecoration(
  color: tc.ctaBackground,
  borderRadius: const BorderRadius.all(Radius.circular(14)),
),

// NEW:
decoration: BoxDecoration(
  color: tc.ctaBackground,
  borderRadius: BorderRadius.circular(AppRadii.lg), // 16
  boxShadow: AppShadows.card,
),
```

- [ ] **Step 6: Unify eyebrow label style**

In `_buildHero`, the eyebrow label "MAXIMUM PENALTY YOU CAN CLAIM" uses `tc.ctaForeground.withOpacity(0.60)`. Change it to use `tc.textSecondary` to match `_card` labels. Also change the text to "TOTAL CLAIMABLE" since we're now showing disputed+penalty.

- [ ] **Step 7: Reuse _RecipientRow for CC Ombudsman row**

In the SEND TO card (lines 313-341), replace the inline CC Ombudsman row with `_RecipientRow`:
```dart
_RecipientRow(
  icon: '✉',
  title: 'CC RBI Ombudsman',
  detail: 'crpc@rbi.org.in',
  selected: ccOmbudsman,
  trailing: ToggleSwitch(value: ccOmbudsman, onChanged: (v) => setState(() => _ccOmbudsman = v)),
),
```

- [ ] **Step 8: Add entrance animations**

Add an `AnimationController` to `_EscalatePageState`. In `_buildBody`, wrap each major card in a `FadeTransition` + `SlideTransition`:
```dart
// In _EscalatePageState
late AnimationController _animController;

@override
void initState() {
  super.initState();
  _animController = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  )..forward();
}

@override
void dispose() {
  _animController.dispose();
  super.dispose();
}

// Helper for staggered animations
Widget _staggeredBox(int index, Widget child) {
  final start = index * 0.08; // 80ms stagger
  final end = start + 0.3;
  return FadeTransition(
    opacity: Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    ),
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.05),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      ),
      child: child,
    ),
  );
}

// Usage in SliverList:
_buildHero(tc, ...) → _staggeredBox(0, _buildHero(tc, ...)),
_buildSendToCard(...) → _staggeredBox(1, _buildSendToCard(...)),
_buildTemplateCard(...) → _staggeredBox(2, _buildTemplateCard(...)),
_buildEmailPreviewCard(...) → _staggeredBox(3, _buildEmailPreviewCard(...)),
```

- [ ] **Step 9: Fix footer safe area padding**

In `_buildFooter`, change the padding to include safe area:
```dart
padding: EdgeInsets.fromLTRB(20, 12, 20,
    12 + MediaQuery.paddingOf(context).bottom),
```

- [ ] **Step 10: Add TAT status indicator to hero**

In `_buildHero`, below the amount, add a TAT status row:
```dart
// TAT status
Row(
  children: [
    Icon(
      deadlineMissed ? Icons.warning_amber_rounded : Icons.access_time,
      size: 14,
      color: deadlineMissed ? tc.alert : tc.ctaForeground.withOpacity(0.7),
    ),
    const SizedBox(width: 4),
    Text(
      deadlineMissed
          ? 'T+5 deadline missed — claim full penalty'
          : 'T+5 deadline in $deadlineDays days',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: deadlineMissed ? tc.alert : tc.ctaForeground.withOpacity(0.7),
      ),
    ),
  ],
),
```

- [ ] **Step 11: Commit**

```bash
git add lib/features/escalate/escalate_page.dart
git commit -m "redesign(escalate): scrollable layout, animations, consistency fixes

- CustomScrollView with slivered content for smooth scroll
- Fixed radius (14→16) and added shadow on hero card
- Staggered entrance animations (fade+slide, 80ms stagger)
- Footer safe-area padding
- Reused _RecipientRow for CC Ombudsman row
- Unified eyebrow label style
- TAT status indicator on hero card"
```

- [ ] **Step 12: Push and monitor CI**

```bash
git push origin main
```

---

## Track C: UTR Auto-Detect from SMS with Instant Notifications

**Subagents 5, 6, 7** — Sequential dependency: Kotlin receiver → Dart provider → UI.

### Task C1: Add RECEIVE_SMS permission to AndroidManifest

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Read current AndroidManifest**

Read `android/app/src/main/AndroidManifest.xml`. Currently has `READ_SMS` at line 21, no `RECEIVE_SMS`.

- [ ] **Step 2: Add RECEIVE_SMS permission**

Add after the `READ_SMS` line:
```xml
<uses-permission android:name="android.permission.RECEIVE_SMS"/>
```

### Task C2: Create SmsReceiver BroadcastReceiver in Kotlin

**Files:**
- Modify: `android/app/src/main/kotlin/com/dhanuk/refundradar/MainActivity.kt`

- [ ] **Step 3: Read current MainActivity.kt**

Read `android/app/src/main/kotlin/com/dhanuk/refundradar/MainActivity.kt`. Currently registers MethodChannel `refund_radar/sms_inbox` with `queryInbox` method using `Telephony.Sms.Inbox`.

- [ ] **Step 4: Add BroadcastReceiver for SMS_RECEIVED**

Add a `SmsReceiver` class that extends `BroadcastReceiver`:
```kotlin
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import io.flutter.plugin.common.MethodChannel

class SmsReceiver(
    private val channel: MethodChannel,
    private val isListening: () -> Boolean,
) : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (!isListening()) return
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        for (sms in messages) {
            val sender = sms.displayOriginatingAddress ?: ""
            val body = sms.messageBody ?: ""
            val timestamp = System.currentTimeMillis()

            // Send to Flutter via event channel
            channel.invokeMethod(
                "onSmsReceived",
                mapOf(
                    "sender" to sender,
                    "body" to body,
                    "timestamp" to timestamp,
                ),
                null,
            )
        }
    }
}
```

- [ ] **Step 5: Register receiver in MainActivity**

In `MainActivity.kt`, in `configureFlutterEngine`:
```kotlin
// Register SMS receiver
var listening = true
val smsReceiver = SmsReceiver(
    channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "refund_radar/sms_events"),
    isListening = { listening },
)

// Register dynamically
val filter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
registerReceiver(smsReceiver, filter)

// Unregister on destroy
override fun onDestroy() {
    listening = false
    unregisterReceiver(smsReceiver)
    super.onDestroy()
}
```

Note: For API 33+, the receiver must be registered with `RECEIVER_NOT_EXPORTED` flag. Add:
```kotlin
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
    registerReceiver(smsReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
} else {
    registerReceiver(smsReceiver, filter)
}
```

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml android/app/src/main/kotlin/com/dhanuk/refundradar/MainActivity.kt
git commit -m "feat(android): add RECEIVE_SMS BroadcastReceiver for live UTR detection

Register SmsReceiver for SMS_RECEIVED_ACTION, parse incoming SMS, and
forward to Flutter via MethodChannel. Receive_SMS permission declared in
AndroidManifest. API 33+ uses RECEIVER_NOT_EXPORTED flag."
```

### Task C3: Fix UTR parser regex

**Files:**
- Modify: `lib/services/sms_parser.dart:10`

- [ ] **Step 7: Expand regex to 12-22 digits**

Read `lib/services/sms_parser.dart` line 10. Change:
```dart
// OLD:
static final _utrRegex = RegExp(r'\b(\d{12})\b');

// NEW:
static final _utrRegex = RegExp(r'\b(\d{12,22})\b');
```

- [ ] **Step 8: Add false-positive filter**

Add a method to exclude Aadhaar-like patterns:
```dart
/// Returns false if the matched number is likely an Aadhaar or
/// non-transaction ID (e.g., appears next to "Aadhaar" keyword,
/// or matches the 4+4+4 Aadhaar format)
static bool _isLikelyTransactionId(String match, String fullSms) {
  // Check if the SMS body mentions Aadhaar near the number
  if (fullSms.toLowerCase().contains('aadhaar')) return false;
  // Check if number is exactly 12 digits AND appears in Aadhaar context
  // (4-digit + space + 4-digit + space + 4-digit format)
  if (match.length == 12 && RegExp(r'\d{4}\s?\d{4}\s?\d{4}').hasMatch(fullSms)) {
    // Could be Aadhaar — only accept if also near UPI/Utr keywords
    final lower = fullSms.toLowerCase();
    if (!lower.contains('utr') && !lower.contains('rrn') &&
        !lower.contains('ref') && !lower.contains('txn')) {
      return false;
    }
  }
  return true;
}
```

Update `parse()` to use the filter:
```dart
// After regex match, verify it's a transaction ID
if (utr != null && !_isLikelyTransactionId(utr!, body)) {
  utr = null;
}
```

- [ ] **Step 9: Commit**

```bash
git add lib/services/sms_parser.dart
git commit -m "fix(parser): expand UTR regex to 12-22 digits + filter Aadhaar false positives

UPI UTRs are 12 digits but IMPS/FASTag RRNs can be 15-22. Added false-
positive filter to exclude Aadhaar-like numbers when no UTR/RRN/txn
keyword is present."
```

### Task C4: Create UtrDetection model + provider

**Files:**
- Create: `lib/data/models/utr_detection.dart`
- Create: `lib/core/providers/utr_detection_provider.dart`
- Modify: `lib/services/sms_inbox_service.dart`

- [ ] **Step 10: Create UtrDetection model**

Create `lib/data/models/utr_detection.dart`:
```dart
class UtrDetection {
  final String utr;
  final double? amount;
  final DateTime? date;
  final String sender;
  final String smsBody;
  final bool claimed;
  final DateTime detectedAt;

  const UtrDetection({
    required this.utr,
    this.amount,
    this.date,
    required this.sender,
    required this.smsBody,
    this.claimed = false,
    required this.detectedAt,
  });

  Map<String, dynamic> toJson() => {
    'utr': utr,
    'amount': amount,
    'date': date?.toIso8601String(),
    'sender': sender,
    'smsBody': smsBody,
    'claimed': claimed,
    'detectedAt': detectedAt.toIso8601String(),
  };

  factory UtrDetection.fromJson(Map<String, dynamic> json) => UtrDetection(
    utr: json['utr'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble(),
    date: json['date'] != null ? DateTime.tryParse(json['date'] as String) : null,
    sender: json['sender'] as String? ?? '',
    smsBody: json['smsBody'] as String? ?? '',
    claimed: json['claimed'] as bool? ?? false,
    detectedAt: DateTime.tryParse(json['detectedAt'] as String? ?? '') ?? DateTime.now(),
  );

  UtrDetection copyWith({bool? claimed}) => UtrDetection(
    utr: utr,
    amount: amount,
    date: date,
    sender: sender,
    smsBody: smsBody,
    claimed: claimed ?? this.claimed,
    detectedAt: detectedAt,
  );
}
```

- [ ] **Step 11: Create UtrDetectionProvider**

Create `lib/core/providers/utr_detection_provider.dart`:
```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../data/models/utr_detection.dart';
import '../services/sms_parser.dart';

/// Listens to the MethodChannel `refund_radar/sms_events` for incoming SMS,
/// parses each with SmsParser, and emits UtrDetection events for bank-like
/// messages that contain a UTR.
final utrDetectionProvider = StreamProvider<UtrDetection>((ref) async* {
  // For testing on non-Android platforms, yield nothing
  if (defaultTargetPlatform != TargetPlatform.android) {
    return;
  }

  final controller = StreamController<UtrDetection>.broadcast();
  const channel = MethodChannel('refund_radar/sms_events');

  channel.setMethodCallHandler((call) async {
    if (call.method == 'onSmsReceived') {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final sender = args['sender'] as String? ?? '';
      final body = args['body'] as String? ?? '';
      final timestamp = args['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;

      // Parse the SMS
      final parsed = SmsParser.parse(body);
      if (parsed.utr != null) {
        controller.add(UtrDetection(
          utr: parsed.utr!,
          amount: parsed.amount,
          date: parsed.date,
          sender: sender,
          smsBody: body,
          detectedAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
        ));
      }
    }
  });

  yield* controller.stream;
});
```

- [ ] **Step 12: Commit**

```bash
git add lib/data/models/utr_detection.dart lib/core/providers/utr_detection_provider.dart lib/services/sms_parser.dart
git commit -m "feat(detection): UtrDetection model + StreamProvider for live SMS

UtrDetection model: utr, amount, date, sender, smsBody, claimed, detectedAt.
UtrDetectionProvider listens to MethodChannel 'refund_radar/sms_events'
from Kotlin SmsReceiver, parses each SMS with SmsParser, and emits
UtrDetection events for bank-like messages containing a UTR."
```

### Task C5: Add notification on UTR detection

**Files:**
- Modify: `lib/services/notification_service.dart`

- [ ] **Step 13: Add showUtrDetectedNotification method**

Add to `lib/services/notification_service.dart`:
```dart
static const _utrDetectedNotificationIdBase = 9100;

Future<void> showUtrDetectedNotification({
  required String utr,
  required double? amount,
  required String sender,
  String? disputeId, // for deep-link routing
}) async {
  final id = utr.hashCode.abs();
  final title = amount != null
      ? 'Transaction detected — ₹${amount.toInt()}'
      : 'Bank transaction detected';
  final body = 'UTR: $utr from $sender. Start a dispute?';

  await _flutterLocalNotifications.show(
    id,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'utr_detection_channel',
        'Transaction detection',
        channelDescription: 'Instant alerts when UTRs are detected in incoming SMS',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    // Deep-link payload: tapping the notification will open the dispute form
    payload: 'utr_detected://utr=$utr&amount=${amount ?? ''}&sender=$sender',
  );
}
```

- [ ] **Step 14: Commit**

```bash
git add lib/services/notification_service.dart
git commit -m "feat(notifications): showUtrDetectedNotification for instant UTR alerts

High-priority notification with amount + UTR + sender. Tapping opens
dispute form with pre-filled fields via payload deep-link."
```

### Task C6: Wire UTR detection to notifications + FCM onMessage

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 15: Add UTR detection stream listener to main.dart**

Read `lib/main.dart`. Find where `FcmReevaluator` is mounted (around line 136). Add a `UtrDetectionListener` widget alongside it:

```dart
// In the app builder, alongside FcmReevaluator:
UtrDetectionListener(),
```

Create `UtrDetectionListener` widget (can be inline in main.dart or a separate file):
```dart
class UtrDetectionListener extends ConsumerStatefulWidget {
  @override
  ConsumerState<UtrDetectionListener> createState() => _UtrDetectionListenerState();
}

class _UtrDetectionListenerState extends ConsumerState<UtrDetectionListener> {
  @override
  void initState() {
    super.initState();
    // Listen to UTR detections, show notification for each
    ref.read(utrDetectionProvider).whenData((detectionStream) {
      // This is a StreamProvider, so we watch it
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(utrDetectionProvider).whenData((detection) {
      // Show notification for each detected UTR
      final notifService = NotificationService();
      notifService.showUtrDetectedNotification(
        utr: detection.utr,
        amount: detection.amount,
        sender: detection.sender,
      );
    });
    return const SizedBox.shrink();
  }
}
```

Actually, since `utrDetectionProvider` is a `StreamProvider`, `ref.watch` will emit multiple values. Use `ref.listen` instead:
```dart
@override
void initState() {
  super.initState();
  // Schedule after first frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.listen<AsyncValue<UtrDetection>>(utrDetectionProvider, (previous, next) {
      next.whenData((detection) {
        NotificationService().showUtrDetectedNotification(
          utr: detection.utr,
          amount: detection.amount,
          sender: detection.sender,
        );
      });
    });
  });
}
```

- [ ] **Step 16: Add FCM onMessage handler**

Add to `lib/main.dart` in the app initialization:
```dart
// FCM foreground message handler
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  // Handle foreground push notifications
  // For now, just show a local notification
  final notification = message.notification;
  if (notification != null) {
    NotificationService().showSimpleNotification(
      title: notification.title ?? '',
      body: notification.body ?? '',
    );
  }
});
```

Add `showSimpleNotification` to NotificationService if it doesn't exist.

- [ ] **Step 17: Commit**

```bash
git add lib/main.dart lib/services/notification_service.dart
git commit -m "feat(main): UTR detection listener + FCM onMessage handler

UtrDetectionListener watches utrDetectionProvider and fires instant
notification on each detection. FCM onMessage handler routes foreground
pushes to local notifications."
```

### Task C7: Deep-link routing from notification tap

**Files:**
- Modify: `lib/main.dart` — notification tap handler
- Modify: `lib/features/dispute_create/dispute_form_page.dart` — accept pre-filled UTR

- [ ] **Step 18: Handle notification tap in main.dart**

In the app initialization, add notification tap handler:
```dart
// Handle notification tap (app in foreground/background)
_flutterLocalNotifications.initialize(
  initializationSettings,
  onDidReceiveNotificationResponse: (response) {
    final payload = response.payload;
    if (payload != null && payload.startsWith('utr_detected://')) {
      // Parse payload: utr_detected://utr=XXX&amount=YYY&sender=ZZZ
      final params = Uri.parse(payload.replaceFirst('utr_detected://', ''));
      final utr = params.queryParameters['utr'] ?? '';
      final amount = double.tryParse(params.queryParameters['amount'] ?? '');
      final sender = params.queryParameters['sender'] ?? '';
      // Navigate to dispute form with pre-filled data
      appRouter.go('/dispute/create?utr=$utr&amount=$amount&sender=$sender');
    }
  },
);
```

- [ ] **Step 19: Accept pre-filled UTR in DisputeFormPage**

Read `lib/features/dispute_create/dispute_form_page.dart`. In `initState`, read the query parameters if present:
```dart
@override
void initState() {
  super.initState();
  // Check for pre-filled UTR from notification deep-link
  final query = WidgetsBinding.instance.window.defaultRouteName;
  // Or use the widget's params if passed via router
  if (widget.prefilledUtr != null) {
    _utrCtrl.text = widget.prefilledUtr!;
    _utrFound = true;
  }
  if (widget.prefilledAmount != null) {
    _amountCtrl.text = widget.prefilledAmount!.toStringAsFixed(0);
  }
}
```

Define `prefilledUtr` and `prefilledAmount` as optional params on the `DisputeFormPage` widget. Update the router to parse them from the URL.

- [ ] **Step 20: Commit**

```bash
git add lib/main.dart lib/features/dispute_create/dispute_form_page.dart lib/core/router/app_router.dart
git commit -m "feat(routing): notification tap → dispute form with pre-filled UTR

Notification payload contains utr/amount/sender. Tapping opens dispute
form with fields pre-filled. Router parses query params."
```

### Task C8: Detected transactions section on Home

**Files:**
- Modify: `lib/features/home/home_page.dart`

- [ ] **Step 21: Add detected UTRs section on home page**

In `home_page.dart`, add a "Detected transactions" section that watches `utrDetectionProvider` and shows unclaimed detections:
```dart
// In the _Body widget, before the disputes list:
ref.watch(utrDetectionProvider).whenData((detections) {
  // Show detected transactions banner
  if (detections.isNotEmpty && !detections.claimed) {
    return DetectedTransactionsBanner(
      utr: detections.utr,
      amount: detections.amount,
      sender: detections.sender,
      onTap: () => context.push('/dispute/create?utr=${detections.utr}...'),
    );
  }
});
```

Note: Since `utrDetectionProvider` is a `StreamProvider`, we need to handle it carefully. Use `ref.watch(utrDetectionProvider.last)` to get the latest detection, or maintain a list of detections in a `StateProvider`.

Consider a simpler approach: a `utrDetectionsProvider` (StateProvider<List<UtrDetection>>) that accumulates detections.

- [ ] **Step 22: Commit**

```bash
git add lib/features/home/home_page.dart
git commit -m "feat(home): detected transactions section for unclaimed UTRs

Shows a banner card when UTRs are auto-detected but not yet claimed.
Tapping the card opens dispute form with pre-filled data."
```

### Task C9: Update SMS permission screen

**Files:**
- Modify: `lib/features/sms_permission/sms_permission_page.dart`

- [ ] **Step 23: Request RECEIVE_SMS alongside READ_SMS**

Read `lib/features/sms_permission/sms_permission_page.dart`. Find where `Permission.sms.request()` is called (around line 367-388). This already requests the `sms` permission group which includes both `READ_SMS` and `RECEIVE_SMS` on Android. But update the UI text to mention auto-detection:

Update the permission description text:
- `app_localizations.dart`: `'smsPermissionDescription': 'RefundRadar reads your SMS inbox to auto-detect transaction references (UTR) and sends you instant notifications to claim or dispute your money. We never upload your SMS content — all detection happens on your device.'`
- `app_en.arb`: same text
- `app_hi.arb`: Hindi translation

- [ ] **Step 24: Commit + Push**

```bash
git add lib/features/sms_permission/sms_permission_page.dart lib/l10n/app_localizations.dart lib/l10n/app_en.arb lib/l10n/app_hi.arb
git commit -m "feat(sms-permission): update permission text for auto-detection

Permission description now mentions instant notifications for UTR
detection. RECEIVE_SMS is part of the sms permission group."
git push origin main
```

---
