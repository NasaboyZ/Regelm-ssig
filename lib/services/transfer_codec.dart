import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cbor/simple.dart';
import 'package:cryptography/cryptography.dart';

import '../models/day_entry.dart';

/// The compressed, authenticated payload is split into these transport chunks.
class TransferChunk {
  const TransferChunk({
    required this.transferId,
    required this.protocolVersion,
    required this.index,
    required this.total,
    required this.salt,
    required this.nonce,
    required this.cipherText,
    required this.mac,
    this.encrypted = true,
  });

  final String transferId;
  final int protocolVersion;
  final int index;
  final int total;
  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List cipherText;
  final Uint8List mac;
  final bool encrypted;

  Uint8List toBytes() {
    final id = Uint8List.fromList(utf8.encode(transferId));
    if (id.length > 255 ||
        salt.length > 255 ||
        nonce.length > 255 ||
        mac.length > 255) {
      throw const TransferCodecException('Transfer-Metadaten sind zu gross.');
    }
    final out = BytesBuilder();
    out.add(const [0x52, 0x47, 0x54, 0x31]); // RGT1
    out.add([protocolVersion, encrypted ? 1 : 0, id.length, ...id]);
    _addUint32(out, index);
    _addUint32(out, total);
    out.add([salt.length, ...salt, nonce.length, ...nonce]);
    _addUint32(out, cipherText.length);
    out.add(cipherText);
    out.add([mac.length, ...mac]);
    return out.takeBytes();
  }

  static TransferChunk fromBytes(List<int> bytes) {
    final input = Uint8List.fromList(bytes);
    var offset = 0;
    int takeByte() {
      if (offset >= input.length)
        throw const TransferCodecException('Transfer-Chunk ist abgeschnitten.');
      return input[offset++];
    }

    List<int> take(int length) {
      if (length < 0 || offset + length > input.length) {
        throw const TransferCodecException('Transfer-Chunk ist abgeschnitten.');
      }
      final result = input.sublist(offset, offset + length);
      offset += length;
      return result;
    }

    int takeUint32() {
      final bytes = take(4);
      return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
    }

    if (!const [0x52, 0x47, 0x54, 0x31].asMap().keys.every(
      (i) => input.length > i && input[i] == const [0x52, 0x47, 0x54, 0x31][i],
    )) {
      throw const TransferCodecException('Unbekanntes Transfer-Format.');
    }
    offset = 4;
    final version = takeByte();
    final encryptedFlag = takeByte();
    if (encryptedFlag > 1) {
      throw const TransferCodecException(
        'Unbekannter Transfer-Sicherheitsmodus.',
      );
    }
    final id = utf8.decode(take(takeByte()), allowMalformed: false);
    final index = takeUint32();
    final total = takeUint32();
    final salt = Uint8List.fromList(take(takeByte()));
    final nonce = Uint8List.fromList(take(takeByte()));
    final cipherText = Uint8List.fromList(take(takeUint32()));
    final mac = Uint8List.fromList(take(takeByte()));
    if (offset != input.length || id.isEmpty || total < 1 || index >= total) {
      throw const TransferCodecException('Ungültige Transfer-Metadaten.');
    }
    return TransferChunk(
      transferId: id,
      protocolVersion: version,
      index: index,
      total: total,
      salt: salt,
      nonce: nonce,
      cipherText: cipherText,
      mac: mac,
      encrypted: encryptedFlag == 1,
    );
  }
}

class TransferPackage {
  const TransferPackage({
    required this.chunks,
    required this.jsonLength,
    required this.compressedLength,
  });

  final List<TransferChunk> chunks;
  final int jsonLength;
  final int compressedLength;
}

class TransferCodec {
  TransferCodec({this.chunkSize = 1800, Random? random})
    : _random = random ?? Random.secure();

  static const protocolVersion = 1;
  static const _saltLength = 16;
  static const _pbkdf2Iterations = 10000;
  final int chunkSize;
  final Random _random;
  final _cipher = AesGcm.with256bits();

  Future<TransferPackage> encode(
    TrackingSnapshot snapshot, {
    required String passphrase,
    required String transferId,
    int? chunkSize,
  }) async {
    _validateInputs(passphrase, transferId, chunkSize ?? this.chunkSize);
    final jsonBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(snapshot.toJson())),
    );
    final cborBytes = Uint8List.fromList(cbor.encode(snapshot.toJson()));
    final compressed = Uint8List.fromList(GZipCodec().encode(cborBytes));
    final salt = _randomBytes(_saltLength);
    final key = await _deriveKey(passphrase, salt);
    final box = await _cipher.encrypt(
      compressed,
      secretKey: key,
      nonce: _cipher.newNonce(),
      aad: _aad(transferId),
    );
    final size = chunkSize ?? this.chunkSize;
    final count = (box.cipherText.length / size).ceil().clamp(1, 0xFFFFFFFF);
    final chunks = [
      for (var index = 0; index < count; index++)
        TransferChunk(
          transferId: transferId,
          protocolVersion: protocolVersion,
          index: index,
          total: count,
          salt: Uint8List.fromList(salt),
          nonce: Uint8List.fromList(box.nonce),
          cipherText: Uint8List.fromList(
            box.cipherText.sublist(
              index * size,
              min((index + 1) * size, box.cipherText.length),
            ),
          ),
          mac: Uint8List.fromList(box.mac.bytes),
        ),
    ];
    return TransferPackage(
      chunks: chunks,
      jsonLength: jsonBytes.length,
      compressedLength: compressed.length,
    );
  }

  Future<TransferPackage> encodeDevelopment(
    TrackingSnapshot snapshot, {
    required String transferId,
    int? chunkSize,
  }) async {
    _validatePlainInputs(transferId, chunkSize ?? this.chunkSize);
    final jsonBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(snapshot.toJson())),
    );
    final cborBytes = Uint8List.fromList(cbor.encode(snapshot.toJson()));
    final compressed = Uint8List.fromList(GZipCodec().encode(cborBytes));
    final size = chunkSize ?? this.chunkSize;
    final count = (compressed.length / size).ceil().clamp(1, 0xFFFFFFFF);
    return TransferPackage(
      chunks: [
        for (var index = 0; index < count; index++)
          TransferChunk(
            transferId: transferId,
            protocolVersion: protocolVersion,
            index: index,
            total: count,
            salt: Uint8List(0),
            nonce: Uint8List(0),
            cipherText: Uint8List.fromList(
              compressed.sublist(
                index * size,
                min((index + 1) * size, compressed.length),
              ),
            ),
            mac: Uint8List(0),
            encrypted: false,
          ),
      ],
      jsonLength: jsonBytes.length,
      compressedLength: compressed.length,
    );
  }

  Future<TrackingSnapshot> decode(
    Iterable<TransferChunk> input, {
    String? passphrase,
  }) async {
    final chunks = input.toList();
    if (chunks.isEmpty)
      throw const TransferCodecException('Transfer ist leer.');
    final first = chunks.first;
    if (first.protocolVersion != protocolVersion ||
        chunks.length != first.total) {
      throw const TransferCodecException(
        'Transfer ist unvollständig oder inkompatibel.',
      );
    }
    final ordered = [...chunks]..sort((a, b) => a.index.compareTo(b.index));
    for (var i = 0; i < ordered.length; i++) {
      final chunk = ordered[i];
      if (chunk.transferId != first.transferId ||
          chunk.protocolVersion != first.protocolVersion ||
          chunk.total != first.total ||
          chunk.encrypted != first.encrypted ||
          chunk.index != i ||
          !_same(chunk.salt, first.salt) ||
          !_same(chunk.nonce, first.nonce) ||
          !_same(chunk.mac, first.mac)) {
        throw const TransferCodecException(
          'Transfer-Chunks passen nicht zusammen.',
        );
      }
    }
    final cipherText = Uint8List.fromList(
      ordered.expand((chunk) => chunk.cipherText).toList(),
    );
    final List<int> clear;
    if (first.encrypted) {
      if (passphrase == null || passphrase.isEmpty) {
        throw const TransferCodecException('Eine Passphrase ist erforderlich.');
      }
      try {
        final key = await _deriveKey(passphrase, first.salt);
        clear = await _cipher.decrypt(
          SecretBox(cipherText, nonce: first.nonce, mac: Mac(first.mac)),
          secretKey: key,
          aad: _aad(first.transferId),
        );
      } catch (_) {
        throw const TransferCodecException(
          'Transfer konnte nicht entschlüsselt werden.',
        );
      }
    } else {
      clear = cipherText;
    }
    try {
      final cborBytes = GZipCodec().decode(clear);
      final object = cbor.decode(cborBytes);
      if (object is! Map)
        throw const TransferCodecException('CBOR-Payload ist kein Snapshot.');
      return TrackingSnapshot.fromJson(_mapWithStringKeys(object));
    } catch (error) {
      if (error is TransferCodecException) rethrow;
      throw TransferCodecException('Transfer-Payload ist beschädigt: $error');
    }
  }

  Future<SecretKey> _deriveKey(String passphrase, List<int> salt) =>
      Pbkdf2.hmacSha256(
        iterations: _pbkdf2Iterations,
        bits: 256,
      ).deriveKeyFromPassword(password: passphrase, nonce: salt);

  List<int> _aad(String transferId) =>
      utf8.encode('regelmaessig.transfer:$protocolVersion:$transferId');

  Uint8List _randomBytes(int length) =>
      Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));

  void _validateInputs(String passphrase, String transferId, int size) {
    if (passphrase.isEmpty ||
        transferId.isEmpty ||
        transferId.length > 255 ||
        size < 1) {
      throw ArgumentError(
        'Passphrase, Transfer-ID und Chunk-Grösse sind erforderlich.',
      );
    }
  }

  void _validatePlainInputs(String transferId, int size) {
    if (transferId.isEmpty || transferId.length > 255 || size < 1) {
      throw ArgumentError('Transfer-ID und Chunk-Grösse sind erforderlich.');
    }
  }

  bool _same(List<int> a, List<int> b) =>
      a.length == b.length && _bytesEqual(a, b);
  bool _bytesEqual(List<int> a, List<int> b) {
    var difference = 0;
    for (var i = 0; i < a.length; i++) difference |= a[i] ^ b[i];
    return difference == 0;
  }
}

Map<String, dynamic> _mapWithStringKeys(Map<Object?, Object?> input) => {
  for (final entry in input.entries)
    if (entry.key is String) entry.key as String: _decodeValue(entry.value),
};

dynamic _decodeValue(dynamic value) {
  if (value is Map) return _mapWithStringKeys(value);
  if (value is List) return value.map(_decodeValue).toList();
  return value;
}

void _addUint32(BytesBuilder builder, int value) {
  builder.add([
    (value >> 24) & 255,
    (value >> 16) & 255,
    (value >> 8) & 255,
    value & 255,
  ]);
}

class TransferCodecException implements Exception {
  const TransferCodecException(this.message);
  final String message;
  @override
  String toString() => message;
}
