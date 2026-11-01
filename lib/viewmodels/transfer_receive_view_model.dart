import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../models/mlqr_camera_frame.dart';
import '../models/mlqr_decoded.dart';
import '../models/transfer_result.dart';
import '../repositories/tracking_repository.dart';
import '../services/mlqr_camera_source.dart';
import '../services/mlqr_decoder_service.dart';
import '../services/mlqr_transfer_service.dart';
import '../services/transfer_codec.dart';

/// Null is an expected unreadable frame while the camera is being aimed.
Future<MlqrDecoded?> decodeCameraFrame(MlqrCameraFrame frame) =>
    compute(_decodeFrame, frame);

MlqrDecoded? _decodeFrame(MlqrCameraFrame frame) {
  final raster = frame.toRaster();
  final decoder = const MlqrDecoderService();
  for (final candidate in [raster.centerCropSquare(), raster]) {
    try {
      return decoder.decodeImage(candidate);
    } on MlqrDecodeException {
      try {
        return decoder.decodeTemporalImage(candidate);
      } on MlqrDecodeException {
        // Continue with the next candidate or report an unreadable frame.
      }
    }
  }
  return null;
}

class TransferReceiveViewModel extends ChangeNotifier {
  TransferReceiveViewModel({
    MlqrCameraSource? source,
    Future<MlqrDecoded?> Function(MlqrCameraFrame)? decode,
    this._repository,
    MlqrTransferService? transfer,
    this.scanTimeout = const Duration(hours: 45),
  }) : _source = source ?? DeviceMlqrCameraSource(),
       _decode = decode ?? decodeCameraFrame,
       _transfer = transfer ?? MlqrTransferService();

  final MlqrCameraSource _source;
  final Future<MlqrDecoded?> Function(MlqrCameraFrame) _decode;
  final TrackingRepository? _repository;
  final MlqrTransferService _transfer;
  final Duration scanTimeout;
  Future<void> _operations = Future.value();
  Timer? _timer;
  int _epoch = 0;
  bool _disposed = false;
  bool _busy = false;
  final _chunks = TransferChunkAccumulator();
  bool _sessionStarted = false;
  bool initializing = true;
  bool paused = false;
  double zoom = 1;
  double minZoom = 1;
  double maxZoom = 1;
  TransferResult? result;
  CameraController? get camera => _source.controller;
  int get receivedChunkCount => _chunks.receivedCount;
  int? get expectedChunkCount => _chunks.expectedCount;
  List<int> get missingChunkIndexes => _chunks.missingIndexes;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void resume() {
    if (_disposed || result != null) return;
    final epoch = ++_epoch;
    if (!_sessionStarted) {
      _chunks.clear();
      _sessionStarted = true;
    }
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
        minZoom = _source.minZoom;
        maxZoom = _source.maxZoom;
        zoom = minZoom;
        _timer?.cancel();
        _armTimeout(epoch);
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

  void _armTimeout(int epoch) {
    _timer?.cancel();
    _timer = Timer(
      scanTimeout,
      () => _finish(
        TransferFailed(
          reason: expectedChunkCount == null
              ? TransferFailureReason.unreadable
              : TransferFailureReason.incomplete,
          receivedCodeCount: expectedChunkCount == null
              ? null
              : receivedChunkCount,
          expectedCodeCount: expectedChunkCount,
        ),
        epoch,
      ),
    );
  }

  Future<void> focusAt(Offset point) => _source.focusAt(point);

  Future<void> setZoom(double value) async {
    final next = value.clamp(minZoom, maxZoom).toDouble();
    await _source.setZoom(next);
    zoom = next;
    _notify();
  }

  Future<void> _onFrame(MlqrCameraFrame frame, int epoch) async {
    if (_disposed || _busy || epoch != _epoch || result != null) return;
    _busy = true;
    try {
      final decoded = await _decode(frame);
      if (decoded != null) {
        if (_repository == null) {
          _finish(TransferCodeRead(decoded), epoch);
        } else {
          await _acceptTransferCode(decoded, epoch);
        }
      }
    } catch (_) {
      _finish(TransferFailed(reason: TransferFailureReason.unreadable), epoch);
    } finally {
      _busy = false;
    }
  }

  Future<void> _acceptTransferCode(MlqrDecoded decoded, int epoch) async {
    try {
      final parsed = [
        for (final packet in decoded.packets) TransferChunk.fromBytes(packet),
      ];
      if (parsed.isEmpty) return;
      final first = parsed.first;
      if (first.encrypted) {
        _finish(
          TransferFailed(reason: TransferFailureReason.verificationFailed),
          epoch,
        );
        return;
      }
      final added = _chunks.acceptAll(parsed);
      if (added > 0) {
        _armTimeout(epoch);
        _notify();
      }
      if (!_chunks.isComplete || _disposed) return;
      final incoming = await _transfer.payloadCodec.decodeSnapshot(
        _chunks.orderedChunks,
      );
      final repository = _repository!;
      await repository.load();
      final merged = _transfer.mergeIncomingSnapshot(
        repository.snapshot,
        incoming,
      );
      await repository.save(merged);
      _finish(
        TransferSucceeded(
          codeCount: _chunks.receivedCount,
          importedCategories: TransferDataCategory.values.toSet(),
        ),
        epoch,
      );
    } on TransferPayloadException {
      _finish(
        TransferFailed(reason: TransferFailureReason.verificationFailed),
        epoch,
      );
    } on FormatException {
      // A standard/non-transfer QR or a partial camera frame is ignored.
    }
  }

  void _finish(TransferResult value, int epoch) {
    if (_disposed || epoch != _epoch || result != null) return;
    result = value;
    _epoch++;
    _timer?.cancel();
    _stop();
    _chunks.clear();
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
