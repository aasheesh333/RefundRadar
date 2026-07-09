import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/shared/widgets/branded_error_banner.dart';
import 'package:refund_radar/shared/widgets/hero_emoji_circle.dart';
import 'package:refund_radar/shared/widgets/info_banner.dart';
import 'package:refund_radar/shared/widgets/radio_row.dart';
import 'package:refund_radar/shared/widgets/stepper_timeline.dart';

Widget _wrap(Widget child, {required bool dark}) {
  return MaterialApp(
    theme: ThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  group('InfoBanner soft backgrounds', () {
    testWidgets('dark success uses theme accentSoft not light pastel',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const InfoBanner(
            kind: InfoKind.success,
            message: TextSpan(text: 'ok'),
          ),
          dark: true,
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(InfoBanner),
          matching: find.byType(Container),
        ).first,
      );
      final dark = AppThemeColors.forTest(isDark: true);
      expect((container.decoration as BoxDecoration).color, dark.accentSoft);
      expect((container.decoration as BoxDecoration).color,
          isNot(AppColors.accentSoft));
    });

    testWidgets('dark danger uses theme errorSoft', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const InfoBanner(
            kind: InfoKind.danger,
            message: TextSpan(text: 'bad'),
          ),
          dark: true,
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(InfoBanner),
          matching: find.byType(Container),
        ).first,
      );
      final dark = AppThemeColors.forTest(isDark: true);
      expect((container.decoration as BoxDecoration).color, dark.errorSoft);
    });
  });

  group('BrandedErrorBanner', () {
    testWidgets('dark uses theme errorSoft background', (tester) async {
      await tester.pumpWidget(
        _wrap(const BrandedErrorBanner(message: 'fail'), dark: true),
      );
      final containers = tester.widgetList<Container>(find.byType(Container));
      final dark = AppThemeColors.forTest(isDark: true);
      final bg = containers
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.color)
          .whereType<Color>()
          .firstWhere((c) => c == dark.errorSoft || c == AppColors.errorSoft);
      expect(bg, dark.errorSoft);
      expect(bg, isNot(AppColors.errorSoft));
    });

    testWidgets('detail row renders the technical error code', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BrandedErrorBanner(
            message: 'Could not load your disputes. Tap Retry.',
            detail: 'cloud_firestore/permission-denied',
          ),
          dark: false,
        ),
      );
      expect(find.text('cloud_firestore/permission-denied'), findsOneWidget);
    });
  });

  group('HeroEmojiCircle', () {
    testWidgets('dark default soft is theme accentSoft; gradient uses surface',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const HeroEmojiCircle(emoji: '💳'), dark: true),
      );
      final container = tester.widget<Container>(find.byType(Container).first);
      final deco = container.decoration as BoxDecoration;
      final gradient = deco.gradient as RadialGradient;
      final dark = AppThemeColors.forTest(isDark: true);
      expect(gradient.colors.last, dark.accentSoft);
      expect(gradient.colors.first, dark.surface);
      expect(gradient.colors.first, isNot(Colors.white));
    });
  });

  group('RadioRow', () {
    testWidgets('selected dark uses theme accentSoft', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RadioRow(label: 'A', selected: true, onTap: () {}),
          dark: true,
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(RadioRow),
          matching: find.byType(Container),
        ).first,
      );
      final dark = AppThemeColors.forTest(isDark: true);
      expect((container.decoration as BoxDecoration).color, dark.accentSoft);
    });
  });

  group('StepperTimeline pending greys', () {
    testWidgets('pending step uses surfaceAlt / textTertiary / divider',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          StepperTimeline(
            items: const [
              StepperItem(
                title: 'one',
                isDone: false,
                isCurrent: false,
                child: Text('body'),
              ),
            ],
          ),
          dark: true,
        ),
      );
      final dark = AppThemeColors.forTest(isDark: true);
      final circle = tester.widgetList<Container>(find.byType(Container)).firstWhere(
            (c) {
              final d = c.decoration;
              return d is BoxDecoration && d.shape == BoxShape.circle;
            },
          );
      expect((circle.decoration as BoxDecoration).color, dark.surfaceAlt);
      final number = tester.widget<Text>(find.text('1'));
      expect(number.style?.color, dark.textTertiary);
    });
  });
}
