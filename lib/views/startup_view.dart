import 'package:flutter/material.dart';

import '../viewmodels/startup_view_model.dart';
import '../viewmodels/onboarding_view_model.dart';
import 'main_view.dart';
import 'onboarding_view.dart';
import 'splash_view.dart';

/// Keeps startup state for this app session, including background/resume.
class StartupView extends StatefulWidget {
  const StartupView({super.key});

  @override
  State<StartupView> createState() => _StartupViewState();
}

class _StartupViewState extends State<StartupView> {
  final _viewModel = StartupViewModel();
  final _onboardingViewModel = OnboardingViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.start();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _onboardingViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_viewModel, _onboardingViewModel]),
    builder: (context, child) {
      if (!_viewModel.isReady) return const SplashView();
      if (!_onboardingViewModel.isComplete) {
        return OnboardingView(viewModel: _onboardingViewModel);
      }
      return const MainView();
    },
  );
}
