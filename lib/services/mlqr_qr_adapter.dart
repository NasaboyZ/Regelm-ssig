// ZXing's matrix/detector APIs are not re-exported by qrcode.dart. Keep these
// version-pinned imports in this adapter; no other application file uses them.
// ignore_for_file: implementation_imports
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:zxing2/qrcode.dart';
import 'package:zxing2/src/common/bit_matrix.dart';
import 'package:zxing2/src/common/perspective_transform.dart';
import 'package:zxing2/src/qrcode/decoder/decoder.dart';
import 'package:zxing2/src/qrcode/detector/detector.dart';

import '../models/mlqr_code.dart';
import '../models/mlqr_decoded.dart';

class MlqrQrAdapter {
  Uint8List decode(QrModuleMatrix matrix) {
    final bits = BitMatrix(matrix.size);
    for (var row = 0; row < matrix.size; row++) {
      for (var col = 0; col < matrix.size; col++) {
        if (matrix.isDark(row, col)) bits.set(col, row);
      }
    }
    try {
      final result = Decoder().decode(bits, hints: DecodeHints());
      // rawBytes are QR data codewords, not the original payload!
      final segments = result.byteSegments;
      if (segments == null) {
        throw const MlqrDecodeException('Die Ebene enthält keine Byte-Pakete.');
      }
      return Uint8List.fromList([for (final segment in segments) ...segment]);
    } on ReaderException {
      throw const MlqrDecodeException(
        'Eine QR-Ebene konnte nicht gelesen werden.',
      );
    }
  }

  /// Try several monochrome projections for finding shared finder patterns.
  /// Decoding still uses the original RGB pixels, never these projections.
  Iterable<MlqrSamplingGrid> locate(MlqrRgbRaster image) sync* {
    for (var mode = 0; mode < 3; mode++) {
      final pixels = Int32List(image.pixels.length);
      for (var i = 0; i < pixels.length; i++) {
        final rgb = image.pixels[i];
        if (mode == 0) {
          pixels[i] = rgb;
        } else {
          final r = (rgb >> 16) & 255;
          final g = (rgb >> 8) & 255;
          final b = rgb & 255;
          final value = mode == 1
              ? math.min(r, math.min(g, b))
              : math.max(r, math.max(g, b));
          pixels[i] = value * 0x010101;
        }
      }
      try {
        final binary = BinaryBitmap(
          HybridBinarizer(
            RGBLuminanceSource(image.width, image.height, pixels),
          ),
        );
        final found = Detector(
          binary.getBlackMatrix(),
        ).detect(hints: DecodeHints()..put(DecodeHintType.tryHarder));
        final dimension = found.bits.width;
        if (dimension < 21 || dimension > 177 || dimension % 4 != 1) continue;
        final bottomLeft = found.points[0];
        final topLeft = found.points[1];
        final topRight = found.points[2];
        final alignment = found.points.length == 4 ? found.points[3] : null;
        final far = dimension - 3.5;
        final fourth = alignment == null ? far : far - 3;
        // Finder centres are (3.5,3.5); the alignment centre is three modules
        // inward from the missing bottom-right finder. Same geometry as ZXing.
        final transform = PerspectiveTransform.quadrilateralToQuadrilateral(
          3.5,
          3.5,
          far,
          3.5,
          fourth,
          fourth,
          3.5,
          far,
          topLeft.x,
          topLeft.y,
          topRight.x,
          topRight.y,
          alignment?.x ?? topRight.x + bottomLeft.x - topLeft.x,
          alignment?.y ?? topRight.y + bottomLeft.y - topLeft.y,
          bottomLeft.x,
          bottomLeft.y,
        );
        yield MlqrSamplingGrid._(image, dimension, transform);
      } on ReaderException {
        // A bad projection/frame is expected while the user aims the camera.
      }
    }
  }
}

class MlqrSamplingGrid {
  MlqrSamplingGrid._(this.image, this.size, this._transform);
  final MlqrRgbRaster image;
  final int size;
  final PerspectiveTransform _transform;

  /// Average nine samples within the central part of a module.
  List<double> sample(double x, double y) {
    final positions = <double>[
      for (final dy in [-0.18, 0.0, 0.18])
        for (final dx in [-0.18, 0.0, 0.18]) ...[x + dx, y + dy],
    ];
    _transform.transformPoints(positions);
    final result = [0.0, 0.0, 0.0];
    for (var i = 0; i < positions.length; i += 2) {
      final px = positions[i];
      final py = positions[i + 1];
      if (!px.isFinite ||
          !py.isFinite ||
          px < 0 ||
          py < 0 ||
          px >= image.width ||
          py >= image.height) {
        throw const MlqrDecodeException(
          'Code und Referenzbalken müssen vollständig sichtbar sein.',
        );
      }
      final pixel = image.pixelAt(py.floor(), px.floor());
      result[0] += (pixel >> 16) & 255;
      result[1] += (pixel >> 8) & 255;
      result[2] += pixel & 255;
    }
    return result.map((v) => v / 9).toList();
  }
}
