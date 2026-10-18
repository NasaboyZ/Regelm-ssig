import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../models/mlqr_camera_frame.dart';
import '../models/mlqr_decoded.dart';
import '../models/transfer_result.dart';
import '../services/mlqr_camera_source.dart';
import '../services/mlqr_decoder_service.dart';

/// Null is an expected unreadable frame while the camera is being aimed.
Future<MlqrDecoded?> decodeCameraFrame(MlqrCameraFrame frame) =>
    compute(_decodeFrame, frame);

MlqrDecoded? _decodeFrame(MlqrCameraFrame frame) {
  try {
    return const MlqrDecoderService().decodeImage(frame.toRaster());
  } on MlqrDecodeException {
    return null;
  }
}

class TransferReceiveViewModel extends ChangeNotifier {
  TransferReceiveViewModel({
    MlqrCameraSource? source,
    Future<MlqrDecoded?> Function(MlqrCameraFrame)? decode,
    this.scanTimeout = const Duration(seconds: 45),
  }) : _source = source ?? DeviceMlqrCameraSource(),
       _decode = decode ?? decodeCameraFrame;

  final MlqrCameraSource _source;
  final Future<MlqrDecoded?> Function(MlqrCameraFrame) _decode;
  final Duration scanTimeout;
  Future<void> _operations = Future.value();
  Timer? _timer;
  int _epoch = 0;
  bool _disposed = false;
  bool _busy = false;
  bool initializing = true;
  bool paused = false;
  TransferResult? result;
  CameraController? get camera => _source.controller;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void resume() {
    if (_disposed || result != null) return;
    final epoch = ++_epoch;
    paused = false;
    initializing = true;
    _notify();
    _operations = _operations.then((_) async {
      if (_disposed || epoch != _epoch) return;
      try {
        await _source.stop();
        await _source.start((frame) => _onFrame(frame, epoch));
        if (_disposed || epoch != _epoch) {
          await _source.stop();
          return;
        }
        initializing = false;
        _timer?.cancel();
        _timer = Timer(
          scanTimeout,
          () => _finish(
            TransferFailed(reason: TransferFailureReason.unreadable),
            epoch,
          ),
        );
        _notify();
      } catch (error) {
        final denied =
            error is CameraException &&
            (error.code.contains('AccessDenied') ||
                error.code.contains('Restricted'));
        _finish(
          TransferFailed(
            reason: denied
                ? TransferFailureReason.cameraPermissionDenied
                : TransferFailureReason.cameraUnavailable,
          ),
          epoch,
        );
      }
    });
  }

  Future<void> _onFrame(MlqrCameraFrame frame, int epoch) async {
    if (_disposed || _busy || epoch != _epoch || result != null) return;
    _busy = true;
    try {
      final decoded = await _decode(frame);
      if (decoded != null) _finish(TransferCodeRead(decoded), epoch);
    } catch (_) {
      _finish(TransferFailed(reason: TransferFailureReason.unreadable), epoch);
    } finally {
      _busy = false;
    }
  }

  void _finish(TransferResult value, int epoch) {
    if (_disposed || epoch != _epoch || result != null) return;
    result = value;
    _epoch++;
    _timer?.cancel();
    _stop();
    _notify();
  }

  void pause() {
    if (_disposed || result != null) return;
    _epoch++;
    paused = true;
    _timer?.cancel();
    _stop();
    _notify();
  }

  void _stop() {
    _operations = _operations.then((_) => _source.stop()).catchError((
      Object _,
    ) {
      // Best effort cleanup, including permission denial and native teardown.
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _timer?.cancel();
    _stop();
    super.dispose();
  }
}
