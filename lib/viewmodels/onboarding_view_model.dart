import 'package:flutter/foundation.dart';

enum OnboardingStep { cycle, privacy, transfer }

class OnboardingViewModel extends ChangeNotifier {
  OnboardingStep _step = OnboardingStep.cycle;
  bool _isComplete = false;

  OnboardingStep get step => _step;
  int get stepNumber => _step.index + 1;
  int get stepCount => OnboardingStep.values.length;
  bool get isComplete => _isComplete;
  bool get isLastStep => _step == OnboardingStep.transfer;
  String get buttonLabel => isLastStep ? 'App einrichten' : 'Weiter';

  void next() {
    if (_isComplete) return;
    if (isLastStep) {
      _isComplete = true;
    } else {
      _step = OnboardingStep.values[_step.index + 1];
    }
    notifyListeners();
  }

  void back() {
    if (_isComplete || _step == OnboardingStep.cycle) return;
    _step = OnboardingStep.values[_step.index - 1];
    notifyListeners();
  }
}
