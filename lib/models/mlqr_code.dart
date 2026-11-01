import 'dart:math' as math;

/// Square binary module matrix. True means black, as in the QR library.
class QrModuleMatrix {
  QrModuleMatrix({required this.size, required List<bool> darkModules})
    : darkModules = List.unmodifiable(darkModules) {
    if (size < 1 || darkModules.length != size * size) {
      throw ArgumentError('Eine quadratische QR-Matrix wird benötigt.');
    }
  }

  final int size;
  final List<bool> darkModules;

  bool isDark(int row, int column) {
    RangeError.checkValidIndex(row, darkModules, 'row', size);
    RangeError.checkValidIndex(column, darkModules, 'column', size);
    return darkModules[row * size + column];
  }
}

/// Immutable RGB raster; each pixel is packed as 0xRRGGBB, without alpha.
class MlqrRgbRaster {
  MlqrRgbRaster({
    required this.width,
    required this.height,
    required List<int> pixels,
  }) : pixels = List.unmodifiable(pixels) {
    if (width < 1 ||
        height < 1 ||
        pixels.length != width * height ||
        pixels.any((pixel) => pixel < 0 || pixel > 0xffffff)) {
      throw ArgumentError('Ungültiges RGB-Raster.');
    }
  }

  final int width;
  final int height;
  final List<int> pixels;

  int pixelAt(int row, int column) {
    RangeError.checkValidIndex(row, pixels, 'row', height);
    RangeError.checkValidIndex(column, pixels, 'column', width);
    return pixels[row * width + column];
  }

  /// Returns the centered square used by the on-screen scan guide.
  MlqrRgbRaster centerCropSquare({double fraction = 0.84}) {
    final safeFraction = fraction.clamp(0.1, 1.0).toDouble();
    final side = (math.min(width, height) * safeFraction).round();
    final left = (width - side) ~/ 2;
    final top = (height - side) ~/ 2;
    return MlqrRgbRaster(
      width: side,
      height: side,
      pixels: [
        for (var row = 0; row < side; row++)
          for (var column = 0; column < side; column++)
            pixelAt(top + row, left + column),
      ],
    );
  }
}

enum MlqrChannel { red, green, blue }

class MlqrLayer {
  const MlqrLayer({
    required this.matrix,
    required this.channel,
    required this.weight,
    required this.payloadIndex,
  });

  final QrModuleMatrix matrix;
  final MlqrChannel channel;
  final int weight;

  /// Null marks a dummy; otherwise this is the input packet's index.
  final int? payloadIndex;
  bool get isDummy => payloadIndex == null;
}

class MlqrCode {
  MlqrCode({
    required this.raster,
    required this.displayRaster,
    required this.qrVersion,
    required this.payloadCount,
    required List<int> partition,
    required List<MlqrLayer> layers,
  }) : partition = List.unmodifiable(partition),
       layers = List.unmodifiable(layers);

  /// Core modules only, before quiet zone and reference bar.
  final MlqrRgbRaster raster;
  final MlqrRgbRaster displayRaster;

  /// Null for arbitrary binary matrices composed without QR encoding.
  final int? qrVersion;
  final int payloadCount;
  final List<int> partition;
  final List<MlqrLayer> layers;
  int get dummyCount => layers.length - payloadCount;

  // Four quiet modules between the bar and the core, four on other sides.
  static const quietZone = 4;
  static const coreLeft = 5;
  static const coreTop = 4;
}
