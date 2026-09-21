import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TrackingStorage {
  Future<String?> read();
  Future<void> write(String value);
}

/// Local, platform-protected persistence behind an exchangeable storage API.
class SecureTrackingStorage implements TrackingStorage {
  const SecureTrackingStorage(this.storage);
  final FlutterSecureStorage storage;
  static const _key = 'regelmaessig.tracking.v1';
  @override
  Future<String?> read() => storage.read(key: _key);
  @override
  Future<void> write(String value) => storage.write(key: _key, value: value);
}
