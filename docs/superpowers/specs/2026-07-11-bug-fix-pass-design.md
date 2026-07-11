# Comprehensive Bug-Fix & UX Improvement Pass — Design Spec

**Date:** 2026-07-11
**Author:** Brainstorming session with user
**Status:** Approved (all 7 sections)
**Scope:** 9 user-reported issues grouped into 7 tracks (A-G)

---

## Track A: Home Screen Total Amount Shows Zero

### Problem
The hero counter on `home_page.dart:182` displays `CompensationCalculator.compute(d).compensationDue` — the accrued RBI penalty compensation. This is ₹0 for every newly created dispute because the bank's turnaround time (T+1/T+5) hasn't elapsed. The user sees "₹0" even with active disputes listed below.

### Root Cause
- `lib/features/home/home_page.dart:182-183`: `totalOwed = fold(0, (sum, d) => sum + CompensationCalculator.compute(d).compensationDue)`
- `lib/services/compensation_calculator.dart:22-45`: returns `compensationDue: 0` when `tatDays == null` (fastag/bankCharge/wrongTransfer) OR when `today < txnDate + tatDays` (deadline hasn't passed)
- The `amount` field is correctly stored as `double` and correctly parsed — the data layer is sound

### Fix
Change `totalOwed` to show **combined: disputed amount + accrued penalty**:
```dart
final totalOwed = disputes.fold<double>(0, (sum, d) =>
  sum + d.amount + CompensationCalculator.compute(d).compensationDue);
```
- Hero shows big number = "Total claimable"
- Subtitle breakdown: "₹{disputedSum} disputed · ₹{penaltySum} penalty accrued"
- Daily-growth pill (₹/day) stays — shows potential per-day penalty growth
- If all disputes pre-deadline: shows ₹{disputedSum} with subtitle "₹0 penalty accrued (TAT pending)"

### Files Changed
- `lib/features/home/home_page.dart` — `totalOwed` calculation, subtitle breakdown
- `lib/shared/widgets/owed_counter_card.dart` — add subtitle breakdown parameter

---

## Track B: Escalation Step Screen Full Redesign

### Problem
The escalate page (`escalate_page.dart`) feels flat, static, unaligned, not scrollable. Issues found:
- Hero card radius (14px) mismatches cards (16px `AppRadii.lg`)
- Hero has no shadow while all other cards use `AppShadows.card` — hero looks flat
- `Column(header, Expanded(ListView), footer)` — only middle band scrolls; on short content nothing scrolls
- Duplicated `_RecipientRow` widget for CC Ombudsman row (inline hand-rolled)
- No entrance animations
- Footp padding doesn't include `MediaQuery.paddingOf(context).bottom`
- Eyebrow labels differ in style between hero and cards

### Redesign

1. **Scrollable layout** — `CustomScrollView` with `SliverAppBar` (header collapses on scroll). Content as `SliverList` with `SliverToBoxAdapter` per card. Footer stays as bottom bar with safe-area padding.

2. **Visual consistency:**
   - Hero radius: 14 → `AppRadii.lg` (16)
   - Add `AppShadows.card` to hero
   - Unify eyebrow label: use `tc.textSecondary` for all (hero + cards)
   - Reuse `_RecipientRow` for CC Ombudsman row instead of inline duplicate

3. **Hero card redesign:**
   - Show disputed amount + max penalty breakdown
   - TAT status indicator: "T+5 deadline in 3 days" or "⚠ T+5 missed"

4. **Entrance animations** — staggered `FadeTransition` + `SlideTransition`:
   - 80ms stagger between hero, SEND TO, EMAIL PREVIEW cards
   - `Curves.easeOutCubic` with 300ms duration

5. **Template picker section** — Dedicated "TEMPLATE" card between SEND TO and EMAIL PREVIEW:
   - Shows currently selected template name + category badge
   - Pencil button to open picker (existing)
   - Free vs Pro tabs in bottom sheet

6. **Post-send upsell** — Success dialog after "Send escalation →":
   - "Escalation sent!" + "What's next?" section
   - "Level 3: Ombudsman notice" preview (locked for free)
   - CTA: "Unlock Ombudsman templates →" → paywall (free) or direct nav (premium)

7. **Footer safe area** — Add `MediaQuery.paddingOf(context).bottom` to footer padding.

### Files Changed
- `lib/features/escalate/escalate_page.dart` — full redesign
- `lib/shared/widgets/owed_counter_card.dart` — subtitle support

---

## Track C: UTR Auto-Detect from SMS with Instant Notifications

### Problem
No real-time SMS detection exists. Current flow is manual: user taps "Inbox" → app reads existing inbox → user picks an SMS → regex extracts UTR. No `RECEIVE_SMS` permission, no BroadcastReceiver, no background detection, no instant notifications.

### Fix

1. **Add `RECEIVE_SMS` permission** to `AndroidManifest.xml`. Update `sms_permission_page.dart` to request both `READ_SMS` + `RECEIVE_SMS`.

2. **Create `SmsReceiverService`** (Kotlin BroadcastReceiver in `MainActivity.kt`):
   - Register `android.provider.Telephony.SMS_RECEIVED` receiver
   - On receive: parse sender + body, check if bank-like (reuse `SmsParser` heuristics)
   - If UTR/amount detected: send to Flutter via `MethodChannel` event channel

3. **Create `UtrDetectionProvider`** (Riverpod `StreamProvider`):
   - Listens to MethodChannel events from BroadcastReceiver
   - Parses SMS with `SmsParser.parse()` (with fixed regex)
   - Emits `UtrDetection` events: `{utr, amount, date, sender, smsBody, claimed: false}`

4. **Instant local notification** on detection:
   - Title: "Transaction detected — ₹{amount}"
   - Body: "UTR: {utr} from {sender}. Start a dispute?"
   - Tapping notification → deep-link to `DisputeFormPage` with pre-filled `txnId`, `amount`, `txnDate`
   - Use `flutter_local_notifications` with a dedicated channel

5. **`FirebaseMessaging.onMessage` handler** — add foreground push handler in `main.dart` for future server-side detection prompts.

6. **Fix UTR parser regex** — `lib/services/sms_parser.dart:10`:
   - Current: `\b(\d{12})\b` — only matches exactly 12 digits
   - New: `\b(\d{12,22})\b` — captures IMPS/FASTag RRNs too
   - Add false-positive filter: exclude Aadhaar patterns (4-digit + 4-digit + 4-digit), exclude numbers that appear after "Aadhaar" keyword

7. **"Detected transactions" inbox on Home** — lightweight section showing unclaimed detected UTRs (dismissed notifications aren't lost).

### Files Changed
- `android/app/src/main/AndroidManifest.xml` — add `RECEIVE_SMS` permission
- `android/app/src/main/kotlin/com/dhanuk/refundradar/MainActivity.kt` — BroadcastReceiver + event channel
- `lib/services/sms_parser.dart` — fix regex
- `lib/services/sms_inbox_service.dart` — add live SMS stream
- `lib/core/providers/utr_detection_provider.dart` — new `StreamProvider`
- `lib/services/notification_service.dart` — add `showUtrDetectedNotification()`
- `lib/main.dart` — add `FirebaseMessaging.onMessage` handler + UTR detection stream init
- `lib/features/home/home_page.dart` — detected transactions section
- `lib/features/sms_permission/sms_permission_page.dart` — request `RECEIVE_SMS`
- `lib/features/dispute_create/dispute_form_page.dart` — accept pre-filled UTR from notification deep-link
- `lib/data/models/utr_detection.dart` — new model

---

## Track D: Bank Dropdown — All 55 Banks with Search

### Problem
The dispute form's bank picker only shows `(onboarding-picked banks ∪ kFallbackBanks)`. `kFallbackBanks` has 5 entries. If user didn't pick banks during onboarding, only 4-5 banks appear.

### Fix
- Replace `_pickBank` method: show all `BankCatalog.banks` (55 entries) instead of `mergeOnboardBanksWithFallback`
- Add search `TextField` at top of bottom sheet — filters by `name` or `short` (case-insensitive)
- Onboarding-picked banks at top under "Your banks" section header
- Remaining banks under "All banks" section
- "Other bank" always at bottom
- FASTag still uses `rules.fastagIssuers` (unchanged)

### Files Changed
- `lib/features/dispute_create/dispute_form_page.dart` — `_pickBank` + `_showBankPicker` redesign
- `lib/data/constants/bank_catalog.dart` — no changes (already has 55 banks)

---

## Track E: Settings — Daily Comp + Weekly Digest Functional

### Problem
Both are stub toggles with `onChanged: null`, labeled "Coming soon". Providers exist (`notifDailyProvider`, `notifWeeklyProvider`) but UI never calls them. No scheduler exists.

### Fix

1. **Wire toggles** — connect "Daily comp clock" to `setNotifDaily()`, "Weekly digest" to `setNotifWeekly()`. Remove "(Coming soon)" labels.

2. **`DailyCompScheduler`** — schedules daily `flutter_local_notifications` at 9 AM (user-configurable time):
   - Queries all active disputes, computes `compensationDue` for each
   - If any accrued > 0 today: "₹{X} penalty accrued today across {N} disputes"
   - If none: suppress notification (don't spam)
   - Respects `notifDailyProvider` toggle (cancel if off)

3. **`WeeklyDigestScheduler`** — schedules weekly notification (Sunday 9 AM):
   - Summary: disputes filed this week, escalations sent, penalties accrued, resolved count
   - Respects `notifWeeklyProvider` toggle

### Files Changed
- `lib/features/settings/settings_page.dart` — wire toggles, remove "Coming soon"
- `lib/services/notification_service.dart` — add `scheduleDailyComp()`, `scheduleWeeklyDigest()`
- `lib/core/providers/app_state_provider.dart` — no changes (providers already exist)
- `lib/services/daily_comp_scheduler.dart` — new file
- `lib/services/weekly_digest_scheduler.dart` — new file
- `lib/main.dart` — init schedulers on app start

---

## Track F: Template Monetization — Four Fixes

### Problem
1. Auto-matched templates bypass premium gating (free users get premium bodies)
2. Template picker lacks Free vs Pro grouping
3. No template picker on dispute detail screen
4. No post-escalation upsell to Ombudsman-level templates

### Fixes

1. **Fix auto-match leak** — In `_matchEscalationTemplate` (`escalate_page.dart:644-658`):
   - Filter to unlocked templates only: `!repo.isLocked(t, freeIds, isPremiumUser: isPremiumUser)`
   - Fallback to first free template in category if no unlocked match
   - If no free template in category either, show empty state with paywall CTA

2. **Free vs Pro tabs in picker** — Redesign `_showTemplatePicker` bottom sheet:
   - TabBar: "Free ({count})" | "Pro ({count})"
   - Free tab: all unlocked templates (free + allowlist), sorted by relevance
   - Pro tab: locked templates with blur preview of first 2 sentences + "Unlock to use" CTA
   - Selected template highlighted in both tabs
   - Locked template tap → paywall (existing behavior, keep)

3. **Template picker on dispute detail screen** — Add template section on `DisputeDetailPage`:
   - Shows L1/L2 template used (if any) with name
   - Pencil icon to pick/change template
   - Gate locked templates → paywall
   - Syncs with escalate page's `selectedTemplateId`

4. **Post-escalation upsell CTA** — After "Send escalation →" success:
   - Success dialog: "Escalation sent!" + "What's next?"
   - "Level 3: Ombudsman notice" preview (locked for free users)
   - CTA: "Unlock Ombudsman templates →" → paywall (free) or direct nav (premium)

### Files Changed
- `lib/features/escalate/escalate_page.dart` — fix auto-match, Free/Pro tabs, post-send upsell
- `lib/features/dispute_detail/dispute_detail_page.dart` — add template picker section
- `lib/data/repositories/template_repository.dart` — no changes needed (`isLocked` already works)

---

## Track G: Activity Log — Expanded Event Types

### Problem
Only 4 hardcoded event types computed from dispute fields: resolved, L1 ticket filed, auto-detected UTR, marked active. No escalation-sent, template-used, reminder-fired, or status-changed events.

### Fix

1. **Add `activityLog` field to `Dispute` model** — `List<ActivityLogEntry>` stored in Firestore.

2. **`ActivityLogEntry` model:**
   ```dart
   class ActivityLogEntry {
     final String type;      // dispute_created, l1_ticket_filed, etc.
     final String label;     // localized display label
     final String meta;      // timestamp / meta text
     final DateTime timestamp;
     final bool highlighted;
   }
   ```

3. **Event types:**
   - `dispute_created` — written on form submit
   - `l1_ticket_filed` — written when L1 ticket registered
   - `l2_ticket_filed` — written when L2 ticket registered
   - `escalation_email_sent` — written on escalate send
   - `template_used` — written when template selected
   - `status_changed` — written on status transition
   - `reminder_fired` — written when deadline reminder fires
   - `resolved` — written on resolve toggle
   - `utr_detected` — written when UTR auto-detected

4. **Write events at action points:**
   - `DisputeFormPage` submit → `dispute_created`
   - Escalate page send → `escalation_email_sent` + `template_used`
   - Detail page resolve toggle → `resolved` / `status_changed`
   - Reminder notification fired → `reminder_fired`

5. **Activity log widget** renders chronologically with icons per type.

6. **Migration** — existing disputes get synthetic `dispute_created` event from `createdAt`.

### Files Changed
- `lib/data/models/dispute.dart` — add `activityLog` field
- `lib/data/models/activity_log_entry.dart` — new model
- `lib/data/repositories/firestore_dispute_repository.dart` — persist `activityLog`
- `lib/features/dispute_create/dispute_form_page.dart` — write `dispute_created`
- `lib/features/escalate/escalate_page.dart` — write `escalation_email_sent` + `template_used`
- `lib/features/dispute_detail/dispute_detail_page.dart` — write `resolved` / `status_changed`
- `lib/services/notification_service.dart` — write `reminder_fired`
- `lib/shared/widgets/activity_log.dart` — render expanded types with icons

---

## Implementation Strategy

This spec will be implemented using 10+ parallel subagents, each handling an independent track:

| Subagent | Track | Scope |
|----------|-------|-------|
| 1 | A | Home screen total amount fix |
| 2 | B | Escalate page redesign (layout, animations, consistency) |
| 3 | B | Escalate page template picker section + Free/Pro tabs |
| 4 | B | Escalate page post-send upsell dialog |
| 5 | C | Kotlin BroadcastReceiver + MethodChannel |
| 6 | C | Dart UTR detection provider + notification + parser fix |
| 7 | C | Home detected-transactions section + deep-link route |
| 8 | D | Bank dropdown all-55-with-search |
| 9 | E | Settings daily comp + weekly digest functional |
| 10 | F | Dispute detail template picker + auto-match fix |
| 11 | G | Activity log expanded event types + model + persistence |

Dependencies:
- Track A is independent (can start immediately)
- Track B subagents 2→3→4 have minor sequential dependency (layout first, then template section, then upsell)
- Track C subagents 5→6→7 have sequential dependency (Kotlin first, then Dart provider, then UI)
- Track D is independent
- Track E is independent
- Track F depends on Track B's template picker design
- Track G is independent but touches many files (coordinate carefully)

### Critical Constraint: NO LOCAL DEBUG/BUILD/TEST
- **No subagent shall run `flutter run`, `flutter build`, `flutter analyze`, or `flutter test` locally.**
- **No local debugging or building on the machine.**
- All verification (analyze + test + build) happens via **GitHub Actions CI** only.
- Subagents write code, commit, and push. CI runs the quality gate.
- If CI fails, the orchestrator reads the CI error log and dispatches a fix subagent.
- Do NOT attempt to install SDKs, run gradle, or boot an emulator locally.

### CI Workflow
The repository has a `Build Release` GitHub Actions workflow (`.github/workflows/`) triggered on push:
1. **Analyze + Test job** — runs `flutter analyze` + `flutter test` (quality gate)
2. **Release AAB (Play Store) job** — builds signed AAB (tag-triggered only)
3. **Release APK (sideload) job** — builds signed APK (tag-triggered only)

The orchestrator monitors CI after each push. If `Analyze + Test` fails:
- Read the failing test/analyze output via `gh run view --log-failed`
- Dispatch a targeted fix subagent with the exact error message
- Re-push and re-monitor until green

Only tag a release (`git tag vX.Y.Z`) after CI is fully green on `main`.

Verification:
- `flutter analyze` must be clean (verified via CI, not locally)
- `flutter test` must pass all existing tests + new tests for each track (verified via CI)
- Each subagent must ensure its code compiles and follows existing patterns before committing
- No subagent runs any Flutter/Dart/Gradle command locally — period
