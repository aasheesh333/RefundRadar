# Production UI/UX Bugfix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make RefundRadar production-ready by fixing dark-mode invisible text, Create-dispute silent fail, escalate display bugs, residual i18n, and misrouted CTAs.

**Architecture:** Centralize all soft surfaces through `AppThemeColors`; never paint light-only `AppColors.*Soft` in feature UI. Auth-sensitive actions await `userIdProvider.future` and always show SnackBars. Empty “Add dispute” CTAs route to `/disputes/create`.

**Tech Stack:** Flutter 3, Riverpod, go_router, AppLocalizations (en/hi), Material 3 theme tokens.

**Spec:** `docs/superpowers/specs/2026-07-09-production-uiux-bugfix-design.md`

## Global Constraints

- Do not change brand hex values in `AppColors` (primary/accent/alert/error).
- Do not revive OpenDesign MCP.
- Every commit must leave `flutter analyze` clean (0 issues) and `flutter test` green.
- Prefer `AppThemeColors.of(context)` over bare `AppColors.*Soft` / `Colors.grey` / `Colors.white` for chrome.
- i18n: add keys to both `app_en.arb` and `app_hi.arb`, then wire `app_localizations.dart` (project uses hand-synced map, not flutter gen-l10n only — match existing pattern).
- No comments unless existing file style requires them for non-obvious guards.
- Android-first; no iOS work.

---

### Task 1: Theme foundation — StatusKind + softColorFor

**Files:**
- Modify: `lib/core/theme/app_tokens.dart` (StatusKind extension)
- Modify: `lib/shared/widgets/status_pill.dart`
- Modify: `lib/data/extensions/dispute_type_display.dart`
- Test: `test/theme_soft_tokens_test.dart` (create)

**Interfaces:**
- Produces: `StatusKindX.bgFor(AppThemeColors tc)`, `StatusKindX.fgFor(AppThemeColors tc)` (optional; fg can stay mode-independent)
- Produces: `DisputeTypeX.softColorFor(AppThemeColors tc)`
- Consumes: `AppThemeColors` from `app_theme_colors.dart`

- [ ] **Step 1: Write failing unit test for dark softs**

Create `test/theme_soft_tokens_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/data/extensions/dispute_type_display.dart';
import 'package:refund_radar/data/models/dispute.dart';

void main() {
  group('StatusKind.bgFor', () {
    test('dark softs are not light pastels', () {
      const dark = AppThemeColors(Brightness.dark);
      expect(StatusKind.success.bgFor(dark), isNot(const Color(0xFFD7F5E7)));
      expect(StatusKind.warn.bgFor(dark), isNot(AppColors.alertSoft));
      expect(StatusKind.danger.bgFor(dark), isNot(AppColors.errorSoft));
      expect(StatusKind.info.bgFor(dark), isNot(AppColors.accentSoft));
      expect(StatusKind.premium.bgFor(dark), isNot(AppColors.premiumGoldSoft));
    });

    test('light softs match AppColors pastels', () {
      const light = AppThemeColors(Brightness.light);
      expect(StatusKind.info.bgFor(light), AppColors.accentSoft);
      expect(StatusKind.warn.bgFor(light), AppColors.alertSoft);
    });
  });

  group('DisputeType.softColorFor', () {
    test('dark uses theme softs', () {
      const dark = AppThemeColors(Brightness.dark);
      expect(DisputeType.upiP2p.softColorFor(dark), dark.accentSoft);
      expect(DisputeType.bankCharge.softColorFor(dark), dark.alertSoft);
    });
  });
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
cd /home/ubuntu/RefundRadar && flutter test test/theme_soft_tokens_test.dart
```

Expected: compile/API errors — `bgFor` / `softColorFor` missing.

- [ ] **Step 3: Implement StatusKind.bgFor / fgFor**

In `app_tokens.dart`, extend `StatusKindX`:

```dart
extension StatusKindX on StatusKind {
  Color get fg => switch (this) {
        StatusKind.neutral => const Color(0xFF5A6560),
        StatusKind.info => AppColors.primary,
        StatusKind.warn => AppColors.alert,
        StatusKind.danger => AppColors.error,
        StatusKind.success => AppColors.success,
        StatusKind.premium => AppColors.premiumGold,
      };

  /// Light-only; prefer [bgFor] in widgets.
  Color get bg => switch (this) {
        StatusKind.neutral => const Color(0xFFE5E7E2),
        StatusKind.info => AppColors.accentSoft,
        StatusKind.warn => AppColors.alertSoft,
        StatusKind.danger => AppColors.errorSoft,
        StatusKind.success => const Color(0xFFD7F5E7),
        StatusKind.premium => const Color(0xFFFBF0D6),
      };

  Color bgFor(AppThemeColors tc) => switch (this) {
        StatusKind.neutral => tc.surfaceAlt,
        StatusKind.info => tc.accentSoft,
        StatusKind.warn => tc.alertSoft,
        StatusKind.danger => tc.errorSoft,
        StatusKind.success => tc.accentSoft,
        StatusKind.premium => tc.premiumGoldSoft,
      };

  Color fgFor(AppThemeColors tc) => switch (this) {
        StatusKind.neutral => tc.textSecondary,
        StatusKind.info => tc.isDark ? AppColors.accent : AppColors.primary,
        StatusKind.warn => AppColors.alert,
        StatusKind.danger => AppColors.error,
        StatusKind.success => AppColors.success,
        StatusKind.premium => AppColors.premiumGold,
      };
}
```

Add import for `app_theme_colors.dart` at top of `app_tokens.dart` if needed (watch circular imports — if circular, put `bgFor` in a small extension file under `core/theme/status_kind_theme.dart` instead).

- [ ] **Step 4: Implement softColorFor on DisputeType**

In `dispute_type_display.dart`:

```dart
Color softColorFor(AppThemeColors tc) => switch (this) {
      DisputeType.upiP2p => tc.accentSoft,
      DisputeType.upiP2m => tc.accentSoft,
      DisputeType.fastag => tc.alertSoft,
      DisputeType.bankCharge => tc.alertSoft,
      DisputeType.wrongTransfer => tc.errorSoft,
      // cover all enum values present in dispute.dart
    };
```

Keep existing `softColor` getter for any legacy callers; migrate call sites in later tasks.

- [ ] **Step 5: Update StatusPill.kind to take BuildContext**

```dart
factory StatusPill.kind({
  Key? key,
  required BuildContext context,
  required String label,
  required StatusKind kind,
  String? prefix,
}) {
  final tc = AppThemeColors.of(context);
  return StatusPill(
    key: key,
    label: label,
    prefix: prefix,
    fg: kind.fgFor(tc),
    bg: kind.bgFor(tc),
  );
}
```

Grep all `StatusPill.kind(` and add `context:` first named arg.

- [ ] **Step 6: Run tests**

```bash
flutter test test/theme_soft_tokens_test.dart && flutter analyze
```

Expected: PASS, analyze 0 issues.

- [ ] **Step 7: Commit**

```bash
git add lib/core/theme/app_tokens.dart lib/shared/widgets/status_pill.dart lib/data/extensions/dispute_type_display.dart test/theme_soft_tokens_test.dart
# plus any StatusPill.kind call-site fixes required to compile
git commit -m "fix(theme): brightness-aware StatusKind softs + dispute softColorFor"
```

---

### Task 2: Shared soft banners & cards

**Files:**
- Modify: `lib/shared/widgets/info_banner.dart`
- Modify: `lib/shared/widgets/branded_error_banner.dart`
- Modify: `lib/shared/widgets/hero_emoji_circle.dart`
- Modify: `lib/shared/widgets/radio_row.dart`
- Modify: `lib/shared/widgets/stepper_timeline.dart`
- Modify: `lib/shared/widgets/dispute_card.dart`

**Interfaces:**
- Consumes: `AppThemeColors`, `softColorFor`, `StatusKind.bgFor`

- [ ] **Step 1: Fix info_banner soft backgrounds**

Replace:

```dart
// BAD
InfoKind.success => AppColors.accentSoft,
```

With:

```dart
final tc = AppThemeColors.of(context);
// ...
InfoKind.success => tc.accentSoft,
InfoKind.warning => tc.alertSoft, // match existing enum names
InfoKind.error => tc.errorSoft,
InfoKind.info => tc.accentSoft,
InfoKind.premium => tc.premiumGoldSoft,
```

Ensure message text stays `tc.textPrimary` (now readable on dark softs).

- [ ] **Step 2: Fix branded_error_banner**

```dart
color: tc.errorSoft, // not AppColors.errorSoft
```

Keep icon `AppColors.error`; retry button keep white on primary if already set.

- [ ] **Step 3: hero_emoji_circle**

```dart
final soft = softColor ?? AppThemeColors.of(context).accentSoft;
// gradient: tc.surface → soft (not Colors.white → soft)
```

- [ ] **Step 4: radio_row selected bg**

```dart
selected ? AppThemeColors.of(context).accentSoft : Colors.transparent,
```

- [ ] **Step 5: stepper_timeline greys**

Pending step: `tc.surfaceAlt` circle, `tc.textTertiary` number, connector `tc.divider`. Done steps keep accent + white check.

- [ ] **Step 6: dispute_card**

- Emoji tile: `dispute.type.softColorFor(tc)`
- Status pills: `tc.accentSoft` / `tc.errorSoft` / `tc.alertSoft`
- Amount / View: use `Theme.of(context).colorScheme.primary` or `tc.isDark ? AppColors.accent : AppColors.primary`

- [ ] **Step 7: Analyze + commit**

```bash
flutter analyze && git add lib/shared/widgets && git commit -m "fix(ui): theme-aware soft banners, cards, stepper greys"
```

---

### Task 3: Create-dispute functional fixes

**Files:**
- Modify: `lib/features/dispute_create/dispute_form_page.dart`
- Modify: `lib/features/wizard/wizard_page.dart`
- Modify: `lib/features/dispute_create/dispute_type_page.dart` (CTA colors only if not Task 6)
- Test: `test/create_dispute_auth_guard_test.dart` (create) — pure helper preferred

**Interfaces:**
- Produces: non-silent auth resolution in `_save` / wizard persist

- [ ] **Step 1: Extract or inline await uid with feedback**

In `dispute_form_page.dart` `_save()` replace lines 105–106:

```dart
String? uid;
try {
  uid = await ref.read(userIdProvider.future);
} catch (_) {
  uid = null;
}
if (uid == null || uid.isEmpty) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        AppLocalizations.of(context)?.formAuthRequired ??
            'Could not sign in. Please restart the app and try again.',
      ),
    ),
  );
  return;
}
```

Add ARB key `formAuthRequired` (en+hi) in Task 8 if not added here.

- [ ] **Step 2: Fix bank picker error branch empty onTap**

Find `onTap: () {}` (~308). Replace with fallback:

```dart
onTap: () => _showBankPicker(fallbackBanks),
```

Where `fallbackBanks` is the same static list used when rules succeed (extract list to a top-level or class const if duplicated).

- [ ] **Step 3: Form soft banners use tc.*Soft**

Warn banner `AppColors.alertSoft` → `tc.alertSoft`; success `AppColors.accentSoft` → `tc.accentSoft`; type chip same.

- [ ] **Step 4: Wizard silent returns**

In `wizard_page.dart` any `if (uid == null) return;` during mark-filed → SnackBar + return.

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze && git add lib/features/dispute_create lib/features/wizard && git commit -m "fix(create): non-silent auth on save; bank picker fallback; form softs"
```

---

### Task 4: Feature soft surfaces A (escalate, sms, paywall)

**Files:**
- Modify: `lib/features/escalate/escalate_page.dart`
- Modify: `lib/features/sms_permission/sms_permission_page.dart`
- Modify: `lib/features/paywall/paywall_page.dart`

- [ ] **Step 1: Escalate softs + TO preview**

1. T+5 pill bg: `tc.alertSoft`
2. Amber callout bg: `tc.alertSoft`
3. Nodal emoji tile: `tc.alertSoft`
4. Email preview card — after subject container, add:

```dart
Text(
  'TO: ${_nodalEmail(dispute)}',
  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tc.textPrimary),
),
if (ccOmbudsman)
  Text(
    'CC: crpc@rbi.org.in',
    style: TextStyle(fontSize: 11, color: tc.textSecondary),
  ),
```

5. Hero: keep `maxClaim = refund + comp.compensationDue`. If `refund == 0`, show subtitle “No transaction amount on this dispute” (i18n key optional).
6. Edit button `textColor`: `tc.isDark ? AppColors.accent : AppColors.primary`

- [ ] **Step 2: SMS permission page**

Hero + step number softs → `tc.accentSoft`; privacy note → `tc.premiumGoldSoft`; sample SMS / maybe-later colors → theme primary/accent in dark.

- [ ] **Step 3: Paywall**

Plans-unavailable box: `tc.alertSoft` + explicit `tc.textPrimary`; package border `Colors.grey.shade300` → `tc.divider`.

- [ ] **Step 4: Commit**

```bash
git add lib/features/escalate lib/features/sms_permission lib/features/paywall
git commit -m "fix(ui): escalate TO/softs, sms/paywall dark soft surfaces"
```

---

### Task 5: Feature soft surfaces B (home, history, settings, templates, onboarding, detail)

**Files:**
- Modify: `lib/features/home/home_page.dart`
- Modify: `lib/features/history/history_page.dart`
- Modify: `lib/features/settings/settings_page.dart`
- Modify: `lib/features/templates/template_library_page.dart`
- Modify: `lib/features/onboarding/onboarding_page.dart`
- Modify: `lib/features/dispute_detail/dispute_detail_page.dart`
- Modify: `lib/features/dispute_create/dispute_type_page.dart` (emoji soft)
- Modify: `lib/features/add_banks/add_banks_page.dart` (gradient if needed)
- Modify: `lib/features/reminders/reminders_page.dart` (softColor alpha tiles)

- [ ] **Step 1: Replace type.softColor → softColorFor(tc)** at all feature call sites (grep `softColor`).

- [ ] **Step 2: Replace AppColors.*Soft backgrounds** with `tc.*Soft` in these files (grep each file).

- [ ] **Step 3: dispute_detail amount color** — dark: `AppColors.accent`; light: `AppColors.primary`. Day/deadline/resolved pills use `tc.*Soft`.

- [ ] **Step 4: settings sign-out button bg** → `tc.errorSoft`; Pro badges → `tc.premiumGoldSoft` / `tc.accentSoft`.

- [ ] **Step 5: onboarding slides** pass `tc.*Soft` into hero (build method has context).

- [ ] **Step 6: Commit**

```bash
git add lib/features lib/data/extensions
git commit -m "fix(ui): dark-safe soft tiles across home/history/settings/templates/detail"
```

---

### Task 6: Primary FilledButtons + grey hardcodes

**Files:**
- Modify: `lib/features/dispute_create/dispute_type_page.dart` (Continue button)
- Modify: `lib/features/onboarding/onboarding_page.dart`
- Modify: `lib/features/wizard/wizard_page.dart`
- Modify: `lib/features/reminders/reminders_page.dart`
- Modify: `lib/features/ombudsman/ombudsman_letter_page.dart`

- [ ] **Step 1: Pattern for primary override**

Every FilledButton that sets `backgroundColor: AppColors.primary` must also set:

```dart
style: FilledButton.styleFrom(
  backgroundColor: AppColors.primary,
  foregroundColor: Colors.white,
  disabledBackgroundColor: ...,
  disabledForegroundColor: ...,
),
```

Or remove override entirely and rely on theme.

Apply to: type Continue, onboarding CTA, wizard Done, reminders Track button.

- [ ] **Step 2: ombudsman disclaimer**

`Colors.grey` → `AppThemeColors.of(context).textTertiary`

- [ ] **Step 3: Commit**

```bash
git commit -am "fix(ui): primary CTA foreground white; ombudsman grey → tertiary"
```

---

### Task 7: Empty CTA routes → create flow

**Files:**
- Modify: `lib/features/history/history_page.dart`
- Modify: `lib/features/reminders/reminders_page.dart`

- [ ] **Step 1: History empty CTA**

```dart
// was: context.go('/home')
onPressed: () => context.push('/disputes/create'),
```

- [ ] **Step 2: Reminders empty CTA**

```dart
onPressed: () => context.push('/disputes/create'),
```

- [ ] **Step 3: Commit**

```bash
git commit -am "fix(nav): history/reminders empty CTAs open create dispute"
```

---

### Task 8: Residual i18n + final verification

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_hi.arb`
- Modify: `lib/l10n/app_localizations.dart`
- Modify: `lib/features/ombudsman/ombudsman_letter_page.dart`
- Modify: `lib/features/paywall/paywall_page.dart`
- Modify: `lib/features/settings/settings_page.dart`
- Modify: `lib/features/dispute_create/dispute_form_page.dart` (formAuthRequired, formSelectBank)
- Modify: `PROGRESS.md`

**Keys to add (en / hi):**

| Key | en | hi |
|-----|----|----|
| `formAuthRequired` | Could not sign in. Please restart the app and try again. | साइन इन नहीं हो सका। ऐप रीस्टार्ट करके फिर कोशिश करें। |
| `formSelectBank` | Select a bank | बैंक चुनें |
| `ombudsmanPremiumFeature` | Premium feature | प्रीमियम सुविधा |
| `paywallUnlimited` | Unlimited | असीमित |
| `paywallHindiTemplates` | Hindi premium templates | हिंदी प्रीमियम टेम्पलेट |
| `settingsSessionRefreshed` | Session refreshed. | सत्र रीफ़्रेश हो गया। |

(Match exact remaining hardcodes by grepping those files before finalizing strings.)

- [ ] **Step 1: Add ARB keys + app_localizations map + getters**

Follow existing pattern in `app_localizations.dart` (`_t` map + getter).

- [ ] **Step 2: Replace hardcodes with l10n getters**

- [ ] **Step 3: Grep for leftover light softs in feature UI**

```bash
rg "AppColors\.(accentSoft|alertSoft|errorSoft|premiumGoldSoft)" lib/ --glob '!**/app_tokens.dart' --glob '!**/app_theme_colors.dart'
```

Expected: only intentional leftovers (if any documented) or zero.

- [ ] **Step 4: Full gate**

```bash
flutter analyze
flutter test
```

Expected: 0 issues; all tests pass (95 + theme soft tests).

- [ ] **Step 5: Update PROGRESS.md** with this fix pass summary + date.

- [ ] **Step 6: Final commit**

```bash
git add lib/l10n lib/features test PROGRESS.md docs/superpowers
git commit -m "fix(i18n+qa): residual strings, soft-token sweep complete, tests green"
```

---

## Parallel execution map (8+ agents)

```
Phase 0 (serial): Task 1 foundation
Phase 1 (parallel after Task 1):
  Agent A → Task 2 shared widgets
  Agent B → Task 3 create functional
  Agent C → Task 4 escalate/sms/paywall
  Agent D → Task 5 feature softs B
  Agent E → Task 6 buttons + greys
  Agent F → Task 7 empty routes
Phase 2 (serial): Task 8 i18n + full gate
```

If merge conflicts on same file (e.g. dispute_form in Task 3+5), Task 3 owns form functional; Task 5 only soft colors in other files.

---

## Self-review checklist

| Spec requirement | Task |
|------------------|------|
| Soft banners dark-safe | 2, 4, 5 |
| StatusKind / pills | 1, 2, 5 |
| Primary CTA contrast | 6 |
| Create dispute silent fail | 3 |
| Bank picker dead onTap | 3 |
| Wizard silent uid | 3 |
| Empty CTAs → create | 7 |
| Escalate TO + softs | 4 |
| Residual i18n | 8 |
| Tests + analyze | 1, 8 |
| No OpenDesign dependency | N/A |

No TBD placeholders. Types match existing `AppThemeColors`, `DisputeType`, `StatusKind`.
