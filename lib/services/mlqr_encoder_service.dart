import 'dart:typed_data';

import 'package:qr/qr.dart';

import '../models/mlqr_code.dart';

/// Noppakaew, Khomkuth & Sriwilas (2018), sections 2.1–2.4.
/// DOI: 10.22436/jmcs.018.03.06. Independently implemented from the paper.
class MlqrEncoderService {
  const MlqrEncoderService();

  static const maxPayloadLayers = 15;
  static const errorCorrectionLevel = QrErrorCorrectLevel.M;

  /// Partition of 255 using a=2. One common partition for all RGB channels.
  List<int> partitionFor(int layerCount) {
    _validateCount(layerCount);
    final length = (layerCount + 2) ~/ 3;
    final step = 255 ~/ ((1 << length) - 1);
    final weights = [for (var i = 0; i < length - 1; i++) step * (1 << i)];
    weights.add(255 - weights.fold(0, (sum, weight) => sum + weight));
    return List.unmodifiable(weights);
  }

  /// Each packet becomes one ordinary QR code. Does not split or encrypt data.
  MlqrCode encode(List<Uint8List> packets, {bool padWithDummies = true}) {
    _validateCount(packets.length);
    var version = 1;
    try {
      for (final packet in packets) {
        final candidate = QrCode.fromUint8List(
          data: packet,
          errorCorrectLevel: errorCorrectionLevel,
        );
        if (candidate.typeNumber > version) version = candidate.typeNumber;
      }
      final matrices = <QrModuleMatrix>[];
      for (final packet in packets) {
        final code = QrCode(version, errorCorrectionLevel)
          ..addByteData(ByteData.sublistView(packet));
        // Public API also validates capacity at the version-40 boundary.
        final image = QrImage(code);
        matrices.add(
          QrModuleMatrix(
            size: image.moduleCount,
            darkModules: [
              for (var row = 0; row < image.moduleCount; row++)
                for (var col = 0; col < image.moduleCount; col++)
                  image.isDark(row, col),
            ],
          ),
        );
      }
      return _compose(matrices, padWithDummies, version);
    } on InputTooLongException {
      throw const FormatException(
        'Ein Datenpaket überschreitet die QR-Kapazität bei Fehlerkorrektur M. '
        'Teile die Daten in kleinere Pakete auf.',
      );
    }
  }

  /// Matrix-level entry point for mathematical tests and external QR adapters.
  MlqrCode compose(
    List<QrModuleMatrix> matrices, {
    bool padWithDummies = true,
  }) => _compose(matrices, padWithDummies, null);

  MlqrCode _compose(
    List<QrModuleMatrix> matrices,
    bool padWithDummies,
    int? version,
  ) {
    _validateCount(matrices.length);
    final size = matrices.first.size;
    if (matrices.any((matrix) => matrix.size != size)) {
      throw ArgumentError('Alle QR-Ebenen müssen gleich gross sein.');
    }
    final partition = partitionFor(matrices.length);
    final total = padWithDummies ? partition.length * 3 : matrices.length;
    if (total > matrices.length && size < 21) {
      throw ArgumentError(
        'Dummy-Ebenen benötigen ein QR-Raster ab 21 Modulen.',
      );
    }
    final layers = <MlqrLayer>[
      for (var i = 0; i < total; i++)
        MlqrLayer(
          matrix: i < matrices.length ? matrices[i] : _dummy(size),
          channel: MlqrChannel.values[i ~/ partition.length],
          weight: partition[i % partition.length],
          payloadIndex: i < matrices.length ? i : null,
        ),
    ];
    final pixels = List<int>.filled(size * size, 0);
    for (final layer in layers) {
      final shift = (2 - layer.channel.index) * 8;
      for (var i = 0; i < pixels.length; i++) {
        if (!layer.matrix.darkModules[i]) {
          pixels[i] += layer.weight << shift;
        }
      }
    }
    final raster = MlqrRgbRaster(width: size, height: size, pixels: pixels);
    return MlqrCode(
      raster: raster,
      displayRaster: _decorate(raster, total),
      qrVersion: version,
      payloadCount: matrices.length,
      partition: partition,
      layers: layers,
    );
  }

  QrModuleMatrix _dummy(int size) {
    final modules = List<bool>.filled(size * size, false);
    for (final (top, left) in [(0, 0), (0, size - 7), (size - 7, 0)]) {
      for (var row = 0; row < 7; row++) {
        for (var col = 0; col < 7; col++) {
          modules[(top + row) * size + left + col] =
              row == 0 ||
              row == 6 ||
              col == 0 ||
              col == 6 ||
              (row >= 2 && row <= 4 && col >= 2 && col <= 4);
        }
      }
    }
    return QrModuleMatrix(size: size, darkModules: modules);
  }

  MlqrRgbRaster _decorate(MlqrRgbRaster core, int layerCount) {
    final width = core.width + MlqrCode.coreLeft + MlqrCode.quietZone;
    // Arbitrary tiny test matrices may need a taller reference bar.
    final contentHeight = core.height > layerCount ? core.height : layerCount;
    final height = contentHeight + MlqrCode.coreTop + MlqrCode.quietZone;
    final pixels = List<int>.filled(width * height, 0xffffff);
    for (var row = 0; row < core.height; row++) {
      for (var col = 0; col < core.width; col++) {
        pixels[(row + MlqrCode.coreTop) * width + col + MlqrCode.coreLeft] =
            core.pixelAt(row, col);
      }
    }
    const referenceColors = [0x00ff00, 0x0000ff, 0xff0000];
    for (var i = 0; i < layerCount; i++) {
      pixels[(MlqrCode.coreTop + i) * width] = referenceColors[i % 3];
    }
    return MlqrRgbRaster(width: width, height: height, pixels: pixels);
  }

  void _validateCount(int count) {
    if (count < 1 || count > maxPayloadLayers) {
      throw ArgumentError(
        'Es werden 1 bis $maxPayloadLayers Nutzdatenebenen benötigt.',
      );
    }
  }
}
