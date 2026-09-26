import 'package:flutter/foundation.dart';
import 'main.dart' as app;

/// Compatibility entrypoint for existing launch configurations.
/// The normal development entrypoint now uses the same database.
void main() {
  if (kDebugMode) {
    app.main();
  } else {
    throw UnsupportedError('The SQLCipher test entrypoint is debug-only');
  }
}
