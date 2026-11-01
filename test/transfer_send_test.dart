import 'dart:io';
import 'package:regelmaessig/viewmodels/transfer_receive_view_model.dart';
import 'package:regelmaessig/views/transfer/transfer_receive_view.dart';
import 'support/fake_mlqr_camera.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regelmaessig/theme/app_colors.dart';
import 'package:regelmaessig/models/day_entry.dart';
import 'package:regelmaessig/viewmodels/transfer_send_view_model.dart';
import 'package:regelmaessig/views/transfer/transfer_send_view.dart';
import 'package:regelmaessig/views/transfer/transfer_view.dart';
import 'package:regelmaessig/widgets/transfer/mlqr_raster_view.dart';
import 'package:regelmaessig/services/mlqr_transfer_service.dart';

Widget harness({Widget? home}) => MaterialApp(
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
    'repeats temporal chunks so missed camera frames can be recovered',
    () async {
      final sequence = await MlqrTransferService()
          .encodeUnencryptedSnapshotForDevelopment(
            TrackingSnapshot(),
            transferId: 'repeat-test',
            chunkSize: 5,
          );
      final model = TransferSendViewModel.sequence(sequence);

      expect(model.temporalFrameCount, greaterThan(sequence.chunkCount));
      expect(
        model.temporalFrameCount,
        sequence.temporalFrames.length * TransferSendViewModel.temporalRounds,
      );
    },
  );

  testWidgets('Send opens an actual MLQR preview; both exit actions return', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    final send = find.text('Von diesem Gerät senden');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.byType(TransferSendView), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.text('Code 1 von 1'), findsOneWidget);
    final view = tester.widget<TransferSendView>(find.byType(TransferSendView));
    final rendered = tester.widget<MlqrRasterView>(find.byType(MlqrRasterView));
    expect(rendered.raster, same(view.viewModel.code.displayRaster));
    expect(view.viewModel.code.layers, hasLength(3));
    expect(
      view.viewModel.code.raster.pixels.any((p) => p != 0 && p != 0xffffff),
      isTrue,
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Code 1 von 1'), findsOneWidget);
    expect(find.textContaining('Codes bestätigt'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(TransferSendView), findsNothing);

    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();
    final cancel = find.text('Transfer abbrechen');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(find.byType(TransferSendView), findsNothing);
    expect(send, findsOneWidget);
    final receive = find.text('Auf diesem Gerät empfangen');
    await tester.ensureVisible(receive);
    await tester.tap(receive);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TransferReceiveView), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Send preview is scrollable at narrow width and enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.5)),
          child: child!,
        ),
        home: TransferSendView(viewModel: TransferSendViewModel.preview()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Transfer abbrechen'));
    expect(find.text('Transfer abbrechen').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Send preview visual inspection', (tester) async {
    final path = Platform.environment['TRANSFER_PREVIEW_PATH'];
    for (final (variable, family) in [
      ('MLQR_PREVIEW_FONT', 'Roboto'),
      ('TRANSFER_PREVIEW_ICON_FONT', 'MaterialIcons'),
    ]) {
      final fontPath = Platform.environment[variable];
      if (fontPath != null) {
        await tester.runAsync(() async {
          final loader = FontLoader(family)
            ..addFont(File(fontPath).readAsBytes().then(ByteData.sublistView));
          await loader.load();
        });
      }
    }
    await tester.binding.setSurfaceSize(const Size(393, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final previewKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: previewKey, child: harness()));
    await tester.ensureVisible(find.text('Von diesem Gerät senden'));
    await tester.tap(find.text('Von diesem Gerät senden'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (path != null) {
      final boundary =
          previewKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(path).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
