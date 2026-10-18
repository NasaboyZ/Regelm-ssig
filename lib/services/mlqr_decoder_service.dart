import 'dart:math' as math;
import 'dart:typed_data';

import '../models/mlqr_code.dart';
import '../models/mlqr_decoded.dart';
import 'mlqr_encoder_service.dart';
import 'mlqr_qr_adapter.dart';

/// Paper section 3: subset-sum separation followed by standard QR decoding.
class MlqrDecoderService {
  const MlqrDecoderService();

  /// Decode an already aligned core raster. Exact digital values by default.
  MlqrDecoded decodeRaster(
    MlqrRgbRaster core, {
    required int opticalLayerCount,
    double tolerance = 0,
  }) {
    if (core.width != core.height ||
        core.width < 21 ||
        core.width > 177 ||
        core.width % 4 != 1) {
      throw const MlqrDecodeException('Ungültiges QR-Modulraster.');
    }
    final partition = const MlqrEncoderService().partitionFor(
      opticalLayerCount,
    );
    final matrices = List.generate(
      opticalLayerCount,
      (_) => List<bool>.filled(core.pixels.length, true),
    );
    for (var channel = 0; channel < 3; channel++) {
      final first = channel * partition.length;
      final length = math.min(partition.length, opticalLayerCount - first);
      final sums = <int, int>{};
      if (length > 0) {
        for (var mask = 0; mask < 1 << length; mask++) {
          var sum = 0;
          for (var bit = 0; bit < length; bit++) {
            if (mask & (1 << bit) != 0) sum += partition[bit];
          }
          sums[sum] = mask;
        }
      } else {
        sums[0] = 0;
      }
      final lookup = List<int?>.filled(256, null);
      for (var value = 0; value < 256; value++) {
        var distance = double.infinity;
        int? nearest;
        var tied = false;
        for (final entry in sums.entries) {
          final delta = (entry.key - value).abs().toDouble();
          if (delta < distance) {
            distance = delta;
            nearest = entry.value;
            tied = false;
          } else if (delta == distance) {
            tied = true;
          }
        }
        if (!tied && distance <= tolerance) lookup[value] = nearest;
      }
      for (var pixel = 0; pixel < core.pixels.length; pixel++) {
        final value = (core.pixels[pixel] >> ((2 - channel) * 8)) & 255;
        final mask = lookup[value];
        if (mask == null) {
          throw const MlqrDecodeException(
            'Farben sind nicht eindeutig trennbar. Bitte neu ausrichten.',
          );
        }
        for (var bit = 0; bit < length; bit++) {
          matrices[first + bit][pixel] = mask & (1 << bit) == 0;
        }
      }
    }
    final adapter = MlqrQrAdapter();
    final packets = <Uint8List>[];
    var seenDummy = false;
    var dummyCount = 0;
    for (final modules in matrices) {
      final matrix = QrModuleMatrix(size: core.width, darkModules: modules);
      if (_isExactDummy(matrix)) {
        seenDummy = true;
        dummyCount++;
        continue;
      }
      if (seenDummy) {
        throw const MlqrDecodeException('Dummy-Ebenen müssen am Ende stehen.');
      }
      try {
        packets.add(adapter.decode(matrix));
      } on MlqrDecodeException catch (error) {
        throw MlqrDecodeException(error.message, layersRead: packets.length);
      }
    }
    if (packets.isEmpty ||
        dummyCount > 2 ||
        (dummyCount > 0 && opticalLayerCount % 3 != 0)) {
      throw const MlqrDecodeException(
        'Ungültige Nutzdaten- oder Dummy-Ebenen.',
      );
    }
    return MlqrDecoded(
      opticalLayerCount: opticalLayerCount,
      qrVersion: (core.width - 17) ~/ 4,
      packets: packets,
    );
  }

  /// Locate in a camera RGB frame; read the bar, calibrate and sample modules.
  MlqrDecoded decodeImage(MlqrRgbRaster image) {
    MlqrDecodeException last = const MlqrDecodeException(
      'Noch kein vollständiger Multi-Layer-QR-Code erkannt.',
    );
    for (final grid in MlqrQrAdapter().locate(image)) {
      try {
        final black = grid.sample(3.5, 3.5);
        final white = grid.sample(-2.5, 3.5);
        final range = List.generate(3, (i) => white[i] - black[i]);
        if (range.any((value) => value < 45)) {
          throw const MlqrDecodeException(
            'Zu wenig Farbkontrast. Bitte Beleuchtung prüfen.',
          );
        }
        List<double> normalize(List<double> rgb) => List.generate(
          3,
          (i) =>
              ((rgb[i] - black[i]) * 255 / range[i]).clamp(0, 255).toDouble(),
        );
        var count = 0;
        const order = [1, 2, 0]; // green, blue, red
        // Read one extra cell to reject a truncated or >15-layer reference bar.
        for (var i = 0; i <= 15; i++) {
          final color = normalize(grid.sample(-4.5, i + 0.5));
          final expected = order[i % 3];
          final other = [
            for (var c = 0; c < 3; c++)
              if (c != expected) color[c],
          ].reduce(math.max);
          if (color[expected] > 120 && color[expected] - other > 60) {
            count++;
          } else if (color.every((v) => v > 175)) {
            break;
          } else {
            throw const MlqrDecodeException(
              'Referenzbalken nicht eindeutig erkannt.',
            );
          }
        }
        if (count < 1 || count > 15) {
          throw const MlqrDecodeException('Kein gültiger Referenzbalken.');
        }
        final pixels = <int>[];
        for (var row = 0; row < grid.size; row++) {
          for (var col = 0; col < grid.size; col++) {
            final rgb = normalize(grid.sample(col + 0.5, row + 0.5));
            pixels.add(
              (rgb[0].round() << 16) | (rgb[1].round() << 8) | rgb[2].round(),
            );
          }
        }
        final partition = const MlqrEncoderService().partitionFor(count);
        // Never accept a value on/beyond half the minimum subset spacing.
        // This is deliberately conservative; no guesses across ambiguous bins.
        final tolerance = partition.first / 2 - 0.5;
        return decodeRaster(
          MlqrRgbRaster(width: grid.size, height: grid.size, pixels: pixels),
          opticalLayerCount: count,
          tolerance: tolerance,
        );
      } on MlqrDecodeException catch (error) {
        if (error.layersRead >= last.layersRead) last = error;
      }
    }
    throw last;
  }

  bool _isExactDummy(QrModuleMatrix matrix) {
    for (var row = 0; row < matrix.size; row++) {
      for (var col = 0; col < matrix.size; col++) {
        var dark = false;
        for (final (top, left) in [
          (0, 0),
          (0, matrix.size - 7),
          (matrix.size - 7, 0),
        ]) {
          final r = row - top;
          final c = col - left;
          if (r >= 0 && r < 7 && c >= 0 && c < 7) {
            dark =
                r == 0 ||
                r == 6 ||
                c == 0 ||
                c == 6 ||
                (r >= 2 && r <= 4 && c >= 2 && c <= 4);
          }
        }
        if (matrix.isDark(row, col) != dark) return false;
      }
    }
    return true;
  }
}
