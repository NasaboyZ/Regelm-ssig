import 'dart:math' as math;
import 'dart:typed_data';

import 'mlqr_code.dart';

enum MlqrCameraFormat { bgra8888, yuv420 }

/// Owned copies: the camera may reuse its native buffers after the callback.
class MlqrCameraPlane {
  MlqrCameraPlane(List<int> bytes, this.rowStride, this.pixelStride)
    : bytes = Uint8List.fromList(bytes);
  final Uint8List bytes;
  final int rowStride;
  final int pixelStride;
}

class MlqrCameraFrame {
  const MlqrCameraFrame({
    required this.width,
    required this.height,
    required this.format,
    required this.planes,
  });
  final int width;
  final int height;
  final MlqrCameraFormat format;
  final List<MlqrCameraPlane> planes;

  /// Preserve RGB, respect row padding and interleaved chroma pixel strides.
  /// Conversion and decoding run in an isolate, never in the preview build.
  MlqrRgbRaster toRaster({int maxDimension = 1280}) {
    if (width < 1 ||
        height < 1 ||
        maxDimension < 1 ||
        planes.length != (format == MlqrCameraFormat.bgra8888 ? 1 : 3)) {
      throw const FormatException('Nicht unterstütztes Kamerabild.');
    }
    final step = math.max(1, (math.max(width, height) / maxDimension).ceil());
    final w = (width + step - 1) ~/ step;
    final h = (height + step - 1) ~/ step;
    int sample(int plane, int x, int y, [int channel = 0]) {
      final p = planes[plane];
      final index = y * p.rowStride + x * p.pixelStride + channel;
      if (p.rowStride < 1 || p.pixelStride < 1 || index >= p.bytes.length) {
        throw const FormatException('Ungültige Kamerabild-Geometrie.');
      }
      return p.bytes[index];
    }

    int clamp(double value) => value.round().clamp(0, 255);
    final pixels = List<int>.filled(w * h, 0);
    for (var row = 0; row < h; row++) {
      for (var col = 0; col < w; col++) {
        final x = col * step;
        final y = row * step;
        int r, g, b;
        if (format == MlqrCameraFormat.bgra8888) {
          b = sample(0, x, y);
          g = sample(0, x, y, 1);
          r = sample(0, x, y, 2);
        } else {
          final luminance = sample(0, x, y).toDouble();
          final u = sample(1, x ~/ 2, y ~/ 2) - 128;
          final v = sample(2, x ~/ 2, y ~/ 2) - 128;
          r = clamp(luminance + 1.402 * v);
          g = clamp(luminance - 0.344136 * u - 0.714136 * v);
          b = clamp(luminance + 1.772 * u);
        }
        pixels[row * w + col] = (r << 16) | (g << 8) | b;
      }
    }
    return MlqrRgbRaster(width: w, height: h, pixels: pixels);
  }
}
