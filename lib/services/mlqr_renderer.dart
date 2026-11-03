import 'dart:typed_data';

import '../models/mlqr_code.dart';
import 'mlqr_encoder_service.dart';

/// Deep seam for the expensive visual MLQR operation.
abstract interface class MlqrRenderer {
  List<MlqrCode> render(
    List<Uint8List> packets, {
    required int maxLayersPerCode,
    bool padWithDummies = true,
  });

  bool get supportsTemporalFallback;
}

class DartMlqrRenderer implements MlqrRenderer {
  const DartMlqrRenderer({this.encoder = const MlqrEncoderService()});

  final MlqrEncoderService encoder;

  @override
  List<MlqrCode> render(
    List<Uint8List> packets, {
    required int maxLayersPerCode,
    bool padWithDummies = true,
  }) {
    if (packets.isEmpty) return const [];
    return [
      for (var offset = 0; offset < packets.length; offset += maxLayersPerCode)
        encoder.encode(
          packets.sublist(
            offset,
            (offset + maxLayersPerCode).clamp(0, packets.length),
          ),
          padWithDummies: padWithDummies,
        ),
    ];
  }

  @override
  bool get supportsTemporalFallback => true;
}
