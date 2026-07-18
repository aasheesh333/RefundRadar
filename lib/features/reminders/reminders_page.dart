import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/router/app_routes.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/data/extensions/dispute_type_display.dart';
import 'package:refund_radar/data/models/reminder.dart';
import 'package:refund_radar/data/repositories/reminder_repository.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/shared/widgets/branded_error_banner.dart';
import 'package:refund_radar/shared/utils/error_mapper.dart';
import 'package:refund_radar/shared/utils/date_time_ext.dart';
import 'package:refund_radar/shared/widgets/skeleton.dart';

class RemindersPage extends ConsumerWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    final uidAsync = ref.watch(userIdProvider);
    return Scaffold(
      backgroundColor: tc.bg,
      body: SafeArea(
        child: uidAsync.when(
          loading: () => const SkeletonList(itemCount: 4, itemHeight: 84),
          error: (e, _) => BrandedErrorBanner(
            message: friendlyError(e),
            detail: errorDetail(e),
            onRetry: () => ref.invalidate(userIdProvider),
          ),
          data: (uid) {
            if (uid == null) {
              final authErr = ref.watch(lastAuthErrorProvider);
              return BrandedErrorBanner(
                message: authErr != null &&
                        authErr.toLowerCase().contains('operation-not-allowed')
                    ? 'Anonymous sign-in is disabled. Enable it in Firebase Console → Authentication → Sign-in method → Anonymous.'
                    : 'Could not sign in. Check your connection and try again.',
                detail: authErr,
                onRetry: () async {
                  await ref.read(reauthProvider)();
                  ref.invalidate(userIdProvider);
                },
              );
            }
            final remindersAsync = ref.watch(remindersProvider(uid));
            return remindersAsync.when(
              loading: () =>
                  const SkeletonList(itemCount: 4, itemHeight: 84),
              error: (e, _) => BrandedErrorBanner(
                message: friendlyError(e),
                detail: errorDetail(e),
                onRetry: () => ref.invalidate(remindersProvider(uid)),
              ),
              data: (reminders) {
                final active =
                    reminders.where((r) => !r.dismissed).toList();
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _PageHeader(tc: tc, l10n: l10n),
                    ),
                    if (active.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        sliver: SliverList.separated(
                          itemCount: active.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) =>
                              _ReminderCard(reminder: active[i]),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final AppThemeColors tc;
  final AppLocalizations? l10n;
  const _PageHeader({required this.tc, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 10),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: tc.textPrimary),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              l10n?.remindersTitle ?? 'Reminders',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: tc.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends ConsumerWidget {
  final Reminder reminder;
  const _ReminderCard({required this.reminder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    final type = reminder.disputeType;
    final now = DateTime.now();
    final daysLeft = reminder.fireAt.differenceInDays(now);
    final overdue = daysLeft < 0;
    final subtitle = overdue
        ? (daysLeft == -1
            ? 'Overdue today — escalate now'
            : 'Overdue by ${-daysLeft} ${-daysLeft == 1 ? 'day' : 'days'}')
        : daysLeft == 0
            ? 'Due today'
            : 'In $daysLeft ${daysLeft == 1 ? 'day' : 'days'}';
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.md),
      onTap: () =>
          context.push(AppRoutes.disputeDetail(reminder.disputeId)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tc.surface,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: overdue ? AppColors.error.withValues(alpha: 0.30) : tc.divider,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: type.softColorFor(tc),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Text(type.emoji, style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          reminder.title,
                          style: TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: tc.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: overdue ? tc.errorSoft : tc.surfaceAlt,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          overdue
                              ? 'OVERDUE'
                              : reminder.stage.displayName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color:
                                overdue ? AppColors.error : tc.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reminder.body,
                    style: TextStyle(
                      fontSize: 12,
                      color: tc.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        overdue
                            ? Icons.warning_amber_rounded
                            : Icons.schedule_rounded,
                        size: 12,
                        color: overdue ? AppColors.error : tc.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              overdue ? AppColors.error : tc.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final l10n = AppLocalizations.of(context);
                          try {
                            await dismissReminderAndCancelNotification(
                              ref,
                              reminder.uid,
                              reminder.id,
                            );
                            ref.invalidate(remindersProvider(reminder.uid));
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n?.remindersDismissed ??
                                      'Reminder dismissed',
                                ),
                              ),
                            );
                          } catch (_) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n?.remindersDismissFailed ??
                                      'Could not dismiss. Reconnect and try again.',
                                ),
                              ),
                            );
                          }
                        },
                        child: Text(
                          l10n?.remindersDismissAction ?? 'Dismiss',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: tc.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => context.push(
                            AppRoutes.disputeDetail(reminder.disputeId)),
                        child: Text(
                          l10n?.remindersOpenAction ?? 'Open',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: tc.ctaBackground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tc.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.notifications_none_outlined,
                  size: 36, color: tc.ctaBackground),
            ),
            const SizedBox(height: 20),
            Text(
              l10n?.remindersNoneUpcoming ?? 'No upcoming reminders',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: tc.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n?.remindersEmptySubtitle ??
                  'Reminders appear when you create or escalate a dispute — '
                  'so you never miss a 30-day follow-up window.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: tc.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: tc.ctaBackground,
                foregroundColor: tc.ctaForeground,
              ),
              onPressed: () => context.push(AppRoutes.disputesCreate),
              child: Text(l10n?.remindersTrackNew ?? 'Track a new dispute'),
            ),
          ],
        ),
      ),
    );
  }
}
