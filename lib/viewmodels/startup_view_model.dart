import 'dart:async';

import 'package:flutter/foundation.dart';

class StartupViewModel extends ChangeNotifier {
  static const splashDuration = Duration(milliseconds: 1500);

  Timer? _timer;
  bool _isReady = false;
  bool get isReady => _isReady;

  void start() {
    if (_timer != null || _isReady) return;
    _timer = Timer(splashDuration, () {
      _isReady = true;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
