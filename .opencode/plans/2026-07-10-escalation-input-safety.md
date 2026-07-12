# Escalation Email Quality + Input Safety — Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make RefundRadar production-ready by (1) generating full dispute-type-aware escalation emails from template assets, (2) enforcing input safety on UTR/amount/description fields, and (3) expanding the bank catalog to ~30 major Indian banks.

**Base commit:** `e55ee45`
**Verified baseline:** 183 tests pass, `flutter analyze` 0 issues.

**Architecture:** Flutter + Riverpod + GoRouter. Reuse existing `TemplateRepository`, `filledTemplateBody`, `fillValuesForDispute`. No new abstractions.

## Global Constraints

- All UI strings via `AppLocalizations.of(context)?.getter ?? 'fallback'` + `app_en.arb`/`app_hi.arb` sync.
- All colors via `AppThemeColors.of(context)` / `AppColors.*` tokens.
- No cosmetic changes beyond task scope.
- Verification: `flutter analyze` + `flutter test` locally; GitHub Actions after push.
- No full local APK build (host OOM risk).
- Decision: Pragmatic RBI compliance (active-only Home, RBI disclosure in About/Help, History page already handles resolved/expired).
- Decision: Soft SMS fallback (silent accept, hard input validation, toast warnings only).

---

## Track 1: Escalation Email from Templates
**File:** `lib/features/escalate/escalate_page.dart`

- [ ] 1.1 Extract `_emailBody()` into `_emailBodyWithTemplates(TemplateRepository repo, String localeCode, Dispute dispute)`:
  - Load templates via `templatesProvider` (already cached FutureProvider).
  - Filter for `template.escalationLevel == 2`.
  - Match by dispute type category:
    - `upiP2p`/`upiP2m`/`atm`/`imps` → `'UPI / IMPS / ATM'`
    - `fastag` → `'FASTag'`
    - `bankCharge` → `'Bank charges'`
    - `wrongTransfer` → `'Wrong transfer'`
  - Use `filledTemplateBody(template, localeCode, dispute)` for the body.
  - Defensive fallback: current hardcoded string if no template matches.
- [ ] 1.2 Wire template loading into `_Body` widget (ConsumerWidget → ConsumerStatefulWidget or pass repo):
  - Read `ref.watch(templatesProvider)` in the `_Body` build.
  - Show skeleton/loading indicator while templates load.
  - Pass matched template + filled body to the preview card.
- [ ] 1.3 Make the 3-line preview tappable:
  - Wrap the preview `Text` in `GestureDetector` → open `showDialog` with `AlertDialog` containing `SingleChildScrollView` + `SelectableText(body)`.
  - Add "View full email" affordance (down chevron or tap hint).
- [ ] 1.4 Fix `_nodalEmail()` to use `BankCatalog.nodalEmailFor(dispute.entityId)` first, then fall back to current string matching.
- [ ] 1.5 Add l10n keys: `escalateViewFullEmail`, `escalateTemplatesLoading` to `app_localizations.dart` + ARB files.

## Track 2: Input Safety
**File:** `lib/features/dispute_create/dispute_form_page.dart`

- [ ] 2.1 UTR field (line ~554-573):
  - `keyboardType: TextInputType.number` (was `TextInputType.text`).
  - Add `inputFormatters: [FilteringTextInputFormatter.digitsOnly]`.
  - Add `maxLength: 22`.
- [ ] 2.2 Amount field (line ~622-639):
  - Add `inputFormatters: [FilteringTextInputFormatter.digitsOnly]`.
- [ ] 2.3 Description field (line ~689-706):
  - Add `maxLength: 500`.
  - Add `maxLengthEnforcement: MaxLengthEnforcement.enforced`.
- [ ] 2.4 `_save()` validation (line ~209+):
  - After existing `amount <= 0` check, add: reject if `amount > 500000` with localized snackbar `formAmountCap`.
  - Add: reject if `_utrCtrl.text.trim().isEmpty` with localized snackbar `formUtrRequired`.
  - Change `txnId: _utrCtrl.text` → `txnId: _utrCtrl.text.trim()`.
- [ ] 2.5 Add l10n keys: `formUtrRequired`, `formAmountCap` to `app_localizations.dart` + ARB files.

## Track 3: Bank Catalog Expansion
**File:** `lib/data/constants/bank_catalog.dart`

- [ ] 3.1 Add ~13 banks to `banks` list (before `'other'`):
  - `boi` → Bank of India
  - `unionbank` → Union Bank of India
  - `idbi` → IDBI Bank
  - `indianbank` → Indian Bank
  - `uco` → UCO Bank
  - `centralbank` → Central Bank of India
  - `maha` → Bank of Maharashtra
  - `psb` → Punjab & Sind Bank
  - `sib` → South Indian Bank
  - `jk` → J&K Bank
  - `cub` → City Union Bank
  - `tmb` → Tamilnad Mercantile Bank
  - `kvb` → Karur Vysya Bank
- [ ] 3.2 Add known nodal emails to `_nodalEmails` map where available (research-deferred: leave unknown → RulesEngine fallback).
- [ ] 3.3 Verify `BankCatalog.banks` IDs are unique and stable.

## Track 4: Regression Tests

- [ ] 4.1 `test/escalate_email_body_test.dart`:
  - Test: when a level-2 template matches the dispute type category, email body uses filled template (not hardcoded fallback).
  - Test: when no template matches, falls back to hardcoded string.
  - Test: `_nodalEmail` uses BankCatalog when entityId is known.
- [ ] 4.2 `test/dispute_form_validation_test.dart`:
  - Test: UTR empty → validation rejects.
  - Test: amount > 500000 → validation rejects.
  - Test: amount = 0 → validation rejects (already works, confirm).
  - Test: description maxLength 500 enforced.
- [ ] 4.3 Verify all 183 existing tests still pass.
- [ ] 4.4 `flutter analyze` → 0 issues.

## Execution Order

Tracks 1, 2, 3 are independent (different files) and can be dispatched in parallel. Track 4 depends on 1+2+3.

- Wave A (parallel): Track 1 (escalate), Track 2 (form), Track 3 (bank catalog).
- Wave B (after A): Track 4 (tests + verification).
- Final: push, monitor GitHub Actions.

## Verification Gate

Before claiming done:
1. `/home/ubuntu/flutter-sdk/bin/flutter analyze` → 0 issues.
2. `/home/ubuntu/flutter-sdk/bin/flutter test` → all pass.
3. `git diff --check` → no whitespace errors.
4. Push → GitHub Actions `Analyze + Test` → green.
