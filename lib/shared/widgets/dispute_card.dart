import 'package:flutter/material.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/services/compensation_calculator.dart';

class DisputeCard extends StatelessWidget {
  final Dispute dispute;
  final VoidCallback onTap;
  const DisputeCard({super.key, required this.dispute, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final comp = CompensationCalculator.compute(dispute);
    return InkWell(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dispute.type.id.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  Chip(
                    label: Text(dispute.status.value,
                        style: const TextStyle(fontSize: 11)),
                    backgroundColor: const Color(0xFF16C784).withValues(alpha: 0.15),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                CompensationCalculator.formatIndian(dispute.amount),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              if (comp.compensationDue > 0) ...[
                const SizedBox(height: 4),
                Text('Owed: ${CompensationCalculator.formatIndian(comp.compensationDue)}',
                    style: TextStyle(
                        color: const Color(0xFFF5A623),
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ],
              const SizedBox(height: 8),
              MiniStepper(
                levels: dispute.type.id == 'fastag'
                    ? 5
                    : dispute.type.id == 'bank_charge'
                        ? 2
                        : 3,
                current: _currentLevel(dispute),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _currentLevel(Dispute d) {
    if (d.status == DisputeStatus.resolved) return 99;
    if (d.status == DisputeStatus.ombudsman) return 3;
    if (d.status == DisputeStatus.filedL2) return 2;
    if (d.status == DisputeStatus.filedL1) return 1;
    return 0;
  }
}

class MiniStepper extends StatelessWidget {
  final int levels;
  final int current;
  const MiniStepper({super.key, required this.levels, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(levels, (i) {
        final done = i < current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < levels - 1 ? 4 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: done ? const Color(0xFF16C784) : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
