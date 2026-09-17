import 'package:flutter/material.dart';

import '../viewmodels/startup_view_model.dart';
import 'main_view.dart';
import 'splash_view.dart';

/// Keeps startup state for this app session, including background/resume.
class StartupView extends StatefulWidget {
  const StartupView({super.key});

  @override
  State<StartupView> createState() => _StartupViewState();
}

class _StartupViewState extends State<StartupView> {
  final _viewModel = StartupViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.start();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _viewModel,
    builder: (context, child) =>
        _viewModel.isReady ? const MainView() : const SplashView(),
  );
}
