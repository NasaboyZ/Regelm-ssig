import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'dependencies.dart';
import 'main.dart' show MyApp;
import 'services/sqlcipher_tracking_storage.dart';

/// Separate opt-in entrypoint; never imported by the regular application.
Future<void> main() async {
  if (kDebugMode) {
    WidgetsFlutterBinding.ensureInitialized();
    final path = p.join(
      await getDatabasesPath(),
      'regelmaessig_tracking_debug.db',
    );
    configureDependencies(
      trackingStorage: SqlCipherTrackingStorage(
        path: path,
        // Public fixture key, deliberately unsuitable for personal data.
        keyProvider: () async => 'regelmaessig-debug-test-key-v1',
      ),
    );
    runApp(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Banner(
          message: 'TESTDATEN',
          location: BannerLocation.topEnd,
          child: MyApp(),
        ),
      ),
    );
  } else {
    throw UnsupportedError('The SQLCipher test entrypoint is debug-only');
  }
}
