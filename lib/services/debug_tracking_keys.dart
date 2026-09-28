import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// Public fixtures for invented test data. Neither key protects personal data.
abstract final class DebugTrackingKeys {
  static Future<String> databaseKey() async {
    _requireDebug();
    return 'regelmaessig-debug-test-key-v1';
  }

  /// Fixed, separate AES-256 fixture (hex bytes 00 through 1f).
  static Future<SecretKey> dataKey() async {
    _requireDebug();
    return SecretKey(List<int>.generate(32, (index) => index));
  }

  static void _requireDebug() {
    if (!kDebugMode) {
      throw StateError('Production key management is not configured');
    }
  }
}
