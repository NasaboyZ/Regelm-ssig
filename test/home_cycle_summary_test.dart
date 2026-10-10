import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:regelmaessig/debug/cycle_demo_data.dart';
import 'package:regelmaessig/debug/demo_tracking_storage.dart';
import 'package:regelmaessig/models/day_entry.dart';
import 'package:regelmaessig/services/cycle_calculation_service.dart';
import 'package:regelmaessig/widgets/cycle/cycle_summary_card.dart';
import 'package:regelmaessig/repositories/tracking_repository.dart';
import 'package:regelmaessig/viewmodels/home_view_model.dart';
import 'package:regelmaessig/views/home/home_view.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> showHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = DateTime(2026, 10, 3);
    final repository = TrackingRepository(
      DemoTrackingStorage(createCycleDemoData(today)),
    );
    final model = HomeViewModel(repository: repository, clock: () => today);
    addTearDown(model.dispose);
    addTearDown(repository.dispose);
    await model.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(textTheme: GoogleFonts.interTextTheme()),
        home: Scaffold(
          body: HomeView(
            viewModel: model,
            onOpenCalendar: () {},
            onRecord: () {},
            onDetails: () {},
            onRecordDay: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Home has one recording action with a recorded day', (
    tester,
  ) async {
    await showHome(tester);
    expect(find.text('Heute erfassen'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Heute erfasst'), findsNothing);
  });

  testWidgets('Current cycle shows both averages from the recorded year', (
    tester,
  ) async {
    await showHome(tester);
    await tester.scrollUntilVisible(
      find.text('Aktueller Zyklus'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Ø Zyklus ≈ 28 Tage'), findsOneWidget);
    expect(find.text('Ø Periode ≈ 5 Tage'), findsOneWidget);
    expect(find.text('Aus 12 Zyklen'), findsOneWidget);
    expect(find.text('Aus 13 Perioden'), findsOneWidget);
  });

  testWidgets('Averages fit a narrow screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = DateTime(2026, 10, 3);
    final summary = const CycleCalculationService().calculate(
      createCycleDemoData(today),
      today,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: CycleSummaryCard(cycle: summary),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Ø Zyklus ≈ 28 Tage'), findsOneWidget);
    expect(find.text('Ø Periode ≈ 5 Tage'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Missing observations show placeholders instead of default averages',
    (tester) async {
      final summary = const CycleCalculationService().calculate(
        TrackingSnapshot(),
        DateTime(2026, 10, 3),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CycleSummaryCard(cycle: summary)),
        ),
      );
      expect(find.text('Ø Zyklus –'), findsOneWidget);
      expect(find.text('Ø Periode –'), findsOneWidget);
      expect(find.text('Noch keine vollständigen Daten'), findsNWidgets(2));
    },
  );
}
