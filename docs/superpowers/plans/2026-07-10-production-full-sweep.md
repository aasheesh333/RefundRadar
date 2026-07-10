# Production Full Sweep Implementation Plan

> Use subagent-driven-development. Tasks in Phase 1 land first. Phases 2-5 parallelize per the disjoint-files rule. Commit per phase.

**Spec:** `docs/superpowers/specs/2026-07-10-production-full-sweep-design.md`

## Global Constraints

- Do not change brand hex in `AppColors`.
- `flutter analyze` must end 0 issues; `flutter test` green per phase where touched.
- Prefer `AppThemeColors.of(context)` over bare `AppColors.*Soft` / `Colors.grey`.
- i18n: add keys to both `app_en.arb` and `app_hi.arb`, wire `app_localizations.dart` (hand-synced map).
- No comments unless existing file style requires them.
- Android-first; no iOS.
- One filed-date vocabulary: `l1` | `l2` | `ombudsman`.

---

## Phase 1 — Reminder & create integrity (BLOCKERS — land first)

### Task 1.1 — Align filed-date keys (wizard -> `ombudsman`)
**Files:** `lib/features/wizard/wizard_page.dart`, `lib/data/repositories/reminder_generator.dart`, `test/reminder_generator_test.dart`
- [ ] Change `_ticketKeyForLevel(int level)` so `level >= 2` returns `'ombudsman'` (not `'l3'`).
- [ ] In `ReminderGenerator.forDispute`, keep reading `d.filedDates['ombudsman']` as primary; ALSO read `d.filedDates['l3']` as legacy fallback (off-the-record migration) so existing Firestore docs still schedule ombudsman follow-ups.
- [ ] Add tests: wizard-shaped `filedDates={'ombudsman': ...}` schedules ombudsman follow-up; legacy `filedDates={'l3': ...}` ALSO schedules it.
- [ ] `dart analyze lib/features/wizard lib/data/repositories/reminder_generator.dart test/reminder_generator_test.dart` clean.

### Task 1.2 — Unique notification IDs per reminder stage
**Files:** `lib/services/notification_service.dart`, `lib/data/repositories/reminder_repository.dart`
- [ ] `scheduleDeadlineReminder` gains `required String reminderId`; `id = reminderId.hashCode & 0x7FFFFFFF`.
- [ ] Add `cancelForReminder(String reminderId)` and `cancelForDispute(List<String> reminderIds)` (cancel by ids rather than disputeId-hash).
- [ ] `syncRemindersForDispute` (in `reminder_repository.dart`) builds the desired reminder set, cancels the OLD ids (or cancels all for that dispute by querying known ids), schedules each with its own id.
- [ ] `deleteRemindersForDispute`: after `repo.deleteForDispute`, cancel notifications for the known reminder ids (or `cancelAll` is acceptable only if we accept wiping unrelated scheduled ones — prefer per-id).
- [ ] `dart analyze` clean.

### Task 1.3 — Stop dispute rollback on post-save failure
**Files:** `lib/features/dispute_create/dispute_form_page.dart`
- [ ] Remove the `rollbackNeeded`/`deleteDispute` path in `_save`. Keep the dispute committed even if reminders/analytics throw.
- [ ] On reminders failure: show a soft SnackBar ("Saved. Reminders will sync when online.") but STILL navigate to `/home` (don't treat as full failure).
- [ ] Keep error SnackBar only for the `saveDispute` itself failing (auth/offline). Side-effects are non-fatal.
- [ ] `dart analyze` clean.

### Task 1.4 — Set local timezone
**Files:** `lib/services/notification_service.dart`, `pubspec.yaml` (optional)
- [ ] After `tz.initializeTimeZones()`, detect device timezone. Prefer `flutter_timezone` (add dep) for the real IANA name; if absent on the platform, fallback to `tz.local` the already-named local OR `Asia/Kolkata`.
- [ ] Call `tz.setLocalLocation(tz.getLocation(detected))` inside `init()`.
- [ ] Guard with try/catch (unknown tz name) -> fallback.
- [ ] `dart analyze` clean.

---

## Phase 2 — Resolve, home, history (parallel with 3/4/5 on disjoint files)

### Task 2.1 — Resolve sets amount + copyWith clear resolvedAt + reopen to highest
**Files:** `lib/data/models/dispute.dart`, `lib/features/dispute_detail/dispute_detail_page.dart`, `test/dispute_model_test.dart`
- [ ] Add `Object? resolvedAt = _sentinel` pattern (or `clearResolvedAt` bool flag) to `copyWith` so passing `null` actually clears the field.
- [ ] Mark resolved: set `resolvedAmount: dispute.amount` (min-viable; optional dialog later).
- [ ] Reopen (Resolved -> previous): derive target status from `filedDates` keys present (ombudsman > l2 > l1 > draft); clear `resolvedAt`.
- [ ] Tests: copyWith `resolvedAt: null` clears; reopen path picks highest filed.
- [ ] `dart analyze` + `flutter test test/dispute_model_test.dart` clean.

### Task 2.2 — Home non-terminal only
**Files:** `lib/features/home/home_page.dart`
- [ ] Filter the active disputes list to exclude `DisputeStatus.resolved` and `DisputeStatus.expired`.
- [ ] Counter text reflects filtered count.
- [ ] Keep History as the full archive surface (no change there).
- [ ] `dart analyze` clean.

### Task 2.3 — History Escalated filter logic
**Files:** `lib/features/history/history_page.dart`
- [ ] Escalated filter: `(status == ombudsman || status == filedL2) || (past && filedDates contains 'ombudsman' or 'l2')`.
- [ ] Verify pills still total; Escalated not always empty.
- [ ] `dart analyze` clean.

---

## Phase 3 — Platform & monetization (parallel)

### Task 3.1 — AndroidManifest queries for mailto/tel/https
**Files:** `android/app/src/main/AndroidManifest.xml`, `lib/core/utils/url_launcher_helper.dart`
- [ ] Add `<queries>` for `<intent> <action android:name="android.intent.action.SENDTO"/> <data android:scheme="mailto"/>`, plus `tel:`, plus `https` BROWSE.
- [ ] `url_launcher_helper.dart`: if `canLaunchUrl` returns false but we have a mailto URL, still attempt `launchUrl` (the visibility gate is overly strict on some OEMs).
- [ ] `dart analyze` clean (no Dart change beyond the guard relaxation).

### Task 3.2 — Ombudsman premium gate in page
**Files:** `lib/features/ombudsman/ombudsman_letter_page.dart`
- [ ] Read `isPremiumProvider`; if `false`, redirect to `/paywall?return=/disputes/{id}&trigger=ombudsman_letter` and return a sized box.
- [ ] This is defense-in-depth alongside the existing detail-page button gate.
- [ ] `dart analyze` clean.

### Task 3.3 — RevenueCat logIn(firebaseUid)
**Files:** `lib/services/revenue_cat_service.dart`, `lib/main.dart` (auth wiring)
- [ ] After anonymous auth resolves, call `Purchases.logIn(uid)` (ignore `alreadySignedIn` error via try/catch).
- [ ] On reauth (new uid), `Purchases.logIn(newUid)` (RC handles transfer).
- [ ] `dart analyze` clean.

### Task 3.4 — FCM reeval fires on cold start
**Files:** `lib/core/providers/fcm_reevaluater.dart`
- [ ] On the post-frame when uid becomes non-null (first availability), call `_reeval`. Use `ref.listen(..., fireImmediately: true)` pattern or an explicit initial call gated by `uid != null`.
- [ ] Wrap in try/catch -> Crashlytics breadcrumb.
- [ ] `dart analyze` clean.

### Task 3.5 — Auth error UI on detail/escalate/ombudsman
**Files:** `lib/features/dispute_detail/dispute_detail_page.dart`, `lib/features/escalate/escalate_page.dart`, `lib/features/ombudsman/ombudsman_letter_page.dart`
- [ ] Replace the `userIdProvider.asData?.value` + spinner pattern with `ref.watch(userIdProvider)` + `.when(data:, error:, loading:)`.
- [ ] Error/loading -> `BrandedErrorBanner` with retry (call `ref.invalidate(userIdProvider)`).
- [ ] `dart analyze` clean.

---

## Phase 4 — Product honesty (parallel)

### Task 4.1 — Persist description
**Files:** `lib/data/models/dispute.dart`, `lib/features/dispute_create/dispute_form_page.dart`, `lib/data/repositories/firestore_dispute_repository.dart`, `test/dispute_model_test.dart`
- [ ] Add `final String? description` to `Dispute` (+ copyWith, toJson, fromJson optional).
- [ ] Form save writes `_descCtrl.text.trim()` into the model.
- [ ] Tests: round-trip with description set + null.
- [ ] `dart analyze` + `flutter test test/dispute_model_test.dart` clean.

### Task 4.2 — Template.fill before copy/preview
**Files:** `lib/features/templates/template_library_page.dart`, `lib/features/wizard/wizard_page.dart` (where letters copied)
- [ ] On "Copy" / preview, call `template.fill({...placeholders map...})` using the selected dispute's fields (UTR/amount/date/entity).
- [ ] Fall back to the raw body if no dispute selected.
- [ ] `dart analyze` clean.

### Task 4.3 — Form bank picker uses onboard selection
**Files:** `lib/features/dispute_create/dispute_form_page.dart`, `lib/features/add_banks/add_banks_page.dart`
- [ ] Prefer `AddBanksPage.loadSelectedBanks()` + `BankCatalog`; fallback to `kFallbackBanks` if empty.
- [ ] `dart analyze` clean.

### Task 4.4 — Settings Delete data + honest session refresh
**Files:** `lib/features/settings/settings_page.dart`, `lib/data/repositories/firestore_dispute_repository.dart`
- [ ] "Delete data" opens a confirm dialog -> `deleteAllUserData(uid)` + `deleteAllRemindersAndNotifications(ref, uid)` (already exists) -> success SnackBar -> go `/onboard`.
- [ ] Rename "Session refreshed" copy to honest warning: "Sign out and clear local data?" + persist-after-reauth hint, OR swap to a token-refresh only if feasible.
- [ ] `dart analyze` clean.

### Task 4.5 — Disable/honest placebo toggles
**Files:** `lib/features/settings/settings_page.dart`, `lib/core/providers/app_state_provider.dart`
- [ ] If daily/weekly notification jobs are not scheduled anywhere, DISABLE those toggles with `Switch(value: false, onChanged: null)` + "(Coming soon)" subtitle. Keep deadline toggle functional.
- [ ] `dart analyze` clean.

---

## Phase 5 — UI/UX polish (parallel)

### Task 5.1 — Residual i18n (home empty, cards, SMS, banks)
**Files:** `lib/features/home/home_page.dart`, `lib/shared/widgets/dispute_card.dart`, `lib/shared/widgets/owed_counter_card.dart`, `lib/features/sms_permission/sms_permission_page.dart`, `lib/features/add_banks/add_banks_page.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_hi.arb`, `lib/l10n/app_localizations.dart`
- [ ] Add keys to EN + HI ARBs. Hand-sync the `AppLocalizations` map.
- [ ] Replace hard English Text()s with `AppLocalizations.of(context)?.<key> ?? '<english>'`.
- [ ] `dart analyze` clean.

### Task 5.2 — Residual i18n (snackbars / escalate / settings)
**Files:** `lib/features/dispute_create/dispute_form_page.dart`, `lib/features/wizard/wizard_page.dart`, `lib/features/escalate/escalate_page.dart`, `lib/features/settings/settings_page.dart`, `lib/l10n/*`
- [ ] Add keys + wire snackbars/labels.
- [ ] `dart analyze` clean.

### Task 5.3 — Touch targets (>= 48dp)
**Files:** `lib/shared/widgets/filter_pills.dart`, `lib/shared/widgets/radio_row.dart`
- [ ] `FilterPills`: `SizedBox(height: 48)` wrap or `materialTapTargetSize: MaterialTapTargetSize.padded` + vertical padding.
- [ ] `RadioRow`: `minHeight: 48` via `InkWell` + `SizedBox` or `constraints`.
- [ ] Existing tests in `shared_soft_widgets_test.dart` still green.
- [ ] `dart analyze` clean.

### Task 5.4 — Dark CTA consistency + minor soft/chip/shadow
**Files:** `lib/features/home/home_page.dart` (FAB/empty), `lib/core/theme/app_theme.dart` (chip selectedColor), `lib/core/theme/app_tokens.dart` (AppShadows tint), `lib/core/theme/status_kind_theme.dart` (success soft distinct)
- [ ] Dark home FAB/empty CTAs use theme-accent + dark fg (or document primary as intentional — prefer align).
- [ ] Chip selectedColor -> `AppThemeColors.accentSoft`.
- [ ] AppShadows retint to primary blue or neutral.
- [ ] `StatusKind.success.bgFor` -> dedicated success soft (not accent-soft).
- [ ] `dart analyze` clean.

---

## Phase 6 — Final gate

### Task 6.1 — Full analyze + test + PROGRESS
- [ ] `flutter analyze` -> 0 issues.
- [ ] `flutter test` -> green.
- [ ] Update `PROGRESS.md` with this pass log (tasks done + commit ids).
- [ ] Commit final.

## Merge order

Phase 1 (1.1 -> 1.2 -> 1.3 + 1.4 parallel) -> landing gate (analyze) -> Phases 2+3+4+5 parallel -> Phase 6.
