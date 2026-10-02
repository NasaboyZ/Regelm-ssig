import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:regelmaessig/models/day_entry.dart';
import 'package:regelmaessig/services/debug_tracking_keys.dart';
import 'package:regelmaessig/services/sqlcipher_tracking_storage.dart';
import 'package:regelmaessig/services/tracking_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Only invented data. Retains evidence in a unique app-sandbox directory.
/// The host-side verifier copies it before the next simulator installation.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('export real Flutter SQLCipher evidence with public test keys', (
    _,
  ) async {
    final directory = await Directory(
      await getDatabasesPath(),
    ).createTemp('encryption_evidence_');
    final path = p.join(directory.path, 'flutter.db');
    final evidence = await Directory(
      p.join(directory.path, 'evidence'),
    ).create();
    final storage = SqlCipherTrackingStorage(
      path: path,
      keyProvider: DebugTrackingKeys.databaseKey,
      dataKeyProvider: DebugTrackingKeys.dataKey,
    );
    addTearDown(storage.close);
    final date = DateTime(2026, 9, 28);
    final fixture = TrackingSnapshot(
      days: {
        date: DayEntry(
          date: date,
          note: 'ERFUNDEN-FLUTTER-AUDIT-20260928-schön',
          selections: {
            'mood': {'calm'},
          },
          customValues: {
            'audit': ['ERFUNDENER-WERT'],
          },
          temperature: 36.7,
          weight: 62.5,
          appointments: [
            DayAppointment(
              id: 'audit-appointment',
              title: 'ERFUNDENER-TERMIN',
              location: 'ERFUNDENER-ORT',
              startsAt: DateTime(2026, 9, 29, 9),
            ),
          ],
        ),
      },
      categories: {'audit': 'ERFUNDENE-KATEGORIE'},
    );
    await storage.write(fixture);
    expect((await storage.read()).toJson(), fixture.toJson());

    final inspection = await openDatabase(
      path,
      password: await DebugTrackingKeys.databaseKey(),
      singleInstance: false,
      readOnly: true,
    );
    final pragmas = <String, Object?>{};
    try {
      for (final name in [
        'cipher_version',
        'cipher_provider',
        'cipher_provider_version',
        'cipher_page_size',
        'kdf_iter',
        'cipher_hmac_algorithm',
        'cipher_kdf_algorithm',
        'cipher_use_hmac',
        'cipher',
        'journal_mode',
        'user_version',
        'compile_options',
        'cipher_integrity_check',
        'integrity_check',
      ]) {
        pragmas[name] = await inspection.rawQuery('PRAGMA $name');
      }
      expect(pragmas['cipher_version'], isNotEmpty);
      expect(await inspection.getVersion(), 2);
    } finally {
      await inspection.close();
    }

    final artifacts = <Map<String, Object?>>[];
    Future<void> capture(String phase) async {
      for (final suffix in ['', '-wal', '-journal', '-shm']) {
        final source = File('$path$suffix');
        final exists = await source.exists();
        final name = '$phase-flutter.db$suffix';
        if (exists) await source.copy(p.join(evidence.path, name));
        artifacts.add({
          'phase': phase,
          'file': name,
          'exists': exists,
          if (exists) 'bytes': await source.length(),
        });
      }
    }

    // These live copies are marker-scan samples, not recovery snapshots.
    await capture('open');
    await storage.close();
    await capture('closed');
    final reopened = SqlCipherTrackingStorage(
      path: path,
      keyProvider: DebugTrackingKeys.databaseKey,
      dataKeyProvider: DebugTrackingKeys.dataKey,
    );
    try {
      expect((await reopened.read()).toJson(), fixture.toJson());
    } finally {
      await reopened.close();
    }
    await File(p.join(evidence.path, 'manifest.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'timestamp_utc': DateTime.now().toUtc().toIso8601String(),
        'scope': 'Actual Flutter storage; invented data; public debug keys',
        'platform': Platform.operatingSystem,
        'os_version': Platform.operatingSystemVersion,
        'dart_version': Platform.version,
        'database_key': await DebugTrackingKeys.databaseKey(),
        'data_key_hex':
            (await (await DebugTrackingKeys.dataKey()).extractBytes())
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join(),
        'expected_snapshot': fixture.toJson(),
        'inspection_connection_pragmas': pragmas,
        'artifacts': artifacts,
        'roundtrip_after_reopen': true,
      }),
    );
    // Machine-readable marker for the host-side evidence collection.
    // ignore: avoid_print
    print('REGELMAESSIG_EVIDENCE_PATH=${evidence.path}');
  });
}
