import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:regelmaessig/main.dart';
import 'package:regelmaessig/widgets/cycle/cycle_calendar.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('Home shows the design without gear or preview badge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('Heute erfassen'), findsOneWidget);
    expect(find.text('Vorschau'), findsNothing);
    expect(find.text('Guten Morgen, Jo'), findsNothing);
    expect(find.byIcon(Icons.settings), findsNothing);
    expect(find.text('10 Tagen'), findsNothing);
    expect(find.text('Noch keine Zyklusdaten'), findsOneWidget);
    expect(find.text('Details ›'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    for (final calendar in tester.widgetList<CycleCalendar>(
      find.byType(CycleCalendar, skipOffstage: false),
    )) {
      expect(calendar.periodDays, isEmpty);
      expect(calendar.today.year, DateTime.now().year);
    }

    await tester.tap(find.text('Kalender öffnen ›'));
    await tester.pumpAndSettle();
    expect(find.text('Noch keine Einträge'), findsOneWidget);
  });
  testWidgets('Calendar navigates across year boundary', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CycleCalendar(
            today: DateTime(2026, 12, 18),
            periodDays: const {},
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Nächster Monat'));
    await tester.pump();
    expect(find.text('Januar 2027'), findsOneWidget);
    await tester.tap(find.byTooltip('Vorheriger Monat'));
    await tester.pump();
    expect(find.text('Dezember 2026'), findsOneWidget);
  });
  testWidgets('Home fits narrow screens and enlarged text', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
  });
}
