import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'debug/cycle_demo_data.dart';
import 'debug/demo_tracking_storage.dart';
import 'dependencies.dart';
import 'main.dart';

void main() {
  if (!kDebugMode) {
    throw UnsupportedError('Die Zyklus-Demo benötigt den Debug-Modus.');
  }
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies(
    trackingStorage: DemoTrackingStorage(createCycleDemoData(DateTime.now())),
  );
  runApp(
    const Directionality(
      textDirection: TextDirection.ltr,
      child: Banner(
        message: 'ZYKLUS-DEMO',
        location: BannerLocation.topEnd,
        child: MyApp(),
      ),
    ),
  );
}
