import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:cbor/simple.dart';
import 'package:ffi/ffi.dart';

import '../models/day_entry.dart';
import 'go_native_library.dart';
import 'transfer_codec.dart';

typedef _EncodeNative =
    Pointer<Uint8> Function(
      Pointer<Uint8>,
      Int32,
      Pointer<Uint8>,
      Int32,
      Pointer<Uint8>,
      Int32,
      Int32,
      Int32,
      Pointer<Int32>,
    );
typedef _EncodeDart =
    Pointer<Uint8> Function(
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      int,
      int,
      Pointer<Int32>,
    );
typedef _DecodeNative =
    Pointer<Uint8> Function(
      Pointer<Uint8>,
      Int32,
      Pointer<Uint8>,
      Int32,
      Pointer<Int32>,
    );
typedef _DecodeDart =
    Pointer<Uint8> Function(
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      Pointer<Int32>,
    );

/// Native transfer codec. It keeps Snapshot and database ownership in Dart,
/// while Go owns compression, encryption and chunk creation.
final class GoTransferCodec extends TrackingSnapshotTransferCodec {
  GoTransferCodec._(GoNativeLibrary native, {required super.chunkSize})
    : _encode = native.library.lookupFunction<_EncodeNative, _EncodeDart>(
        'regelmaessig_transfer_encode',
      ),
      _decode = native.library.lookupFunction<_DecodeNative, _DecodeDart>(
        'regelmaessig_transfer_decode',
      ),
      _free = native.free;

  final _EncodeDart _encode;
  final _DecodeDart _decode;
  final GoFreeFunction _free;

  static GoTransferCodec? tryLoad({int chunkSize = 1800}) {
    final native = GoNativeLibrary.tryLoad();
    if (native == null) return null;
    try {
      return GoTransferCodec._(native, chunkSize: chunkSize);
    } on Object {
      return null;
    }
  }

  @override
  Future<TransferPackage> encodeEncryptedSnapshot(
    TrackingSnapshot snapshot, {
    required String passphrase,
    required String transferId,
    int? chunkSize,
  }) => _encodeSnapshot(
    snapshot,
    passphrase: passphrase,
    transferId: transferId,
    chunkSize: chunkSize ?? this.chunkSize,
    encrypted: true,
  );

  @override
  Future<TransferPackage> encodeUnencryptedSnapshotForDevelopment(
    TrackingSnapshot snapshot, {
    required String transferId,
    int? chunkSize,
  }) => _encodeSnapshot(
    snapshot,
    passphrase: '',
    transferId: transferId,
    chunkSize: chunkSize ?? this.chunkSize,
    encrypted: false,
  );

  @override
  Future<TrackingSnapshot> decodeSnapshot(
    Iterable<TransferChunk> input, {
    String? passphrase,
  }) async {
    final chunks = input.toList();
    if (chunks.isEmpty) {
      throw const TransferPayloadException('Transfer ist leer.');
    }
    final packed = BytesBuilder();
    _writeUint32(packed, chunks.length);
    for (final chunk in chunks) {
      final wire = chunk.toBytes();
      _writeUint32(packed, wire.length);
      packed.add(wire);
    }
    final packedBytes = packed.takeBytes();
    final passBytes = Uint8List.fromList(utf8.encode(passphrase ?? ''));
    final packedPointer = calloc<Uint8>(packedBytes.length);
    final passPointer = calloc<Uint8>(passBytes.isEmpty ? 1 : passBytes.length);
    final resultLength = calloc<Int32>();
    try {
      packedPointer.asTypedList(packedBytes.length).setAll(0, packedBytes);
      if (passBytes.isNotEmpty) {
        passPointer.asTypedList(passBytes.length).setAll(0, passBytes);
      }
      final result = _decode(
        packedPointer,
        packedBytes.length,
        passPointer,
        passBytes.length,
        resultLength,
      );
      if (result == nullptr || resultLength.value <= 0) {
        throw const TransferPayloadException(
          'Transfer konnte nicht durch Go entschlüsselt werden.',
        );
      }
      final cborBytes = result.asTypedList(resultLength.value).toList();
      _free(result.cast());
      final object = cbor.decode(cborBytes);
      if (object is! Map) {
        throw const TransferPayloadException('CBOR-Payload ist kein Snapshot.');
      }
      return TrackingSnapshot.fromJson(_mapWithStringKeys(object));
    } finally {
      calloc.free(packedPointer);
      calloc.free(passPointer);
      calloc.free(resultLength);
    }
  }

  Future<TransferPackage> _encodeSnapshot(
    TrackingSnapshot snapshot, {
    required String passphrase,
    required String transferId,
    required int chunkSize,
    required bool encrypted,
  }) async {
    if (transferId.isEmpty || transferId.length > 255 || chunkSize < 1) {
      throw ArgumentError('Transfer-ID und Chunk-Grösse sind erforderlich.');
    }
    if (encrypted && passphrase.isEmpty) {
      throw ArgumentError('Eine Passphrase ist erforderlich.');
    }
    final jsonBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(snapshot.toJson())),
    );
    final cborBytes = Uint8List.fromList(cbor.encode(snapshot.toJson()));
    final compressedLength = GZipCodec().encode(cborBytes).length;
    final payloadPointer = calloc<Uint8>(cborBytes.length);
    final idBytes = Uint8List.fromList(utf8.encode(transferId));
    final idPointer = calloc<Uint8>(idBytes.length);
    final passBytes = Uint8List.fromList(utf8.encode(passphrase));
    final passPointer = calloc<Uint8>(passBytes.isEmpty ? 1 : passBytes.length);
    final resultLength = calloc<Int32>();
    try {
      payloadPointer.asTypedList(cborBytes.length).setAll(0, cborBytes);
      idPointer.asTypedList(idBytes.length).setAll(0, idBytes);
      if (passBytes.isNotEmpty) {
        passPointer.asTypedList(passBytes.length).setAll(0, passBytes);
      }
      final result = _encode(
        payloadPointer,
        cborBytes.length,
        idPointer,
        idBytes.length,
        passPointer,
        passBytes.length,
        chunkSize,
        encrypted ? 1 : 0,
        resultLength,
      );
      if (result == nullptr || resultLength.value <= 0) {
        throw StateError('Go-Transfer-Encoder konnte keine Ausgabe erzeugen.');
      }
      final bytes = result.asTypedList(resultLength.value).toList();
      _free(result.cast());
      return _parseResult(
        bytes,
        jsonLength: jsonBytes.length,
        cborLength: cborBytes.length,
        compressedLength: compressedLength,
        chunkSize: chunkSize,
      );
    } finally {
      calloc.free(payloadPointer);
      calloc.free(idPointer);
      calloc.free(passPointer);
      calloc.free(resultLength);
    }
  }

  TransferPackage _parseResult(
    List<int> bytes, {
    required int jsonLength,
    required int cborLength,
    required int compressedLength,
    required int chunkSize,
  }) {
    if (bytes.length < 4) {
      throw StateError('Abgeschnittene Go-Transfer-Ausgabe.');
    }
    var offset = 4;
    final count = _readUint32(bytes, 0);
    final chunks = <TransferChunk>[];
    for (var index = 0; index < count; index++) {
      final length = _readUint32(bytes, offset);
      offset += 4;
      if (offset + length > bytes.length) {
        throw StateError('Ungültige Go-Transfer-Ausgabe.');
      }
      chunks.add(
        TransferChunk.fromBytes(bytes.sublist(offset, offset + length)),
      );
      offset += length;
    }
    if (chunks.isEmpty || offset != bytes.length) {
      throw StateError('Ungültige Go-Transfer-Ausgabe.');
    }
    return TransferPackage(
      chunks: chunks,
      jsonLength: jsonLength,
      cborLength: cborLength,
      compressedLength: compressedLength,
      chunkSize: chunkSize,
    );
  }
}

void _writeUint32(BytesBuilder builder, int value) {
  builder.add([
    (value >> 24) & 255,
    (value >> 16) & 255,
    (value >> 8) & 255,
    value & 255,
  ]);
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

int _readUint32(List<int> bytes, int offset) {
  if (offset < 0 || offset + 4 > bytes.length) {
    throw StateError('Abgeschnittene Go-Transfer-Ausgabe.');
  }
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}
