import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:regelmaessig/models/day_entry.dart';
import 'package:regelmaessig/services/transfer_codec.dart';

void main() {
  final codec = TransferCodec();

  TrackingSnapshot snapshot() => TrackingSnapshot(
    categories: const {'mood': 'Stimmung'},
    days: {
      DateTime(2026, 1, 1): DayEntry(
        date: DateTime(2026, 1, 1),
        selections: const {
          'mood': {'good', 'calm'},
        },
        note: 'Erster Testtag',
        temperature: 36.7,
      ),
    },
  );

  test(
    'snapshot round-trips through CBOR, GZIP, encryption and chunks',
    () async {
      final transfer = await codec.encode(
        snapshot(),
        passphrase: 'correct horse battery staple',
        transferId: 'transfer-1',
        chunkSize: 20,
      );

      expect(transfer.chunks.length, greaterThan(1));
      expect(
        transfer.chunks.every((chunk) => chunk.total == transfer.chunks.length),
        isTrue,
      );
      expect(
        transfer.chunks.map((chunk) => chunk.index),
        orderedEquals(List.generate(transfer.chunks.length, (index) => index)),
      );

      final restored = await codec.decode(
        transfer.chunks.reversed.toList(),
        passphrase: 'correct horse battery staple',
      );
      expect(restored.toJson(), snapshot().toJson());
    },
  );

  test('development mode round-trips without a passphrase', () async {
    final transfer = await codec.encodeDevelopment(
      snapshot(),
      transferId: 'development-transfer',
      chunkSize: 20,
    );
    expect(transfer.chunks.every((chunk) => !chunk.encrypted), isTrue);
    final restored = await codec.decode(transfer.chunks);
    expect(restored.toJson(), snapshot().toJson());
  });

  test('wrong passphrase and missing chunks are rejected', () async {
    final transfer = await codec.encode(
      snapshot(),
      passphrase: 'secret',
      transferId: 'transfer-2',
      chunkSize: 20,
    );

    expect(
      () => codec.decode(transfer.chunks, passphrase: 'wrong'),
      throwsA(isA<TransferCodecException>()),
    );
    expect(
      () => codec.decode(
        transfer.chunks.sublist(0, transfer.chunks.length - 1),
        passphrase: 'secret',
      ),
      throwsA(isA<TransferCodecException>()),
    );
  });

  test(
    'compressed payload is smaller than the JSON representation for repetitive data',
    () async {
      final repetitive = TrackingSnapshot(
        days: {
          for (var i = 0; i < 365; i++)
            DateTime(2026, 1, 1).add(Duration(days: i)): DayEntry(
              date: DateTime(2026, 1, 1).add(Duration(days: i)),
              selections: const {
                'symptoms': {'headache', 'fatigue'},
              },
              note: 'repetitive health note',
            ),
        },
      );
      final transfer = await codec.encode(
        repetitive,
        passphrase: 'secret',
        transferId: 'measure',
        chunkSize: 2000,
      );
      expect(transfer.compressedLength, lessThan(transfer.jsonLength));
    },
  );

  test('chunk metadata cannot be mixed between transfers', () async {
    final first = await codec.encode(
      snapshot(),
      passphrase: 'secret',
      transferId: 'a',
      chunkSize: 20,
    );
    final second = await codec.encode(
      snapshot(),
      passphrase: 'secret',
      transferId: 'b',
      chunkSize: 20,
    );
    final mixed = <TransferChunk>[first.chunks.first, second.chunks.last];
    expect(
      () => codec.decode(mixed, passphrase: 'secret'),
      throwsA(isA<TransferCodecException>()),
    );
  });

  test('chunk accumulator is order-independent and idempotent', () async {
    final transfer = await codec.encodeDevelopment(
      snapshot(),
      transferId: 'accumulator',
      chunkSize: 20,
    );
    final accumulator = TransferChunkAccumulator();

    accumulator.acceptAll(transfer.chunks.reversed.take(2).toList());
    accumulator.acceptAll(transfer.chunks.take(2).toList());
    accumulator.acceptAll(transfer.chunks);

    expect(accumulator.isComplete, isTrue);
    expect(accumulator.receivedCount, transfer.chunks.length);
    expect(accumulator.missingIndexes, isEmpty);
    expect(
      accumulator.orderedChunks.map((chunk) => chunk.index),
      orderedEquals(List.generate(transfer.chunks.length, (index) => index)),
    );
  });

  test('chunk accumulator reports missing chunks without completing', () async {
    final transfer = await codec.encodeDevelopment(
      snapshot(),
      transferId: 'missing',
      chunkSize: 20,
    );
    final accumulator = TransferChunkAccumulator();

    accumulator.acceptAll(transfer.chunks.take(2).toList());

    expect(accumulator.isComplete, isFalse);
    expect(accumulator.missingIndexes, isNotEmpty);
    expect(accumulator.orderedChunks.length, 2);
  });

  test('chunk accumulator rejects conflicting duplicate indices', () async {
    final transfer = await codec.encodeDevelopment(
      snapshot(),
      transferId: 'conflict',
      chunkSize: 20,
    );
    final original = transfer.chunks.first;
    final conflicting = TransferChunk(
      transferId: original.transferId,
      protocolVersion: original.protocolVersion,
      index: original.index,
      total: original.total,
      salt: original.salt,
      nonce: original.nonce,
      cipherText: Uint8List.fromList([...original.cipherText, 0xff]),
      mac: original.mac,
      encrypted: original.encrypted,
    );
    final accumulator = TransferChunkAccumulator();
    accumulator.accept(original);

    expect(
      () => accumulator.accept(conflicting),
      throwsA(isA<TransferCodecException>()),
    );
    expect(accumulator.receivedCount, 1);
  });
}
