import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:regelmaessig/models/day_entry.dart';
import 'package:regelmaessig/models/tracking_catalog.dart';
import 'package:regelmaessig/repositories/tracking_repository.dart';
import 'package:regelmaessig/services/appointment_reminders.dart';
import 'package:regelmaessig/services/sqlcipher_tracking_storage.dart';
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

  SqlCipherTrackingStorage connect({String key = testKey}) {
    final connection = SqlCipherTrackingStorage(
      path: path,
      keyProvider: () async => key,
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

  testWidgets('corrupt stored JSON blocks loading and cannot be overwritten', (
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
        {'data_json': '{bad'},
        where: 'date = ?',
        whereArgs: [dayKey(day)],
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
        where: 'date = ?',
        whereArgs: [dayKey(day)],
      );
      expect(rows.single['data_json'], '{bad');
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
