import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/mlqr_code.dart';
import '../services/mlqr_encoder_service.dart';

class MlqrDemoViewModel extends ChangeNotifier {
  MlqrDemoViewModel({this.encoder = const MlqrEncoderService()}) {
    _generate();
  }

  final MlqrEncoderService encoder;
  int _layerCount = 3;
  bool _padWithDummies = true;
  MlqrCode? _code;
  String? _error;

  int get layerCount => _layerCount;
  bool get padWithDummies => _padWithDummies;
  MlqrCode? get code => _code;
  String? get error => _error;
  List<String> get sampleTexts => List.generate(
    _layerCount,
    (index) =>
        'Regelmässig MLQR Test | Ebene ${index + 1} | ABC-${index + 100}',
  );

  void configure({int? layerCount, bool? padWithDummies}) {
    _layerCount = layerCount ?? _layerCount;
    _padWithDummies = padWithDummies ?? _padWithDummies;
    _generate();
    notifyListeners();
  }

  void _generate() {
    try {
      _code = encoder.encode([
        for (final text in sampleTexts) Uint8List.fromList(utf8.encode(text)),
      ], padWithDummies: _padWithDummies);
      _error = null;
    } on FormatException catch (error) {
      _code = null;
      _error = error.message;
    } on ArgumentError catch (error) {
      _code = null;
      _error = error.message.toString();
    }
  }
}
