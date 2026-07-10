# 2026-07-10 Production Hardening With SMS — Design Spec

**Status:** Approved in chat for design direction; written spec pending user review  
**App:** RefundRadar (Flutter, Android-first)  
**Decision:** Keep real SMS inbox import and declare SMS permission in Play Console

## Problem Statement

RefundRadar has passed the prior production sweep, but a final audit found release-quality
risks that still need a focused hardening pass. The largest product decision is SMS: the app
will keep `READ_SMS` and real inbox import for best UX, so the implementation must be honest
about Android inbox access, keep a manual fallback, and support Play Console declaration review.

Other production risks are correctness issues: notification IDs currently depend on Dart
`String.hashCode`, dismissed reminders may leave local notifications scheduled, and premium
template access may still appear locked for paid users.

## Goals / Success Criteria

| Area | Pass Criteria |
|------|---------------|
| SMS permission | Keep `READ_SMS`; consent copy accurately says Android grants inbox access and parsing is on-device |
| SMS fallback | Users can decline permission and still paste SMS manually without dead ends |
| SMS native query | Native inbox query only requests fields the app uses, where Android APIs allow it |
| Play declaration support | README or release notes include concise SMS declaration guidance matching app behavior |
| Notifications | Local notification IDs are stable across app launches and SDK versions |
| Reminder dismiss | Dismissing a reminder cancels the matching scheduled local notification |
| Premium templates | Premium users see premium templates unlocked consistently in library, preview, and copy flows |
| UI polish | SMS, reminders, templates, and empty/error states communicate clearly without redesign |
| Quality gate | `flutter analyze` passes; targeted tests pass locally; GitHub Actions full Analyze + Test passes after push |

## Non-Goals

- Removing SMS inbox import or moving to paste-only.
- Building a non-Play/internal SMS flavor split.
- iOS support.
- Play Store submission itself.
- A new brand system, new theme colors, or OpenDesign work.
- New major features outside SMS hardening, notification correctness, template access, and targeted UX polish.

## Approach Considered

### Recommended: Keep SMS And Harden Compliance

Keep the current platform-channel SMS architecture, but fix misleading permission language and
tighten the implementation around privacy, fallback UX, and Play declaration consistency. This
preserves the best refund-detection UX while making the behavior easier to explain and review.

### Alternative: Hybrid Play/Internal Split

Use paste/manual import in Play builds and SMS import only in internal builds. This lowers Play
policy risk but conflicts with the product decision to declare SMS permission and ship inbox import.

### Alternative: Paste-Only

Remove SMS permission and rely on manual paste. This is safest for Play policy but worsens the
core onboarding/create flow and is out of scope for this pass.

## Architecture Rules

1. SMS import remains on-device: native Android reads inbox rows, Dart filters likely financial/refund messages, and parsing does not upload raw SMS for import.
2. Permission copy must not claim the app can technically access only financial SMS. It must state that Android grants inbox access and RefundRadar scans locally for relevant messages.
3. Manual paste remains first-class. Permission denial must not block dispute creation.
4. Notification IDs must be deterministic from stable string input using app-owned code, not Dart `String.hashCode`.
5. Reminder lifecycle changes must update both persisted reminder state and local scheduled notifications when possible.
6. Premium access checks must be consistent across list, preview, and copy actions.
7. UI changes should use existing components, localization patterns, and `AppThemeColors`; no broad redesign.

## Design

### SMS Permission And Import

Current files:

- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/dhanuk/refundradar/MainActivity.kt`
- `lib/services/sms_inbox_service.dart`
- `lib/features/sms_permission/sms_permission_page.dart`
- `lib/features/dispute_create/dispute_form_page.dart`

The app will keep `android.permission.READ_SMS`. The permission screen will be rewritten around
accurate consent:

- Android grants SMS inbox access when the user accepts.
- RefundRadar scans messages on-device to find likely refund-related bank or merchant messages.
- Users can skip permission and paste an SMS manually.
- SMS parsing is used to prefill dispute details.
- The app should avoid saying it reads "only financial SMS" because the permission itself is broader.

The native `queryInbox` implementation should keep the smallest practical projection, such as SMS
id, sender/address, body, and date. Dart filtering stays in `SmsInboxService`, because Android SMS
providers do not reliably support semantic financial-message filtering at query time.

The dispute form should preserve the Inbox/Paste split and improve denial/no-match feedback:

- If permission is denied, show a clear message with a Paste SMS action.
- If inbox import returns no likely refund SMS, explain that the user can paste a message or enter details manually.
- Loading, empty, and error states should not imply the app is stuck.

README or release notes should include Play Console declaration guidance aligned with the UI:

- Core feature: detect refund-related bank/merchant SMS and prefill refund dispute forms.
- Access: SMS inbox read permission.
- Handling: on-device filtering/parsing for import; manual paste fallback available.
- User benefit: reduces manual data entry and helps identify eligible refund/failed-transaction disputes.

### Notification Correctness

Current files:

- `lib/services/notification_service.dart`
- `lib/data/repositories/reminder_repository.dart`
- `lib/features/reminders/reminders_page.dart`
- `test/notification_service_test.dart`

Replace notification IDs based on `String.hashCode` with an app-owned stable deterministic hash.
A simple FNV-1a style 32-bit hash is sufficient:

- Input: reminder id, such as `${disputeId}_${stage.id}`.
- Output: positive signed 31-bit integer for Android notification APIs.
- Behavior: fixed for the same input across app launches, Dart versions, and devices.

Tests should assert fixed expected IDs for representative reminder IDs. This avoids tests that only
prove same-process determinism.

Reminder dismissal should cancel local notifications for the same reminder. The repository or action
path should call the existing cancellation capability and treat cancellation failures as best-effort
after persisted dismissal succeeds. The user-facing result should remain responsive and not roll back
the dismissal solely because local notification cancellation failed.

### Premium Template Access

Current files:

- `lib/features/templates/template_library_page.dart`
- `lib/features/templates/template_preview_page.dart`
- entitlement/premium provider files discovered during implementation

Premium template lock state must come from one consistent access decision. Library cards, preview
page, and copy action should agree:

- Free user + premium template: show locked state and upgrade path.
- Premium user + premium template: show unlocked state and allow preview/copy.
- Unknown entitlement/loading: avoid granting premium access until known, but do not permanently lock paid users after entitlement resolves.

Prefer a small shared helper or provider usage pattern only if it reduces duplication. Do not add a
new entitlement abstraction unless the existing code is inconsistent enough to require it.

### UI/UX Polish

This pass should improve production clarity without redesigning the app.

Targeted surfaces:

- SMS permission screen: honest consent, trust note, and manual fallback.
- Dispute form SMS import: clear loading, denied, no-match, and paste states.
- Reminders: dismissal should feel final and match local notification behavior.
- Templates: premium lock/unlock state should update promptly and consistently.
- Empty/error states: use existing branded components and localized strings where practical.

All UI should preserve existing visual language and theme helpers.

## Testing Plan

Add or update targeted tests for:

- Stable notification ID fixed values.
- Reminder dismissal calling local notification cancellation where testable.
- SMS service filtering behavior remains intact after native/query contract changes.
- Permission-denied or no-match SMS UI behavior if existing widget-test patterns make this practical.
- Premium template access for free, premium, and loading/unknown entitlement states.

Verification commands:

- `/home/ubuntu/flutter-sdk/bin/flutter analyze`
- Targeted `/home/ubuntu/flutter-sdk/bin/flutter test ...` for changed areas.
- GitHub Actions full `Analyze + Test` after push.

Do not run a full local Flutter test suite or APK build unless explicitly approved, because this host
has prior OOM/crash risk.

## Rollout

Implement in small commits or phases:

1. SMS copy, fallback UX, native projection, and Play declaration docs.
2. Stable notification IDs and reminder dismissal cancellation.
3. Premium template access consistency.
4. Targeted tests, analyze, Actions verification, and `PROGRESS.md` update if appropriate.

## Risks And Mitigations

| Risk | Mitigation |
|------|------------|
| Play rejects broad SMS use despite declaration | Keep UI/docs truthful; document core feature justification; maintain paste fallback for future pivot |
| Native SMS providers vary by device | Keep projection minimal and tolerant of missing fields; Dart parser handles incomplete rows |
| Notification ID migration leaves old scheduled notifications | Repair/cancel known reminder notifications where possible; stable IDs apply going forward |
| Dismiss cancellation fails after Firestore update | Treat local cancellation as best-effort and do not roll back dismissed state |
| Premium entitlement loads asynchronously | Use loading/unknown state deliberately and refresh UI once resolved |
