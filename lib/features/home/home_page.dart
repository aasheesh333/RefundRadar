import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
import 'package:refund_radar/services/compensation_calculator.dart';
import 'package:refund_radar/shared/widgets/owed_counter_card.dart';
import 'package:refund_radar/shared/widgets/dispute_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uidAsync = ref.watch(userIdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Refund Radar')),
      body: uidAsync.when(
        data: (uid) {
          if (uid == null) return const Center(child: Text('Loading...'));
          final disputesAsync = ref.watch(disputesProvider(uid));
          return disputesAsync.when(
            data: (disputes) {
              if (disputes.isEmpty) return const _EmptyState();
              final totalOwed = disputes.fold<double>(
                  0, (sum, d) => sum + CompensationCalculator.compute(d).compensationDue);
              final perDay = disputes.fold<double>(0,
                  (sum, d) => sum + (d.type.compensationPerDay ?? 0).toDouble());
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  OwedCounterCard(
                    totalOwed: totalOwed,
                    disputeCount: disputes.length,
                    perDay: perDay,
                  ),
                  const SizedBox(height: 16),
                  ...disputes.map((d) => DisputeCard(
                        dispute: d,
                        onTap: () => context.go('/disputes/${d.id}'),
                      )),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/disputes/create'),
        icon: const Icon(Icons.add),
        label: const Text('New dispute'),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.money_off_csred, size: 64, color: Color(0xFF16C784)),
            const SizedBox(height: 16),
            Text('No disputes yet', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Add your first stuck transaction to start tracking compensation.',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/disputes/create'),
              icon: const Icon(Icons.add),
              label: const Text('Add dispute'),
            ),
          ],
        ),
      ),
    );
  }
}
