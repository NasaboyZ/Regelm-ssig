import 'dart:typed_data';

import '../models/day_entry.dart';
import '../models/mlqr_code.dart';
import '../models/mlqr_decoded.dart';
import '../models/period_entry.dart';
import 'mlqr_decoder_service.dart';
import 'mlqr_encoder_service.dart';
import 'go_mlqr_renderer.dart';
import 'go_transfer_codec.dart';
import 'mlqr_renderer.dart';
import 'mlqr_transfer_profile.dart';
import 'transfer_codec.dart';

class MlqrTransferSequence {
  const MlqrTransferSequence({
    required this.codes,
    required this.package,
    required this.profile,
    required this.preparationDuration,
  });
  final List<MlqrCode> codes;
  final TransferPackage package;
  final MlqrTransferProfile profile;
  final Duration preparationDuration;
  int get codeCount => codes.length;
  int get chunkCount => package.chunks.length;
  int get maxPayloadLayersPerCode => codes.fold<int>(
    0,
    (max, code) => code.payloadCount > max ? code.payloadCount : max,
  );
  int get maxLayersPerCode => codes.fold<int>(
    0,
    (max, code) => code.layers.length > max ? code.layers.length : max,
  );
  int get maxQrVersion => codes.fold<int>(
    0,
    (max, code) => (code.qrVersion ?? 0) > max ? code.qrVersion! : max,
  );
  List<int> get payloadLayersPerCode => [
    for (final code in codes) code.payloadCount,
  ];
  List<int> get opticalLayersPerCode => [
    for (final code in codes) code.layers.length,
  ];
  int get visibleFrameCount => codes.length;
}

/// Bridges the logical transfer chunks and the physical multi-layer images.
class MlqrTransferService {
  MlqrTransferService({
    MlqrEncoderService? encoder,
    MlqrDecoderService? decoder,
    TrackingSnapshotTransferCodec? payloadCodec,
    MlqrRenderer? renderer,
    MlqrTransferProfile? profile,
    Iterable<MlqrProfileMeasurement> measuredProfiles = const [],
    int? targetQrVersion,
    int? maxPayloadLayersPerCode,
  }) : encoder = encoder ?? const MlqrEncoderService(),
       decoder = decoder ?? const MlqrDecoderService(),
       payloadCodec =
           payloadCodec ??
           GoTransferCodec.tryLoad() ??
           TrackingSnapshotTransferCodec(),
       renderer =
           renderer ?? GoMlqrRenderer.tryLoad() ?? const DartMlqrRenderer(),
       profile =
           profile ??
           const MlqrTransferProfileSelector().select(measuredProfiles),
       targetQrVersion =
           targetQrVersion ??
           (profile ??
                   const MlqrTransferProfileSelector().select(measuredProfiles))
               .targetQrVersion,
       maxPayloadLayersPerCode =
           maxPayloadLayersPerCode ??
           (profile ??
                   const MlqrTransferProfileSelector().select(measuredProfiles))
               .maxPayloadLayersPerCode,
       _automaticUnmeasuredProfile =
           profile == null &&
           measuredProfiles.isEmpty &&
           targetQrVersion == null &&
           maxPayloadLayersPerCode == null;

  final MlqrEncoderService encoder;
  final MlqrDecoderService decoder;
  final TrackingSnapshotTransferCodec payloadCodec;
  final MlqrRenderer renderer;
  final MlqrTransferProfile profile;
  final int targetQrVersion;
  final int maxPayloadLayersPerCode;
  final bool _automaticUnmeasuredProfile;

  Future<MlqrTransferSequence> encodeEncryptedSnapshot(
    TrackingSnapshot snapshot, {
    required String passphrase,
    required String transferId,
    int? chunkSize,
  }) async {
    final stopwatch = Stopwatch()..start();
    final effectiveChunkSize =
        chunkSize ?? _recommendedChunkSize(transferId, encrypted: true);
    final package = await payloadCodec.encodeEncryptedSnapshot(
      snapshot,
      passphrase: passphrase,
      transferId: transferId,
      chunkSize: effectiveChunkSize,
    );
    return _encodePackage(package, stopwatch.elapsed);
  }

  Future<MlqrTransferSequence> encodeUnencryptedSnapshotForDevelopment(
    TrackingSnapshot snapshot, {
    required String transferId,
    int? chunkSize,
  }) async {
    final stopwatch = Stopwatch()..start();
    final effectiveChunkSize =
        chunkSize ?? _recommendedChunkSize(transferId, encrypted: false);
    final package = await payloadCodec.encodeUnencryptedSnapshotForDevelopment(
      snapshot,
      transferId: transferId,
      chunkSize: effectiveChunkSize,
    );
    return _encodePackage(package, stopwatch.elapsed);
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
      protocolVersion: TrackingSnapshotTransferCodec.protocolVersion,
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

  MlqrTransferSequence _encodePackage(
    TransferPackage package,
    Duration preparationDuration,
  ) {
    if (maxPayloadLayersPerCode < 1 ||
        maxPayloadLayersPerCode > MlqrEncoderService.maxPayloadLayers) {
      throw ArgumentError.value(
        maxPayloadLayersPerCode,
        'maxPayloadLayersPerCode',
        'muss zwischen 1 und ${MlqrEncoderService.maxPayloadLayers} liegen',
      );
    }
    final fallbackToRobust =
        _automaticUnmeasuredProfile && package.chunks.length <= 10;
    final effectiveMaxPayloadLayers = fallbackToRobust
        ? MlqrTransferProfile.robust.maxPayloadLayersPerCode
        : maxPayloadLayersPerCode;
    final effectiveProfile = fallbackToRobust
        ? MlqrTransferProfile.robust
        : profile;
    final packets = package.chunks.map((chunk) => chunk.toBytes()).toList();
    final rendered = <MlqrCode>[];
    final distribution = _balancedDistribution(
      packets.length,
      effectiveMaxPayloadLayers,
    );
    var offset = 0;
    for (final count in distribution) {
      final end = offset + count;
      rendered.addAll(
        renderer.render(
          packets.sublist(offset, end),
          maxLayersPerCode: effectiveMaxPayloadLayers,
        ),
      );
      offset = end;
    }
    if (rendered.isEmpty) {
      throw const FormatException('Transfer enthält keine Nutzdaten.');
    }
    return MlqrTransferSequence(
      codes: List.unmodifiable(rendered),
      package: package,
      profile: effectiveProfile,
      preparationDuration: preparationDuration,
    );
  }

  List<int> _balancedDistribution(int totalChunks, int maxPerCode) {
    if (totalChunks < 1) {
      throw ArgumentError.value(totalChunks, 'totalChunks');
    }
    final codeCount = (totalChunks + maxPerCode - 1) ~/ maxPerCode;
    final base = totalChunks ~/ codeCount;
    final remainder = totalChunks % codeCount;
    return [for (var i = 0; i < codeCount; i++) base + (i < remainder ? 1 : 0)];
  }

  Future<TrackingSnapshot> decodeSnapshot(
    Iterable<MlqrDecoded> decodedCodes, {
    required String passphrase,
  }) async {
    final chunks = <TransferChunk>[];
    for (final code in decodedCodes) {
      for (final packet in code.packets) {
        chunks.add(TransferChunk.fromBytes(packet));
      }
    }
    return payloadCodec.decodeSnapshot(chunks, passphrase: passphrase);
  }

  Future<TrackingSnapshot> decodeUnencryptedSnapshotForDevelopment(
    Iterable<MlqrDecoded> decodedCodes,
  ) async {
    final chunks = <TransferChunk>[];
    for (final code in decodedCodes) {
      for (final packet in code.packets) {
        chunks.add(TransferChunk.fromBytes(packet));
      }
    }
    return payloadCodec.decodeSnapshot(chunks);
  }

  TrackingSnapshot mergeIncomingSnapshot(
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

  Future<TrackingSnapshot> decodeSnapshotFromImages(
    Iterable<MlqrRgbRaster> images, {
    required String passphrase,
  }) async {
    final decoded = [for (final image in images) decoder.decodeImage(image)];
    return decodeSnapshot(decoded, passphrase: passphrase);
  }

  Future<TrackingSnapshot> decodeSnapshotFromMlqrCodes(
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
    return decodeSnapshot(decoded, passphrase: passphrase);
  }

  Future<TrackingSnapshot> decodeUnencryptedSnapshotFromMlqrCodesForDevelopment(
    Iterable<MlqrCode> codes,
  ) {
    final decoded = [
      for (final code in codes)
        decoder.decodeRaster(
          code.raster,
          opticalLayerCount: code.layers.length,
        ),
    ];
    return decodeUnencryptedSnapshotForDevelopment(decoded);
  }
}
