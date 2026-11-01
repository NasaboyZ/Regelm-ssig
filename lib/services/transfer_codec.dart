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
      throw const TransferPayloadException('Transfer-Metadaten sind zu gross.');
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
      if (offset >= input.length) {
        throw const TransferPayloadException(
          'Transfer-Chunk ist abgeschnitten.',
        );
      }
      return input[offset++];
    }

    List<int> take(int length) {
      if (length < 0 || offset + length > input.length) {
        throw const TransferPayloadException(
          'Transfer-Chunk ist abgeschnitten.',
        );
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
      throw const TransferPayloadException('Unbekanntes Transfer-Format.');
    }
    offset = 4;
    final version = takeByte();
    final encryptedFlag = takeByte();
    if (encryptedFlag > 1) {
      throw const TransferPayloadException(
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
      throw const TransferPayloadException('Ungültige Transfer-Metadaten.');
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
    required this.cborLength,
    required this.compressedLength,
    required this.chunkSize,
  });

  final List<TransferChunk> chunks;
  final int jsonLength;
  final int cborLength;
  final int compressedLength;
  final int chunkSize;
  int get chunkWireBytes =>
      chunks.fold(0, (total, chunk) => total + chunk.toBytes().length);
}

/// Holds validated chunks for one transfer session until the complete payload
/// is available. The accumulator is intentionally memory-only; callers decide
/// when the session is discarded.
class TransferChunkAccumulator {
  final _chunks = <int, TransferChunk>{};
  String? _transferId;
  int? _protocolVersion;
  int? _total;
  bool? _encrypted;

  String? get transferId => _transferId;
  int? get expectedCount => _total;
  int get receivedCount => _chunks.length;
  bool get isComplete => _total != null && _chunks.length == _total;
  List<TransferChunk> get orderedChunks => [
    for (final index in _chunks.keys.toList()..sort()) _chunks[index]!,
  ];
  List<int> get missingIndexes => _total == null
      ? const []
      : [
          for (var index = 0; index < _total!; index++)
            if (!_chunks.containsKey(index)) index,
        ];

  /// Adds one complete MLQR payload chunk. Identical duplicates are ignored.
  bool accept(TransferChunk chunk) {
    _validateSessionMetadata(chunk);
    final existing = _chunks[chunk.index];
    if (existing != null) {
      if (!_sameChunk(existing, chunk)) {
        throw const TransferPayloadException(
          'Ein Chunk-Index wurde mit unterschiedlichen Daten empfangen.',
        );
      }
      return false;
    }
    _chunks[chunk.index] = chunk;
    return true;
  }

  /// Validates the entire decoded MLQR code before changing the accumulator.
  /// This prevents a later conflict from leaving a partially accepted code.
  int acceptAll(Iterable<TransferChunk> chunks) {
    final incoming = chunks.toList();
    if (incoming.isEmpty) return 0;
    final transferId = _transferId ?? incoming.first.transferId;
    final protocolVersion = _protocolVersion ?? incoming.first.protocolVersion;
    final total = _total ?? incoming.first.total;
    final encrypted = _encrypted ?? incoming.first.encrypted;
    final staged = <int, TransferChunk>{};
    for (final chunk in incoming) {
      _validateChunkMetadata(
        chunk,
        transferId: transferId,
        protocolVersion: protocolVersion,
        total: total,
        encrypted: encrypted,
      );
      final existing = _chunks[chunk.index] ?? staged[chunk.index];
      if (existing != null && !_sameChunk(existing, chunk)) {
        throw const TransferPayloadException(
          'Ein Chunk-Index wurde mit unterschiedlichen Daten empfangen.',
        );
      }
      staged[chunk.index] = chunk;
    }
    _transferId ??= transferId;
    _protocolVersion ??= protocolVersion;
    _total ??= total;
    _encrypted ??= encrypted;
    var added = 0;
    for (final entry in staged.entries) {
      if (!_chunks.containsKey(entry.key)) {
        _chunks[entry.key] = entry.value;
        added++;
      }
    }
    return added;
  }

  void clear() {
    _chunks.clear();
    _transferId = null;
    _protocolVersion = null;
    _total = null;
    _encrypted = null;
  }

  void _validateSessionMetadata(TransferChunk chunk) {
    if (_transferId == null) {
      _transferId = chunk.transferId;
      _protocolVersion = chunk.protocolVersion;
      _total = chunk.total;
      _encrypted = chunk.encrypted;
      return;
    }
    _validateChunkMetadata(
      chunk,
      transferId: _transferId!,
      protocolVersion: _protocolVersion!,
      total: _total!,
      encrypted: _encrypted!,
    );
  }

  void _validateChunkMetadata(
    TransferChunk chunk, {
    required String transferId,
    required int protocolVersion,
    required int total,
    required bool encrypted,
  }) {
    if (chunk.transferId != transferId ||
        chunk.protocolVersion != protocolVersion ||
        chunk.total != total ||
        chunk.encrypted != encrypted) {
      throw const TransferPayloadException(
        'Transfer-Chunks passen nicht zur laufenden Sitzung.',
      );
    }
  }

  bool _sameChunk(TransferChunk a, TransferChunk b) =>
      a.toBytes().length == b.toBytes().length &&
      _bytesEqual(a.toBytes(), b.toBytes());

  bool _bytesEqual(List<int> a, List<int> b) {
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}

class TrackingSnapshotTransferCodec {
  TrackingSnapshotTransferCodec({this.chunkSize = 1800, Random? random})
    : _random = random ?? Random.secure();

  static const protocolVersion = 1;
  static const _saltLength = 16;
  static const _pbkdf2Iterations = 10000;
  final int chunkSize;
  final Random _random;
  final _cipher = AesGcm.with256bits();

  Future<TransferPackage> encodeEncryptedSnapshot(
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
      cborLength: cborBytes.length,
      compressedLength: compressed.length,
      chunkSize: size,
    );
  }

  Future<TransferPackage> encodeUnencryptedSnapshotForDevelopment(
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
      cborLength: cborBytes.length,
      compressedLength: compressed.length,
      chunkSize: size,
    );
  }

  Future<TrackingSnapshot> decodeSnapshot(
    Iterable<TransferChunk> input, {
    String? passphrase,
  }) async {
    final chunks = input.toList();
    if (chunks.isEmpty) {
      throw const TransferPayloadException('Transfer ist leer.');
    }
    final first = chunks.first;
    if (first.protocolVersion != protocolVersion ||
        chunks.length != first.total) {
      throw const TransferPayloadException(
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
        throw const TransferPayloadException(
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
        throw const TransferPayloadException(
          'Eine Passphrase ist erforderlich.',
        );
      }
      try {
        final key = await _deriveKey(passphrase, first.salt);
        clear = await _cipher.decrypt(
          SecretBox(cipherText, nonce: first.nonce, mac: Mac(first.mac)),
          secretKey: key,
          aad: _aad(first.transferId),
        );
      } catch (_) {
        throw const TransferPayloadException(
          'Transfer konnte nicht entschlüsselt werden.',
        );
      }
    } else {
      clear = cipherText;
    }
    try {
      final cborBytes = GZipCodec().decode(clear);
      final object = cbor.decode(cborBytes);
      if (object is! Map) {
        throw const TransferPayloadException('CBOR-Payload ist kein Snapshot.');
      }
      return TrackingSnapshot.fromJson(_mapWithStringKeys(object));
    } catch (error) {
      if (error is TransferPayloadException) rethrow;
      throw TransferPayloadException('Transfer-Payload ist beschädigt: $error');
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
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
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

class TransferPayloadException implements Exception {
  const TransferPayloadException(this.message);
  final String message;
  @override
  String toString() => message;
}
