import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _pc.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: _pc,
              onPageChanged: (i) => setState(() => _page = i),
              children: const [
                _Slide(
                  title: '₹100/day — banks owe YOU\nfor failed UPI',
                  desc: 'RBI rules make banks pay compensation for delayed refunds.',
                  icon: Icons.payments_rounded,
                ),
                _Slide(
                  title: 'FASTag double-cut?\n30 din ka window',
                  desc: 'NPCI mandates 30 days to dispute toll deductions.',
                  icon: Icons.directions_car_rounded,
                ),
                _Slide(
                  title: 'We guide, you claim\nRBI-rule backed',
                  desc: 'Smart deadlines, pre-made complaints, escalation ladder.',
                  icon: Icons.gavel_rounded,
                ),
              ],
            ),
            Positioned(
              top: 16,
              right: 16,
              child: TextButton(onPressed: () => context.go('/home'), child: const Text('Skip')),
            ),
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      final active = _page == i;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFF16C784) : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: const Color(0xFF0B3D2E),
                      ),
                      child: Text(_page < 2 ? 'Next' : 'Start free'),
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Independent tool · Not affiliated with RBI/NPCI/banks',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  const _Slide({required this.title, required this.desc, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 96, color: const Color(0xFF16C784)),
          const SizedBox(height: 24),
          Text(title, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2)),
          const SizedBox(height: 16),
          Text(desc, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.grey)),
        ],
      ),
    );
  }
}
