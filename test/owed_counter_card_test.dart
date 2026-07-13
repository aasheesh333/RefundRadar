import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/shared/widgets/owed_counter_card.dart';

void main() {
  group('OwedCounterCard animation', () {
    testWidgets('counter settles at totalOwed and stays (no oscillation)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OwedCounterCard(
              totalOwed: 50000,
              disputeCount: 3,
              perDay: 100,
            ),
          ),
        ),
      );

      // Let the forward animation (600ms) complete.
      await tester.pump(const Duration(milliseconds: 700));

      // The displayed amount should be ₹ 50,000 — not 0, not oscillating.
      expect(find.text('₹ 50,000'), findsOneWidget);

      // Pump past the OLD pulse period (1400ms) to verify the amount
      // does NOT oscillate back to 0. This is the regression test for
      // the single-controller repeat(reverse:true) bug.
      await tester.pump(const Duration(milliseconds: 1400));
      expect(find.text('₹ 50,000'), findsOneWidget);

      // Pump even further — should still be stable.
      await tester.pump(const Duration(milliseconds: 2800));
      expect(find.text('₹ 50,000'), findsOneWidget);
    });

    testWidgets('counter updates when totalOwed changes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OwedCounterCard(
              totalOwed: 30000,
              disputeCount: 2,
              perDay: 50,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('₹ 30,000'), findsOneWidget);

      // Rebuild with a new total — didUpdateWidget should re-run the
      // count-up from old to new value.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OwedCounterCard(
              totalOwed: 75000,
              disputeCount: 5,
              perDay: 200,
            ),
          ),
        ),
      );

      // After rebuild, the tween goes from 30000 → 75000. The value
      // mid-animation is between the two, so we don't check immediately.
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('₹ 75,000'), findsOneWidget);

      // Verify it stays.
      await tester.pump(const Duration(milliseconds: 1400));
      expect(find.text('₹ 75,000'), findsOneWidget);
    });

    testWidgets('zero amount shows ₹ 0 and stays', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OwedCounterCard(
              totalOwed: 0,
              disputeCount: 0,
              perDay: 0,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('₹ 0'), findsOneWidget);

      // Should not oscillate.
      await tester.pump(const Duration(milliseconds: 1400));
      expect(find.text('₹ 0'), findsOneWidget);
    });
  });
}
