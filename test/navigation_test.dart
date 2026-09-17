import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:regelmaessig/main.dart';
import 'package:regelmaessig/viewmodels/startup_view_model.dart';
import 'package:regelmaessig/theme/app_colors.dart';
import 'package:regelmaessig/widgets/bottom_navigation_bar.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Navigation animates between every tab and opens its content', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(StartupViewModel.splashDuration);
    await tester.pumpAndSettle();

    final navigation = find.byType(AppBottomNavigationBar);
    final circle = find.descendant(
      of: find.descendant(
        of: navigation,
        matching: find.byType(AnimatedPositioned),
      ),
      matching: find.byType(Container),
    );
    const labels = ['Home', 'Zyklusverlauf', 'Einstellungen'];
    const icons = [
      Icons.home_outlined,
      Icons.calendar_month_outlined,
      Icons.tune,
    ];
    const content = [
      'Noch keine Zyklusdaten',
      'Noch keine Einträge',
      'Hier werden deine Einstellungen verfügbar sein.',
    ];
    Finder tab(int index) =>
        find.descendant(of: navigation, matching: find.text(labels[index]));
    Finder icon(int index) =>
        find.descendant(of: navigation, matching: find.byIcon(icons[index]));

    void expectSelected(int index) {
      expect(
        tester.getCenter(circle).dx,
        closeTo(tester.getCenter(tab(index)).dx, 0.1),
      );
      expect(
        tester.getCenter(circle).dy,
        closeTo(tester.getCenter(icon(index)).dy, 0.1),
      );
      for (var i = 0; i < labels.length; i++) {
        expect(
          tester.widget<Icon>(icon(i)).color,
          i == index ? AppColors.backgroundColor : AppColors.fontColor,
        );
        expect(
          tester.widget<Text>(tab(i)).style!.fontWeight,
          i == index ? FontWeight.w700 : FontWeight.w400,
        );
      }
      expect(find.text(content[index]), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    expectSelected(0);
    // Covers all six directed transitions, including jumps across the middle.
    for (final target in [1, 2, 0, 2, 1, 0]) {
      final start = tester.getCenter(circle).dx;
      final end = tester.getCenter(tab(target)).dx;
      await tester.tap(tab(target));
      await tester.pump();
      expect(tester.getCenter(circle).dx, closeTo(start, 0.1));
      await tester.pump(const Duration(milliseconds: 100));
      final intermediate = tester.getCenter(circle).dx;
      expect(intermediate, greaterThan(start < end ? start : end));
      expect(intermediate, lessThan(start < end ? end : start));
      await tester.pumpAndSettle();
      expectSelected(target);
    }

    // A second tap on the active tab leaves the indicator in place.
    final position = tester.getCenter(circle);
    await tester.tap(tab(0));
    await tester.pumpAndSettle();
    expect(tester.getCenter(circle), position);
    expectSelected(0);

    // Changing destination mid-animation must finish at the latest tapped tab.
    await tester.tap(tab(2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(tab(1));
    await tester.pumpAndSettle();
    expectSelected(1);
  });
}
