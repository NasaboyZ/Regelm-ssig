import 'dart:typed_data';

class MlqrDecoded {
  MlqrDecoded({
    required this.opticalLayerCount,
    required this.qrVersion,
    required List<Uint8List> packets,
  }) : packets = List.unmodifiable(
         packets.map((p) => Uint8List.fromList(p).asUnmodifiableView()),
       );

  final int opticalLayerCount;
  final int qrVersion;
  final List<Uint8List> packets;
  int get dummyCount => opticalLayerCount - packets.length;
}

class MlqrDecodeException implements Exception {
  const MlqrDecodeException(this.message, {this.layersRead = 0});
  final String message;
  final int layersRead;
  @override
  String toString() => message;
}
