import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../models/mlqr_camera_frame.dart';

abstract interface class MlqrCameraSource {
  CameraController? get controller;
  double get minZoom;
  double get maxZoom;
  Future<void> start(void Function(MlqrCameraFrame) onFrame);
  Future<void> stop();
  Future<void> focusAt(Offset point);
  Future<void> setZoom(double zoom);
}

/// Lifecycle calls are serialized by TransferReceiveViewModel.
class DeviceMlqrCameraSource implements MlqrCameraSource {
  CameraController? _controller;
  double _minZoom = 1;
  double _maxZoom = 1;
  @override
  CameraController? get controller => _controller;
  @override
  double get minZoom => _minZoom;
  @override
  double get maxZoom => _maxZoom;

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
      await _configure(controller);
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

  Future<void> _configure(CameraController controller) async {
    try {
      await controller.setFocusMode(FocusMode.auto);
    } on CameraException {
      // Some devices expose no configurable focus mode.
    }
    try {
      await controller.setExposureMode(ExposureMode.auto);
    } on CameraException {
      // Some devices expose no configurable exposure mode.
    }
    try {
      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = await controller.getMaxZoomLevel();
    } on CameraException {
      _minZoom = 1;
      _maxZoom = 1;
    }
  }

  @override
  Future<void> focusAt(Offset point) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.setFocusPoint(point);
      await controller.setExposurePoint(point);
    } on CameraException {
      // Manual focus is an enhancement; scanning remains available.
    }
  }

  @override
  Future<void> setZoom(double zoom) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.setZoomLevel(zoom.clamp(_minZoom, _maxZoom));
    } on CameraException {
      // Keep scanning if a platform rejects a zoom request.
    }
  }

  @override
  Future<void> stop() async {
    final camera = _controller;
    _controller = null;
    await camera?.dispose();
  }
}
