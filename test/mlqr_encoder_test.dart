import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:qr/qr.dart';
import 'package:regelmaessig/models/mlqr_code.dart';
import 'package:regelmaessig/services/mlqr_encoder_service.dart';

Uint8List packet(String text) => Uint8List.fromList(utf8.encode(text));

QrModuleMatrix matrix(int size, {bool dark = false}) =>
    QrModuleMatrix(size: size, darkModules: List.filled(size * size, dark));

void main() {
  const encoder = MlqrEncoderService();

  test('Paper partitions sum to 255 and all subsets have distinct sums', () {
    const expected = [
      [255],
      [85, 170],
      [36, 72, 147],
      [17, 34, 68, 136],
      [8, 16, 32, 64, 135],
    ];
    for (var count = 1; count <= 15; count++) {
      final weights = encoder.partitionFor(count);
      expect(weights, expected[(count - 1) ~/ 3]);
      expect(weights.reduce((a, b) => a + b), 255);
      final sums = <int>{};
      for (var mask = 0; mask < 1 << weights.length; mask++) {
        var sum = 0;
        for (var i = 0; i < weights.length; i++) {
          if (mask & (1 << i) != 0) sum += weights[i];
        }
        expect(sums.add(sum), isTrue, reason: 'Duplicate sum at $count layers');
      }
    }
  });

  test(
    'Hand-calculated three-channel pixels: white contributes, black does not',
    () {
      final code = encoder.compose([
        QrModuleMatrix(size: 2, darkModules: [false, true, false, true]),
        QrModuleMatrix(size: 2, darkModules: [true, false, false, true]),
        QrModuleMatrix(size: 2, darkModules: [true, true, false, true]),
      ], padWithDummies: false);
      expect(code.raster.pixels, [0xff0000, 0x00ff00, 0xffffff, 0x000000]);
      expect(code.qrVersion, isNull);
    },
  );

  test('Paper example 3.1: red values 0,36,108,219,147,72,183,255,36', () {
    const samples = [0, 36, 108, 219, 147, 72, 183, 255, 36];
    final code = encoder.compose([
      QrModuleMatrix(
        size: 3,
        darkModules: [
          true,
          false,
          false,
          true,
          true,
          true,
          false,
          false,
          false,
        ],
      ),
      QrModuleMatrix(
        size: 3,
        darkModules: [true, true, false, false, true, false, true, false, true],
      ),
      QrModuleMatrix(
        size: 3,
        darkModules: [true, true, true, false, false, true, false, false, true],
      ),
      for (var i = 0; i < 4; i++) matrix(3, dark: true),
    ], padWithDummies: false);
    expect(code.partition, [36, 72, 147]);
    expect(code.raster.pixels, samples.map((value) => value << 16));
    expect(code.layers.map((layer) => layer.weight), [
      36,
      72,
      147,
      36,
      72,
      147,
      36,
    ]);
    expect(code.layers.map((layer) => layer.channel), [
      MlqrChannel.red,
      MlqrChannel.red,
      MlqrChannel.red,
      MlqrChannel.green,
      MlqrChannel.green,
      MlqrChannel.green,
      MlqrChannel.blue,
    ]);
  });

  test('Seven unpadded all-white layers have the paper background colour', () {
    final code = encoder.compose(
      List.generate(7, (_) => matrix(21)),
      padWithDummies: false,
    );
    expect(code.raster.pixels.toSet(), {0xffff24});
    expect(code.dummyCount, 0);
  });

  test(
    'Seven plus two dummies: white background and exactly three finder patterns',
    () {
      final code = encoder.encode(List.generate(7, (i) => packet('Layer $i')));
      expect(code.layers.length, 9);
      expect(code.payloadCount, 7);
      expect(code.dummyCount, 2);
      expect(
        code.layers.take(7).map((l) => l.payloadIndex),
        orderedEquals(List.generate(7, (i) => i)),
      );
      expect(code.layers.skip(7).every((layer) => layer.isDummy), isTrue);
      final size = code.raster.width;
      for (final layer in code.layers.skip(7)) {
        final dummy = layer.matrix;
        expect(dummy.darkModules.where((dark) => dark).length, 3 * 33);
        for (final (top, left) in [(0, 0), (0, size - 7), (size - 7, 0)]) {
          expect(dummy.isDark(top, left), isTrue);
          expect(dummy.isDark(top + 1, left + 1), isFalse);
          expect(dummy.isDark(top + 3, left + 3), isTrue);
          final separatorRow = top == 0 ? 7 : top - 1;
          final separatorColumn = left == 0 ? 7 : left - 1;
          expect(dummy.isDark(separatorRow, separatorColumn), isFalse);
          for (var r = 0; r < 7; r++) {
            for (var c = 0; c < 7; c++) {
              expect(
                dummy.isDark(top + r, left + c),
                code.layers.first.matrix.isDark(top + r, left + c),
              );
            }
          }
        }
      }
      expect(code.raster.pixelAt(0, 0), 0);
      expect(code.raster.pixelAt(1, 1), 0xffffff);
      final whiteInput = encoder.compose(List.generate(7, (_) => matrix(21)));
      expect(whiteInput.raster.pixelAt(10, 10), 0xffffff);
    },
  );

  test(
    'One to fifteen payload layers preserve input order and pad predictably',
    () {
      for (var count = 1; count <= 15; count++) {
        final code = encoder.encode(
          List.generate(count, (i) => packet('Test $i')),
        );
        expect(code.layers.length, ((count + 2) ~/ 3) * 3);
        expect(code.dummyCount, (3 - count % 3) % 3);
        expect(
          code.layers.take(count).map((l) => l.payloadIndex),
          List.generate(count, (i) => i),
        );
        expect(
          code.raster.pixels.every((pixel) => pixel >= 0 && pixel <= 0xffffff),
          isTrue,
        );
      }
    },
  );

  test(
    'Reference bar counts optical layers, stays outside an intact quiet zone',
    () {
      for (final padded in [false, true]) {
        final code = encoder.encode(
          List.generate(7, (i) => packet('Layer $i')),
          padWithDummies: padded,
        );
        final image = code.displayRaster;
        expect(image.width, code.raster.width + 9);
        expect(image.height, code.raster.height + 8);
        final count = padded ? 9 : 7;
        const colors = [0x00ff00, 0x0000ff, 0xff0000];
        for (var row = 0; row < image.height; row++) {
          for (var col = 0; col < image.width; col++) {
            final inCore =
                row >= 4 &&
                row < 4 + code.raster.height &&
                col >= 5 &&
                col < 5 + code.raster.width;
            if (inCore) {
              expect(
                image.pixelAt(row, col),
                code.raster.pixelAt(row - 4, col - 5),
              );
            } else if (col == 0 && row >= 4 && row < 4 + count) {
              expect(image.pixelAt(row, col), colors[(row - 4) % 3]);
            } else {
              expect(image.pixelAt(row, col), 0xffffff);
            }
          }
        }
      }
    },
  );

  test(
    'Smallest shared QR version and raw bytes, including a typed-data slice',
    () {
      final backing = Uint8List.fromList([99, 0, 128, 255, 77]);
      final packets = [
        Uint8List.sublistView(backing, 1, 4),
        packet('Grüsse 🌈'),
        Uint8List.fromList(List.generate(100, (i) => i)),
      ];
      final code = encoder.encode(packets);
      expect(code.qrVersion, 6); // Version 5-M holds 84 bytes; 6-M holds 106.
      for (var i = 0; i < packets.length; i++) {
        final expected = QrImage(
          QrCode(6, QrErrorCorrectLevel.M)
            ..addByteData(ByteData.sublistView(Uint8List.fromList(packets[i]))),
        );
        final actual = code.layers[i].matrix;
        expect(actual.size, 41);
        for (var row = 0; row < 41; row++) {
          for (var col = 0; col < 41; col++) {
            expect(actual.isDark(row, col), expected.isDark(row, col));
          }
        }
      }
      expect(encoder.encode([Uint8List(0)]).qrVersion, 1);
    },
  );

  test('QR version 40-M boundary accepts 2331 bytes and rejects 2332', () {
    expect(encoder.encode([Uint8List(2331)]).qrVersion, 40);
    expect(() => encoder.encode([Uint8List(2332)]), throwsFormatException);
    expect(() => encoder.encode([Uint8List(10000)]), throwsFormatException);
  });

  test(
    'Invalid layer counts, matrix dimensions and RGB values are rejected',
    () {
      expect(() => encoder.encode([]), throwsArgumentError);
      expect(
        () => encoder.encode(List.generate(16, (_) => packet('a'))),
        throwsArgumentError,
      );
      expect(() => encoder.partitionFor(0), throwsArgumentError);
      expect(() => encoder.partitionFor(16), throwsArgumentError);
      expect(
        () => encoder.compose([matrix(21), matrix(25)]),
        throwsArgumentError,
      );
      expect(() => encoder.compose([matrix(2)]), throwsArgumentError);
      expect(
        () => QrModuleMatrix(size: 2, darkModules: [true]),
        throwsArgumentError,
      );
      expect(
        () => MlqrRgbRaster(width: 1, height: 1, pixels: [0x1000000]),
        throwsArgumentError,
      );
    },
  );

  test('Matrices and results cannot be changed through caller-owned lists', () {
    final input = [false];
    final source = QrModuleMatrix(size: 1, darkModules: input);
    input[0] = true;
    expect(source.isDark(0, 0), isFalse);
    final code = encoder.compose([source], padWithDummies: false);
    expect(() => code.raster.pixels[0] = 0, throwsUnsupportedError);
    expect(() => code.layers.clear(), throwsUnsupportedError);
    expect(() => code.partition.clear(), throwsUnsupportedError);
    expect(() => source.darkModules[0] = true, throwsUnsupportedError);
  });
}
