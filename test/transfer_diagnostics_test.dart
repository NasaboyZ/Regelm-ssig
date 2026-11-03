import 'package:flutter_test/flutter_test.dart';
import 'package:regelmaessig/services/transfer_diagnostics.dart';

void main() {
  test('benchmark profiles preserve the documented before/after settings', () {
    expect(TransferTimingProfile.legacy.temporalRounds, 3);
    expect(
      TransferTimingProfile.legacy.frameInterval,
      const Duration(seconds: 3),
    );
    expect(TransferTimingProfile.current.temporalRounds, 1);
    expect(
      TransferTimingProfile.current.frameInterval,
      const Duration(milliseconds: 1500),
    );
    expect(
      TransferTimingProfile.legacy.displayDuration(
        mlqrFrames: 1,
        temporalFrames: 7,
      ),
      const Duration(seconds: 66),
    );
    expect(
      TransferTimingProfile.current.displayDuration(
        mlqrFrames: 1,
        temporalFrames: 7,
      ),
      const Duration(seconds: 12),
    );
  });
}
