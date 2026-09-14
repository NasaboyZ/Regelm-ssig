import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../viewmodels/home_view_model.dart';
import '../../viewmodels/home_state.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/cycle/cycle_ring.dart';
import '../../widgets/cycle/cycle_summary_card.dart';
import '../../widgets/cycle/cycle_calendar.dart';

class HomeView extends StatelessWidget {
  const HomeView({
    super.key,
    required this.viewModel,
    required this.onOpenCalendar,
    required this.onRecord,
    required this.onDetails,
  });
  final HomeViewModel viewModel;
  final VoidCallback onOpenCalendar;
  final VoidCallback onRecord;
  final VoidCallback onDetails;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final state = viewModel.state;
      return switch (state) {
        HomeInitial() ||
        HomeLoading() => const Center(child: CircularProgressIndicator()),
        HomeError(:final message) => Center(child: Text(message)),
        HomeEmpty() => _emptyHome(),
        HomeSuccess(:final cycle) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Regelmässig',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 36,
                      height: 1.1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              color: const Color(0xFFF5F3F2),
              border: Border.all(style: BorderStyle.none),
              padding: const EdgeInsets.all(10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ring = CycleRing(
                    cycleDay: cycle.day,
                    cycleLength: cycle.length,
                    phase: cycle.phase,
                  );
                  final forecast = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nächste Periode\nvoraussichtlich in',
                        style: TextStyle(fontSize: 15),
                      ),
                      Text(
                        '${cycle.daysUntilPeriod} Tagen',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Divider(height: 24),
                      const PhaseLegend(),
                    ],
                  );
                  if (constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                    return Column(
                      children: [
                        SizedBox(width: 190, child: ring),
                        forecast,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: ring),
                      const SizedBox(width: 8),
                      Expanded(child: forecast),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            AppButton(label: 'Heute erfassen', onPressed: onRecord),
            const SizedBox(height: 16),
            CycleSummaryCard(cycle: cycle, onDetails: onDetails),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Zyklusverlauf',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: onOpenCalendar,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.burntOrange,
                        ),
                        child: const Text(
                          'Kalender öffnen ›',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  CycleCalendar(
                    today: cycle.today,
                    periodDays: {
                      for (var i = 0; i < cycle.periodLength; i++)
                        cycle.start.add(Duration(days: i)),
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      };
    },
  );

  Widget _emptyHome() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Text(
          'Regelmässig',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 36,
            height: 1.1,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      const SizedBox(height: 12),
      const AppCard(
        color: Color(0xFFF5F3F2),
        child: Text(
          'Noch keine Zyklusdaten',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ),
      const SizedBox(height: 12),
      AppButton(label: 'Heute erfassen', onPressed: onRecord),
      const SizedBox(height: 16),
      const AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aktueller Zyklus',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Noch keine Einträge',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Zyklusverlauf',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
            CycleCalendar(today: DateTime.now(), periodDays: const {}),
          ],
        ),
      ),
    ],
  );
}
