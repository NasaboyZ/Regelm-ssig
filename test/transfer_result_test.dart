import 'dart:io';
import 'package:regelmaessig/viewmodels/transfer_receive_view_model.dart';
import 'package:regelmaessig/views/transfer/transfer_receive_view.dart';
import 'support/fake_mlqr_camera.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regelmaessig/models/transfer_result.dart';
import 'package:regelmaessig/theme/app_colors.dart';
import 'package:regelmaessig/viewmodels/transfer_result_view_model.dart';
import 'package:regelmaessig/views/transfer/transfer_result_view.dart';
import 'package:regelmaessig/views/transfer/transfer_view.dart';

TransferResultViewModel sample(bool success) => TransferResultViewModel(
  isPreview: true,
  result: success
      ? TransferSucceeded(
          codeCount: 12,
          importedCategories: TransferDataCategory.values.toSet(),
        )
      : TransferFailed(
          reason: TransferFailureReason.incomplete,
          receivedCodeCount: 9,
          expectedCodeCount: 12,
        ),
);

Widget app({Widget? home}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(
    scaffoldBackgroundColor: AppColors.backgroundColor,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
  ),
  home:
      home ??
      Scaffold(
        body: SafeArea(
          child: TransferView(
            receiveViewModelFactory: () =>
                TransferReceiveViewModel(source: FakeMlqrCamera()),
          ),
        ),
      ),
);

void main() {
  test(
    'Success only lists imported categories; failure never reports success',
    () {
      final categories = {TransferDataCategory.appointments};
      final success = TransferResultViewModel(
        result: TransferSucceeded(codeCount: 2, importedCategories: categories),
      );
      categories.clear();
      expect(success.categories, [TransferDataCategory.appointments]);
      expect(success.codeSummary, '2 von 2 Codes empfangen');
      for (final reason in TransferFailureReason.values) {
        final failure = TransferResultViewModel(
          result: TransferFailed(reason: reason),
        );
        expect(failure.succeeded, isFalse);
        expect(failure.dataSummary, 'Keine Daten gespeichert');
        expect(
          failure.verificationLabel,
          isNot('Integritätsprüfung erfolgreich'),
        );
        expect(failure.description, isNotEmpty);
      }
      expect(sample(false).codeSummary, '9 von 12 Codes empfangen');
      expect(
        () => TransferFailed(
          reason: TransferFailureReason.incomplete,
          receivedCodeCount: 12,
          expectedCodeCount: 12,
        ),
        throwsArgumentError,
      );
      expect(
        () => TransferFailed(
          reason: TransferFailureReason.incomplete,
          receivedCodeCount: 13,
          expectedCodeCount: 12,
        ),
        throwsRangeError,
      );
    },
  );

  testWidgets(
    'Debug previews expose details, overview and honest retry action',
    (tester) async {
      await tester.pumpWidget(app());
      final previews = find.text('Ergebnisansichten testen');
      await tester.ensureVisible(previews);
      await tester.tap(previews);
      await tester.pumpAndSettle();
      for (final success in [true, false]) {
        final launcher = find.text(
          success ? 'Erfolg ansehen' : 'Fehler ansehen',
        );
        await tester.ensureVisible(launcher);
        await tester.tap(launcher);
        await tester.pumpAndSettle();
        expect(find.byType(TransferResultView), findsOneWidget);
        expect(find.text('VORSCHAU · KEINE ECHTE ÜBERTRAGUNG'), findsOneWidget);
        expect(
          find.text(success ? 'Übernommen' : 'Nicht übernommen'),
          findsOneWidget,
        );
        expect(find.byType(BackButton), findsNothing);
        expect(find.byIcon(Icons.help_outline), findsNothing);
        if (!success) {
          expect(find.text('Integritätsprüfung erfolgreich'), findsNothing);
        }
        final details = find.text('Übertragungsdetails ansehen');
        await tester.ensureVisible(details);
        await tester.tap(details);
        await tester.pumpAndSettle();
        expect(
          find.text(
            success ? '12 von 12 Codes empfangen' : '9 von 12 Codes empfangen',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Schliessen'));
        await tester.pumpAndSettle();
        final action = find.text(
          success ? 'Zur Übersicht' : 'Erneut versuchen',
        );
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(TransferResultView), findsNothing);
        if (!success) {
          expect(find.byType(TransferReceiveView), findsOneWidget);
          await tester.ensureVisible(find.text('Empfangen abbrechen'));
          await tester.tap(find.text('Empfangen abbrechen'));
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'Both result screens remain usable with enlarged text on a small screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final success in [true, false]) {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: TransferResultView(viewModel: sample(success)),
          ),
        );
        await tester.pumpAndSettle();
        final action = find.text(
          success ? 'Zur Übersicht' : 'Erneut versuchen',
        );
        await tester.ensureVisible(action);
        expect(action.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('Render result previews for visual inspection', (tester) async {
    for (final (variable, family) in [
      ('MLQR_PREVIEW_FONT', 'Roboto'),
      ('TRANSFER_PREVIEW_ICON_FONT', 'MaterialIcons'),
    ]) {
      final path = Platform.environment[variable];
      if (path != null) {
        await tester.runAsync(() async {
          final loader = FontLoader(family)
            ..addFont(File(path).readAsBytes().then(ByteData.sublistView));
          await loader.load();
        });
      }
    }
    await tester.binding.setSurfaceSize(const Size(393, 1150));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final success in [true, false]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: app(home: TransferResultView(viewModel: sample(success))),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final prefix = Platform.environment['TRANSFER_RESULT_PREVIEW_PREFIX'];
      if (prefix != null) {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$prefix-${success ? 'success' : 'failure'}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });
}
