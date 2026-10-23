import 'dart:convert';
import 'dart:typed_data';

import '../models/mlqr_code.dart';
import '../services/mlqr_encoder_service.dart';
import '../services/mlqr_transfer_service.dart';

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
       ];

  TransferSendViewModel.sequence(MlqrTransferSequence sequence)
    : codes = sequence.codes,
      isPreview = false,
      transferSequence = sequence,
      codeInterval = const Duration(milliseconds: 1500);

  final List<MlqrCode> codes;
  final bool isPreview;
  final MlqrTransferSequence? transferSequence;
  final Duration codeInterval;
  MlqrCode get code => codes.first;
  MlqrCode codeAt(int index) => codes[index];
  int get codeNumber => 1;
  int get codeCount => codes.length;
  int get chunkCount => transferSequence?.chunkCount ?? codes.length;
  int get maxLayersPerCode =>
      transferSequence?.maxLayersPerCode ?? code.layers.length;
  int get maxQrVersion =>
      transferSequence?.maxQrVersion ?? (code.qrVersion ?? 0);
  int get confirmedCodeCount => 0;
  double get progress => confirmedCodeCount / codeCount;
}
