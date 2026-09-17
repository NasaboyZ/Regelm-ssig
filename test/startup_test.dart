import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:regelmaessig/main.dart';
import 'package:regelmaessig/viewmodels/startup_view_model.dart';
import 'package:regelmaessig/views/main_view.dart';
import 'package:regelmaessig/views/splash_view.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Startup appears once and main survives rebuild and resume', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(SplashView), findsOneWidget);
    expect(find.text('Regelmässig'), findsOneWidget);
    expect(find.text('Privat. Lokal. Bei dir .'), findsOneWidget);
    expect(find.byType(MainView), findsNothing);

    await tester.pump(const Duration(milliseconds: 1499));
    expect(find.byType(SplashView), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(SplashView), findsNothing);
    expect(find.text('Dein Zyklus.\nDeine Daten.'), findsOneWidget);
    await tester.tap(find.text('Weiter'));
    await tester.pump();
    expect(find.text('Lokal gespeichert.\nImmer verschlüsselt.'), findsOneWidget);
    await tester.tap(find.text('Weiter'));
    await tester.pump();
    expect(find.text('Auch beim Transfer\nverschlüsselt.'), findsOneWidget);
    await tester.tap(find.text('App einrichten'));
    await tester.pumpAndSettle();
    expect(find.byType(MainView), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );

    await tester.tap(find.text('Einstellungen'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const MyApp());
    await tester.pump(StartupViewModel.splashDuration);
    expect(find.byType(SplashView), findsNothing);
    expect(
      find.text('Hier werden deine Einstellungen verfügbar sein.'),
      findsOneWidget,
    );
  });

  testWidgets('Closing during startup cancels the pending transition', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(StartupViewModel.splashDuration);
    expect(tester.takeException(), isNull);
  });
}
