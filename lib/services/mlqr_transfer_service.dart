import 'dart:typed_data';

import '../models/day_entry.dart';
import '../models/mlqr_code.dart';
import '../models/mlqr_decoded.dart';
import '../models/period_entry.dart';
import 'mlqr_decoder_service.dart';
import 'mlqr_encoder_service.dart';
import 'transfer_codec.dart';

class MlqrTransferSequence {
  const MlqrTransferSequence({required this.codes, required this.package});
  final List<MlqrCode> codes;
  final TransferPackage package;
  int get codeCount => codes.length;
  int get chunkCount => package.chunks.length;
  int get maxLayersPerCode => codes.fold<int>(
    0,
    (max, code) => code.layers.length > max ? code.layers.length : max,
  );
  int get maxQrVersion => codes.fold<int>(
    0,
    (max, code) => (code.qrVersion ?? 0) > max ? code.qrVersion! : max,
  );
}

/// Bridges the logical transfer chunks and the physical multi-layer images.
class MlqrTransferService {
  MlqrTransferService({
    MlqrEncoderService? encoder,
    MlqrDecoderService? decoder,
    TransferCodec? codec,
    this.targetQrVersion = 20,
  }) : encoder = encoder ?? const MlqrEncoderService(),
       decoder = decoder ?? const MlqrDecoderService(),
       codec = codec ?? TransferCodec();

  final MlqrEncoderService encoder;
  final MlqrDecoderService decoder;
  final TransferCodec codec;
  final int targetQrVersion;

  Future<MlqrTransferSequence> encode(
    TrackingSnapshot snapshot, {
    required String passphrase,
    required String transferId,
    int? chunkSize,
  }) async {
    final effectiveChunkSize =
        chunkSize ?? _recommendedChunkSize(transferId, encrypted: true);
    final package = await codec.encode(
      snapshot,
      passphrase: passphrase,
      transferId: transferId,
      chunkSize: effectiveChunkSize,
    );
    return _encodePackage(package);
  }

  Future<MlqrTransferSequence> encodeDevelopment(
    TrackingSnapshot snapshot, {
    required String transferId,
    int? chunkSize,
  }) async {
    final effectiveChunkSize =
        chunkSize ?? _recommendedChunkSize(transferId, encrypted: false);
    final package = await codec.encodeDevelopment(
      snapshot,
      transferId: transferId,
      chunkSize: effectiveChunkSize,
    );
    return _encodePackage(package);
  }

  int _recommendedChunkSize(String transferId, {required bool encrypted}) {
    var low = 32;
    var high = 1800;
    var best = low;
    while (low <= high) {
      final candidate = (low + high) ~/ 2;
      final fits = _fitsQrVersion(transferId, candidate, encrypted: encrypted);
      if (fits) {
        best = candidate;
        low = candidate + 1;
      } else {
        high = candidate - 1;
      }
    }
    return best;
  }

  bool _fitsQrVersion(
    String transferId,
    int payloadLength, {
    required bool encrypted,
  }) {
    final sample = TransferChunk(
      transferId: transferId,
      protocolVersion: TransferCodec.protocolVersion,
      index: 0,
      total: 0xffffffff,
      salt: encrypted ? Uint8List(16) : Uint8List(0),
      nonce: encrypted ? Uint8List(12) : Uint8List(0),
      cipherText: Uint8List(payloadLength),
      mac: encrypted ? Uint8List(16) : Uint8List(0),
      encrypted: encrypted,
    );
    try {
      final code = encoder.encode([sample.toBytes()], padWithDummies: false);
      return (code.qrVersion ?? 40) <= targetQrVersion;
    } on FormatException {
      return false;
    }
  }

  MlqrTransferSequence _encodePackage(TransferPackage package) {
    final codes = <MlqrCode>[];
    for (
      var offset = 0;
      offset < package.chunks.length;
      offset += MlqrEncoderService.maxPayloadLayers
    ) {
      final end = (offset + MlqrEncoderService.maxPayloadLayers).clamp(
        0,
        package.chunks.length,
      );
      codes.add(
        encoder.encode(
          package.chunks
              .sublist(offset, end)
              .map((chunk) => chunk.toBytes())
              .toList(),
        ),
      );
    }
    return MlqrTransferSequence(
      codes: List.unmodifiable(codes),
      package: package,
    );
  }

  Future<TrackingSnapshot> decode(
    Iterable<MlqrDecoded> decodedCodes, {
    required String passphrase,
  }) async {
    final chunks = <TransferChunk>[];
    for (final code in decodedCodes) {
      for (final packet in code.packets) {
        chunks.add(TransferChunk.fromBytes(packet));
      }
    }
    return codec.decode(chunks, passphrase: passphrase);
  }

  Future<TrackingSnapshot> decodeDevelopment(
    Iterable<MlqrDecoded> decodedCodes,
  ) async {
    final chunks = <TransferChunk>[];
    for (final code in decodedCodes) {
      for (final packet in code.packets) {
        chunks.add(TransferChunk.fromBytes(packet));
      }
    }
    return codec.decode(chunks);
  }

  TrackingSnapshot mergeSnapshots(
    TrackingSnapshot existing,
    TrackingSnapshot incoming,
  ) {
    final days = <DateTime, DayEntry>{...existing.days, ...incoming.days};
    final categories = <String, String>{
      ...existing.categories,
      ...incoming.categories,
    };
    final periodsById = <String, PeriodEntry>{
      for (final period in existing.periods) period.id: period,
      for (final period in incoming.periods) period.id: period,
    };
    return TrackingSnapshot(
      days: days,
      categories: categories,
      periods: periodsById.values.toList(),
      forecastConsent: incoming.forecastConsent,
    );
  }

  Future<TrackingSnapshot> decodeImages(
    Iterable<MlqrRgbRaster> images, {
    required String passphrase,
  }) async {
    final decoded = [for (final image in images) decoder.decodeImage(image)];
    return decode(decoded, passphrase: passphrase);
  }

  Future<TrackingSnapshot> decodeCodes(
    Iterable<MlqrCode> codes, {
    required String passphrase,
  }) {
    final decoded = [
      for (final code in codes)
        decoder.decodeRaster(
          code.raster,
          opticalLayerCount: code.layers.length,
        ),
    ];
    return decode(decoded, passphrase: passphrase);
  }

  Future<TrackingSnapshot> decodeCodesDevelopment(Iterable<MlqrCode> codes) {
    final decoded = [
      for (final code in codes)
        decoder.decodeRaster(
          code.raster,
          opticalLayerCount: code.layers.length,
        ),
    ];
    return decodeDevelopment(decoded);
  }
}
