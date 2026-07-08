import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:refund_radar/core/providers/auth_provider.dart';
import 'package:refund_radar/core/providers/dispute_provider.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/services/compensation_calculator.dart';
import 'package:refund_radar/shared/widgets/danger_banner.dart';
import 'package:refund_radar/shared/widgets/stepper_timeline.dart';

class DisputeDetailPage extends ConsumerWidget {
  final String id;
  const DisputeDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(userIdProvider).asData?.value;
    if (uid == null) return Scaffold(body: const Center(child: CircularProgressIndicator()));
    final disputesAsync = ref.watch(disputesProvider(uid));
    return Scaffold(
      appBar: AppBar(title: const Text('Dispute')),
      body: disputesAsync.when(
        data: (disputes) {
          final dispute = disputes.firstWhere(
            (d) => d.id == id,
            orElse: () => Dispute(
              id: id, type: DisputeType.upiP2p, amount: 0,
              txnDate: DateTime.now(), txnId: '', createdAt: DateTime.now(),
            ),
          );
          return _DisputeBody(dispute: dispute);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _DisputeBody extends StatelessWidget {
  final Dispute dispute;
  const _DisputeBody({required this.dispute});

  @override
  Widget build(BuildContext context) {
    final comp = CompensationCalculator.compute(dispute);
    final daysToExpiry = dispute.type == DisputeType.fastag
        ? CompensationCalculator.daysUntilFastagExpiry(dispute)
        : CompensationCalculator.daysUntilChargebackExpiry(dispute);
    final showDanger = daysToExpiry < 7 && daysToExpiry > 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFF0B3D2E),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Compensation owed',
                    style: TextStyle(color: Color(0xFFE8F0EC), fontSize: 12)),
                const SizedBox(height: 8),
                Text(
                  CompensationCalculator.formatIndian(comp.compensationDue),
                  style: const TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFFF5A623),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${comp.daysElapsed} days * ${dispute.type.id.toUpperCase()} * ${CompensationCalculator.formatIndian(dispute.amount)}',
                  style: const TextStyle(color: Color(0xFFE8F0EC), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (showDanger) ...[
          DangerBanner(
            message: 'Dispute window closing in $daysToExpiry days! Escalate now.',
            onAction: () => context.push('/wizard/${dispute.id}'),
            actionLabel: 'Escalate',
          ),
          const SizedBox(height: 16),
        ],
        _Timeline(dispute: dispute),
        const SizedBox(height: 16),
        if (dispute.type.id != 'wrong_transfer') ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/wizard/${dispute.id}'),
              icon: const Icon(Icons.gavel),
              label: const Text('Open wizard'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFF0B3D2E),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/ombudsman/${dispute.id}'),
              icon: const Icon(Icons.article),
              label: const Text('Ombudsman letter generator'),
            ),
          ),
        ],
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  final Dispute dispute;
  const _Timeline({required this.dispute});

  @override
  Widget build(BuildContext context) {
    final levels = _levelsForType(dispute.type);
    return StepperTimeline(
      items: List.generate(levels.length, (i) {
        final done = _isDone(i, dispute);
        final current = _isCurrent(i, dispute);
        return StepperItem(
          title: levels[i],
          isDone: done,
          isCurrent: current,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(levels[i], style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              const Text('Follow the wizard for detailed steps.'),
            ],
          ),
        );
      }),
    );
  }

  List<String> _levelsForType(DisputeType t) {
    switch (t) {
      case DisputeType.fastag:
        return ['File with issuer bank', '1033 Helpline', 'IHMCL email', 'NPCI NETC', 'RBI Ombudsman'];
      case DisputeType.bankCharge:
        return ['Bank complaint', 'RBI Ombudsman'];
      case DisputeType.wrongTransfer:
        return ['Your bank request', 'NPCI DRM', 'Cyber cell', 'Legal notice'];
      default:
        return ['Level 1: UPI app + own bank', 'Level 2: NPCI portal', 'Level 3: RBI Ombudsman'];
    }
  }

  bool _isDone(int i, Dispute d) {
    if (d.status == DisputeStatus.resolved) return true;
    if (i == 0) return d.status != DisputeStatus.draft;
    if (i == 1) return d.status == DisputeStatus.filedL2 || d.status == DisputeStatus.ombudsman;
    if (i >= 2) return d.status == DisputeStatus.ombudsman;
    return false;
  }

  bool _isCurrent(int i, Dispute d) {
    if (d.status == DisputeStatus.resolved) return false;
    if (i == 0) return d.status == DisputeStatus.draft;
    if (i == 1) return d.status == DisputeStatus.filedL1;
    if (i == 2) return d.status == DisputeStatus.filedL2;
    return false;
  }
}
