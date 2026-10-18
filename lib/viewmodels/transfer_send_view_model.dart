import 'dart:convert';
import 'dart:typed_data';

import '../models/mlqr_code.dart';
import '../services/mlqr_encoder_service.dart';

/// A single-code preview until encrypted transfer sessions and reception exist.
/// It deliberately has no database dependency or simulated acknowledgements.
class TransferSendViewModel {
  TransferSendViewModel.preview({
    MlqrEncoderService encoder = const MlqrEncoderService(),
  }) : code = encoder.encode([
         for (final text in const [
           'Regelmässig: Erste Testebene mit Buchstaben ABCDEFGHIJKLMNOP.',
           'Zweite Ebene: Zahlenfolge 0123456789 und Farben Rot Grün Blau.',
           'Drittes Testpaket: Ein eigenständiger Inhalt für die QR-Vorschau.',
         ])
           Uint8List.fromList(utf8.encode(text)),
       ]);

  final MlqrCode code;
  int get codeNumber => 1;
  int get codeCount => 1;
  int get confirmedCodeCount => 0;
  double get progress => confirmedCodeCount / codeCount;
}
