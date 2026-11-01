import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regelmaessig/models/mlqr_camera_frame.dart';
import 'package:regelmaessig/models/mlqr_decoded.dart';
import 'package:regelmaessig/models/transfer_result.dart';
import 'package:regelmaessig/services/mlqr_encoder_service.dart';
import 'package:regelmaessig/viewmodels/transfer_receive_view_model.dart';
import 'package:regelmaessig/views/transfer/transfer_receive_view.dart';
import 'package:regelmaessig/views/transfer/transfer_result_view.dart';
import 'package:regelmaessig/views/transfer/transfer_view.dart';
import 'support/fake_mlqr_camera.dart';

final frame = MlqrCameraFrame(
  width: 1,
  height: 1,
  format: MlqrCameraFormat.bgra8888,
  planes: [
    MlqrCameraPlane([0, 0, 0, 255], 4, 4),
  ],
);
final decoded = MlqrDecoded(
  opticalLayerCount: 3,
  qrVersion: 1,
  packets: [
    Uint8List.fromList([65]),
    Uint8List.fromList([66]),
    Uint8List.fromList([67]),
  ],
);

void main() {
  test(
    'BGRA and YUV conversion respects row padding and chroma pixel stride',
    () {
      final bgra = MlqrCameraFrame(
        width: 2,
        height: 2,
        format: MlqrCameraFormat.bgra8888,
        planes: [
          MlqrCameraPlane(
            [
              0,
              0,
              255,
              255,
              0,
              255,
              0,
              255,
              77,
              77,
              77,
              77,
              255,
              0,
              0,
              255,
              255,
              255,
              255,
              255,
            ],
            12,
            4,
          ),
        ],
      );
      expect(bgra.toRaster().pixels, [0xff0000, 0x00ff00, 0x0000ff, 0xffffff]);
      final yuv = MlqrCameraFrame(
        width: 4,
        height: 2,
        format: MlqrCameraFormat.yuv420,
        planes: [
          MlqrCameraPlane([76, 76, 29, 29, 99, 99, 76, 76, 29, 29], 6, 1),
          MlqrCameraPlane([85, 99, 255], 4, 2),
          MlqrCameraPlane([255, 99, 107], 4, 2),
        ],
      );
      final pixels = yuv.toRaster().pixels;
      expect((pixels[0] >> 16) & 255, greaterThan(250));
      expect(pixels[0] & 255, lessThan(3));
      expect(pixels[2] & 255, greaterThan(250));
      expect((pixels[2] >> 16) & 255, lessThan(3));
      expect(pixels.sublist(0, 4), pixels.sublist(4));
    },
  );

  test(
    'Actual isolate recovers binary packets from a BGRA camera frame',
    () async {
      final input = [
        Uint8List.fromList([0, 255, 128, 7]),
        Uint8List.fromList([9, 3]),
      ];
      final code = const MlqrEncoderService().encode(input).displayRaster;
      const scale = 8;
      final w = (code.width + 8) * scale;
      final h = (code.height + 8) * scale;
      final bytes = <int>[];
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final cx = x ~/ scale - 4, cy = y ~/ scale - 4;
          final p = cx < 0 || cy < 0 || cx >= code.width || cy >= code.height
              ? 0xffffff
              : code.pixelAt(cy, cx);
          bytes.addAll([p & 255, (p >> 8) & 255, (p >> 16) & 255, 255]);
        }
      }
      final result = await decodeCameraFrame(
        MlqrCameraFrame(
          width: w,
          height: h,
          format: MlqrCameraFormat.bgra8888,
          planes: [MlqrCameraPlane(bytes, w * 4, 4)],
        ),
      );
      expect(result!.packets, input);
      expect(result.dummyCount, 1);
    },
  );

  testWidgets(
    'Only one frame is decoded; pause discards stale results and releases camera',
    (tester) async {
      final camera = FakeMlqrCamera();
      final pending = Completer<MlqrDecoded?>();
      var calls = 0;
      final model = TransferReceiveViewModel(
        source: camera,
        decode: (_) {
          calls++;
          return pending.future;
        },
      );
      model.resume();
      await tester.pump();
      camera.onFrame!(frame);
      camera.onFrame!(frame);
      expect(calls, 1);
      model.pause();
      pending.complete(decoded);
      await tester.pump();
      expect(model.result, isNull);
      expect(camera.stops, greaterThanOrEqualTo(2));
      model.resume();
      await tester.pump();
      expect(camera.starts, 2);
      model.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'Scanner exposes focus and zoom controls through the camera seam',
    (tester) async {
      final camera = FakeMlqrCamera();
      final model = TransferReceiveViewModel(source: camera);
      model.resume();
      await tester.pump();

      await model.focusAt(const Offset(0.5, 0.5));
      await model.setZoom(3);

      expect(camera.focusPoint, const Offset(0.5, 0.5));
      expect(camera.zoom, 3);
      expect(model.zoom, 3);
      model.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'Dispose during native initialization releases late camera and ignores callbacks',
    (tester) async {
      final camera = FakeMlqrCamera()..starting = Completer<void>();
      final model = TransferReceiveViewModel(
        source: camera,
        decode: (_) async => decoded,
      );
      model.resume();
      await tester.pump();
      model.dispose();
      camera.starting!.complete();
      await tester.pump();
      camera.onFrame!(frame);
      await tester.pump();
      expect(model.result, isNull);
      expect(camera.stops, greaterThanOrEqualTo(2));
    },
  );

  testWidgets(
    'Unreadable frames keep scanning until timeout; denial gets specific failure',
    (tester) async {
      final camera = FakeMlqrCamera();
      final model = TransferReceiveViewModel(
        source: camera,
        decode: (_) async => null,
        scanTimeout: const Duration(seconds: 2),
      );
      model.resume();
      await tester.pump();
      camera.onFrame!(frame);
      await tester.pump();
      expect(model.result, isNull);
      await tester.pump(const Duration(seconds: 2));
      expect(
        (model.result as TransferFailed).reason,
        TransferFailureReason.unreadable,
      );
      model.dispose();
      await tester.pump();
      final denied = TransferReceiveViewModel(
        source: FakeMlqrCamera()
          ..startError = CameraException('CameraAccessDenied', 'Denied'),
      );
      denied.resume();
      await tester.pump();
      expect(
        (denied.result as TransferFailed).reason,
        TransferFailureReason.cameraPermissionDenied,
      );
      denied.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'Receive opens camera, shows read success and packets, but never claims import',
    (tester) async {
      final camera = FakeMlqrCamera();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransferView(
              receiveViewModelFactory: () => TransferReceiveViewModel(
                source: camera,
                decode: (_) async => decoded,
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Auf diesem Gerät empfangen'));
      await tester.tap(find.text('Auf diesem Gerät empfangen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(TransferReceiveView), findsOneWidget);
      camera.onFrame!(frame);
      await tester.pumpAndSettle();
      expect(find.byType(TransferResultView), findsOneWidget);
      expect(find.text('Multi-Layer-QR gelesen'), findsOneWidget);
      expect(find.text('Übernommen'), findsNothing);
      expect(find.text('Integritätsprüfung erfolgreich'), findsNothing);
      await tester.ensureVisible(find.text('Übertragungsdetails ansehen'));
      await tester.tap(find.text('Übertragungsdetails ansehen'));
      await tester.pumpAndSettle();
      expect(find.text('Ebene 1 · 1 Bytes\nA'), findsOneWidget);
      expect(find.text('Keine Daten gespeichert'), findsOneWidget);
      await tester.tap(find.text('Schliessen'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Zur Übersicht'));
      await tester.tap(find.text('Zur Übersicht'));
      await tester.pumpAndSettle();
      expect(find.byType(TransferView), findsOneWidget);
      expect(camera.stops, greaterThanOrEqualTo(2));
    },
  );

  testWidgets(
    'Failure offers a fresh camera retry; cancel returns without false failure',
    (tester) async {
      final cameras = <FakeMlqrCamera>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransferView(
              receiveViewModelFactory: () {
                final camera = FakeMlqrCamera();
                cameras.add(camera);
                return TransferReceiveViewModel(
                  source: camera,
                  decode: (_) async => null,
                  scanTimeout: const Duration(seconds: 2),
                );
              },
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Auf diesem Gerät empfangen'));
      await tester.tap(find.text('Auf diesem Gerät empfangen'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Übertragung nicht abgeschlossen'), findsOneWidget);
      await tester.ensureVisible(find.text('Erneut versuchen'));
      await tester.tap(find.text('Erneut versuchen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(cameras.length, 2);
      expect(find.byType(TransferReceiveView), findsOneWidget);
      await tester.ensureVisible(find.text('Empfangen abbrechen'));
      await tester.tap(find.text('Empfangen abbrechen'));
      await tester.pumpAndSettle();
      expect(find.byType(TransferView), findsOneWidget);
      expect(find.byType(TransferResultView), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Scanner layout stays usable on small screens and renders a preview',
    (tester) async {
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
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final largeText in [false, true]) {
        await tester.binding.setSurfaceSize(
          largeText ? const Size(320, 640) : const Size(393, 1000),
        );
        final camera = FakeMlqrCamera()..starting = Completer<void>();
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(largeText ? 1.5 : 1)),
                child: child!,
              ),
              home: TransferReceiveView(
                viewModel: TransferReceiveViewModel(source: camera),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Kamera wird geöffnet …'), findsOneWidget);
        expect(find.byType(BackButton), findsOneWidget);
        expect(find.byIcon(Icons.help_outline), findsNothing);
        final path = Platform.environment['TRANSFER_SCAN_PREVIEW_PATH'];
        if (!largeText && path != null) {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(path).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.ensureVisible(find.text('Empfangen abbrechen'));
        expect(find.text('Empfangen abbrechen').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        camera.starting!.complete();
        await tester.pump();
      }
    },
  );
}
