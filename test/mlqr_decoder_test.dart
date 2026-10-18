import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:regelmaessig/models/mlqr_code.dart';
import 'package:regelmaessig/models/mlqr_decoded.dart';
import 'package:regelmaessig/services/mlqr_decoder_service.dart';
import 'package:regelmaessig/services/mlqr_encoder_service.dart';

List<Uint8List> packets(int count) => [
  for (var i = 0; i < count; i++)
    Uint8List.fromList(List.generate(35 + i, (j) => (j * 37 + i * 29) % 256)),
];

MlqrRgbRaster enlarge(
  MlqrRgbRaster raster, {
  int scale = 6,
  bool tint = false,
}) {
  final width = (raster.width + 8) * scale;
  final height = (raster.height + 8) * scale;
  return MlqrRgbRaster(
    width: width,
    height: height,
    pixels: [
      for (var row = 0; row < height; row++)
        for (var col = 0; col < width; col++)
          (() {
            final x = col ~/ scale - 4;
            final y = row ~/ scale - 4;
            final rgb =
                x < 0 || y < 0 || x >= raster.width || y >= raster.height
                ? 0xffffff
                : raster.pixelAt(y, x);
            if (!tint) return rgb;
            return ((((rgb >> 16) & 255) * 0.7 + 20).round() << 16) |
                ((((rgb >> 8) & 255) * 0.8 + 15).round() << 8) |
                ((rgb & 255) * 0.65 + 25).round();
          })(),
    ],
  );
}

MlqrRgbRaster rotate(MlqrRgbRaster image) => MlqrRgbRaster(
  width: image.height,
  height: image.width,
  pixels: [
    for (var y = 0; y < image.width; y++)
      for (var x = 0; x < image.height; x++)
        image.pixelAt(image.height - 1 - x, y),
  ],
);

void main() {
  const encoder = MlqrEncoderService();
  const decoder = MlqrDecoderService();

  test(
    'All 1–15 layers round-trip raw bytes, with and without dummy padding',
    () {
      for (var count = 1; count <= 15; count++) {
        final input = packets(count);
        for (final padded in [false, true]) {
          final encoded = encoder.encode(input, padWithDummies: padded);
          final decoded = decoder.decodeRaster(
            encoded.raster,
            opticalLayerCount: encoded.layers.length,
          );
          expect(
            decoded.packets,
            input,
            reason: '$count layers, padded=$padded',
          );
          expect(decoded.dummyCount, encoded.dummyCount);
        }
      }
    },
  );

  test(
    'Camera path finds code, counts reference cells and recovers rotated/tinted RGB',
    () {
      final input = packets(3);
      final encoded = encoder.encode(input);
      var image = enlarge(encoded.displayRaster, tint: true);
      for (var turn = 0; turn < 4; turn++) {
        expect(
          decoder.decodeImage(image).packets,
          input,
          reason: 'Rotation $turn',
        );
        image = rotate(image);
      }
    },
  );

  test(
    'Image path reads the paper seven-layer layout with nine optical layers',
    () {
      final input = packets(7);
      final encoded = encoder.encode(input);
      final decoded = decoder.decodeImage(enlarge(encoded.displayRaster));
      expect(decoded.packets, input);
      expect(decoded.opticalLayerCount, 9);
      expect(decoded.dummyCount, 2);
    },
  );

  test(
    'Ordinary QR without reference bar and ambiguous channel values are rejected',
    () {
      final encoded = encoder.encode(packets(3));
      expect(
        () => decoder.decodeImage(enlarge(encoded.raster)),
        throwsA(isA<MlqrDecodeException>()),
      );
      final pixelData = encoded.raster.pixels.toList()..[0] = 0x120000;
      expect(
        () => decoder.decodeRaster(
          MlqrRgbRaster(
            width: encoded.raster.width,
            height: encoded.raster.height,
            pixels: pixelData,
          ),
          opticalLayerCount: 3,
        ),
        throwsA(isA<MlqrDecodeException>()),
      );
    },
  );

  test(
    'A destroyed layer cannot be silently dropped or reported as success',
    () {
      final encoded = encoder.encode(packets(3));
      final random = math.Random(42);
      final damaged = encoded.raster.pixels
          .map((p) => (p & 0xffff00) | (random.nextBool() ? 255 : 0))
          .toList();
      expect(
        () => decoder.decodeRaster(
          MlqrRgbRaster(
            width: encoded.raster.width,
            height: encoded.raster.height,
            pixels: damaged,
          ),
          opticalLayerCount: 3,
        ),
        throwsA(isA<MlqrDecodeException>()),
      );
    },
  );
}
