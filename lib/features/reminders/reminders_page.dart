import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/data/extensions/dispute_type_display.dart';
import 'package:refund_radar/data/models/reminder.dart';
import 'package:refund_radar/data/repositories/reminder_repository.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/shared/widgets/app_back_button.dart';
import 'package:refund_radar/shared/widgets/branded_error_banner.dart';
import 'package:refund_radar/shared/widgets/skeleton.dart';

class RemindersPage extends ConsumerWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uidAsync = ref.watch(userIdProvider);
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 8),
                  Text(
                    'Reminders',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryLight,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: uidAsync.when(
                loading: () => const SkeletonList(itemCount: 4, itemHeight: 84),
                error: (e, _) => BrandedErrorBanner(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(userIdProvider),
                ),
                data: (uid) {
                  if (uid == null) return const _EmptyState();
                  final remindersAsync = ref.watch(remindersProvider(uid));
                  return remindersAsync.when(
                    loading: () => const SkeletonList(itemCount: 4, itemHeight: 84),
                    error: (e, _) => BrandedErrorBanner(
                      message: e.toString(),
                      onRetry: () => ref.invalidate(remindersProvider(uid)),
                    ),
                    data: (reminders) {
                      final active =
                          reminders.where((r) => !r.dismissed).toList();
                      if (active.isEmpty) {
                        return const _EmptyState();
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        itemCount: active.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final r = active[i];
                          return _ReminderCard(reminder: r);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderCard extends ConsumerWidget {
  final Reminder reminder;
  const _ReminderCard({required this.reminder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = reminder.disputeType;
    final now = DateTime.now();
    final delta = reminder.fireAt.difference(now);
    final overdue = delta.isNegative;
    final daysLeft = delta.inDays;
    final subtitle = overdue
        ? 'Overdue by ${-daysLeft} ${-daysLeft == 1 ? 'day' : 'days'}'
        : daysLeft == 0
            ? 'Due today'
            : 'In $daysLeft ${daysLeft == 1 ? 'day' : 'days'}';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: overdue
              ? AppColors.error.withValues(alpha: 0.30)
              : AppColors.dividerLight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emoji tile
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: type.softColor.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(type.emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          // Text block
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reminder.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryLight,
                            ),
                      ),
                    ),
                    Text(
                      overdue ? 'OVERDUE' : reminder.stage.displayName.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            letterSpacing: 0.6,
                            color: overdue ? AppColors.error : AppColors.textTertiaryLight,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reminder.body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryLight,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      overdue ? Icons.warning_amber_rounded : Icons.schedule_rounded,
                      size: 14,
                      color: overdue ? AppColors.error : AppColors.textTertiaryLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: overdue ? AppColors.error : AppColors.textTertiaryLight,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () async {
                        await ref
                            .read(reminderRepositoryProvider)
                            .dismiss(reminder.uid, reminder.id);
                        ref.invalidate(remindersProvider(reminder.uid));
                      },
                      child: Text(
                        'Dismiss',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => context.go('/disputes/${reminder.disputeId}'),
                      child: Text(
                        'Open',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_none_outlined,
                size: 64, color: AppColors.accent),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)?.remindersNoneUpcoming ??
                  'No upcoming reminders',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryLight,
                  )),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)?.remindersEmptySubtitle ??
                  'Reminders appear when you create or escalate a dispute — '
                  'so you never miss a 30-day follow-up window.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryLight,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/home'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                AppLocalizations.of(context)?.remindersTrackNew ??
                    'Track a new dispute',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
