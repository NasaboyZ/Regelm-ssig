import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regelmaessig/viewmodels/cycle_history_view_model.dart';
import 'package:regelmaessig/views/cycle/cycle_history_view.dart';

void main() {
  test('Calendar crosses years and returns to the current month', () {
    final model = CycleHistoryViewModel(clock: () => DateTime(2026, 12, 18));
    addTearDown(model.dispose);
    model.nextMonth();
    expect(model.month, DateTime(2027, 1));
    model.previousMonth();
    expect(model.month, DateTime(2026, 12));
    model.selectMonth(DateTime(2024, 2, 29));
    expect(model.month, DateTime(2024, 2));
    model.showToday();
    expect(model.month, DateTime(2026, 12));
  });

  testWidgets('Month selection, today and real calendar markings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = CycleHistoryViewModel(
      clock: () => DateTime(2026, 9, 18),
      periodDays: {for (var day = 8; day <= 12; day++) DateTime(2026, 9, day)},
      entryDays: {DateTime(2026, 9, 18, 12)},
      predictedDays: {DateTime(2026, 10, 6)},
    );
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CycleHistoryView(viewModel: model)),
      ),
    );
    expect(find.text('September 2026'), findsOneWidget);
    expect(
      find.bySemanticsLabel('8. September 2026, Eingetragen'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('18. September 2026, Heute, Eintrag vorhanden'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Nächster Monat'));
    await tester.pump();
    expect(find.text('Oktober 2026'), findsOneWidget);
    expect(find.bySemanticsLabel('6. Oktober 2026, Vorschau'), findsOneWidget);
    await tester.tap(find.text('Monat wählen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nächstes Jahr'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Feb'));
    await tester.pumpAndSettle();
    expect(find.text('Februar 2027'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Heute'));
    await tester.pump();
    expect(find.text('September 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Buttons align left/right and a day can be selected', (
    tester,
  ) async {
    final model = CycleHistoryViewModel(clock: () => DateTime(2026, 9, 18));
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CycleHistoryView(viewModel: model)),
      ),
    );
    final today = find.widgetWithText(OutlinedButton, 'Heute');
    final picker = find.widgetWithText(OutlinedButton, 'Monat wählen');
    expect(tester.getTopLeft(today).dx, closeTo(18, 1));
    expect(tester.getTopRight(picker).dx, closeTo(782, 1));
    expect(tester.getCenter(today).dy, tester.getCenter(picker).dy);
    await tester.tap(find.byKey(const ValueKey('day-2026-9-9')));
    await tester.pumpAndSettle();
    expect(model.selectedDay, DateTime(2026, 9, 9));
    final semantics = tester.widget<Semantics>(
      find.bySemanticsLabel('9. September 2026'),
    );
    expect(semantics.properties.selected, isTrue);
    await tester.tap(today);
    await tester.pumpAndSettle();
    expect(model.selectedDay, DateTime(2026, 9, 18));
    expect(
      tester
          .widget<Semantics>(find.bySemanticsLabel('9. September 2026'))
          .properties
          .selected,
      isFalse,
    );
  });

  testWidgets('Month strip swipes both ways and scrolled months are selectable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = CycleHistoryViewModel(clock: () => DateTime(2026, 9, 18));
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CycleHistoryView(viewModel: model)),
      ),
    );
    final strip = find.byKey(const ValueKey('month-strip'));
    final scrollable = find.descendant(
      of: strip,
      matching: find.byType(Scrollable),
    );
    double offset() =>
        tester.state<ScrollableState>(scrollable).position.pixels;
    final initial = offset();
    await tester.drag(strip, const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(offset(), greaterThan(initial));
    final afterLeft = offset();
    await tester.drag(strip, const Offset(180, 0));
    await tester.pumpAndSettle();
    expect(offset(), lessThan(afterLeft));
    // Return to a deterministic position, then select a month revealed by scrolling.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Heute'));
    await tester.pumpAndSettle();
    await tester.drag(strip, const Offset(-128, 0));
    await tester.pumpAndSettle();
    final visibleMonth = find
        .descendant(of: strip, matching: find.byType(InkWell))
        .hitTestable()
        .first;
    final label = tester
        .widget<Text>(
          find.descendant(of: visibleMonth, matching: find.byType(Text)),
        )
        .data;
    await tester.tap(visibleMonth);
    await tester.pumpAndSettle();
    const names = [
      'Jan',
      'Feb',
      'Mär',
      'Apr',
      'Mai',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Okt',
      'Nov',
      'Dez',
    ];
    expect(names[model.month.month - 1], label);
    expect(model.month, isNot(DateTime(2026, 9)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Narrow screen with enlarged text and a six-week month', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = CycleHistoryViewModel(clock: () => DateTime(2026, 3, 31));
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(body: CycleHistoryView(viewModel: model)),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Noch keine Einträge'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Noch keine Einträge'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
