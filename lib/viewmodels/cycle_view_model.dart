import 'package:flutter/foundation.dart';
import '../models/day_entry.dart';
import '../models/cycle_summary.dart';
import '../models/period_entry.dart';
import '../repositories/tracking_repository.dart';
import '../services/cycle_calculation_service.dart';

/// Shared lifecycle for repository-backed cycle screens; no database/UI logic.
class CycleViewModel extends ChangeNotifier {
  CycleViewModel({
    this.repository,
    this.calculator = const CycleCalculationService(),
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now {
    summary = calculator.calculate(
      repository?.snapshot ?? TrackingSnapshot(),
      this.clock(),
    );
    repository?.addListener(refresh);
  }
  final TrackingRepository? repository;
  final CycleCalculationService calculator;
  final DateTime Function() clock;
  late CycleSummary summary;
  bool isLoading = false;
  bool isSavingConsent = false;
  bool _disposed = false;
  String? error;
  String? consentError;
  ForecastConsent get forecastConsent =>
      repository?.snapshot.forecastConsent ?? ForecastConsent.unknown;

  void refresh() {
    if (_disposed) return;
    summary = calculator.calculate(
      repository?.snapshot ?? TrackingSnapshot(),
      clock(),
    );
    error = null;
    notifyListeners();
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await repository?.load();
      refresh();
    } catch (_) {
      if (!_disposed) error = 'Deine Einträge konnten nicht geladen werden.';
    } finally {
      if (!_disposed) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> setForecastConsent(ForecastConsent value) async {
    if (isSavingConsent || repository == null) return;
    isSavingConsent = true;
    consentError = null;
    notifyListeners();
    try {
      await repository!.load();
      await repository!.save(
        repository!.snapshot.copyWith(forecastConsent: value),
      );
    } catch (_) {
      if (!_disposed)
        consentError = 'Speichern fehlgeschlagen. Bitte versuche es erneut.';
    } finally {
      if (!_disposed) {
        isSavingConsent = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    repository?.removeListener(refresh);
    super.dispose();
  }
}
