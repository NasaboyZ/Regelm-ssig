import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:regelmaessig/main.dart' as app;
import 'package:regelmaessig/models/day_entry.dart';
import 'package:regelmaessig/models/tracking_catalog.dart';
import 'package:regelmaessig/repositories/tracking_repository.dart';
import 'package:regelmaessig/services/appointment_reminders.dart';
import 'package:regelmaessig/services/debug_tracking_keys.dart';
import 'package:regelmaessig/services/sqlcipher_tracking_storage.dart';
import 'package:regelmaessig/services/tracking_storage.dart';
import 'package:regelmaessig/viewmodels/record_view_model.dart';
import 'package:regelmaessig/views/record/record_view.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class _Reminders implements AppointmentReminders {
  @override
  Future<String?> synchronize(TrackingSnapshot snapshot) async => null;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const testKey = 'integration-test-only-key';
  final day = DateTime(2026, 9, 18);
  late Directory directory;
  late String path;
  late SqlCipherTrackingStorage storage;
  final connections = <SqlCipherTrackingStorage>[];

  SqlCipherTrackingStorage connect({String key = testKey, SecretKey? dataKey}) {
    final connection = SqlCipherTrackingStorage(
      path: path,
      keyProvider: () async => key,
      dataKeyProvider: () async => dataKey ?? SecretKey(List.filled(32, 42)),
    );
    connections.add(connection);
    return connection;
  }

  TrackingSnapshot fixture() => TrackingSnapshot(
    days: {
      day: DayEntry(
        date: day,
        selections: {
          for (final category in trackingCategories)
            for (final group in category.groups)
              group.id: group.options
                  .take(group.single ? 1 : 2)
                  .map((o) => o.code)
                  .toSet(),
        },
        customValues: {
          for (final category in trackingCategories)
            category.id: ['Eigener Wert'],
          'sleep': ['8 Stunden', 'Gut geschlafen'],
        },
        note: 'SQLCipher-Testnotiz mit Umlauten: schön',
        temperature: 36.7,
        weight: 62.5,
        appointments: [
          DayAppointment(
            id: 'a',
            title: 'Kontrolle',
            location: 'Zürich',
            startsAt: DateTime(2026, 9, 18, 9),
            alarmMinutes: 15,
          ),
          DayAppointment(
            id: 'b',
            title: 'Zweiter Termin',
            startsAt: DateTime(2026, 9, 18, 15),
          ),
        ],
      ),
      DateTime(2026, 9, 19): DayEntry(
        date: DateTime(2026, 9, 19),
        note: 'Zweiter Tag',
      ),
    },
    categories: {'sleep': 'Schlaf', 'empty': 'Leere Kategorie'},
  );

  Future<Database> inspect() =>
      openDatabase(path, password: testKey, singleInstance: false);

  Future<void> createLegacy({
    bool corrupt = false,
    bool blockMigration = false,
  }) async {
    final db = await openDatabase(
      path,
      password: testKey,
      singleInstance: false,
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE day_entries (date TEXT PRIMARY KEY NOT NULL, data_json TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE custom_categories (id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL)',
        );
        for (final entry in fixture().days.values) {
          await db.insert('day_entries', {
            'date': dayKey(entry.date),
            'data_json': corrupt ? '{bad' : jsonEncode(entry.toJson()),
          });
        }
        for (final entry in fixture().categories.entries) {
          await db.insert('custom_categories', {
            'id': entry.key,
            'name': entry.value,
          });
        }
        if (blockMigration) {
          // A collision forces failure after the migration has dropped v1 tables.
          await db.execute(
            'CREATE TABLE tracking_metadata (legacy_marker TEXT)',
          );
        }
      },
    );
    await db.close();
  }

  setUp(() async {
    directory = await Directory(
      await getDatabasesPath(),
    ).createTemp('tracking_test_');
    path = p.join(directory.path, 'tracking.db');
    storage = connect();
  });
  tearDown(() async {
    for (final connection in connections) {
      await connection.close();
    }
    connections.clear();
    await directory.delete(recursive: true);
  });

  testWidgets('v1 migrates all fields and category order to encrypted v2', (
    _,
  ) async {
    await createLegacy();
    expect((await storage.read()).toJson(), fixture().toJson());
    await storage.close();
    expect((await connect().read()).categories.keys.toList(), [
      'sleep',
      'empty',
    ]);
    final db = await inspect();
    try {
      expect(await db.getVersion(), 2);
      for (final table in [
        'day_entries',
        'custom_categories',
        'tracking_metadata',
      ]) {
        final columns = await db.rawQuery('PRAGMA table_info($table)');
        expect(columns.map((c) => c['name']).toList(), ['id', 'payload']);
        final rows = await db.query(table);
        expect(rows, isNotEmpty);
        for (final row in rows) {
          expect(row['id'], isA<int>());
          expect(row['payload'], isA<Uint8List>());
          final value = utf8.decode(
            row['payload'] as List<int>,
            allowMalformed: true,
          );
          for (final marker in [
            '2026-09-18',
            'SQLCipher-Testnotiz',
            'Schlaf',
            'sleep',
          ]) {
            expect(value.contains(marker), isFalse);
          }
        }
      }
      expect(await db.rawQuery('PRAGMA integrity_check'), [
        {'integrity_check': 'ok'},
      ]);
    } finally {
      await db.close();
    }
  });

  testWidgets('damaged v1 and mid-migration SQL failure leave v1 intact', (
    _,
  ) async {
    for (final corrupt in [true, false]) {
      final previousPath = path;
      path = p.join(directory.path, 'legacy_$corrupt.db');
      try {
        await createLegacy(corrupt: corrupt, blockMigration: !corrupt);
        await expectLater(
          connect().read(),
          corrupt ? throwsFormatException : throwsA(isA<DatabaseException>()),
        );
        final db = await inspect();
        try {
          expect(await db.getVersion(), 1);
          final rows = await db.query('day_entries', orderBy: 'date');
          expect(rows.length, 2);
          expect(
            rows.first['data_json'],
            corrupt ? '{bad' : jsonEncode(fixture().days[day]!.toJson()),
          );
          expect((await db.query('custom_categories')).length, 2);
          if (!corrupt) await db.execute('DROP TABLE tracking_metadata');
        } finally {
          await db.close();
        }
        if (!corrupt) {
          expect((await connect().read()).toJson(), fixture().toJson());
        }
      } finally {
        path = previousPath;
      }
    }
  });

  testWidgets('wrong data key is rejected even for an empty database', (
    _,
  ) async {
    await storage.write(TrackingSnapshot());
    await storage.close();
    final wrong = connect(dataKey: SecretKey(List.filled(32, 43)));
    await expectLater(wrong.read(), throwsFormatException);
    await expectLater(wrong.write(fixture()), throwsFormatException);
    expect((await connect().read()).days, isEmpty);
    final db = await inspect();
    try {
      expect(await db.getVersion(), 2);
      expect(await db.query('tracking_metadata'), hasLength(1));
    } finally {
      await db.close();
    }
  });

  testWidgets(
    'invalid data key fails before creating or migrating a database',
    (_) async {
      await expectLater(
        connect(dataKey: SecretKey([1])).read(),
        throwsArgumentError,
      );
      expect(await File(path).exists(), isFalse);
      await createLegacy();
      await expectLater(
        connect(dataKey: SecretKey([1])).read(),
        throwsArgumentError,
      );
      final db = await inspect();
      try {
        expect(await db.getVersion(), 1);
      } finally {
        await db.close();
      }
    },
  );

  testWidgets('tampering after load blocks writes and preserves stored bytes', (
    _,
  ) async {
    await storage.write(fixture());
    final repository = TrackingRepository(storage);
    addTearDown(repository.dispose);
    await repository.load();
    final db = await inspect();
    late Uint8List changed;
    try {
      final rows = await db.query('day_entries', orderBy: 'id');
      changed = Uint8List.fromList(rows.first['payload'] as List<int>);
      changed[13] ^= 1;
      await db.update('day_entries', {'payload': changed}, where: 'id = 1');
    } finally {
      await db.close();
    }
    await expectLater(
      repository.save(TrackingSnapshot()),
      throwsFormatException,
    );
    expect(repository.snapshot.toJson(), fixture().toJson());
    final check = await inspect();
    try {
      expect(
        (await check.query('day_entries', where: 'id = 1')).single['payload'],
        changed,
      );
      expect(await check.query('custom_categories'), hasLength(2));
    } finally {
      await check.close();
    }
  });

  testWidgets('swapped rows and missing key verification cannot be read', (
    _,
  ) async {
    await storage.write(fixture());
    final db = await inspect();
    try {
      final rows = await db.query('day_entries', orderBy: 'id');
      await db.update('day_entries', {
        'payload': rows.last['payload'],
      }, where: 'id = 1');
      await expectLater(storage.read(), throwsFormatException);
      await db.update('day_entries', {
        'payload': rows.first['payload'],
      }, where: 'id = 1');
      expect((await storage.read()).toJson(), fixture().toJson());
      await db.delete('tracking_metadata');
      await expectLater(
        storage.write(TrackingSnapshot()),
        throwsFormatException,
      );
      expect(await db.query('day_entries'), hasLength(2));
    } finally {
      await db.close();
    }
  });

  testWidgets('unknown schema versions are not reset', (_) async {
    await storage.write(fixture());
    await storage.close();
    final db = await inspect();
    try {
      await db.setVersion(3);
    } finally {
      await db.close();
    }
    await expectLater(connect().read(), throwsStateError);
    final check = await inspect();
    try {
      expect(await check.getVersion(), 3);
      expect(await check.query('day_entries'), hasLength(2));
    } finally {
      await check.close();
    }
  });

  testWidgets(
    'normal app startup saves the record in the shared SQLCipher database',
    (tester) async {
      final originalDirectory = await getDatabasesPath();
      await databaseFactory.setDatabasesPath(directory.path);
      await GetIt.instance.reset();
      try {
        app.main();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Weiter'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Weiter'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('App einrichten'));
        await tester.pumpAndSettle();
        expect(
          GetIt.instance<TrackingStorage>(),
          isA<SqlCipherTrackingStorage>(),
        );
        await tester.tap(find.text('Heute erfassen'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ruhig'));
        await tester.pump();
        await tester.tap(find.text('Eintrag speichern · 1'));
        await tester.pumpAndSettle();
        expect(find.byType(RecordView), findsNothing);
        await tester.pumpWidget(const SizedBox());
        final selectedStorage =
            GetIt.instance<TrackingStorage>() as SqlCipherTrackingStorage;
        await selectedStorage.close();
        final reopened = SqlCipherTrackingStorage(
          path: p.join(directory.path, 'regelmaessig_tracking_debug.db'),
          keyProvider: DebugTrackingKeys.databaseKey,
          dataKeyProvider: DebugTrackingKeys.dataKey,
        );
        connections.add(reopened);
        final snapshot = await reopened.read();
        expect(snapshot.days[localDay(DateTime.now())]!.selections['mood'], {
          'calm',
        });
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        if (GetIt.instance.isRegistered<TrackingStorage>()) {
          await (GetIt.instance<TrackingStorage>() as SqlCipherTrackingStorage)
              .close();
        }
        await GetIt.instance.reset();
        await databaseFactory.setDatabasesPath(originalDirectory);
      }
    },
  );

  testWidgets('all fields survive a closed connection and a new repository', (
    _,
  ) async {
    final original = TrackingRepository(storage);
    addTearDown(original.dispose);
    await original.save(fixture());
    await storage.close();
    final restored = TrackingRepository(connect());
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.snapshot.toJson(), fixture().toJson());
  });

  testWidgets(
    'updates, cleared days and empty categories persist without duplicates',
    (_) async {
      await storage.write(fixture());
      final updated = TrackingSnapshot(
        days: {day: DayEntry(date: day, note: 'Geändert')},
        categories: fixture().categories,
      );
      await storage.write(updated);
      await storage.write(updated);
      expect((await storage.read()).toJson(), updated.toJson());
      await storage.write(TrackingSnapshot(categories: updated.categories));
      await storage.close();
      final restored = await connect().read();
      expect(restored.days, isEmpty);
      expect(restored.categories, updated.categories);
    },
  );

  testWidgets(
    'a SQL failure rolls back days and categories and preserves drafts',
    (_) async {
      final repository = TrackingRepository(storage);
      addTearDown(repository.dispose);
      await repository.save(fixture());
      final db = await openDatabase(
        path,
        password: testKey,
        singleInstance: false,
      );
      try {
        await db.execute(
          '''CREATE TRIGGER fail_category BEFORE INSERT ON custom_categories
        BEGIN SELECT RAISE(ABORT, 'injected write failure'); END''',
        );
      } finally {
        await db.close();
      }
      final vm = RecordViewModel(
        repository: repository,
        reminders: _Reminders(),
        date: day,
      );
      addTearDown(vm.dispose);
      await vm.load();
      vm.clearDay();
      vm.selectDay(DateTime(2026, 9, 19));
      vm.setNote('Nicht gespeichert');
      expect(await vm.save(), isFalse);
      expect(vm.isDirty, isTrue);
      expect(vm.entry.note, 'Nicht gespeichert');
      expect(repository.snapshot.toJson(), fixture().toJson());
      await storage.close();
      expect((await connect().read()).toJson(), fixture().toJson());
    },
  );

  testWidgets(
    'wrong or absent keys cannot read the closed encrypted database',
    (_) async {
      await storage.write(fixture());
      await storage.close();
      final bytes = await File(path).readAsBytes();
      expect(latin1.decode(bytes).contains('SQLite format 3'), isFalse);
      expect(
        utf8
            .decode(bytes, allowMalformed: true)
            .contains('SQLCipher-Testnotiz'),
        isFalse,
      );
      await expectLater(
        connect(key: 'incorrect-key').read(),
        throwsA(isA<DatabaseException>()),
      );
      // SQLCipher without a key exercises ordinary SQLite access to the file.
      await expectLater(() async {
        final unkeyed = await openDatabase(
          path,
          readOnly: true,
          singleInstance: false,
        );
        try {
          await unkeyed.rawQuery('SELECT * FROM day_entries');
        } finally {
          await unkeyed.close();
        }
      }(), throwsA(isA<DatabaseException>()));
      expect((await connect().read()).toJson(), fixture().toJson());
    },
  );

  testWidgets('empty keys are rejected before creating a file', (_) async {
    await expectLater(connect(key: '').read(), throwsArgumentError);
    expect(await File(path).exists(), isFalse);
  });

  testWidgets('failed key retrieval can be retried on the same adapter', (
    _,
  ) async {
    var available = false;
    final retrying = SqlCipherTrackingStorage(
      path: path,
      dataKeyProvider: () async => SecretKey(List.filled(32, 42)),
      keyProvider: () async {
        if (!available) throw StateError('Key is unavailable');
        return testKey;
      },
    );
    connections.add(retrying);
    await expectLater(retrying.read(), throwsStateError);
    available = true;
    await retrying.write(fixture());
    expect((await retrying.read()).toJson(), fixture().toJson());
  });

  testWidgets('corrupt payload blocks loading and cannot be overwritten', (
    _,
  ) async {
    await storage.write(fixture());
    await storage.close();
    final db = await openDatabase(
      path,
      password: testKey,
      singleInstance: false,
    );
    try {
      await db.update(
        'day_entries',
        {
          'payload': Uint8List.fromList([1, 2, 3]),
        },
        where: 'id = ?',
        whereArgs: [1],
      );
    } finally {
      await db.close();
    }
    final repository = TrackingRepository(connect());
    addTearDown(repository.dispose);
    await expectLater(repository.load(), throwsFormatException);
    await expectLater(
      repository.save(TrackingSnapshot()),
      throwsFormatException,
    );
    final check = await openDatabase(
      path,
      password: testKey,
      singleInstance: false,
    );
    try {
      final rows = await check.query(
        'day_entries',
        where: 'id = ?',
        whereArgs: [1],
      );
      expect(rows.single['payload'], [1, 2, 3]);
    } finally {
      await check.close();
    }
  });

  testWidgets(
    'save button writes to SQLCipher and a fresh editor restores it',
    (tester) async {
      final repository = TrackingRepository(storage);
      addTearDown(repository.dispose);
      final vm = RecordViewModel(
        repository: repository,
        reminders: _Reminders(),
        date: day,
      );
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RecordView(viewModel: vm),
                  ),
                ),
                child: const Text('Öffnen'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Öffnen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ruhig'));
      await tester.pump();
      await tester.tap(find.text('Eintrag speichern · 1'));
      await tester.pumpAndSettle();
      expect(find.byType(RecordView), findsNothing);
      await storage.close();
      final freshRepository = TrackingRepository(connect());
      addTearDown(freshRepository.dispose);
      final freshVm = RecordViewModel(
        repository: freshRepository,
        reminders: _Reminders(),
        date: day,
      );
      addTearDown(freshVm.dispose);
      await tester.pumpWidget(
        MaterialApp(home: RecordView(viewModel: freshVm)),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('mood-calm')))
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
