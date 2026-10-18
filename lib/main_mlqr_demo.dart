import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'debug/mlqr_demo_app.dart';

void main() {
  if (!kDebugMode) {
    throw UnsupportedError('Die MLQR-Demo benötigt den Debug-Modus.');
  }
  runApp(const MlqrDemoApp());
}
