import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/day_entry.dart';
import 'tracking_payload_cipher.dart';
import 'tracking_storage.dart';

/// Owns one encrypted connection and its independently encrypted records.
/// Authentication and persistent key storage remain the caller's responsibility.
class SqlCipherTrackingStorage implements TrackingStorage {
  SqlCipherTrackingStorage({
    required String path,
    required this.keyProvider,
    required this.dataKeyProvider,
  }) : _resolvePath = (() async => path);

  /// Resolve lazily so opening failures reach the normal load/retry flow.
  SqlCipherTrackingStorage.local({
    required String fileName,
    required this.keyProvider,
    required this.dataKeyProvider,
  }) : _resolvePath = (() async => p.join(await getDatabasesPath(), fileName));

  static const _keyCheck = 'regelmaessig-tracking-data-key-v1';
  final Future<String> Function() _resolvePath;
  final Future<String> Function() keyProvider;
  final Future<SecretKey> Function() dataKeyProvider;
  Future<Database>? _opening;
  TrackingPayloadCipher? _cipher;
  bool _closed = false;

  Future<Database> _database() async {
    if (_closed) throw StateError('Tracking storage is closed');
    final pending = _opening ??= _open();
    try {
      return await pending;
    } catch (_) {
      if (identical(_opening, pending)) _opening = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    final key = await keyProvider();
    if (key.isEmpty) throw ArgumentError('An encryption key is required');
    final cipher = await TrackingPayloadCipher.create(await dataKeyProvider());
    final db = await openDatabase(
      await _resolvePath(),
      password: key,
      version: 2,
      singleInstance: false,
      onConfigure: (db) async {
        final version = await db.rawQuery('PRAGMA cipher_version');
        if (version.isEmpty || version.first.values.single.toString().isEmpty) {
          throw StateError('SQLCipher is unavailable');
        }
        await db.execute('PRAGMA temp_store = MEMORY');
        await db.execute('PRAGMA secure_delete = ON');
      },
      onCreate: (db, version) => _createSchema(db, cipher),
      // sqflite runs schema callbacks and user_version changes in a transaction.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion != 1 || newVersion != 2) {
          throw StateError('Unsupported tracking schema version');
        }
        final snapshot = await _readLegacy(db);
        final rows = await _encryptSnapshot(snapshot, cipher);
        await db.execute('DROP TABLE day_entries');
        await db.execute('DROP TABLE custom_categories');
        await _createSchema(db, cipher);
        await _replaceRows(db, rows);
      },
      onDowngrade: (db, oldVersion, newVersion) async {
        throw StateError('Unsupported tracking schema version');
      },
    );
    try {
      await _verifyKey(db, cipher);
      _cipher = cipher;
      return db;
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  Future<void> _createSchema(
    DatabaseExecutor db,
    TrackingPayloadCipher cipher,
  ) async {
    for (final table in [
      'day_entries',
      'custom_categories',
      'tracking_metadata',
    ]) {
      await db.execute('''
        CREATE TABLE $table (
          id INTEGER PRIMARY KEY NOT NULL,
          payload BLOB NOT NULL
        )
      ''');
    }
    await db.insert('tracking_metadata', {
      'id': 1,
      'payload': await cipher.encrypt(
        utf8.encode(_keyCheck),
        table: 'tracking_metadata',
        id: 1,
      ),
    });
  }

  Future<void> _verifyKey(
    DatabaseExecutor db,
    TrackingPayloadCipher cipher,
  ) async {
    final rows = await db.query('tracking_metadata');
    if (rows.length != 1 || rows.single['id'] != 1) {
      throw const FormatException('Invalid tracking key verification record');
    }
    final bytes = await cipher.decrypt(
      _payload(rows.single),
      table: 'tracking_metadata',
      id: 1,
    );
    if (utf8.decode(bytes, allowMalformed: true) != _keyCheck) {
      throw const FormatException('Invalid tracking key verification record');
    }
  }

  List<int> _payload(Map<String, Object?> row) {
    final payload = row['payload'];
    if (payload is! List<int>) {
      throw const FormatException('Invalid tracking payload');
    }
    return payload;
  }

  Map<String, dynamic> _decodeJson(String value) {
    try {
      return jsonDecode(value) as Map<String, dynamic>;
    } catch (_) {
      // Do not attach decrypted health data to exception messages.
      throw const FormatException('Invalid tracking JSON');
    }
  }

  DayEntry _decodeDay(Map<String, dynamic> json) {
    try {
      final day = DayEntry.fromJson(json);
      if (json['date'] != dayKey(day.date)) {
        throw const FormatException();
      }
      return day;
    } catch (_) {
      throw const FormatException('Invalid tracking day');
    }
  }

  Future<TrackingSnapshot> _readLegacy(DatabaseExecutor db) async {
    final rows = await db.query('day_entries', orderBy: 'date');
    final categories = await db.query('custom_categories', orderBy: 'rowid');
    final days = <DateTime, DayEntry>{};
    for (final row in rows) {
      final day = _decodeDay(_decodeJson(row['data_json'] as String));
      if (row['date'] != dayKey(day.date) || days.containsKey(day.date)) {
        throw const FormatException('Inconsistent tracking date');
      }
      days[day.date] = day;
    }
    return TrackingSnapshot(
      days: days,
      categories: {
        for (final row in categories)
          row['id'] as String: row['name'] as String,
      },
    );
  }

  Future<TrackingSnapshot> _readSnapshot(
    DatabaseExecutor db,
    TrackingPayloadCipher cipher,
  ) async {
    await _verifyKey(db, cipher);
    final days = <DateTime, DayEntry>{};
    final categories = <String, String>{};
    for (final table in ['day_entries', 'custom_categories']) {
      for (final row in await db.query(table, orderBy: 'id')) {
        final bytes = await cipher.decrypt(
          _payload(row),
          table: table,
          id: row['id'] as int,
        );
        // Strict UTF-8, but never include the decrypted bytes in errors.
        late Map<String, dynamic> json;
        try {
          json = _decodeJson(utf8.decode(bytes));
        } catch (_) {
          throw const FormatException('Invalid tracking JSON');
        }
        if (table == 'day_entries') {
          final day = _decodeDay(json);
          if (days.containsKey(day.date)) {
            throw const FormatException('Duplicate tracking date');
          }
          days[day.date] = day;
        } else {
          final id = json['id'];
          final name = json['name'];
          if (id is! String || name is! String || categories.containsKey(id)) {
            throw const FormatException('Invalid tracking category');
          }
          categories[id] = name;
        }
      }
    }
    return TrackingSnapshot(days: days, categories: categories);
  }

  Future<Map<String, List<Map<String, Object?>>>> _encryptSnapshot(
    TrackingSnapshot snapshot,
    TrackingPayloadCipher cipher,
  ) async {
    final values = <String, List<Map<String, dynamic>>>{
      'day_entries': [],
      'custom_categories': [
        for (final entry in snapshot.categories.entries)
          {'id': entry.key, 'name': entry.value},
      ],
    };
    // Keep the previous chronological read order without a plaintext date index.
    final dates = snapshot.days.keys.toList()..sort();
    for (final date in dates) {
      final day = snapshot.days[date]!;
      if (date != day.date) throw ArgumentError('Inconsistent tracking date');
      if (day.hasData) values['day_entries']!.add(day.toJson());
    }
    final result = <String, List<Map<String, Object?>>>{};
    for (final table in values.entries) {
      final rows = <Map<String, Object?>>[];
      for (var index = 0; index < table.value.length; index++) {
        final id = index + 1;
        rows.add({
          'id': id,
          'payload': await cipher.encrypt(
            utf8.encode(jsonEncode(table.value[index])),
            table: table.key,
            id: id,
          ),
        });
      }
      result[table.key] = rows;
    }
    return result;
  }

  Future<void> _replaceRows(
    DatabaseExecutor db,
    Map<String, List<Map<String, Object?>>> tables,
  ) async {
    final batch = db.batch();
    for (final table in tables.entries) {
      batch.delete(table.key);
      for (final row in table.value) {
        batch.insert(table.key, row);
      }
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<TrackingSnapshot> read() async {
    final db = await _database();
    return db.transaction((txn) => _readSnapshot(txn, _cipher!));
  }

  @override
  Future<void> write(TrackingSnapshot snapshot) async {
    final db = await _database();
    final cipher = _cipher!;
    final rows = await _encryptSnapshot(snapshot, cipher);
    await db.transaction((txn) async {
      // Also protect against corruption introduced after a repository's load.
      await _readSnapshot(txn, cipher);
      await _replaceRows(txn, rows);
    });
  }

  /// Create a new adapter to reopen with newly supplied keys.
  Future<void> close() async {
    _closed = true;
    final pending = _opening;
    if (pending == null) return;
    late Database db;
    try {
      db = await pending;
    } catch (_) {
      _cipher = null;
      return;
    }
    try {
      await db.close();
    } finally {
      _cipher = null;
    }
  }
}
