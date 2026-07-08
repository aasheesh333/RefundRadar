import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PaywallPage extends StatelessWidget {
  final String returnPath;
  const PaywallPage({super.key, required this.returnPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Go Premium')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.workspace_premium, size: 72, color: Color(0xFFF5A623)),
          const SizedBox(height: 16),
          const Text(
            'Recover more. Unlimited disputes + 50+ templates.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _PlanCard(
                  title: 'Monthly',
                  price: '₹99',
                  highlighted: false,
                  onTap: () => context.go(returnPath),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PlanCard(
                  title: 'Yearly',
                  price: '₹499',
                  highlighted: true,
                  badge: 'Save 58%',
                  onTap: () => context.go(returnPath),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _ComparisonTable(),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {},
            child: const Text('Restore purchases'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go(returnPath),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFF0B3D2E),
            ),
            child: const Text('Maybe later'),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final bool highlighted;
  final String? badge;
  final VoidCallback onTap;
  const _PlanCard({
    required this.title,
    required this.price,
    required this.highlighted,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: highlighted ? const Color(0xFF16C784) : Colors.grey.shade300,
            width: highlighted ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF16C784).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge!,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF16C784))),
              ),
              const SizedBox(height: 8),
            ],
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(price,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable();
  @override
  Widget build(BuildContext context) {
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder.symmetric(
        inside: BorderSide(color: Colors.grey.shade200),
      ),
      children: const [
        TableRow(children: [
          Padding(padding: EdgeInsets.all(12), child: Text('')),
          Padding(padding: EdgeInsets.all(12), child: Text('Free', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600))),
          Padding(padding: EdgeInsets.all(12), child: Text('Premium', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600))),
        ]),
        TableRow(children: [
          Padding(padding: EdgeInsets.all(12), child: Text('Active disputes')),
          Padding(padding: EdgeInsets.all(12), child: Text('1', textAlign: TextAlign.center)),
          Padding(padding: EdgeInsets.all(12), child: Text('Unlimited', textAlign: TextAlign.center)),
        ]),
        TableRow(children: [
          Padding(padding: EdgeInsets.all(12), child: Text('Templates')),
          Padding(padding: EdgeInsets.all(12), child: Text('5', textAlign: TextAlign.center)),
          Padding(padding: EdgeInsets.all(12), child: Text('50+', textAlign: TextAlign.center)),
        ]),
        TableRow(children: [
          Padding(padding: EdgeInsets.all(12), child: Text('Ombudsman letter generator')),
          Padding(padding: EdgeInsets.all(12), child: Icon(Icons.close, color: Colors.grey)),
          Padding(padding: EdgeInsets.all(12), child: Icon(Icons.check, color: Color(0xFF16C784))),
        ]),
        TableRow(children: [
          Padding(padding: EdgeInsets.all(12), child: Text('Hindi premium templates')),
          Padding(padding: EdgeInsets.all(12), child: Icon(Icons.close, color: Colors.grey)),
          Padding(padding: EdgeInsets.all(12), child: Icon(Icons.check, color: Color(0xFF16C784))),
        ]),
      ],
    );
  }
}
