# RefundRadar Play-Store-Ready & Monetization Redesign

**Date:** 2026-07-15  
**Status:** Pending approval  
**Scope:** Critical bug fixes, UI/UX hardening, dispute lifecycle, and template monetization redesign as a point-of-sale.

---

## 1. Executive Summary

This pass prepares RefundRadar for Play Store submission and turns templates into a true point-of-sale. It fixes all 22 issues uncovered in the pre-release audit, redesigns the free-to-paid template flow to give users a "first win free" in every dispute category, and corrects RevenueCat integration rough edges that could cause price/user-trust issues.

**Deferred out of scope (requires Firebase Blaze/RevenueCat webhook infra):** server-side enforcement of the 1-active-dispute free-tier limit. The existing client-side gate remains unchanged.

---

## 2. 16KB Page-Size Compliance

**Finding:** No action needed. The app is already compliant.

- AGP 9.0.1 / Gradle 9.1.0 / NDK r28.2 — all exceed the AGP ≥ 8.5.1 / NDK ≥ r27 bar.
- No app-owned native code (no `externalNativeBuild`, no `CMakeLists.txt`).
- No plugin ships prebuilt `.so` files directly; native code is only via first-party Google/OneSignal/RevenueCat AARs.
- No packaging overrides (`useLegacyPackaging`, `abiFilters`, etc.).

**Verification at build time (when a build is eventually run):**
- Run `zipalign -c -P 16 -v 4 app-release.apk` on the release artifact.
- Confirm all `.so` entries in the APK Analyzer are 16 KB-aligned.

---

## 3. Bug Fixes — All 22 Audit Findings

### 3.1 Critical

#### CR-1 Escalate "Copy" button leaks Pro template body
- **File:** `lib/features/escalate/escalate_page.dart`
- **Fix:** Gate the Copy action identically to the Send action. If the auto-matched template is locked (`isMatchLocked`), route to the paywall with `trigger=template_locked` instead of copying. Only copy when the template is unlocked or the user is premium.
- **Test:** Free user with a locked auto-matched template taps Copy → paywall route, no clipboard write.

#### CR-2 Disputes never become `expired`
- **File:** `lib/features/home/home_page.dart`, `lib/data/models/dispute.dart`, `lib/data/repositories/firestore_dispute_repository.dart`
- **Rule:** A dispute in a non-terminal status (`filedL1`, `filedL2`, `ombudsman`) is auto-expired when 90 days have elapsed since its **last filing date** or `createdAt` if no filing exists. Drafts are never auto-expired.
- **Implementation:**
  - Add `Dispute.lastActivityDate` getter (max of `filedDates` values or `createdAt`).
  - Add `Dispute.isExpiredByDate(DateTime now)` helper.
  - In `HomePage._Body`, before passing disputes to `activeHomeDisputes`, call a repository method `syncExpiredStatusesIfNeeded(List<Dispute>, String uid)` that:
    - Finds disputes whose last-activity + 90 days < now.
    - For each, writes `status: expired` with an `ActivityLogEntry(type: expired, ...)` via `saveDispute` (to keep merge semantics + retry logic).
    - Deduplicates in-memory so a single session doesn't write the same doc multiple times.
  - The returned list filters out newly-expired disputes so the UI reflects the updated state.
- **Test:** Create a dispute with a filing date 91 days ago; on Home load its status becomes `expired` and it moves out of active.

#### CR-3 Settings "Auto-detect UTR" toggle is fake
- **File:** `lib/features/settings/settings_page.dart`, `lib/main.dart`, new provider `sms_detection_enabled_provider.dart`
- **Fix:**
  - Store a user-controlled `isSmsDetectionEnabled` flag in `SharedPreferences`.
  - Provider returns `false` if permission not granted; otherwise the stored value.
  - Toggle `onChanged`:
    - If turning ON: request `RECEIVE_SMS` permission; on grant → enable receiver; on deny → show explanatory SnackBar.
    - If turning OFF: set provider to false. The Kotlin `SmsReceiver` checks this flag (passed via a Dart method channel or a shared-preference read on the native side) and no-ops when disabled.
  - If permission is revoked in Android Settings, the provider reads permission state and auto-disables.
- **Test:** Toggle off → receiver stops processing new SMS; toggle on + grant permission → receiver resumes.

### 3.2 High

#### HI-1 Amount field has no length cap
- **File:** `lib/features/dispute_create/dispute_form_page.dart`
- **Fix:** Add `maxLength: 10` (₹99,99,99,999 ≈ 9 digits + decimals) and clamp the live `_estimate()` preview to the same 500000 cap applied at save time. Show inline helper text "Max ₹5,00,000".
- **Test:** Typing 12 digits caps input; preview shows ₹5,00,000, not a larger number.

#### HI-2 Reopened resolved dispute loses future reminders
- **File:** `lib/features/dispute_detail/dispute_detail_page.dart`, `lib/data/repositories/reminder_generator.dart`
- **Fix:** When reopening, clear `filedDates` for statuses beyond the new target OR set a synthetic `reopenedAt` date and generate reminders based on "days from now" rather than the stale original `filedDates`. The chosen minimal fix: on reopen, set the relevant `filedDate` to `DateTime.now()` for the current stage so `ReminderGenerator.forDispute` computes future reminders from today, not from months ago.
- **Test:** Reopen a 6-month-old L1 dispute → reminder is generated for 30 days from now, not skipped.

#### HI-3 Fragile "Other bank" fallback
- **File:** `lib/features/dispute_create/dispute_form_page.dart`
- **Fix:** Replace `BankCatalog.banks.last` fallback with an explicit lookup for `id == 'other'` and assert it exists at startup (debug-mode assert). If missing, show an validation error and disable the "Other" path rather than silently selecting the wrong bank.
- **Test:** Remove `other` from catalog → "Other bank" option is hidden/disabled; no fallback to a real bank.

#### HI-4 Stale dispute reference after resolve/reopen
- **File:** `lib/features/dispute_detail/dispute_detail_page.dart`
- **Fix:** After `saveDispute`, await the updated dispute from the repository and pass it back into the local widget state. Invalidate provider after the state update so the next build uses fresh data. Add a `_toggling` guard so the action button is disabled during the operation.

#### HI-5 No re-entrancy guard on Mark Resolved/Reopen
- **File:** `lib/features/dispute_detail/dispute_detail_page.dart`
- **Fix:** Add a `_toggling` boolean. Disable the `_ActionButton` while `true`. Set it before `saveDispute` and reset in `finally`.
- **Combined test for HI-4/HI-5:** Fast double-tap on Resolve → only one write, no duplicate activity-log entries.

### 3.3 Medium

#### ME-1 Hardcoded "T+5" deadline label on Escalate page
- **File:** `lib/features/escalate/escalate_page.dart`
- **Fix:** Compute the label from `dispute.type.tatBasis` / `tatDays`: e.g. "T+1 deadline missed", "30-day window missed". For types with `tatDays == null`, show a generic "Deadlinemissed" or category-specific text (FASTag 30-day, bank charge 30+90).
- **Test:** UPI P2P dispute → "T+1" label; FASTag → "30-day window".

#### ME-2 Off-by-one "Day N of Y" near midnight
- **File:** `lib/services/compensation_calculator.dart`, `lib/features/dispute_detail/dispute_detail_page.dart`
- **Fix:** Floor day boundaries using date-only comparison: `DateTime(now.year, now.month, now.day).difference(DateTime(tnx.year, tnx.month, tnx.day)).inDays` instead of raw `Duration.inDays` on wall-clock `DateTime`.
- **Test:** Sub-24h periods report "Day 1", not "Day 0".

#### ME-3 Live estimate preview ignores amount cap
- **File:** `lib/features/dispute_create/dispute_form_page.dart`
- **Fix:** Apply `min(amount, 500000)` inside `_estimate()` before computing compensation.
- **Test:** Type ₹500,000+; preview headline stays at ₹5,00,000 + comp.

#### ME-4 Fragile Won/Lost/Partial badge ordering
- **File:** `lib/features/history/history_page.dart`
- **Fix:** Replace the ordered switch with explicit boolean helper functions:
  ```dart
  bool isWon(Dispute d) => d.status == DisputeStatus.resolved && (d.resolvedAmount ?? 0) > 0;
  bool isLost(Dispute d) => d.status == DisputeStatus.expired || (d.status == DisputeStatus.resolved && (d.resolvedAmount ?? 0) == 0);
  bool isPartial(Dispute d) => d.status == DisputeStatus.resolved && (d.resolvedAmount ?? 0) > 0 && (d.resolvedAmount ?? 0) < d.amount;
  ```
- **Test:** Unit tests for each classification.

#### ME-5 Reminders missing if status advanced without filedDates
- **File:** `lib/data/repositories/reminder_generator.dart`
- **Fix:** In `forDispute`, if a needed `filedDates` key is missing for the current status, fall back to `dispute.createdAt` for reminder scheduling rather than returning nothing.
- **Test:** Dispute with `status: filedL2` but no `filedDates['l2']` still gets an L2 reminder.

#### ME-6 `reopenTarget()` has no `expired` branch
- **File:** `lib/data/models/dispute.dart`
- **Fix:** Add explicit branch: if `status == DisputeStatus.expired`, return the most advanced prior filing (`ombudsman > l2 > l1 > draft`).

#### ME-7 Template auto-match duplicated in 3 places
- **File:** `lib/features/dispute_detail/dispute_detail_page.dart`, `lib/features/escalate/escalate_page.dart`, `lib/features/escalate/widgets/escalate_template_picker.dart`
- **Fix:** Move matching logic to `TemplateRepository.matchTemplateFor(Dispute, {required int escalationLevel, Set<String>? freeIds, required bool isPremiumUser})`. All three callers use the same method.
- **Test:** Same dispute produces the same matched template on all three screens.

#### ME-8 Cold-start notification-tap race
- **File:** `lib/main.dart`, `lib/core/router/app_router.dart`
- **Fix:** In `_buildNotificationTapHandler`, if `hasSeenOnboardingProvider` is not yet loaded (still in loading state), queue the deep-link in a temporary provider/variable and let the router redirect handle it. Ensure `hydratePersistedAppState` completes before processing notification payloads.
- **Test:** Kill app → tap UTR notification before fully loaded → onboarding flow still takes precedence.

### 3.4 Low

#### LO-1 Indian number formatting duplicated 3×
- **Fix:** Add `IndianNumberFormatter` utility in `lib/shared/utils/` and replace the three copy-pasted implementations in `home_page.dart` (2×) and `compensation_calculator.dart`.

#### LO-2 "Overdue by 0 days" cosmetic wording
- **File:** `lib/features/reminders/reminders_page.dart`
- **Fix:** If `daysLeft == 0`, show "Overdue today"; if `< 0`, show "Overdue by ${days.abs()} day(s)".

#### LO-3 Wrong compensation label for FASTag/bank_charge/wrong_transfer in History
- **File:** `lib/features/history/history_page.dart`
- **Fix:** Use `CompensationCalculator.compute(d).compensationDue > 0` to decide whether to show a comp label at all; for types with no compensation, show no comp text (or "No compensation applies").

#### LO-4 Hardcoded version string in Settings
- **File:** `lib/features/settings/settings_page.dart`
- **Fix:** Use `package_info_plus` (already common in Flutter; if not present, add it) to read `PackageInfo.version` and `buildNumber`.

#### LO-5 Missing Privacy Policy link in Settings
- **File:** `lib/features/settings/settings_page.dart`
- **Fix:** Add a "Privacy Policy" list tile in the Legal dialog that launches a configurable URL (e.g. `https://refundradar.app/privacy`). Add `privacyPolicyUrl` constant in a config file. Also add Terms of Service if available.

---

## 4. UI/UX Redesign

### 4.1 Custom headers for Wizard and Ombudsman Letter
- Replace plain `AppBar(title: Text(...))` with the same `AppBackButton` + themed `Row` used on Home, Escalate, Dispute Form, etc.
- Use `tc.bg`, `tc.textPrimary`, `AppTypography` consistently.

### 4.2 Dark-mode and accessibility fixes
- Replace hardcoded `Colors.white` on Create-Dispute submit button and checkmark icons with `tc.ctaForeground`.
- Replace hardcoded `AppColors.primary` on Home icons with theme-aware colors.
- Increase template-picker pencil icon tap target to ≥48×48 dp by wrapping it in an `IconButton` with `padding: EdgeInsets.all(12)` and `splashRadius: 24`.
- Add confirmation dialog before Mark Resolved/Reopen in Dispute Detail (model after the Settings delete-account dialog).

### 4.3 Consistent premium gating UI
- Every premium gate uses a shared component: `PremiumGateBottomSheet` or `LockedTemplateTile`.
- Remove inconsistent SnackBar-only gates. For form-level gates (free 2nd dispute) keep the brief SnackBar but also show a richer inline card.

---

## 5. Template Monetization Redesign

### 5.1 Free-tier model: one free template per dispute **type**

**Goal:** Every user can solve their first step of any real problem for free, but deeper escalation is the paid ladder.

**Rule:** For each dispute type, the lowest-escalation Level-1 template is free; all higher levels and all Ombudsman/legal templates are Pro.

**Current JSON changes needed:**

| Dispute Type | Template to make free | Why |
|--------------|----------------------|-----|
| UPI P2P | `upi_p2p_bank_complaint` (already free) | keep |
| UPI P2M | `upi_p2m_bank_complaint` | currently paid, no free P2M option |
| ATM | `atm_bank_complaint` | currently paid |
| IMPS | `imps_bank_complaint` | currently paid |
| FASTag | `fastag_1033_call_script` (already free) OR `fastag_ihmcl_double_deduction` (level 3) — chosen: keep `fastag_1033_call_script` as the free Level-2/helpline entry; this is the closest to a "first action" for FASTag. | keep |
| Bank charge | `bank_charge_reversal_basic` (already free) | keep |
| Wrong transfer | `wrong_transfer_bank_request` (already free) | keep |

So the only JSON flag change is: **set `upi_p2m_bank_complaint`, `atm_bank_complaint`, and `imps_bank_complaint` to `"isPremium": false`**.

**Code change:** `TemplateRepository.isLocked` already respects `isPremium` and the live `freeTemplateIds` allowlist, so no repository logic change is needed beyond the JSON flags. If Remote Config ever needs to override, use `freeTemplateIds`.

### 5.2 Blur-preview every locked template in the Template Library

- Replace the generic "Tap to unlock with Premium — 50+ RBI-compliant templates" placeholder in `template_library_page.dart` with the same blurred/faded preview already used in `escalate_template_picker.dart`.
- Each locked card shows:
  - Real title.
  - First 2 lines of the filled body, blurred/faded to the last line.
  - Gold "🔒 Pro" badge.
  - "Unlock →" link.
- Tapping a locked card opens a **preview bottom sheet** (not the paywall immediately) that shows the blurred preview + a "Unlock with Premium" CTA. The CTA then routes to paywall with `trigger=template_locked&templateId={id}` so the paywall can be contextual.
- Extract the existing blur-preview widget from `escalate_template_picker.dart` into a reusable `TemplatePreviewCard` so both callers share it.

### 5.3 Contextual paywall copy

- Pass `templateId` and `templateTitle` query params to the paywall route when triggered from a template.
- In `paywall_page.dart`, read these params. When present, override the generic headline/subtext:
  - Headline: "Unlock this template"
  - Subtext: "'{templateTitle}' and 50+ more RBI-compliant templates are included with Premium."
- Non-template triggers keep the existing generic "Recover more" copy.
- This requires `AppRoutes.paywallWithParams({String? trigger, String? templateId, String? templateTitle})` helper.

### 5.4 Live store pricing

- Remove the hardcoded `_inrPriceFor()` override in `paywall_page.dart`.
- Always display `package.storeProduct.priceString`.
- If `priceString` is null/empty (shouldn't happen in production), fall back to the package identifier, not hardcoded INR numbers.
- Add a Crashlytics log when `priceString` doesn't contain "₹" in an Indian build — this catches misconfigured store accounts without lying to the user.

### 5.5 Premium status loading state

- Convert `isPremiumProvider` from `StateProvider<bool>` to `StateProvider<AsyncValue<bool>>` (or keep a separate `premiumStatusProvider` for new code while keeping `isPremiumProvider` as a derived `bool` for backward compatibility).
- During app startup, show the previous persisted value immediately but mark it as "loading". Paywall gates treat an unhydrated state as "not premium" (fail-safe).
- This prevents a brief flash of premium gates for a lapsed user while RevenueCat configures.

### 5.6 Entitlement constant + restore UX

- Add `lib/core/constants/revenuecat_constants.dart` with `const kPremiumEntitlementId = 'Premium';`.
- Replace the four bare-string `'Premium'` usages in `RevenueCatService`.
- Sanitize restore-failure messages: show localized "Could not restore purchases" instead of raw `e.toString()`.

---

## 6. Dispute Auto-Expiry Details

### 6.1 Algorithm
```dart
DateTime? lastFiling(Dispute d) =>
  d.filedDates.values.whereType<DateTime>().maxOrNull;

DateTime expiryCutoff(Dispute d) {
  final last = lastFiling(d) ?? d.createdAt;
  return last.add(const Duration(days: 90));
}

bool shouldAutoExpire(Dispute d, DateTime now) {
  if (d.status == DisputeStatus.resolved ||
      d.status == DisputeStatus.expired ||
      d.status == DisputeStatus.draft) return false;
  return now.isAfter(expiryCutoff(d));
}
```

### 6.2 Write path
- New method in `firestore_dispute_repository.dart`: `Future<List<Dispute>> syncExpiredStatuses(String uid, List<Dispute> current, DateTime now)`.
- Returns the list with expired disputes' status updated to `expired` and a new activity-log entry appended.
- Uses `saveDispute` for each changed dispute to get merge + retry for free.
- Dedupes by tracking in-flight doc IDs in a static set so rapid rebuilds don't spam writes.

### 6.3 UI integration
- In `HomePage._Body` / wherever `disputesProvider` data is consumed, call `syncExpiredStatuses` once per provider data load before filtering to `activeHomeDisputes`.
- Show a subtle SnackBar or inline banner: "X disputes expired after 90 days of inactivity." (optional, can be silent).

---

## 7. RevenueCat Integration Fixes

| Issue | Fix |
|-------|-----|
| Hardcoded INR prices | Use `storeProduct.priceString` |
| No premium loading state | Convert `isPremiumProvider` to `AsyncValue<bool>` |
| Bare-string entitlement | Add `kPremiumEntitlementId` constant |
| Raw restore error text | Localized message |
| Missing timeout | Add 15s timeout on `fetchOfferings`, `purchasePackage`, `restorePurchases` (consistent with Firestore calls) |

---

## 8. Deferred / Out of Scope

### 8.1 Server-side free-tier enforcement
- **Why deferred:** Requires Firebase Blaze plan + Cloud Functions + RevenueCat webhook to sync `isPremium` to Firestore, then update `firestore.rules` to enforce `create` limits server-side.
- **Current state:** Client-side gate in `dispute_form_page.dart` remains active; a modified/rooted client can bypass it, but there is no backend today to prevent that.
- **When to revisit:** After upgrading to Blaze and after this Play Store pass ships.

---

## 9. Success Metrics

After this pass:
- All 22 audit findings are resolved or explicitly accepted.
- Templates: every dispute type has a usable free template; locked templates show real blurred previews; paywall is contextual by template.
- RevenueCat: displayed prices match store prices; no paywall bypass via Copy; no misleading SMS toggle.
- Play Store: 16KB compliance verified on release artifact; Privacy Policy link present in Settings.

---

## 10. Files Expected to Change

- `lib/features/escalate/escalate_page.dart`
- `lib/features/home/home_page.dart`
- `lib/features/settings/settings_page.dart`
- `lib/features/dispute_create/dispute_form_page.dart`
- `lib/features/dispute_detail/dispute_detail_page.dart`
- `lib/features/wizard/wizard_page.dart`
- `lib/features/ombudsman/ombudsman_letter_page.dart`
- `lib/features/templates/template_library_page.dart`
- `lib/features/escalate/widgets/escalate_template_picker.dart`
- `lib/features/paywall/paywall_page.dart`
- `lib/services/revenue_cat_service.dart`
- `lib/data/repositories/firestore_dispute_repository.dart`
- `lib/data/repositories/template_repository.dart`
- `lib/data/repositories/reminder_generator.dart`
- `lib/data/models/dispute.dart`
- `lib/services/compensation_calculator.dart`
- `lib/shared/utils/` (new `indian_number_formatter.dart`, `revenuecat_constants.dart`)
- `assets/templates/upi/upi_p2m_bank_complaint.json`
- `assets/templates/upi/atm_bank_complaint.json`
- `assets/templates/upi/imps_bank_complaint.json`
- Test files for new/changed logic.
