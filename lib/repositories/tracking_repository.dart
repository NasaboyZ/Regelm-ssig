import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/day_entry.dart';
import '../services/tracking_storage.dart';

class TrackingRepository extends ChangeNotifier {
  TrackingRepository(this.storage);
  final TrackingStorage storage;
  TrackingSnapshot _snapshot = TrackingSnapshot();
  TrackingSnapshot get snapshot => _snapshot;
  Future<void>? _loading;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    if (_loading != null) return _loading;
    _loading = _read();
    try {
      await _loading;
    } finally {
      _loading = null;
    }
  }

  Future<void> _read() async {
    final value = await storage.read();
    final snapshot = value == null
        ? TrackingSnapshot()
        : TrackingSnapshot.fromJson(jsonDecode(value) as Map<String, dynamic>);
    _snapshot = snapshot;
    _loaded = true;
    notifyListeners();
  }

  Future<void> save(TrackingSnapshot snapshot) async {
    // Never overwrite unread data after a failed load.
    await load();
    await storage.write(jsonEncode(snapshot.toJson()));
    _snapshot = snapshot;
    notifyListeners();
  }
}
