import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DisputeTypePage extends StatelessWidget {
  const DisputeTypePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New dispute')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
        children: [
          _TypeCard(
            label: 'Failed UPI',
            sub: 'P2P / P2M / IMPS',
            icon: Icons.payments,
            onTap: () => context.push('/disputes/form?type=upi_p2p'),
          ),
          _TypeCard(
            label: 'FASTag',
            sub: 'Wrong toll deduction',
            icon: Icons.directions_car,
            onTap: () => context.push('/disputes/form?type=fastag'),
          ),
          _TypeCard(
            label: 'ATM',
            sub: 'Cash not dispensed',
            icon: Icons.atm,
            onTap: () => context.push('/disputes/form?type=atm'),
          ),
          _TypeCard(
            label: 'Bank charge',
            sub: 'Wrong / hidden fee',
            icon: Icons.account_balance,
            onTap: () => context.push('/disputes/form?type=bank_charge'),
          ),
          _TypeCard(
            label: 'Wrong transfer',
            sub: 'Wrong UPI ID',
            icon: Icons.send,
            onTap: () => context.push('/disputes/form?type=wrong_transfer'),
          ),
          _TypeCard(
            label: 'IMPS',
            sub: 'Money not credited',
            icon: Icons.bolt,
            onTap: () => context.push('/disputes/form?type=imps'),
          ),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String label;
  final String sub;
  final IconData icon;
  final VoidCallback onTap;
  const _TypeCard({
    required this.label,
    required this.sub,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: const Color(0xFF16C784)),
              const SizedBox(height: 12),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(sub,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
