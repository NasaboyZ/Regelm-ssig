import 'dart:convert';
import 'dart:typed_data';

import '../models/mlqr_code.dart';
import '../services/mlqr_encoder_service.dart';
import '../services/mlqr_transfer_service.dart';

enum TransferDisplayMode { layered }

class TransferDisplayFrame {
  const TransferDisplayFrame({required this.raster, required this.mode});

  final MlqrRgbRaster raster;
  final TransferDisplayMode mode;
}

/// Preview model or a sequence of real transfer images.
class TransferSendViewModel {
  TransferSendViewModel.preview({
    MlqrEncoderService encoder = const MlqrEncoderService(),
  }) : isPreview = true,
       transferSequence = null,
       codeInterval = const Duration(milliseconds: 900),
       codes = [
         encoder.encode([
           for (final text in const [
             'Regelmässig: Erste Testebene mit Buchstaben ABCDEFGHIJKLMNOP.',
             'Zweite Ebene: Zahlenfolge 0123456789 und Farben Rot Grün Blau.',
             'Drittes Testpaket: Ein eigenständiger Inhalt für die QR-Vorschau.',
           ])
             Uint8List.fromList(utf8.encode(text)),
         ]),
       ] {
    frames = [
      TransferDisplayFrame(
        raster: codes.first.displayRaster,
        mode: TransferDisplayMode.layered,
      ),
    ];
  }

  TransferSendViewModel.sequence(MlqrTransferSequence sequence)
    : codes = sequence.codes,
      isPreview = false,
      transferSequence = sequence,
      codeInterval = const Duration(milliseconds: 1500) {
    frames = [
      for (final code in sequence.codes)
        TransferDisplayFrame(
          raster: code.displayRaster,
          mode: TransferDisplayMode.layered,
        ),
    ];
  }

  final List<MlqrCode> codes;
  late final List<TransferDisplayFrame> frames;
  final bool isPreview;
  final MlqrTransferSequence? transferSequence;
  final Duration codeInterval;
  MlqrCode get code => codes.first;
  MlqrCode codeAt(int index) => codes[index];
  int get codeCount => frames.length;
  int get chunkCount => transferSequence?.chunkCount ?? codes.length;
  int get maxLayersPerCode =>
      transferSequence?.maxLayersPerCode ?? code.layers.length;
  int get maxQrVersion =>
      transferSequence?.maxQrVersion ?? (code.qrVersion ?? 0);
  int? get jsonBytes => transferSequence?.package.jsonLength;
  int? get cborBytes => transferSequence?.package.cborLength;
  int? get compressedBytes => transferSequence?.package.compressedLength;
  int? get chunkWireBytes => transferSequence?.package.chunkWireBytes;
  int? get cipherTextBytes => transferSequence?.package.cipherTextBytes;
  int? get chunkMetadataBytes => transferSequence?.package.chunkMetadataBytes;
  int? get chunkSize => transferSequence?.package.chunkSize;
  String? get profileId => transferSequence?.profile.id;
  int? get preparationMilliseconds =>
      transferSequence?.preparationDuration.inMilliseconds;
  List<int> get payloadLayersPerCode =>
      transferSequence?.payloadLayersPerCode ?? [code.payloadCount];
  int get maxPayloadLayersPerCode =>
      transferSequence?.maxPayloadLayersPerCode ?? code.payloadCount;
  int get temporalFrameCount => 0;
  TransferDisplayFrame frameAt(int index) => frames[index];
  bool isTemporalAt(int index) => false;
}
