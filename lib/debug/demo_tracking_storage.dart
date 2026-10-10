import '../models/day_entry.dart';
import '../services/tracking_storage.dart';

/// Session-only storage: demo edits never touch the normal database.
class DemoTrackingStorage implements TrackingStorage {
  DemoTrackingStorage(this._snapshot);

  TrackingSnapshot _snapshot;

  @override
  Future<TrackingSnapshot> read() async => _snapshot;

  @override
  Future<void> write(TrackingSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}
