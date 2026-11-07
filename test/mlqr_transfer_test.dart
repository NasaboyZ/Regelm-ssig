import 'package:flutter_test/flutter_test.dart';
import 'package:regelmaessig/models/day_entry.dart';
import 'package:regelmaessig/services/mlqr_decoder_service.dart';
import 'package:regelmaessig/services/mlqr_encoder_service.dart';
import 'package:regelmaessig/services/mlqr_transfer_service.dart';
import 'package:regelmaessig/services/mlqr_transfer_profile.dart';
import 'package:regelmaessig/services/transfer_codec.dart';

void main() {
  final transfer = MlqrTransferService(
    encoder: const MlqrEncoderService(),
    decoder: const MlqrDecoderService(),
    payloadCodec: TrackingSnapshotTransferCodec(),
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
      final sequence = await transfer.encodeEncryptedSnapshot(
        snapshot,
        passphrase: 'secret',
        transferId: 'sequence-1',
        chunkSize: 5,
      );

      expect(sequence.codes.length, greaterThan(1));
      final decoded = await transfer.decodeSnapshotFromMlqrCodes(
        sequence.codes.reversed.toList(),
        passphrase: 'secret',
      );
      expect(decoded.toJson(), snapshot.toJson());
    },
  );

  test(
    'every generated MLQR code stays within the fifteen-layer limit',
    () async {
      final sequence = await transfer.encodeEncryptedSnapshot(
        snapshot,
        passphrase: 'secret',
        transferId: 'sequence-2',
        chunkSize: 5,
      );
      expect(sequence.codes.every((code) => code.payloadCount <= 15), isTrue);
    },
  );

  test('balances chunks across MLQR codes', () async {
    final balancedTransfer = MlqrTransferService(maxPayloadLayersPerCode: 4);
    final sequence = await balancedTransfer
        .encodeUnencryptedSnapshotForDevelopment(
          snapshot,
          transferId: 'balanced-sequence',
          chunkSize: 5,
        );
    final distribution = sequence.payloadLayersPerCode;
    final minimum = distribution.reduce((a, b) => a < b ? a : b);
    final maximum = distribution.reduce((a, b) => a > b ? a : b);

    expect(distribution.reduce((a, b) => a + b), sequence.chunkCount);
    expect(distribution.every((count) => count <= 4), isTrue);
    expect(maximum - minimum, lessThanOrEqualTo(1));
  });

  test('uses measured profiles and falls back to the standard profile', () {
    const selector = MlqrTransferProfileSelector();
    expect(selector.select(const []).id, MlqrTransferProfile.standard.id);
    expect(
      selector.select([
        MlqrProfileMeasurement(
          profile: MlqrTransferProfile.fast,
          successRate: 0.99,
          p95RecognitionMs: 4200,
        ),
        MlqrProfileMeasurement(
          profile: MlqrTransferProfile.experimental,
          successRate: 0.90,
          p95RecognitionMs: 1800,
        ),
      ]).id,
      MlqrTransferProfile.fast.id,
    );
  });

  test(
    'uses the robust profile when an unmeasured transfer would have two codes',
    () async {
      final sequence = await MlqrTransferService()
          .encodeUnencryptedSnapshotForDevelopment(
            TrackingSnapshot(),
            transferId: 'short-unmeasured-transfer',
          );

      expect(sequence.profile, MlqrTransferProfile.robust);
      expect(sequence.maxPayloadLayersPerCode, lessThanOrEqualTo(3));
      expect(
        sequence.codeCount,
        greaterThanOrEqualTo(sequence.chunkCount ~/ 3),
      );
    },
  );

  test('development sequence decodes without a passphrase', () async {
    final sequence = await transfer.encodeUnencryptedSnapshotForDevelopment(
      snapshot,
      transferId: 'development-sequence',
      chunkSize: 5,
    );
    final decoded = await transfer
        .decodeUnencryptedSnapshotFromMlqrCodesForDevelopment(sequence.codes);
    expect(decoded.toJson(), snapshot.toJson());
  });

  test(
    'default development sizing keeps QR versions camera-friendly',
    () async {
      final sequence = await transfer.encodeUnencryptedSnapshotForDevelopment(
        snapshot,
        transferId: 'sized-sequence',
      );
      expect(sequence.maxQrVersion, lessThanOrEqualTo(10));
      expect(sequence.maxPayloadLayersPerCode, lessThanOrEqualTo(7));
      expect(sequence.codes.every((code) => code.payloadCount <= 7), isTrue);
      expect(sequence.codeCount, greaterThan(0));
    },
  );

  test(
    'one year of repetitive data survives the complete digital sequence',
    () async {
      final year = TrackingSnapshot(
        days: {
          for (var i = 0; i < 365; i++)
            DateTime(2026, 1, 1).add(Duration(days: i)): DayEntry(
              date: DateTime(2026, 1, 1).add(Duration(days: i)),
              selections: const {
                'symptoms': {'fatigue'},
              },
              note: 'Daily observation',
            ),
        },
      );
      final sequence = await transfer.encodeUnencryptedSnapshotForDevelopment(
        year,
        transferId: 'one-year-sequence',
      );

      final restored = await transfer
          .decodeUnencryptedSnapshotFromMlqrCodesForDevelopment(
            sequence.codes.reversed.toList(),
          );

      expect(sequence.chunkCount, greaterThan(1));
      expect(sequence.maxPayloadLayersPerCode, lessThanOrEqualTo(7));
      expect(sequence.codeCount, greaterThan(0));
      expect(sequence.package.jsonLength, greaterThan(0));
      expect(sequence.package.cborLength, greaterThan(0));
      expect(sequence.package.compressedLength, greaterThan(0));
      expect(sequence.package.chunkWireBytes, greaterThan(0));
      expect(
        sequence.package.chunkWireBytes,
        sequence.package.cipherTextBytes + sequence.package.chunkMetadataBytes,
      );
      expect(sequence.preparationDuration, isNotNull);
      expect(restored.toJson(), year.toJson());
    },
  );
}
