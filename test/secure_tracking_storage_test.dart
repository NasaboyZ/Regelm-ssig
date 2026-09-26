import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regelmaessig/models/day_entry.dart';
import 'package:regelmaessig/repositories/tracking_repository.dart';
import 'package:regelmaessig/services/tracking_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const legacyKey = 'regelmaessig.tracking.v1';
  const secureStorage = FlutterSecureStorage();
  const storage = SecureTrackingStorage(secureStorage);

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('missing data returns an empty snapshot', () async {
    expect((await storage.read()).days, isEmpty);
    expect((await storage.read()).categories, isEmpty);
  });

  test(
    'existing v1 JSON stays readable and uses the same storage key',
    () async {
      const legacy = '''{"version":1,"days":[{"date":"2026-09-18",
      "selections":{"mood":["calm"]},"customValues":{"sleep":["8 Stunden"]},
      "appointments":[],"note":"Bestehende Notiz","temperature":36.7,
      "weight":62.5}],"categories":{"sleep":"Schlaf"}}''';
      FlutterSecureStorage.setMockInitialValues({legacyKey: legacy});
      final snapshot = await storage.read();
      expect(snapshot.days[DateTime(2026, 9, 18)]!.note, 'Bestehende Notiz');
      await storage.write(snapshot);
      expect(
        jsonDecode((await secureStorage.read(key: legacyKey))!),
        jsonDecode(legacy),
      );
    },
  );

  for (final invalid in ['{bad', '{"version":99,"days":[],"categories":{}}']) {
    test('unreadable legacy data cannot be overwritten: $invalid', () async {
      FlutterSecureStorage.setMockInitialValues({legacyKey: invalid});
      final repository = TrackingRepository(storage);
      addTearDown(repository.dispose);
      await expectLater(repository.load(), throwsFormatException);
      await expectLater(
        repository.save(TrackingSnapshot()),
        throwsFormatException,
      );
      expect(await secureStorage.read(key: legacyKey), invalid);
    });
  }
}
