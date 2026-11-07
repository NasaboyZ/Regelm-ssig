/// Optical transfer profile selected independently from payload size.
class MlqrTransferProfile {
  const MlqrTransferProfile({
    required this.id,
    required this.targetQrVersion,
    required this.maxPayloadLayersPerCode,
    required this.codeInterval,
  });

  static const standard = MlqrTransferProfile(
    id: 'standard-5-layer',
    targetQrVersion: 10,
    maxPayloadLayersPerCode: 5,
    codeInterval: Duration(seconds: 3),
  );
  static const robust = MlqrTransferProfile(
    id: 'robust-3-layer',
    targetQrVersion: 10,
    maxPayloadLayersPerCode: 3,
    codeInterval: Duration(seconds: 3),
  );
  static const balanced = MlqrTransferProfile(
    id: 'balanced-5-layer',
    targetQrVersion: 10,
    maxPayloadLayersPerCode: 5,
    codeInterval: Duration(seconds: 3),
  );
  static const fast = MlqrTransferProfile(
    id: 'fast-9-layer',
    targetQrVersion: 10,
    maxPayloadLayersPerCode: 9,
    codeInterval: Duration(seconds: 3),
  );
  static const experimental = MlqrTransferProfile(
    id: 'experimental-15-layer',
    targetQrVersion: 10,
    maxPayloadLayersPerCode: 15,
    codeInterval: Duration(seconds: 3),
  );

  final String id;
  final int targetQrVersion;
  final int maxPayloadLayersPerCode;
  final Duration codeInterval;
}

class MlqrProfileMeasurement {
  const MlqrProfileMeasurement({
    required this.profile,
    required this.successRate,
    required this.p95RecognitionMs,
  });

  final MlqrTransferProfile profile;
  final double successRate;
  final int p95RecognitionMs;

  bool meetsTarget({double minimumSuccessRate = 0.95, int maxMs = 5000}) =>
      successRate >= minimumSuccessRate && p95RecognitionMs <= maxMs;
}

class MlqrTransferProfileSelector {
  const MlqrTransferProfileSelector();

  MlqrTransferProfile select(
    Iterable<MlqrProfileMeasurement> measurements, {
    double minimumSuccessRate = 0.95,
    int maxRecognitionMs = 5000,
  }) {
    final eligible =
        measurements
            .where(
              (measurement) => measurement.meetsTarget(
                minimumSuccessRate: minimumSuccessRate,
                maxMs: maxRecognitionMs,
              ),
            )
            .toList()
          ..sort((a, b) {
            final duration = a.p95RecognitionMs.compareTo(b.p95RecognitionMs);
            if (duration != 0) return duration;
            return b.profile.maxPayloadLayersPerCode.compareTo(
              a.profile.maxPayloadLayersPerCode,
            );
          });
    return eligible.isEmpty
        ? MlqrTransferProfile.standard
        : eligible.first.profile;
  }
}
