import 'package:flutter/material.dart';
import '../models/cycle_data.dart';
import '../viewmodels/home_view_model.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/cycle/cycle_calendar.dart';
import '../widgets/cycle/cycle_summary_card.dart';
import 'home/home_view.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});
  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  int _selectedIndex = 0;
  // Fixed demo fixture until the local repository is connected.
  final _cycle = CycleData(
    today: DateTime(2026, 9, 18),
    start: DateTime(2026, 9, 1),
  );
  late final _homeViewModel = HomeViewModel(initialData: _cycle);
  @override
  void dispose() {
    _homeViewModel.dispose();
    super.dispose();
  }

  void _record() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Heute erfassen',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'Hier kannst du künftig deine Periode, Symptome und Stimmung erfassen. Die Erfassung ist noch nicht verfügbar.',
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
  void _details() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CycleSummaryCard(
              cycle: _cycle,
              onDetails: () => Navigator.pop(context),
            ),
            const SizedBox(height: 16),
            const Text(
              'Beispieldaten: Zykluslänge 28 Tage, Periodendauer 5 Tage. Persönliche Auswertungen folgen nach der Datenerfassung.',
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeView(
            viewModel: _homeViewModel,
            onOpenCalendar: () => setState(() => _selectedIndex = 1),
            onRecord: _record,
            onDetails: _details,
          ),
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Zyklusverlauf',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              CycleCalendar(
                today: _cycle.today,
                periodDays: {
                  for (var i = 0; i < _cycle.periodLength; i++)
                    _cycle.start.add(Duration(days: i)),
                },
              ),
              const SizedBox(height: 20),
              const Text('Beispieldaten · September 2026'),
            ],
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Einstellungen',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 12),
                  Text('Hier werden deine Einstellungen verfügbar sein.'),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: AppBottomNavigationBar(
      selectedIndex: _selectedIndex,
      onItemSelected: (index) => setState(() => _selectedIndex = index),
    ),
  );
}
