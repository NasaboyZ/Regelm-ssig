import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/day_entry.dart';

abstract interface class TrackingStorage {
  Future<TrackingSnapshot> read();
  Future<void> write(TrackingSnapshot snapshot);
}

/// Local, platform-protected persistence behind an exchangeable storage API.
class SecureTrackingStorage implements TrackingStorage {
  const SecureTrackingStorage(this.storage);
  final FlutterSecureStorage storage;
  static const _key = 'regelmaessig.tracking.v1';
  @override
  Future<TrackingSnapshot> read() async {
    final value = await storage.read(key: _key);
    return value == null
        ? TrackingSnapshot()
        : TrackingSnapshot.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  @override
  Future<void> write(TrackingSnapshot snapshot) =>
      storage.write(key: _key, value: jsonEncode(snapshot.toJson()));
}
