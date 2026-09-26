import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/day_entry.dart';
import 'tracking_storage.dart';

/// Owns one encrypted connection. Authentication and key storage belong to the
/// caller; this adapter never persists a key or falls back to plaintext.
class SqlCipherTrackingStorage implements TrackingStorage {
  SqlCipherTrackingStorage({required this.path, required this.keyProvider});

  final String path;
  final Future<String> Function() keyProvider;
  Future<Database>? _opening;
  bool _closed = false;

  Future<Database> _database() async {
    if (_closed) throw StateError('Tracking storage is closed');
    final pending = _opening ??= _open();
    try {
      return await pending;
    } catch (_) {
      // Failed authentication/opening can be retried without replacing the file.
      if (identical(_opening, pending)) _opening = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    final key = await keyProvider();
    if (key.isEmpty) throw ArgumentError('An encryption key is required');
    return openDatabase(
      path,
      password: key,
      version: 1,
      // A cached connection must never bypass authentication for a new caller.
      singleInstance: false,
      onConfigure: (db) async {
        final cipher = await db.rawQuery('PRAGMA cipher_version');
        if (cipher.isEmpty || cipher.first.values.single.toString().isEmpty) {
          throw StateError('SQLCipher is unavailable');
        }
        await db.execute('PRAGMA temp_store = MEMORY');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE day_entries (
            date TEXT PRIMARY KEY NOT NULL,
            data_json TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE custom_categories (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL
          )
        ''');
      },
      // Future versions need an explicit migration, never a destructive reset.
      onUpgrade: (db, oldVersion, newVersion) async {
        throw StateError('Unsupported tracking schema version');
      },
      onDowngrade: (db, oldVersion, newVersion) async {
        throw StateError('Unsupported tracking schema version');
      },
    );
  }

  @override
  Future<TrackingSnapshot> read() async {
    final db = await _database();
    return db.transaction((txn) async {
      final rows = await txn.query('day_entries', orderBy: 'date');
      final categories = await txn.query('custom_categories', orderBy: 'rowid');
      final days = <DateTime, DayEntry>{};
      for (final row in rows) {
        final day = DayEntry.fromJson(
          jsonDecode(row['data_json'] as String) as Map<String, dynamic>,
        );
        if (row['date'] != dayKey(day.date)) {
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
    });
  }

  @override
  Future<void> write(TrackingSnapshot snapshot) async {
    final days = <String, String>{};
    for (final entry in snapshot.days.entries) {
      if (entry.key != entry.value.date) {
        throw ArgumentError('Inconsistent tracking date');
      }
      if (entry.value.hasData) {
        days[dayKey(entry.key)] = jsonEncode(entry.value.toJson());
      }
    }
    final db = await _database();
    await db.transaction((txn) async {
      final existing = await txn.query('day_entries', columns: ['date']);
      final batch = txn.batch();
      for (final row in existing) {
        if (!days.containsKey(row['date'])) {
          batch.delete(
            'day_entries',
            where: 'date = ?',
            whereArgs: [row['date']],
          );
        }
      }
      for (final day in days.entries) {
        batch.insert('day_entries', {
          'date': day.key,
          'data_json': day.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // Definitions can exist without a recorded day; preserve their UI order.
      batch.delete('custom_categories');
      for (final category in snapshot.categories.entries) {
        batch.insert('custom_categories', {
          'id': category.key,
          'name': category.value,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  /// Release the connection before copying the file or ending its owner scope.
  /// Create a new adapter to reopen it with a newly supplied key.
  Future<void> close() async {
    _closed = true;
    final pending = _opening;
    if (pending == null) return;
    Database db;
    try {
      db = await pending;
    } catch (_) {
      return;
    }
    await db.close();
  }
}
