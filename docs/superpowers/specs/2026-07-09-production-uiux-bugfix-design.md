# 2026-07-09 Production UI/UX Bugfix — Design Spec

**Status:** Approved (user: full production sweep)  
**App:** RefundRadar (Flutter, Android-first)  
**Scope:** Dark-mode contrast blockers, Create-dispute silent fail, escalate display bugs, residual i18n, empty-CTA routes, critical widget tests  
**Out of scope:** Redesign, OpenDesign MCP revival, iOS, new features, store submission

---

## 1. Problem statement

Device screenshots in `bugs/` (dark mode) plus user reports show the app is **not production-ready**:

1. **Invisible / unreadable text** — light pastel soft surfaces (`AppColors.*Soft`) with near-white dark-mode text; primary FilledButtons with dark foreground on deep green.
2. **Create dispute does nothing** — form CTA silently returns when `userIdProvider.asData?.value` is null.
3. **Escalate feels broken** — max-claim can show ₹0 for non-compensable types if amount not surfaced correctly; email preview has no TO line; soft callouts glow light pastels.
4. **Misrouted empty CTAs** — History/Reminders “Add dispute” only go home.
5. **Residual English hardcodes** — ombudsman, paywall, settings strings.
6. **No widget tests** for critical create/escalate paths.

Prior dark-mode sweep (`79d3896`) migrated scaffolds to `AppThemeColors` but left **light-only soft tokens** and **primary-only button overrides** in shared widgets and feature banners.

---

## 2. Goals / success criteria

| Criterion | Pass condition |
|-----------|----------------|
| Dark soft surfaces | Zero uses of `AppColors.accentSoft/alertSoft/errorSoft/premiumGoldSoft` as widget backgrounds outside token definitions |
| CTA contrast | Every primary FilledButton sets both bg+fg, or uses unstyled theme default |
| Create dispute | Null/loading auth always shows SnackBar (never silent); bank picker works when rules fail |
| Empty CTAs | History + Reminders open `/disputes/create` |
| Escalate | Hero shows `formatIndian(amount + compensation)`; email preview shows TO (+ CC if on); softs via `tc.*Soft` |
| i18n | No user-visible English hardcodes in ombudsman/paywall/settings residual list |
| Quality gate | `flutter analyze` 0 issues; `flutter test` green (95 + new widget tests) |
| Visual | Dark mode: no light pastel “holes”; body text readable on all banners/pills |

---

## 3. Non-goals

- Rebuild design system from scratch / OpenDesign daemon
- Change brand hex values (`#0B3D2E`, `#16C784`, etc.)
- Light-mode redesign
- Full QA checklist §9 / Play Store submit
- RevenueCat live keys

---

## 4. Architecture (Approach A — centralize dark softs)

```
AppColors (mode-independent brand)
    └── AppThemeColors.of(context)  ← ONLY soft surfaces for feature UI
            ├── accentSoft / alertSoft / errorSoft / premiumGoldSoft
            ├── surface / surfaceAlt / divider / text*
            └── used by StatusPill, InfoBanner, DisputeType soft tiles, feature banners

Material theme FilledButton
    └── dark: accent bg + primaryDark fg  (leave alone OR override BOTH)
```

**Rules for implementers:**

1. Feature UI must never paint `AppColors.*Soft` as a background.
2. `StatusKind` gains `bgFor(AppThemeColors tc)` (and optional `fgFor`); deprecate bare `.bg` for UI.
3. `DisputeType.softColor` stays for light default; add `softColorFor(AppThemeColors tc)`.
4. Primary CTAs: prefer unstyled `FilledButton` / `PrimaryCTA`; if override `backgroundColor: AppColors.primary`, also set `foregroundColor: Colors.white`.
5. Auth-sensitive actions: `await ref.read(userIdProvider.future)` + SnackBar on failure — never silent `return`.
6. Navigation CTAs labeled “Add/Track dispute” must `push/go('/disputes/create')`.

---

## 5. Functional fixes

### 5.1 Create dispute silent fail

**File:** `lib/features/dispute_create/dispute_form_page.dart`

```dart
// BEFORE (blocker)
final uid = ref.read(userIdProvider).asData?.value;
if (uid == null) return;

// AFTER
String? uid;
try {
  uid = await ref.read(userIdProvider.future);
} catch (_) {
  uid = null;
}
if (uid == null || uid.isEmpty) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(l10n?.formAuthRequired ?? 'Could not sign in. Tap retry or restart the app.')),
  );
  return;
}
```

Also:
- Bank picker error branch: fallback bank list (same hardcoded banks as success path) or retry — never `onTap: () {}`.
- Wizard `wizard_page.dart`: same non-silent uid/dispute guards.

### 5.2 Empty CTAs

| Location | Change |
|----------|--------|
| `history_page.dart` empty “Add dispute” | `context.push('/disputes/create')` |
| `reminders_page.dart` empty “Track a new dispute” | `context.push('/disputes/create')` |

### 5.3 Escalate

| Issue | Fix |
|-------|-----|
| Soft pastels | `tc.alertSoft` for T+5 pill + amber callout |
| Email preview missing TO | Add TO line: `_nodalEmail(dispute)`; if `ccOmbudsman`, show `CC: crpc@rbi.org.in` |
| ₹0 hero | Ensure `maxClaim = dispute.amount + comp.compensationDue` always; if amount is 0 show honest ₹0 + helper “No amount on this dispute”; for types without daily comp still show refund amount (already coded — verify amount persisted) |
| Edit button text color | Dark: use `AppColors.accent` or `tc.textPrimary` not light-only primary if low contrast |
| Hardcoded email body months | Keep for now; optional i18n later |

### 5.4 Residual i18n

Migrate to ARB (en+hi) + `app_localizations.dart` helpers:
- Ombudsman: “Premium feature”, long blurb
- Paywall: “Unlimited”, “Hindi premium templates”, restore error
- Settings: “Session refreshed.”
- Form: “Select a bank” SnackBar (already partially wired)

---

## 6. Color inventory (fix targets)

### Blockers
| Area | Files |
|------|-------|
| Soft bg + `tc.textPrimary` | `info_banner`, `branded_error_banner`, form banners, escalate callout, SMS privacy note, paywall plans-unavailable |
| Primary FilledButton without white fg | `dispute_type_page`, `onboarding_page`, `wizard_page`, `reminders_page` |

### Majors
| Area | Files |
|------|-------|
| Status pills / soft chips | `status_pill`, `app_tokens` StatusKind, dispute_card, dispute_detail, escalate pill, form type chip, templates, settings badges |
| Dispute type soft tiles | `dispute_type_display.softColorFor`, dispute_card, dispute_type_page, dispute_detail, history, home empty, sms heroes, onboarding |
| Greys | ombudsman disclaimer, stepper_timeline, paywall border |
| Amount text `AppColors.primary` in dark | dispute_detail, dispute_card, sms sample |

### Minors
Hero gradients using `Colors.white` → soft; radio_row selected soft; chip selected one-off hex.

---

## 7. Testing strategy

| Test | Type | Asserts |
|------|------|---------|
| Existing 95 unit tests | unit | Still green |
| `test/create_dispute_auth_test.dart` (or widget) | unit/widget | `_save` path: null uid produces no silent success; prefer testing via extracted helper if widget harness heavy |
| Soft color resolver | unit | `softColorFor` / `StatusKind.bgFor` dark ≠ light pastels |
| Compensation | existing | non-UPI types return 0 comp but amount still formats |
| Manual | device | Dark mode walk: home → create → form → detail → escalate; banners readable |

**CI gate unchanged:** `flutter analyze` + `flutter test`.

---

## 8. Agent workstreams (8 parallel)

| Agent | Workstream | Key files |
|-------|------------|-----------|
| 1 | Theme foundation | `app_tokens.dart`, `status_pill.dart`, `dispute_type_display.dart` |
| 2 | Shared soft banners | `info_banner`, `branded_error_banner`, `hero_emoji_circle`, `radio_row`, `stepper_timeline`, `dispute_card` |
| 3 | Create-dispute functional | `dispute_form_page`, `dispute_type_page` CTA, wizard silent returns |
| 4 | Soft feature screens A | form banners, escalate, sms_permission, paywall softs |
| 5 | Soft feature screens B | home, history, settings badges, templates, onboarding, reminders CTA colors |
| 6 | Primary buttons + greys | type/onboarding/wizard/reminders FilledButtons; ombudsman grey; paywall border |
| 7 | Escalate display + empty routes | escalate TO/CC preview; history/reminders push create |
| 8 | i18n residual + tests | ARB keys, settings/paywall/ombudsman strings; unit tests for soft resolvers + auth guard |

Merge order: **1 → 2 → (3,4,5,6,7 parallel) → 8 → analyze/test**.

---

## 9. Risks

| Risk | Mitigation |
|------|------------|
| Merge conflicts on shared widgets | Agent 1 lands first; others rebased |
| Widget tests need full MaterialApp+Provider | Prefer pure unit tests for resolvers; keep widget tests minimal |
| Changing StatusKind.bg breaks callers | Add `bgFor(tc)` without removing `.bg` initially; migrate callers |
| Over-fix light mode | Soft tokens already correct in light via `AppThemeColors` |

---

## 10. Rollout

1. Single feature branch or sequential commits on `main` (repo currently clean on main).
2. Commit per workstream with conventional messages.
3. Final gate: analyze + test; update `PROGRESS.md`.
4. User device re-verify with new screenshots in `bugs/` (optional).

---

## 11. OpenDesign note

`open-design` daemon exists at `/home/ubuntu/open-design` but was previously abandoned for this project (`AGENT_EXECUTION_FAILED`). **Not used in this fix pass.** Design source of truth remains `app_tokens.dart` + `Refund Plan.html` §6 + `ss/` mockups.
