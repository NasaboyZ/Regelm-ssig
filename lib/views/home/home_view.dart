import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/period_entry.dart';
import '../../viewmodels/home_view_model.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/cycle/cycle_ring.dart';
import '../../widgets/cycle/cycle_summary_card.dart';
import '../../widgets/cycle/cycle_calendar.dart';
import '../../widgets/cycle/forecast_settings.dart';

class HomeView extends StatelessWidget {
  const HomeView({
    super.key,
    required this.viewModel,
    required this.onOpenCalendar,
    required this.onRecord,
    required this.onDetails,
    this.onRecordDay,
  });
  final HomeViewModel viewModel;
  final VoidCallback onOpenCalendar;
  final VoidCallback onRecord;
  final VoidCallback onDetails;
  final ValueChanged<DateTime>? onRecordDay;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      if (viewModel.isLoading)
        return const Center(child: CircularProgressIndicator());
      if (viewModel.error != null)
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(viewModel.error!),
              TextButton(
                onPressed: viewModel.load,
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        );
      final cycle = viewModel.summary;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Regelmässig',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 36,
              height: 1.1,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            color: const Color(0xFFF5F3F2),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final forecast = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (cycle.currentStart == null)
                      const Text('Noch keine Zyklusdaten'),
                    if (cycle.countdown != null)
                      Text(
                        cycle.countdown!,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (cycle.predictedNextStart != null)
                      Text(
                        'Ungefähr ${cycleDateLabel(cycle.predictedNextStart!)}',
                      ),
                    const SizedBox(height: 8),
                    Text(
                      cycle.predictionExplanation,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                );
                final ring = SizedBox(
                  width: 155,
                  child: CycleRing(summary: cycle),
                );
                if (constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                  return Column(children: [ring, forecast]);
                }
                return Row(
                  children: [
                    ring,
                    const SizedBox(width: 12),
                    Expanded(child: forecast),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          AppButton(label: 'Heute erfassen', onPressed: onRecord),
          const SizedBox(height: 12),
          CycleSummaryCard(cycle: cycle, onDetails: onDetails),
          if (viewModel.forecastConsent == ForecastConsent.unknown &&
              cycle.currentStart != null) ...[
            const SizedBox(height: 12),
            AppCard(child: ForecastSettings(viewModel: viewModel)),
          ],
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Zyklusverlauf',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: onOpenCalendar,
                      child: const Text(
                        'Kalender öffnen ›',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                CycleCalendar(
                  today: cycle.today,
                  entryDays: cycle.entryDays,
                  periodDays: cycle.periodDays,
                  spottingDays: cycle.spottingDays,
                  predictedDays: cycle.predictedDays,
                  onDaySelected: onRecordDay,
                ),
                const SizedBox(height: 8),
                const CalendarLegend(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Kalenderprognosen bestätigen keinen Eisprung und sind nicht zur Verhütung geeignet.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      );
    },
  );
}
