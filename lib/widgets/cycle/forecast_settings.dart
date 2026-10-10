import 'package:flutter/material.dart';
import '../../models/period_entry.dart';
import '../../viewmodels/cycle_view_model.dart';

class ForecastSettings extends StatelessWidget {
  const ForecastSettings({super.key, required this.viewModel});
  final CycleViewModel viewModel;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Voraussetzungen für Prognosen',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      const Text(
        'Liegt ein natürlicher Zyklus ohne hormonelle Verhütung, Schwangerschaft oder Stillzeit vor?',
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          for (final option in [
            (ForecastConsent.yes, 'Ja'),
            (ForecastConsent.no, 'Nein'),
            (ForecastConsent.unsure, 'Unsicher'),
          ])
            ChoiceChip(
              label: Text(option.$2),
              selected: viewModel.forecastConsent == option.$1,
              onSelected: viewModel.isSavingConsent
                  ? null
                  : (_) => viewModel.setForecastConsent(option.$1),
            ),
        ],
      ),
      if (viewModel.isSavingConsent) const LinearProgressIndicator(),
      if (viewModel.consentError != null)
        Text(
          viewModel.consentError!,
          style: const TextStyle(color: Colors.red),
        ),
      const SizedBox(height: 8),
      const Text(
        'Bei Nein oder Unsicher pausieren Prognosen. Deine Einträge bleiben verfügbar. Diese Angabe kannst du jederzeit ändern.',
        style: TextStyle(fontSize: 12),
      ),
    ],
  );
}
