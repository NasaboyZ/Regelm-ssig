import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Authenticated record encryption, separate from the SQLCipher file key.
class TrackingPayloadCipher {
  TrackingPayloadCipher._(this._key);

  static const _version = 1;
  static const _nonceLength = 12;
  static const _tagLength = 16;
  final SecretKey _key;
  final _algorithm = AesGcm.with256bits();

  static Future<TrackingPayloadCipher> create(SecretKey key) async {
    if ((await key.extractBytes()).length != 32) {
      throw ArgumentError('A 32-byte tracking data key is required');
    }
    return TrackingPayloadCipher._(key);
  }

  List<int> _context(String table, int id) =>
      utf8.encode(jsonEncode(['regelmaessig.tracking', _version, table, id]));

  Future<Uint8List> encrypt(
    List<int> clearText, {
    required String table,
    required int id,
  }) async {
    final box = await _algorithm.encrypt(
      clearText,
      secretKey: _key,
      nonce: _algorithm.newNonce(),
      aad: _context(table, id),
    );
    return Uint8List.fromList([
      _version,
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  Future<List<int>> decrypt(
    List<int> payload, {
    required String table,
    required int id,
  }) async {
    if (payload.length < 1 + _nonceLength + _tagLength ||
        payload.first != _version) {
      throw const FormatException('Unsupported or truncated tracking payload');
    }
    final tagStart = payload.length - _tagLength;
    final box = SecretBox(
      payload.sublist(1 + _nonceLength, tagStart),
      nonce: payload.sublist(1, 1 + _nonceLength),
      mac: Mac(payload.sublist(tagStart)),
    );
    try {
      return await _algorithm.decrypt(
        box,
        secretKey: _key,
        aad: _context(table, id),
      );
    } on SecretBoxAuthenticationError {
      throw const FormatException('Tracking payload authentication failed');
    }
  }
}
