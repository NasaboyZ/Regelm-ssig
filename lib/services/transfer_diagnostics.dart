import 'package:flutter/foundation.dart';

/// Debug-only, privacy-safe diagnostics for physical transfer measurements.
///
/// The diagnostics deliberately contain counts and durations only. They never
/// contain passphrases, payloads, transfer IDs, or health data.
abstract final class TransferDiagnostics {
  static void event(String name, Map<String, Object?> fields) {
    if (!kDebugMode) return;
    final details = fields.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    debugPrint('transfer.$name $details');
  }
}

/// The two display profiles used by the before/after benchmark.
abstract final class TransferTimingProfile {
  static const legacy = TransferTimingProfileDefinition(
    name: 'legacy',
    temporalRounds: 3,
    frameInterval: Duration(seconds: 3),
  );

  static const current = TransferTimingProfileDefinition(
    name: 'current',
    temporalRounds: 1,
    frameInterval: Duration(milliseconds: 1500),
  );
}

final class TransferTimingProfileDefinition {
  const TransferTimingProfileDefinition({
    required this.name,
    required this.temporalRounds,
    required this.frameInterval,
  });

  final String name;
  final int temporalRounds;
  final Duration frameInterval;

  Duration displayDuration({
    required int mlqrFrames,
    required int temporalFrames,
  }) => frameInterval * (mlqrFrames + temporalFrames * temporalRounds);
}
