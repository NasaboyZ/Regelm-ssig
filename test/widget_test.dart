import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:regelmaessig/main.dart';
import 'package:regelmaessig/widgets/bottom_navigation_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Navigation tests use the test font, without downloading Google Fonts.
    GoogleFonts.config.allowRuntimeFetching = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final asset = const StringCodec().decodeMessage(message);
          if (asset == 'AssetManifest.bin') {
            return const StandardMessageCodec().encodeMessage({
              'Inter-Regular.ttf': [
                {'asset': 'Inter-Regular.ttf'},
              ],
            });
          }
          if (asset == 'Inter-Regular.ttf') return ByteData(0);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    GoogleFonts.config.allowRuntimeFetching = true;
  });

  for (final width in [320.0, 600.0]) {
    testWidgets('Selection and circle follow taps at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      final circle = find.byKey(const ValueKey('navigation-selection'));
      void expectSelection(int index, String label, IconData icon) {
        expect(
          tester.widget<AppBottomNavigationBar>(
            find.byType(AppBottomNavigationBar),
          ).selectedIndex,
          index,
        );
        expect(
          tester.getCenter(circle).dx,
          closeTo(tester.getCenter(find.text(label)).dx, 0.01),
        );
        expect(
          find.descendant(of: circle, matching: find.byIcon(icon)),
          findsOneWidget,
        );
        expect(find.byIcon(icon), findsOneWidget);
        expect(find.text('Main View'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      expectSelection(1, 'Post', Icons.add);
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expectSelection(0, 'Search', Icons.search);

      await tester.tap(find.text('Notifs'));
      await tester.pumpAndSettle();
      expectSelection(2, 'Notifs', Icons.notifications_none);

      await tester.tap(circle);
      await tester.pumpAndSettle();
      expectSelection(2, 'Notifs', Icons.notifications_none);

      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();
      expectSelection(1, 'Post', Icons.add);

      final startX = tester.getCenter(circle).dx;
      await tester.tap(find.text('Search'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.getCenter(circle).dx, lessThan(startX));
      expect(
        tester.getCenter(circle).dx,
        greaterThan(tester.getCenter(find.text('Search')).dx),
      );
      await tester.tap(find.text('Notifs'));
      await tester.pumpAndSettle();
      expectSelection(2, 'Notifs', Icons.notifications_none);

      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == 'Notifs',
        )),
        matchesSemantics(
          label: 'Notifs',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });
  }
}
