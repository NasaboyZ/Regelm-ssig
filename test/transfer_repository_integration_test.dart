import 'package:flutter_test/flutter_test.dart';
import 'package:regelmaessig/models/day_entry.dart';
import 'package:regelmaessig/models/mlqr_camera_frame.dart';
import 'package:regelmaessig/repositories/tracking_repository.dart';
import 'package:regelmaessig/services/mlqr_decoder_service.dart';
import 'package:regelmaessig/services/mlqr_transfer_service.dart';
import 'package:regelmaessig/services/tracking_storage.dart';
import 'package:regelmaessig/viewmodels/transfer_receive_view_model.dart';
import 'support/fake_mlqr_camera.dart';

class MemoryTrackingStorage implements TrackingStorage {
  MemoryTrackingStorage(this.value);
  TrackingSnapshot value;

  @override
  Future<TrackingSnapshot> read() async => value;

  @override
  Future<void> write(TrackingSnapshot snapshot) async => value = snapshot;
}

void main() {
  testWidgets(
    'real repository snapshot is transferred and merged without a passphrase',
    (tester) async {
      final sourceSnapshot = TrackingSnapshot(
        days: {
          DateTime(2026, 10, 15): DayEntry(
            date: DateTime(2026, 10, 15),
            note: 'Eintrag vom 15.',
          ),
        },
      );
      final sequence = await MlqrTransferService()
          .encodeUnencryptedSnapshotForDevelopment(
            sourceSnapshot,
            transferId: 'integration-transfer',
            chunkSize: 5,
          );
      final decoder = const MlqrDecoderService();
      final decoded = [
        for (final code in sequence.codes)
          decoder.decodeRaster(
            code.raster,
            opticalLayerCount: code.layers.length,
          ),
      ];
      final storage = MemoryTrackingStorage(TrackingSnapshot());
      final repository = TrackingRepository(storage);
      final camera = FakeMlqrCamera();
      var index = 0;
      final model = TransferReceiveViewModel(
        source: camera,
        repository: repository,
        decode: (_) async => index < decoded.length ? decoded[index++] : null,
      );

      model.resume();
      await tester.pump();
      for (final _ in decoded) {
        camera.onFrame!(
          MlqrCameraFrame(
            width: 1,
            height: 1,
            format: MlqrCameraFormat.bgra8888,
            planes: [
              MlqrCameraPlane([0, 0, 0, 255], 4, 4),
            ],
          ),
        );
        await tester.pump();
      }
      await tester.pump();

      expect(
        repository.snapshot.days[DateTime(2026, 10, 15)]?.note,
        'Eintrag vom 15.',
      );
      expect(model.result, isNotNull);
      model.dispose();
      await tester.pump();
    },
  );
}
