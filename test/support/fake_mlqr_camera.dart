import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:regelmaessig/models/mlqr_camera_frame.dart';
import 'package:regelmaessig/services/mlqr_camera_source.dart';

class FakeMlqrCamera implements MlqrCameraSource {
  void Function(MlqrCameraFrame)? onFrame;
  Object? startError;
  Completer<void>? starting;
  int starts = 0;
  int stops = 0;
  double zoom = 1;
  Offset? focusPoint;
  @override
  double get minZoom => 1;
  @override
  double get maxZoom => 4;
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

  @override
  Future<void> focusAt(Offset point) async {
    focusPoint = point;
  }

  @override
  Future<void> setZoom(double value) async {
    zoom = value;
  }
}
