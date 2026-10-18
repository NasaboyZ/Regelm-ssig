import 'dart:async';
import 'package:camera/camera.dart';
import 'package:regelmaessig/models/mlqr_camera_frame.dart';
import 'package:regelmaessig/services/mlqr_camera_source.dart';

class FakeMlqrCamera implements MlqrCameraSource {
  void Function(MlqrCameraFrame)? onFrame;
  Object? startError;
  Completer<void>? starting;
  int starts = 0;
  int stops = 0;
  @override
  CameraController? get controller => null;
  @override
  Future<void> start(void Function(MlqrCameraFrame) callback) async {
    starts++;
    onFrame = callback;
    await starting?.future;
    if (startError != null) throw startError!;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}
