import 'package:flutter_test/flutter_test.dart';
import 'package:regelmaessig/models/day_entry.dart';
import 'package:regelmaessig/services/mlqr_decoder_service.dart';
import 'package:regelmaessig/services/mlqr_encoder_service.dart';
import 'package:regelmaessig/services/mlqr_transfer_service.dart';
import 'package:regelmaessig/services/transfer_codec.dart';

void main() {
  final transfer = MlqrTransferService(
    encoder: const MlqrEncoderService(),
    decoder: const MlqrDecoderService(),
    codec: TransferCodec(),
  );

  final snapshot = TrackingSnapshot(
    days: {
      for (var i = 0; i < 40; i++)
        DateTime(2026, 1, 1).add(Duration(days: i)): DayEntry(
          date: DateTime(2026, 1, 1).add(Duration(days: i)),
          note: 'Day $i',
        ),
    },
  );

  test(
    'groups transfer chunks into a sequence of MLQR codes and restores data',
    () async {
      final sequence = await transfer.encode(
        snapshot,
        passphrase: 'secret',
        transferId: 'sequence-1',
        chunkSize: 5,
      );

      expect(sequence.codes.length, greaterThan(1));
      final decoded = await transfer.decodeCodes(
        sequence.codes.reversed.toList(),
        passphrase: 'secret',
      );
      expect(decoded.toJson(), snapshot.toJson());
    },
  );

  test(
    'every generated MLQR code stays within the fifteen-layer limit',
    () async {
      final sequence = await transfer.encode(
        snapshot,
        passphrase: 'secret',
        transferId: 'sequence-2',
        chunkSize: 5,
      );
      expect(sequence.codes.every((code) => code.payloadCount <= 15), isTrue);
    },
  );

  test('development sequence decodes without a passphrase', () async {
    final sequence = await transfer.encodeDevelopment(
      snapshot,
      transferId: 'development-sequence',
      chunkSize: 5,
    );
    final decoded = await transfer.decodeCodesDevelopment(sequence.codes);
    expect(decoded.toJson(), snapshot.toJson());
  });

  test(
    'default development sizing keeps QR versions camera-friendly',
    () async {
      final sequence = await transfer.encodeDevelopment(
        snapshot,
        transferId: 'sized-sequence',
      );
      expect(sequence.maxQrVersion, lessThanOrEqualTo(20));
      expect(sequence.codes.every((code) => code.layers.length <= 15), isTrue);
    },
  );
}
