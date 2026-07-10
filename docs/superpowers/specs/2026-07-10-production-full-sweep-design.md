# 2026-07-10 Production Full Sweep — Design Spec

**Status:** Approved (user: B — full production sweep, subagent-driven, 6+ agents)
**App:** RefundRadar (Flutter, Android-first)
**Prior pass:** 2026-07-09 fixed dark softs, create silent fail, empty CTAs, escalate TO/CC.

## Problem statement

Production-readiness audit found 3 blockers + 18 majors + 8 minors still open after the
2026-07-09 pass. The app would ship with: wrong/overwriting reminders, data loss on flaky
saves, wrong timezone alerts, broken win/loss history, premium bypass, infinite auth
spinners, placebo settings, discarded descriptions/templates/banks, and large English-only
surfaces in Hindi.

## Goals / success criteria

| Gate | Pass |
|------|------|
| Reminders | L1/L2/Ombudsman unique notification IDs; Ombudsman fires after wizard L3 (key alignment) |
| Create | Dispute never deleted because reminders/analytics failed (best-effort side effects) |
| Timezone | Notifications use device local TZ (IST on Indian devices) |
| Resolve/History | Mark resolved sets amount; win-rate/TOTAL WON correct; Escalated filter works; home non-terminal only |
| Escalate | Mail app opens (mailto queries); auth hang shows retry not infinite spinner |
| Premium | `/ombudsman/:id` gated for free users |
| Auth UX | Detail/escalate/ombudsman show BrandedErrorBanner on auth failure |
| Data honesty | Description saved; templates filled; onboard banks used; Delete data works; session refresh warns |
| Settings | Placebo daily/weekly toggles removed/disabled honestly |
| Monetization | RevenueCat `logIn(firebaseUid)`; FCM reeval fires on cold start |
| i18n | No hard-only English on home empty, cards, SMS, banks, residual snackbars |
| Touch | Filter pills + radio rows >= 48dp |
| Quality | `flutter analyze` 0; `flutter test` green |

## Non-goals

- Play Store submit, iOS, brand hex redesign, OpenDesign, live RevenueCat Play keys.
- Brand color changes.
- New features.

## Architecture rules

1. Soft surfaces only via `AppThemeColors` / `bgFor` / `softColorFor`.
2. Auth-sensitive actions: await `userIdProvider.future` + SnackBar/retry — never silent, never infinite spinner.
3. Post-save side effects (reminders, analytics) are **best-effort** — never roll back committed disputes.
4. Filed-date key vocabulary: **`l1` | `l2` | `ombudsman`** (wizard migrates off `l3`). Generator tolerates legacy `l3` during migration.
5. Notification ID = stable hash of **reminder id** (`'${disputeId}_${stage.id}'`), not dispute alone.

## Phases

### Phase 1 — Reminder & create integrity (blockers)
- B1: Wizard `_ticketKeyForLevel(2+)` -> `'ombudsman'`; generator tolerates legacy `l3`.
- B2: `scheduleDeadlineReminder` takes `reminderId`; unique IDs; `cancelForReminder` / cancel-all-for-dispute by known ids.
- B3: Remove rollback `deleteDispute` on post-save failure.
- B4: Set local timezone in `NotificationService.init`.

### Phase 2 — Resolve, home, history
- M1: On resolve, `resolvedAmount: dispute.amount`.
- M2: `copyWith` clear `resolvedAt`; reopen -> highest filed status.
- M3: Home non-terminal only.
- M4: Escalated filter (open escalated OR past-with-ombudsman-filed).

### Phase 3 — Platform & monetization
- M5: AndroidManifest mailto/https/tel queries.
- M6: Ombudsman page premium gate.
- M10: RC `Purchases.logIn(firebaseUid)`.
- M11: FCM reeval fires on cold start.
- U1: Auth error UI on detail/escalate/ombudsman.

### Phase 4 — Product honesty
- M7: Persist `description` on Dispute + form + repos.
- M8: `Template.fill` called before copy/preview.
- M9: Form bank picker uses onboard selection.
- M10b: Settings Delete data + honest session refresh.
- M12: Disable/honest daily/weekly toggles if unimplemented.

### Phase 5 — UI/UX polish
- U2: Residual i18n (home empty, cards, SMS, banks, snackbars, escalate labels).
- U3: Filter pills + radio rows >= 48dp.
- U4: Dark CTA consistency (accent + dark fg).
- Minor soft/chip/shadow cleanups.

### Phase 6 — Tests & gate
- Unit tests for: reminder key ombudsman, notification id uniqueness, resolve sets amount, copyWith clear resolvedAt, home filter.
- `flutter analyze` 0; `flutter test` green; update PROGRESS.md.

## Risks

| Risk | Mitigation |
|------|------------|
| Existing Firestore docs with `l3` key | Generator reads both `ombudsman` and `l3` |
| `flutter_timezone` plugin friction | Fallback `Asia/Kolkata` if plugin unavailable |
| Description schema change | Optional field; default empty; rules already loose |
| i18n volume | Batch by surface; keep English `??` fallbacks |
| Merge conflicts across phases | Phase 1 lands first; others touch disjoint files |

## Rollout

Subagent-driven, 6+ agents in parallel where files are disjoint. Commit per phase. No redesign.
Gate at end of each phase: `dart analyze` on touched files.
