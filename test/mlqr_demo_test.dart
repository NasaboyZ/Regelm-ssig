import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regelmaessig/debug/mlqr_demo_app.dart';
import 'package:regelmaessig/viewmodels/mlqr_demo_view_model.dart';
import 'package:regelmaessig/widgets/transfer/mlqr_raster_view.dart';

void main() {
  test('Demo keeps the seven-layer paper comparison available', () {
    final model = MlqrDemoViewModel();
    addTearDown(model.dispose);
    expect(model.code!.payloadCount, 3);
    model.configure(layerCount: 7);
    expect(model.code!.dummyCount, 2);
    model.configure(padWithDummies: false);
    expect(model.code!.layers.length, 7);
    expect(model.code!.partition, [36, 72, 147]);
    expect(model.error, isNull);
  });

  testWidgets('Standalone demo shows real rasters and updates controls', (
    tester,
  ) async {
    final previewFont = Platform.environment['MLQR_PREVIEW_FONT'];
    if (previewFont != null) {
      await tester.runAsync(() async {
        final loader = FontLoader('Roboto')
          ..addFont(File(previewFont).readAsBytes().then(ByteData.sublistView));
        await loader.load();
      });
    }
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final previewKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: previewKey, child: const MlqrDemoApp()),
    );
    expect(
      find.text('3 Nutzdaten + 0 Dummys = 3 dargestellte Ebenen'),
      findsOneWidget,
    );
    expect(find.byType(MlqrRasterView), findsNWidgets(4));
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 Ebenen').last);
    await tester.pumpAndSettle();
    expect(
      find.text('7 Nutzdaten + 2 Dummys = 9 dargestellte Ebenen'),
      findsOneWidget,
    );
    expect(find.text('Partition: 36, 72, 147'), findsOneWidget);
    expect(find.byType(MlqrRasterView), findsNWidgets(10));
    expect(tester.takeException(), isNull);

    // Optional visual QA artifact; no goldens or project files are changed.
    final previewPath = Platform.environment['MLQR_PREVIEW_PATH'];
    if (previewPath != null) {
      final boundary =
          previewKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(previewPath).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
      find.text('7 Nutzdaten + 0 Dummys = 7 dargestellte Ebenen'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
