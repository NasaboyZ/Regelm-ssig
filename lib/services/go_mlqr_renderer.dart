import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../models/mlqr_code.dart';
import 'go_native_library.dart';
import 'mlqr_renderer.dart';

typedef _EncodeNative =
    Pointer<Uint8> Function(Pointer<Uint8>, Int32, Int32, Pointer<Int32>);
typedef _EncodeDart =
    Pointer<Uint8> Function(Pointer<Uint8>, int, int, Pointer<Int32>);

/// Optional in-process Go renderer. The Dart renderer remains the safe
/// fallback until the platform build embeds libregelmaessig_transfer.
final class GoMlqrRenderer implements MlqrRenderer {
  GoMlqrRenderer._(GoNativeLibrary native)
    : _encode = native.library.lookupFunction<_EncodeNative, _EncodeDart>(
        'regelmaessig_mlqr_encode',
      ),
      _free = native.free;

  final _EncodeDart _encode;
  final GoFreeFunction _free;

  static GoMlqrRenderer? tryLoad() {
    try {
      final native = GoNativeLibrary.tryLoad();
      if (native != null) return GoMlqrRenderer._(native);
    } on Object {
      // The platform build may not contain Go yet; caller uses Dart.
    }
    return null;
  }

  @override
  List<MlqrCode> render(
    List<Uint8List> packets, {
    required int maxLayersPerCode,
    bool padWithDummies = true,
  }) {
    if (packets.isEmpty) return const [];
    final input = BytesBuilder();
    _writeUint32(input, packets.length);
    for (final packet in packets) {
      _writeUint32(input, packet.length);
      input.add(packet);
    }
    final inputBytes = input.takeBytes();
    final inputPointer = calloc<Uint8>(inputBytes.length);
    final resultLength = calloc<Int32>();
    try {
      inputPointer.asTypedList(inputBytes.length).setAll(0, inputBytes);
      final result = _encode(
        inputPointer,
        inputBytes.length,
        maxLayersPerCode,
        resultLength,
      );
      if (result == nullptr || resultLength.value <= 0) {
        throw StateError('Go-MLQR-Encoder konnte keine Ausgabe erzeugen.');
      }
      final bytes = result.asTypedList(resultLength.value).toList();
      _free(result.cast());
      return _decodeFrames(bytes);
    } finally {
      calloc.free(inputPointer);
      calloc.free(resultLength);
    }
  }

  @override
  bool get supportsTemporalFallback => false;

  List<MlqrCode> _decodeFrames(List<int> bytes) {
    var offset = 0;
    final count = _readUint32(bytes, offset);
    offset += 4;
    final codes = <MlqrCode>[];
    for (var frame = 0; frame < count; frame++) {
      final width = _readUint32(bytes, offset);
      final height = _readUint32(bytes, offset + 4);
      final qrVersion = _readUint32(bytes, offset + 8);
      final payloadCount = _readUint32(bytes, offset + 12);
      final pixelLength = _readUint32(bytes, offset + 16);
      offset += 20;
      if (pixelLength != width * height * 3 ||
          offset + pixelLength > bytes.length) {
        throw StateError('Ungültige Go-MLQR-Ausgabe.');
      }
      final displayPixels = <int>[
        for (var index = offset; index < offset + pixelLength; index += 3)
          (bytes[index] << 16) | (bytes[index + 1] << 8) | bytes[index + 2],
      ];
      offset += pixelLength;
      final coreLeft = MlqrCode.coreLeft;
      final coreTop = MlqrCode.coreTop;
      final coreWidth = width - coreLeft - MlqrCode.quietZone;
      final coreHeight = height - coreTop - MlqrCode.quietZone;
      final corePixels = <int>[
        for (var row = 0; row < coreHeight; row++)
          for (var col = 0; col < coreWidth; col++)
            displayPixels[(row + coreTop) * width + col + coreLeft],
      ];
      final core = MlqrRgbRaster(
        width: coreWidth,
        height: coreHeight,
        pixels: corePixels,
      );
      final layers = [
        for (var index = 0; index < payloadCount; index++)
          MlqrLayer(
            matrix: QrModuleMatrix(
              size: coreWidth,
              darkModules: List<bool>.filled(coreWidth * coreWidth, false),
            ),
            channel: MlqrChannel.values[index % 3],
            weight: 0,
            payloadIndex: index,
          ),
      ];
      codes.add(
        MlqrCode(
          raster: core,
          displayRaster: MlqrRgbRaster(
            width: width,
            height: height,
            pixels: displayPixels,
          ),
          qrVersion: qrVersion,
          payloadCount: payloadCount,
          partition: const [],
          layers: layers,
        ),
      );
    }
    if (offset != bytes.length) throw StateError('Überzählige Go-MLQR-Daten.');
    return codes;
  }
}

void _writeUint32(BytesBuilder builder, int value) {
  builder.add([
    (value >> 24) & 255,
    (value >> 16) & 255,
    (value >> 8) & 255,
    value & 255,
  ]);
}

int _readUint32(List<int> bytes, int offset) {
  if (offset < 0 || offset + 4 > bytes.length) {
    throw StateError('Abgeschnittene Go-MLQR-Ausgabe.');
  }
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}
