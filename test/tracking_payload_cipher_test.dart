import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regelmaessig/services/tracking_payload_cipher.dart';

void main() {
  late TrackingPayloadCipher cipher;
  final content = utf8.encode('{"date":"2026-09-16","note":"schön 🐱"}');

  setUp(() async {
    cipher = await TrackingPayloadCipher.create(SecretKey(List.filled(32, 42)));
  });

  test('roundtrip and fresh nonce even for identical records', () async {
    final first = await cipher.encrypt(content, table: 'day_entries', id: 1);
    final second = await cipher.encrypt(content, table: 'day_entries', id: 1);
    expect(first, isNot(second));
    expect(first.sublist(1, 13), isNot(second.sublist(1, 13)));
    expect(first.length, content.length + 29);
    expect(await cipher.decrypt(first, table: 'day_entries', id: 1), content);
    expect(await cipher.decrypt(second, table: 'day_entries', id: 1), content);
  });

  test(
    'AES-256-GCM output interoperates with a direct library decrypt',
    () async {
      final payload = await cipher.encrypt(
        content,
        table: 'day_entries',
        id: 7,
      );
      final decoded = await AesGcm.with256bits().decrypt(
        SecretBox(
          payload.sublist(13, payload.length - 16),
          nonce: payload.sublist(1, 13),
          mac: Mac(payload.sublist(payload.length - 16)),
        ),
        secretKey: SecretKey(List.filled(32, 42)),
        aad: utf8.encode(
          jsonEncode(['regelmaessig.tracking', 1, 'day_entries', 7]),
        ),
      );
      expect(decoded, content);
    },
  );

  test('wrong key, nonce, ciphertext and tag are rejected', () async {
    final payload = await cipher.encrypt(content, table: 'day_entries', id: 1);
    final other = await TrackingPayloadCipher.create(
      SecretKey(List.filled(32, 43)),
    );
    await expectLater(
      other.decrypt(payload, table: 'day_entries', id: 1),
      throwsFormatException,
    );
    for (final offset in [1, 13, payload.length - 1]) {
      final changed = payload.toList();
      changed[offset] ^= 1;
      await expectLater(
        cipher.decrypt(changed, table: 'day_entries', id: 1),
        throwsFormatException,
      );
    }
  });

  test('payload cannot be moved to another row or table', () async {
    final payload = await cipher.encrypt(content, table: 'day_entries', id: 1);
    await expectLater(
      cipher.decrypt(payload, table: 'day_entries', id: 2),
      throwsFormatException,
    );
    await expectLater(
      cipher.decrypt(payload, table: 'custom_categories', id: 1),
      throwsFormatException,
    );
  });

  test('unknown versions, truncation and invalid key lengths fail', () async {
    final payload = await cipher.encrypt(content, table: 'day_entries', id: 1);
    for (final invalid in [
      <int>[],
      payload.sublist(0, 28),
      [2, ...payload.skip(1)],
    ]) {
      await expectLater(
        cipher.decrypt(invalid, table: 'day_entries', id: 1),
        throwsFormatException,
      );
    }
    for (final length in [0, 16, 31, 33]) {
      await expectLater(
        TrackingPayloadCipher.create(SecretKey(List.filled(length, 42))),
        throwsArgumentError,
      );
    }
  });
}
