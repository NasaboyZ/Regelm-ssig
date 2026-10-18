import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../models/mlqr_camera_frame.dart';

abstract interface class MlqrCameraSource {
  CameraController? get controller;
  Future<void> start(void Function(MlqrCameraFrame) onFrame);
  Future<void> stop();
}

/// Lifecycle calls are serialized by TransferReceiveViewModel.
class DeviceMlqrCameraSource implements MlqrCameraSource {
  CameraController? _controller;
  @override
  CameraController? get controller => _controller;

  @override
  Future<void> start(void Function(MlqrCameraFrame) onFrame) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException('NoCamera', 'Keine Kamera verfügbar.');
    }
    final rear = cameras.where(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    final controller = CameraController(
      rear.isEmpty ? cameras.first : rear.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );
    _controller = controller;
    try {
      await controller.initialize();
      final clock = Stopwatch()..start();
      var lastFrame = -500;
      await controller.startImageStream((image) {
        if (clock.elapsedMilliseconds - lastFrame < 500) return;
        lastFrame = clock.elapsedMilliseconds;
        final format = switch (image.format.group) {
          ImageFormatGroup.bgra8888 => MlqrCameraFormat.bgra8888,
          ImageFormatGroup.yuv420 => MlqrCameraFormat.yuv420,
          _ => null,
        };
        if (format == null) return;
        onFrame(
          MlqrCameraFrame(
            width: image.width,
            height: image.height,
            format: format,
            planes: [
              for (final plane in image.planes)
                MlqrCameraPlane(
                  plane.bytes,
                  plane.bytesPerRow,
                  plane.bytesPerPixel ??
                      (format == MlqrCameraFormat.bgra8888 ? 4 : 1),
                ),
            ],
          ),
        );
      });
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    final camera = _controller;
    _controller = null;
    await camera?.dispose();
  }
}
